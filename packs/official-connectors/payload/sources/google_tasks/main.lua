local api_root = "https://tasks.googleapis.com/tasks/v1"

local function require_string(value, label)
  if type(value) ~= "string" or value == "" then
    error(label .. " must be a nonempty string")
  end
  return value
end

local function require_boolean(value, label)
  if type(value) ~= "boolean" then error(label .. " must be a boolean") end
  return value
end

local function validate_source(source)
  if type(source) ~= "table" then error("source must be an object") end
  local expected = {
    provider = true,
    account_id = true,
    account_label = true,
    include_completed = true,
    list_ids = true
  }
  for key, _ in pairs(source) do
    if not expected[key] then error("unknown Google Tasks source field: " .. tostring(key)) end
  end
  if source.provider ~= "google_tasks" then error("provider must be google_tasks") end
  require_string(source.account_id, "account_id")
  require_string(source.account_label, "account_label")
  require_boolean(source.include_completed, "include_completed")
  if type(source.list_ids) ~= "table" then error("list_ids must be an array") end
  local selected = {}
  for index, list_id in ipairs(source.list_ids) do
    require_string(list_id, "list_ids[" .. tostring(index) .. "]")
    if selected[list_id] then error("list_ids must be unique") end
    selected[list_id] = true
  end
  return selected
end

local function with_page_token(url, token)
  if token == nil then return url end
  require_string(token, "nextPageToken")
  return url .. "&pageToken=" .. lant.url.encode_query_component(token)
end

local function paged_items(url, label)
  local values = {}
  local token = nil
  repeat
    local response = lant.http.request({
      method = "GET",
      url = with_page_token(url, token),
      headers = {accept = "application/json"}
    })
    if response.status ~= 200 then error(label .. " request failed with HTTP " .. tostring(response.status)) end
    if type(response.json) ~= "table" then error(label .. " response is not a Google Tasks collection") end
    local items = response.json.items
    if items == nil then items = {} end
    if type(items) ~= "table" then error(label .. " items must be an array") end
    for _, value in ipairs(items) do
      if type(value) ~= "table" then error(label .. " contains a non-object value") end
      table.insert(values, value)
    end
    token = response.json.nextPageToken
    if token ~= nil then require_string(token, label .. " nextPageToken") end
  until token == nil
  return values
end

local function encoded_task_identity(list_id, task_id)
  return "task:" .. tostring(#list_id) .. ":" .. list_id .. task_id
end

local function parse_task_identity(identity)
  local length_text, remainder = string.match(identity, "^task:(%d+):(.*)$")
  local list_length = tonumber(length_text)
  if list_length == nil or list_length < 1 or #remainder <= list_length then
    error("external_identity is not a Google Tasks task identity")
  end
  return string.sub(remainder, 1, list_length), string.sub(remainder, list_length + 1)
end

local function task_locator(source, list_id, task_id)
  return "google-tasks://" .. lant.url.encode_path_segment(source.account_id)
    .. "/lists/" .. lant.url.encode_path_segment(list_id)
    .. "/tasks/" .. lant.url.encode_path_segment(task_id)
end

local function task_url(list_id, task_id)
  return api_root .. "/lists/" .. lant.url.encode_path_segment(list_id)
    .. "/tasks/" .. lant.url.encode_path_segment(task_id)
end

local function cleanup_target(source, target)
  validate_source(source)
  if type(target) ~= "table" then error("cleanup target must be an object") end
  local expected = {external_identity = true, locator = true, container_identity = true}
  for key, _ in pairs(target) do
    if not expected[key] then error("unknown Google Tasks cleanup target field: " .. tostring(key)) end
  end
  local external_identity = require_string(target.external_identity, "external_identity")
  local locator = require_string(target.locator, "locator")
  local container_identity = require_string(target.container_identity, "container_identity")
  local list_id, task_id = parse_task_identity(external_identity)
  if container_identity ~= "list:" .. list_id then error("cleanup container identity does not match the task identity") end
  if locator ~= task_locator(source, list_id, task_id) then error("cleanup locator does not match the exact provider target") end
  return task_url(list_id, task_id), task_id
end

local function cleanup_item(source, target)
  local url, task_id = cleanup_target(source, target)
  local response = lant.http.request({method = "DELETE", url = url, headers = {accept = "application/json"}})
  local provider_reference = "Google Task " .. task_id
  if response.status == 204 or response.status == 404 then
    return {outcome = "succeeded", provider_reference = provider_reference, redacted_detail = response.status == 204 and "Deleted from Google Tasks." or "Already absent from Google Tasks."}
  end
  if response.status == 429 or response.status >= 500 then
    return {outcome = "failed_retryable", provider_reference = provider_reference, redacted_detail = "Google Tasks returned HTTP " .. tostring(response.status) .. "."}
  end
  return {outcome = "failed_terminal", provider_reference = provider_reference, redacted_detail = "Google Tasks returned HTTP " .. tostring(response.status) .. "."}
end

local function verify_cleanup_item(source, target)
  local url, task_id = cleanup_target(source, target)
  local response = lant.http.request({method = "GET", url = url, headers = {accept = "application/json"}})
  local provider_reference = "Google Task " .. task_id
  if response.status == 404 then
    return {outcome = "succeeded", provider_reference = provider_reference, redacted_detail = "Verified absent from Google Tasks."}
  end
  if response.status == 200 then
    return {outcome = "failed_retryable", provider_reference = provider_reference, redacted_detail = "Verified still present in Google Tasks."}
  end
  return {outcome = "outcome_unknown", provider_reference = provider_reference, redacted_detail = "Google Tasks verification returned HTTP " .. tostring(response.status) .. "."}
end

local function cleanup_container_target(source, target)
  local selected = validate_source(source)
  if type(target) ~= "table" then error("container cleanup target must be an object") end
  for key, _ in pairs(target) do
    if key ~= "external_identity" then error("unknown Google Tasks container cleanup target field: " .. tostring(key)) end
  end
  local external_identity = require_string(target.external_identity, "external_identity")
  local list_id = string.match(external_identity, "^list:(.+)$")
  if list_id == nil then error("external_identity is not a Google Tasks list identity") end
  if next(selected) ~= nil and not selected[list_id] then error("container cleanup target is outside the configured Google Tasks list scope") end
  local encoded = lant.url.encode_path_segment(list_id)
  return list_id,
    api_root .. "/users/@me/lists/" .. encoded,
    api_root .. "/lists/" .. encoded .. "/tasks?maxResults=100&showAssigned=true&showCompleted=true&showDeleted=false&showHidden=true"
end

local function inspect_cleanup_container(source, target)
  local list_id, list_url, tasks_url = cleanup_container_target(source, target)
  local response = lant.http.request({method = "GET", url = list_url, headers = {accept = "application/json"}})
  local external_identity = "list:" .. list_id
  if response.status == 404 then
    return {external_identity = external_identity, label = list_id, outcome = "absent", item_count = -1, provider_version = "", redacted_detail = "The Google Tasks list is already absent."}
  end
  if response.status ~= 200 or type(response.json) ~= "table" then error("Google Tasks list inspection failed") end
  if require_string(response.json.id, "task list id") ~= list_id then error("Google Tasks list inspection returned a different identity") end
  local label = require_string(response.json.title, "task list title")
  local provider_version = response.json.etag
  if provider_version == nil then provider_version = "" end
  if type(provider_version) ~= "string" then error("task list etag must be a string") end

  local default_response = lant.http.request({method = "GET", url = api_root .. "/users/@me/lists/@default", headers = {accept = "application/json"}})
  if default_response.status ~= 200 or type(default_response.json) ~= "table" then
    error("Google Tasks default-list inspection failed; container deletion cannot be proven safe")
  end
  if require_string(default_response.json.id, "default task list id") == list_id then
    return {external_identity = external_identity, label = label, outcome = "protected", item_count = -1, provider_version = provider_version, redacted_detail = "The Google Tasks default list is protected."}
  end

  local tasks = paged_items(tasks_url, "Google Tasks container tasks")
  local count = #tasks
  return {
    external_identity = external_identity,
    label = label,
    outcome = count == 0 and "empty" or "nonempty",
    item_count = count,
    provider_version = provider_version,
    redacted_detail = count == 0 and "Verified empty in Google Tasks." or ("Google Tasks still contains " .. tostring(count) .. " task(s).")
  }
end

local function cleanup_container(source, target)
  local inspection = inspect_cleanup_container(source, target)
  local provider_reference = "Google Tasks list " .. inspection.label
  if inspection.outcome == "absent" then
    return {outcome = "succeeded", provider_reference = provider_reference, redacted_detail = "Already absent from Google Tasks."}
  end
  if inspection.outcome ~= "empty" then
    return {outcome = "failed_terminal", provider_reference = provider_reference, redacted_detail = inspection.redacted_detail .. " Nothing was deleted."}
  end
  local _, list_url = cleanup_container_target(source, target)
  local response = lant.http.request({method = "DELETE", url = list_url, headers = {accept = "application/json"}})
  if response.status == 204 or response.status == 404 then
    return {outcome = "succeeded", provider_reference = provider_reference, redacted_detail = response.status == 204 and "Deleted the verified empty list from Google Tasks." or "Already absent from Google Tasks."}
  end
  if response.status == 429 or response.status >= 500 then
    return {outcome = "failed_retryable", provider_reference = provider_reference, redacted_detail = "Google Tasks returned HTTP " .. tostring(response.status) .. "."}
  end
  return {outcome = "failed_terminal", provider_reference = provider_reference, redacted_detail = "Google Tasks returned HTTP " .. tostring(response.status) .. "."}
end

local function verify_cleanup_container(source, target)
  local list_id, list_url = cleanup_container_target(source, target)
  local response = lant.http.request({method = "GET", url = list_url, headers = {accept = "application/json"}})
  local provider_reference = "Google Tasks list " .. list_id
  if response.status == 404 then
    return {outcome = "succeeded", provider_reference = provider_reference, redacted_detail = "Verified absent from Google Tasks."}
  end
  if response.status == 200 then
    return {outcome = "failed_retryable", provider_reference = provider_reference, redacted_detail = "Verified still present in Google Tasks."}
  end
  return {outcome = "outcome_unknown", provider_reference = provider_reference, redacted_detail = "Google Tasks verification returned HTTP " .. tostring(response.status) .. "."}
end

local function normalized_title(title)
  local value = string.lower(title)
  value = string.gsub(value, "%s+", " ")
  value = string.gsub(value, "^%s+", "")
  return string.gsub(value, "%s+$", "")
end

local function source_object(source, list, task)
  local list_id = require_string(list.id, "task list id")
  local task_id = require_string(task.id, "task id")
  local title = task.title
  if type(title) ~= "string" or title == "" then title = "Untitled Google Task" end
  local external_id = encoded_task_identity(list_id, task_id)
  local snapshot = {
    schema = "google-tasks/task@1",
    provider = "google_tasks",
    account_id = source.account_id,
    task_list = list,
    task = task
  }
  local duplicate_keys = {"google_tasks:" .. source.account_id .. ":" .. external_id}
  local title_key = normalized_title(title)
  if title_key ~= "" then table.insert(duplicate_keys, "title:" .. title_key) end
  return {
    external_id = external_id,
    locator = task_locator(source, list_id, task_id),
    container_id = "list:" .. list_id,
    title = title,
    shape = "task",
    completed = task.status == "completed",
    attachment_count = 0,
    content = {kind = "structured", schema = "google-tasks/task@1", json = lant.json.encode(snapshot)},
    duplicate_keys = duplicate_keys
  }
end

return function(request)
  if request.schema == "little-ant/source-cleanup-item-request@1" then return cleanup_item(request.source, request.target) end
  if request.schema == "little-ant/source-cleanup-item-verify-request@1" then return verify_cleanup_item(request.source, request.target) end
  if request.schema == "little-ant/source-cleanup-container-inspect-request@1" then return inspect_cleanup_container(request.source, request.target) end
  if request.schema == "little-ant/source-cleanup-container-request@1" then return cleanup_container(request.source, request.target) end
  if request.schema == "little-ant/source-cleanup-container-verify-request@1" then return verify_cleanup_container(request.source, request.target) end
  if request.schema ~= "little-ant/source-provider-request@1" then error("unsupported source provider request schema") end
  if request.mode ~= "snapshot" and request.mode ~= "synchronize" and request.mode ~= "migrate" then
    error("Google Tasks supports snapshot, synchronize, and migrate")
  end

  local source = request.source
  local selected = validate_source(source)
  local all_lists = paged_items(api_root .. "/users/@me/lists?maxResults=1000", "Google Tasks task lists")
  local selected_lists = {}
  local found = {}
  for _, list in ipairs(all_lists) do
    local list_id = require_string(list.id, "task list id")
    require_string(list.title, "task list title")
    if next(selected) == nil or selected[list_id] then
      table.insert(selected_lists, list)
      found[list_id] = true
    end
  end
  for list_id, _ in pairs(selected) do
    if not found[list_id] then error("selected Google Tasks list was not found: " .. list_id) end
  end
  table.sort(selected_lists, function(left, right) return left.id < right.id end)

  local containers = {}
  local objects = {}
  local open_count = 0
  local completed_count = 0
  for _, list in ipairs(selected_lists) do
    local list_id = list.id
    table.insert(containers, {external_id = "list:" .. list_id, label = list.title})
    local completed = source.include_completed and "true" or "false"
    local hidden = source.include_completed and "true" or "false"
    local tasks_url = api_root .. "/lists/" .. lant.url.encode_path_segment(list_id)
      .. "/tasks?maxResults=100&showAssigned=false&showCompleted=" .. completed
      .. "&showDeleted=false&showHidden=" .. hidden
    local tasks = paged_items(tasks_url, "Google Tasks tasks")
    for _, task in ipairs(tasks) do
      local is_completed = task.status == "completed"
      if is_completed then completed_count = completed_count + 1 else open_count = open_count + 1 end
      if source.include_completed or not is_completed then table.insert(objects, source_object(source, list, task)) end
    end
  end
  table.sort(objects, function(left, right) return left.external_id < right.external_id end)

  return {
    source_label = "Google Tasks",
    account_label = source.account_label,
    identity = {
      provider = "google_tasks",
      account_id = source.account_id,
      list_count = tostring(#selected_lists),
      open_item_count = tostring(open_count),
      completed_item_count = tostring(completed_count),
      included_item_count = tostring(#objects)
    },
    supported_modes = {"snapshot", "synchronize", "migrate"},
    cleanup_supported = true,
    containers = containers,
    objects = objects,
    unsupported_fields = {"assigned tasks are excluded because deleting one may also delete its source task in Docs or Chat"},
    warnings = {}
  }
end
