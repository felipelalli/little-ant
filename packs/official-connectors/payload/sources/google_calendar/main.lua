local api_root = "https://www.googleapis.com/calendar/v3"

local function require_string(value, label)
  if type(value) ~= "string" or value == "" then
    error(label .. " must be a nonempty string")
  end
  return value
end

local function validate_source(source)
  if type(source) ~= "table" then error("source must be an object") end
  local expected = {provider = true, account_id = true, account_label = true}
  for key, _ in pairs(source) do
    if not expected[key] then error("unknown Google Calendar source field: " .. tostring(key)) end
  end
  if source.provider ~= "google_calendar" then error("provider must be google_calendar") end
  require_string(source.account_id, "account_id")
  require_string(source.account_label, "account_label")
end

local function selected_calendars(request)
  if type(request.selected_containers) ~= "table" then
    error("selected_containers must be an array")
  end
  local selected = {}
  for index, external_id in ipairs(request.selected_containers) do
    require_string(external_id, "selected_containers[" .. tostring(index) .. "]")
    local calendar_id = string.match(external_id, "^calendar:(.+)$")
    if calendar_id == nil then error("selected container is not a Google Calendar identity") end
    if selected[calendar_id] then error("selected_containers must be unique") end
    selected[calendar_id] = true
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
    if type(response.json) ~= "table" then error(label .. " response is not a Google Calendar collection") end
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

local function frame(value)
  return tostring(#value) .. ":" .. value
end

local function original_start(event)
  local original = event.originalStartTime
  if original == nil then return "", "", "" end
  if type(original) ~= "table" then error("event originalStartTime must be an object") end
  local date = original.date
  local date_time = original.dateTime
  if date ~= nil and date_time ~= nil then error("event originalStartTime cannot contain both date and dateTime") end
  local zone = original.timeZone
  if zone == nil then zone = "" else require_string(zone, "event originalStartTime timeZone") end
  if date ~= nil then return "date", require_string(date, "event originalStartTime date"), zone end
  if date_time ~= nil then return "date_time", require_string(date_time, "event originalStartTime dateTime"), zone end
  error("event originalStartTime must contain date or dateTime")
end

local function encoded_event_identity(calendar_id, event)
  local event_id = require_string(event.id, "event id")
  local recurring_id = event.recurringEventId
  if recurring_id == nil then recurring_id = "" else require_string(recurring_id, "event recurringEventId") end
  local original_kind, original_value, original_zone = original_start(event)
  return "event:" .. frame(calendar_id) .. frame(event_id) .. frame(recurring_id)
    .. frame(original_kind) .. frame(original_value) .. frame(original_zone)
end

local function event_locator(source, calendar_id, event)
  local locator = "google-calendar://" .. lant.url.encode_path_segment(source.account_id)
    .. "/calendars/" .. lant.url.encode_path_segment(calendar_id)
    .. "/events/" .. lant.url.encode_path_segment(require_string(event.id, "event id"))
  local recurring_id = event.recurringEventId
  local original_kind, original_value = original_start(event)
  if recurring_id ~= nil then
    locator = locator .. "?recurring_event_id=" .. lant.url.encode_query_component(require_string(recurring_id, "event recurringEventId"))
      .. "&original_start_kind=" .. lant.url.encode_query_component(original_kind)
      .. "&original_start=" .. lant.url.encode_query_component(original_value)
  end
  return locator
end

local function normalized_title(title)
  local value = string.lower(title)
  value = string.gsub(value, "%s+", " ")
  value = string.gsub(value, "^%s+", "")
  return string.gsub(value, "%s+$", "")
end

local function attachment_count(event)
  if event.attachments == nil then return 0 end
  if type(event.attachments) ~= "table" then error("event attachments must be an array") end
  local count = 0
  for _, attachment in ipairs(event.attachments) do
    if type(attachment) ~= "table" then error("event attachments contains a non-object value") end
    count = count + 1
  end
  return count
end

local function event_facts(event)
  local recurring = event.recurringEventId ~= nil
  if recurring then require_string(event.recurringEventId, "event recurringEventId") end
  local all_day = false
  if event.start ~= nil then
    if type(event.start) ~= "table" then error("event start must be an object") end
    if event.start.date ~= nil and event.start.dateTime ~= nil then
      error("event start cannot contain both date and dateTime")
    end
    if event.start.date ~= nil then
      require_string(event.start.date, "event start date")
      all_day = true
    elseif event.start.dateTime ~= nil then
      require_string(event.start.dateTime, "event start dateTime")
    end
  end
  return recurring, all_day, event.status == "cancelled"
end

local function source_object(source, calendar, event)
  local calendar_id = require_string(calendar.id, "calendar id")
  local title = event.summary
  if type(title) ~= "string" or title == "" then title = "Untitled Google Calendar event" end
  local external_id = encoded_event_identity(calendar_id, event)
  local original_kind, original_value, original_zone = original_start(event)
  local snapshot = {
    schema = "google-calendar/event@1",
    provider = "google_calendar",
    account_id = source.account_id,
    identity = {
      calendar_id = calendar_id,
      event_id = event.id,
      recurring_event_id = event.recurringEventId or "",
      original_start_kind = original_kind,
      original_start = original_value,
      original_start_time_zone = original_zone
    },
    calendar = calendar,
    event = event
  }
  local duplicate_keys = {"google_calendar:" .. source.account_id .. ":" .. external_id}
  local title_key = normalized_title(title)
  if title_key ~= "" then table.insert(duplicate_keys, "title:" .. title_key) end
  return {
    external_id = external_id,
    locator = event_locator(source, calendar_id, event),
    container_id = "calendar:" .. calendar_id,
    title = title,
    shape = "other",
    completed = false,
    attachment_count = attachment_count(event),
    content = {kind = "structured", schema = "google-calendar/event@1", json = lant.json.encode(snapshot)},
    duplicate_keys = duplicate_keys
  }
end

return function(request)
  if request.schema ~= "little-ant/source-provider-request@1" then
    error("unsupported source provider request schema")
  end
  if request.mode ~= "snapshot" and request.mode ~= "synchronize" then
    error("Google Calendar supports snapshot and synchronize")
  end

  local source = request.source
  validate_source(source)
  local selected = selected_calendars(request)
  local all_calendars = paged_items(
    api_root .. "/users/me/calendarList?maxResults=250&minAccessRole=reader&showDeleted=false&showHidden=true",
    "Google Calendar calendar list"
  )
  local available = {}
  local selected_values = {}
  for _, calendar in ipairs(all_calendars) do
    local calendar_id = require_string(calendar.id, "calendar id")
    local label = calendar.summary
    if type(label) ~= "string" or label == "" then label = calendar_id end
    available[calendar_id] = calendar
    if selected[calendar_id] then table.insert(selected_values, calendar) end
  end
  for calendar_id, _ in pairs(selected) do
    if available[calendar_id] == nil then error("selected Google Calendar was not found: " .. calendar_id) end
  end

  local discovery = next(selected) == nil
  local visible = discovery and all_calendars or selected_values
  table.sort(visible, function(left, right) return left.id < right.id end)
  local containers = {}
  for _, calendar in ipairs(visible) do
    local label = calendar.summary
    if type(label) ~= "string" or label == "" then label = calendar.id end
    table.insert(containers, {external_id = "calendar:" .. calendar.id, label = label})
  end

  local objects = {}
  local cancelled_count = 0
  local recurring_count = 0
  local all_day_count = 0
  if not discovery then
    for _, calendar in ipairs(visible) do
      local calendar_id = calendar.id
      local events = paged_items(
        api_root .. "/calendars/" .. lant.url.encode_path_segment(calendar_id)
          .. "/events?maxResults=2500&showDeleted=true&showHiddenInvitations=false&singleEvents=false",
        "Google Calendar events"
      )
      for _, event in ipairs(events) do
        local recurring, all_day, cancelled = event_facts(event)
        if recurring then recurring_count = recurring_count + 1 end
        if all_day then all_day_count = all_day_count + 1 end
        if cancelled then cancelled_count = cancelled_count + 1 end
        table.insert(objects, source_object(source, calendar, event))
      end
    end
    table.sort(objects, function(left, right) return left.external_id < right.external_id end)
  end

  return {
    source_label = "Google Calendar",
    account_label = source.account_label,
    identity = {
      provider = "google_calendar",
      account_id = source.account_id,
      discovery = discovery and "true" or "false",
      calendar_count = tostring(#containers),
      event_count = tostring(#objects),
      cancelled_event_count = tostring(cancelled_count),
      recurring_event_count = tostring(recurring_count),
      all_day_event_count = tostring(all_day_count)
    },
    supported_modes = {"snapshot", "synchronize"},
    cleanup_supported = false,
    containers = containers,
    objects = objects,
    unsupported_fields = {},
    warnings = {}
  }
end
