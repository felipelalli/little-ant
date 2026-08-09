local graph_root = "https://graph.microsoft.com/v1.0/me/todo"

local function require_string(value, label)
  if type(value) ~= "string" or value == "" then
    error(label .. " must be a nonempty string")
  end
  return value
end

local function require_boolean(value, label)
  if type(value) ~= "boolean" then
    error(label .. " must be a boolean")
  end
  return value
end

local function validate_source(source)
  if type(source) ~= "table" then error("source must be an object") end
  local expected = {
    provider = true,
    account_id = true,
    account_label = true,
    include_completed = true,
    allow_incomplete_attachments = true,
    list_ids = true
  }
  for key, _ in pairs(source) do
    if not expected[key] then error("unknown Microsoft To Do source field: " .. tostring(key)) end
  end
  if source.provider ~= "microsoft_todo" then error("provider must be microsoft_todo") end
  require_string(source.account_id, "account_id")
  require_string(source.account_label, "account_label")
  require_boolean(source.include_completed, "include_completed")
  require_boolean(source.allow_incomplete_attachments, "allow_incomplete_attachments")
  if type(source.list_ids) ~= "table" then error("list_ids must be an array") end
  local selected = {}
  for index, list_id in ipairs(source.list_ids) do
    require_string(list_id, "list_ids[" .. tostring(index) .. "]")
    if selected[list_id] then error("list_ids must be unique") end
    selected[list_id] = true
  end
  return selected
end

local function cleanup_target(source, target)
  validate_source(source)
  if type(target) ~= "table" then error("cleanup target must be an object") end
  local expected = {external_identity = true, locator = true, container_identity = true}
  for key, _ in pairs(target) do
    if not expected[key] then error("unknown Microsoft To Do cleanup target field: " .. tostring(key)) end
  end
  local external_identity = require_string(target.external_identity, "external_identity")
  local locator = require_string(target.locator, "locator")
  local container_identity = require_string(target.container_identity, "container_identity")
  local list_id, task_id = string.match(external_identity, "^task:([^:]+):(.+)$")
  if list_id == nil or task_id == nil then error("external_identity is not a Microsoft To Do task identity") end
  if container_identity ~= "list:" .. list_id then error("cleanup container identity does not match the task identity") end
  local expected_locator = "microsoft-todo://" .. lant.url.encode_path_segment(source.account_id)
    .. "/lists/" .. lant.url.encode_path_segment(list_id)
    .. "/tasks/" .. lant.url.encode_path_segment(task_id)
  if locator ~= expected_locator then error("cleanup locator does not match the exact provider target") end

  local url = graph_root .. "/lists/" .. lant.url.encode_path_segment(list_id)
    .. "/tasks/" .. lant.url.encode_path_segment(task_id)
  return url, task_id
end

local function cleanup_item(source, target)
  local url, task_id = cleanup_target(source, target)
  local response = lant.http.request({method = "DELETE", url = url, headers = {accept = "application/json"}})
  local provider_reference = "Microsoft To Do task " .. task_id
  if response.status == 204 then
    return {outcome = "succeeded", provider_reference = provider_reference, redacted_detail = "Deleted from Microsoft To Do."}
  end
  if response.status == 404 then
    return {outcome = "succeeded", provider_reference = provider_reference, redacted_detail = "Already absent from Microsoft To Do."}
  end
  if response.status == 429 or response.status >= 500 then
    return {outcome = "failed_retryable", provider_reference = provider_reference, redacted_detail = "Microsoft Graph returned HTTP " .. tostring(response.status) .. "."}
  end
  return {outcome = "failed_terminal", provider_reference = provider_reference, redacted_detail = "Microsoft Graph returned HTTP " .. tostring(response.status) .. "."}
end

local function verify_cleanup_item(source, target)
  local url, task_id = cleanup_target(source, target)
  local response = lant.http.request({method = "GET", url = url, headers = {accept = "application/json"}})
  local provider_reference = "Microsoft To Do task " .. task_id
  if response.status == 404 then
    return {outcome = "succeeded", provider_reference = provider_reference, redacted_detail = "Verified absent from Microsoft To Do."}
  end
  if response.status == 200 then
    return {outcome = "failed_retryable", provider_reference = provider_reference, redacted_detail = "Verified still present in Microsoft To Do."}
  end
  return {outcome = "outcome_unknown", provider_reference = provider_reference, redacted_detail = "Microsoft Graph verification returned HTTP " .. tostring(response.status) .. "."}
end

local function collection(url, label)
  local values = {}
  local next_url = url
  while next_url ~= nil do
    require_string(next_url, label .. " page URL")
    local response = lant.http.request({
      method = "GET",
      url = next_url,
      headers = {accept = "application/json"}
    })
    if response.status ~= 200 then
      error(label .. " request failed with HTTP " .. tostring(response.status))
    end
    if type(response.json) ~= "table" or type(response.json.value) ~= "table" then
      error(label .. " response is not a Microsoft Graph collection")
    end
    for _, value in ipairs(response.json.value) do
      if type(value) ~= "table" then error(label .. " contains a non-object value") end
      table.insert(values, value)
    end
    next_url = response.json["@odata.nextLink"]
    if next_url ~= nil and type(next_url) ~= "string" then
      error(label .. " @odata.nextLink must be a string")
    end
  end
  return values
end

local function normalized_title(title)
  local value = string.lower(title)
  value = string.gsub(value, "%s+", " ")
  value = string.gsub(value, "^%s+", "")
  return string.gsub(value, "%s+$", "")
end

local function attachment_facts(task)
  local known = task.attachments
  if type(known) == "table" then
    local bodies_missing = 0
    for _, attachment in ipairs(known) do
      if type(attachment) ~= "table" or type(attachment.contentBytes) ~= "string" then
        bodies_missing = bodies_missing + 1
      end
    end
    return #known, bodies_missing > 0
  end
  if task.hasAttachments == true then return 0, true end
  return 0, false
end

local function source_object(source, list, task)
  local list_id = require_string(list.id, "list id")
  local task_id = require_string(task.id, "task id")
  local title = task.title
  if type(title) ~= "string" or title == "" then title = "Untitled Microsoft To Do task" end
  local external_id = "task:" .. list_id .. ":" .. task_id
  local attachment_count, missing_attachment_bodies = attachment_facts(task)
  local snapshot = {
    schema = "microsoft-graph/todo-task@1",
    provider = "microsoft_todo",
    account_id = source.account_id,
    list = list,
    task = task,
    attachment_materialization = missing_attachment_bodies and "metadata_only" or "complete"
  }
  local duplicate_keys = {"microsoft_todo:" .. source.account_id .. ":" .. list_id .. ":" .. task_id}
  local title_key = normalized_title(title)
  if title_key ~= "" then table.insert(duplicate_keys, "title:" .. title_key) end
  return {
    external_id = external_id,
    locator = "microsoft-todo://" .. lant.url.encode_path_segment(source.account_id)
      .. "/lists/" .. lant.url.encode_path_segment(list_id)
      .. "/tasks/" .. lant.url.encode_path_segment(task_id),
    container_id = "list:" .. list_id,
    title = title,
    shape = "task",
    completed = task.status == "completed",
    attachment_count = attachment_count,
    content = {
      kind = "structured",
      schema = "microsoft-graph/todo-task@1",
      json = lant.json.encode(snapshot)
    },
    duplicate_keys = duplicate_keys
  }, missing_attachment_bodies
end

return function(request)
  if request.schema == "little-ant/source-cleanup-item-request@1" then
    return cleanup_item(request.source, request.target)
  end
  if request.schema == "little-ant/source-cleanup-item-verify-request@1" then
    return verify_cleanup_item(request.source, request.target)
  end
  if request.schema ~= "little-ant/source-provider-request@1" then
    error("unsupported source provider request schema")
  end
  if request.mode ~= "snapshot" and request.mode ~= "synchronize" and request.mode ~= "migrate" then
    error("Microsoft To Do supports snapshot, synchronize, and migrate")
  end

  local source = request.source
  local selected = validate_source(source)
  local all_lists = collection(graph_root .. "/lists", "Microsoft To Do lists")
  local selected_lists = {}
  local found = {}
  for _, list in ipairs(all_lists) do
    local list_id = require_string(list.id, "list id")
    require_string(list.displayName, "list displayName")
    if next(selected) == nil or selected[list_id] then
      table.insert(selected_lists, list)
      found[list_id] = true
    end
  end
  for list_id, _ in pairs(selected) do
    if not found[list_id] then error("selected Microsoft To Do list was not found: " .. list_id) end
  end
  table.sort(selected_lists, function(left, right) return left.id < right.id end)

  local containers = {}
  local objects = {}
  local open_count = 0
  local completed_count = 0
  local deferred_attachment_tasks = 0
  for _, list in ipairs(selected_lists) do
    local list_id = list.id
    table.insert(containers, {external_id = "list:" .. list_id, label = list.displayName})
    local tasks_url = graph_root .. "/lists/" .. lant.url.encode_path_segment(list_id) .. "/tasks"
    local tasks = collection(tasks_url, "Microsoft To Do tasks")
    for _, task in ipairs(tasks) do
      local completed = task.status == "completed"
      if completed then completed_count = completed_count + 1 else open_count = open_count + 1 end
      if source.include_completed or not completed then
        local object, attachment_bodies_missing = source_object(source, list, task)
        table.insert(objects, object)
        if attachment_bodies_missing then deferred_attachment_tasks = deferred_attachment_tasks + 1 end
      end
    end
  end
  table.sort(objects, function(left, right) return left.external_id < right.external_id end)

  if request.mode == "migrate" and deferred_attachment_tasks > 0 and not source.allow_incomplete_attachments then
    error("migrate requires explicit allow_incomplete_attachments because Microsoft To Do attachment bodies were not materialized")
  end

  local unsupported_fields = {}
  local warnings = {}
  if deferred_attachment_tasks > 0 then
    table.insert(unsupported_fields, tostring(deferred_attachment_tasks) .. " tasks have attachment bodies that were not materialized")
    table.insert(warnings, "Attachment metadata remains in structured task Raw material, but some attachment bodies were not imported")
  end
  table.insert(unsupported_fields, "checklistItems and linkedResources are preserved only when Microsoft Graph includes them in the task response")

  return {
    source_label = "Microsoft To Do",
    account_label = source.account_label,
    identity = {
      provider = "microsoft_todo",
      account_id = source.account_id,
      list_count = tostring(#selected_lists),
      open_item_count = tostring(open_count),
      completed_item_count = tostring(completed_count),
      included_item_count = tostring(#objects),
      deferred_attachment_task_count = tostring(deferred_attachment_tasks)
    },
    supported_modes = {"snapshot", "synchronize", "migrate"},
    cleanup_supported = true,
    containers = containers,
    objects = objects,
    unsupported_fields = unsupported_fields,
    warnings = warnings
  }
end
