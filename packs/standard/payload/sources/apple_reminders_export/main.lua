local top_keys = {
  schema = true,
  exported_at = true,
  identity_strategy = true,
  device_name = true,
  reminders = true
}

local reminder_keys = {
  id = true,
  list_id = true,
  list_title = true,
  title = true,
  completed = true,
  notes = true,
  due_kind = true,
  due_value = true,
  completed_at = true,
  priority = true,
  url = true,
  tags = true,
  flagged = true
}

local function fail(message)
  error(message, 0)
end

local function exact_keys(value, allowed, label)
  if type(value) ~= "table" then fail(label .. " must be an object") end
  for key, _ in pairs(value) do
    if type(key) ~= "string" or not allowed[key] then
      fail(label .. " contains an unknown field")
    end
  end
end

local function array(value, label)
  if type(value) ~= "table" then fail(label .. " must be an array") end
  local count = 0
  for key, _ in pairs(value) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      fail(label .. " must be an array")
    end
    count = count + 1
  end
  if count ~= #value then fail(label .. " must not contain holes") end
  return value
end

local function text(value, label, empty_allowed, maximum)
  if type(value) ~= "string" or (not empty_allowed and value == "") or #value > maximum then
    fail(label .. " is invalid")
  end
  return value
end

local function optional_text(value, label, maximum)
  if value ~= nil then text(value, label, true, maximum) end
end

local function iso_date(value)
  return type(value) == "string" and string.match(value, "^%d%d%d%d%-%d%d%-%d%d$") ~= nil
end

local function iso_instant(value)
  if type(value) ~= "string" or string.match(value, "^%d%d%d%d%-%d%d%-%d%dT") == nil then return false end
  return string.match(value, "Z$") ~= nil or string.match(value, "[+-]%d%d:%d%d$") ~= nil
end

local function validate_instant(value, label)
  if not iso_instant(value) then fail(label .. " must be an ISO 8601 instant with an offset") end
end

local function validate_reminder(reminder, index)
  local label = "reminder " .. tostring(index)
  exact_keys(reminder, reminder_keys, label)
  text(reminder.id, label .. " id", false, 2048)
  text(reminder.list_id, label .. " list_id", false, 2048)
  text(reminder.list_title, label .. " list_title", false, 2048)
  text(reminder.title, label .. " title", true, 2048)
  if type(reminder.completed) ~= "boolean" then fail(label .. " completed must be boolean") end
  optional_text(reminder.notes, label .. " notes", 8388608)
  optional_text(reminder.url, label .. " url", 8192)
  if reminder.flagged ~= nil and type(reminder.flagged) ~= "boolean" then fail(label .. " flagged must be boolean") end
  if reminder.priority ~= nil and reminder.priority ~= 0 and reminder.priority ~= 1 and reminder.priority ~= 5 and reminder.priority ~= 9 then
    fail(label .. " priority must be 0, 1, 5, or 9")
  end
  if (reminder.due_kind == nil) ~= (reminder.due_value == nil) then
    fail(label .. " due_kind and due_value must appear together")
  end
  if reminder.due_kind ~= nil then
    if reminder.due_kind == "date" then
      if not iso_date(reminder.due_value) then fail(label .. " due_value must be an ISO 8601 date") end
    elseif reminder.due_kind == "instant" then
      validate_instant(reminder.due_value, label .. " due_value")
    else
      fail(label .. " due_kind must be date or instant")
    end
  end
  if reminder.completed_at ~= nil then validate_instant(reminder.completed_at, label .. " completed_at") end
  if reminder.tags ~= nil then
    for tag_index, tag in ipairs(array(reminder.tags, label .. " tags")) do
      text(tag, label .. " tag " .. tostring(tag_index), false, 256)
    end
  end
end

return function(request)
  if request.schema ~= "little-ant/source-preflight-request@1" then fail("unsupported source request schema") end
  if request.mode ~= "snapshot" and request.mode ~= "migrate" then
    fail("Apple Reminders exports support only snapshot and migrate")
  end
  if request.input.media_type ~= "application/vnd.little-ant.apple-reminders+json" then
    fail("Apple Reminders input must use the versioned Shortcut JSON media type")
  end

  local bytes = lant.input_bytes()
  if #bytes ~= request.input.byte_count or lant.sha256(bytes) ~= request.input.digest then
    fail("host input custody does not match the request")
  end
  local export = lant.json.decode(bytes)
  exact_keys(export, top_keys, "Apple Reminders export")
  if export.schema ~= "little-ant/apple-reminders-export@1" then fail("unsupported Apple Reminders export schema") end
  validate_instant(export.exported_at, "exported_at")
  if export.identity_strategy ~= "apple_identifier" then fail("Apple identifiers are required for stable source identity") end
  optional_text(export.device_name, "device_name", 256)

  local objects = {}
  local containers_by_id = {}
  local object_ids = {}
  for index, reminder in ipairs(array(export.reminders, "reminders")) do
    validate_reminder(reminder, index)
    local external_id = "reminder:" .. reminder.id
    local container_id = "list:" .. reminder.list_id
    if object_ids[external_id] then fail("the export contains duplicate reminder identifiers") end
    object_ids[external_id] = true
    if containers_by_id[container_id] ~= nil and containers_by_id[container_id] ~= reminder.list_title then
      fail("one list identifier has conflicting titles")
    end
    containers_by_id[container_id] = reminder.list_title
    local canonical = lant.json.encode(reminder)
    table.insert(objects, {
      external_id = external_id,
      locator = "apple-reminders:" .. lant.url.encode_path_segment(reminder.list_id) .. "/" .. lant.url.encode_path_segment(reminder.id),
      container_id = container_id,
      title = reminder.title ~= "" and reminder.title or "Untitled Apple reminder",
      shape = "task",
      completed = reminder.completed,
      attachment_count = 0,
      content = {kind = "structured", schema = "little-ant/apple-reminder@1", json = canonical},
      duplicate_keys = {lant.sha256(canonical)}
    })
  end

  table.sort(objects, function(left, right) return left.external_id < right.external_id end)
  local container_ids = {}
  for container_id, _ in pairs(containers_by_id) do table.insert(container_ids, container_id) end
  table.sort(container_ids)
  local containers = {}
  for _, container_id in ipairs(container_ids) do
    table.insert(containers, {external_id = container_id, label = containers_by_id[container_id]})
  end

  local identity = {
    export_sha256 = request.input.digest,
    exported_at = export.exported_at,
    identity_strategy = export.identity_strategy,
    list_count = tostring(#containers),
    reminder_count = tostring(#objects)
  }
  if export.device_name ~= nil and export.device_name ~= "" then identity.device_name = export.device_name end

  return {
    source_label = "Apple Reminders Shortcut export",
    account_label = "",
    identity = identity,
    supported_modes = {"snapshot", "migrate"},
    cleanup_supported = false,
    containers = containers,
    objects = objects,
    unsupported_fields = {"recurrence rules, subtasks, attachments, and location alarms are not exported by this kit"},
    warnings = {}
  }
end
