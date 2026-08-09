local function require_projection(projection)
  if type(projection) ~= "table" or projection.schema ~= "little-ant/taskjuggler@1" then
    error("taskjuggler requires little-ant/taskjuggler@1")
  end
  local payload = projection.payload
  if type(payload) ~= "table"
      or type(payload.project) ~= "table"
      or type(payload.tasks) ~= "table"
      or type(payload.manifest) ~= "table"
      or type(payload.manifest_digest) ~= "string"
      or type(payload.manifest_jcs_base64url) ~= "string"
      or type(payload.warnings) ~= "table" then
    error("taskjuggler received an invalid planning payload")
  end
  return payload
end

local function quote(value)
  value = tostring(value or "")
  value = string.gsub(value, "\\", "\\\\")
  value = string.gsub(value, '"', '\\"')
  value = string.gsub(value, "\r", "")
  value = string.gsub(value, "\n", "\\n")
  return '"' .. value .. '"'
end

local function append(lines, value)
  table.insert(lines, value)
end

local function integer(value)
  if type(value) ~= "number" or value ~= math.floor(value) then error("taskjuggler expected an integer") end
  return string.format("%.0f", value)
end

local function microhours(value)
  if type(value) ~= "string" or not string.match(value, "^%d+$") or (#value > 1 and string.sub(value, 1, 1) == "0") then
    error("taskjuggler expected canonical microhours")
  end
  local padded = value
  if #padded < 7 then padded = string.rep("0", 7 - #padded) .. padded end
  local whole = string.sub(padded, 1, #padded - 6)
  local fraction = string.gsub(string.sub(padded, #padded - 5), "0+$", "")
  if fraction == "" then return whole .. "h" end
  return whole .. "." .. fraction .. "h"
end

local function utc_taskjuggler(value)
  local year, month, day, hour, minute = string.match(value.utc or "", "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):%d%dZ$")
  if year == nil then error("taskjuggler received an invalid UTC instant") end
  return year .. "-" .. month .. "-" .. day .. "-" .. hour .. ":" .. minute
end

local function emit_manifest(lines, payload)
  append(lines, "# Generated from an immutable Little Ant planning manifest.")
  append(lines, "# LANT-MANIFEST-SHA256: " .. payload.manifest_digest)
  local encoded = payload.manifest_jcs_base64url
  local width = 160
  local sequence = 1
  for offset = 1, #encoded, width do
    append(lines, string.format("# LANT-MANIFEST-JCS-BASE64URL-%04d: %s", sequence, string.sub(encoded, offset, offset + width - 1)))
    sequence = sequence + 1
  end
  append(lines, "")
end

local function emit_project(lines, project)
  append(lines, "project " .. project.id .. " " .. quote(project.name) .. " " .. quote(project.version) .. " " .. project.start .. " +10y {")
  append(lines, "  timezone " .. quote(project.timezone))
  append(lines, "  now ${projectstart}")
  append(lines, "  scenario plan " .. quote("Realistic") .. " {")
  append(lines, "    scenario optimistic " .. quote("Optimistic"))
  append(lines, "    scenario pessimistic " .. quote("Pessimistic"))
  append(lines, "    scenario actual " .. quote("Actual"))
  append(lines, "  }")
  append(lines, "  trackingscenario actual")
  append(lines, "}")
  append(lines, "")
end

local function emit_effort_macros(lines, manifest)
  local macros = manifest.effort_profile and manifest.effort_profile.macros or {}
  for _, effort in ipairs(macros) do
    append(lines, "macro " .. effort.macro .. " [")
    append(lines, "  effort " .. integer(effort.realistic_hours) .. "h")
    append(lines, "  optimistic:effort " .. integer(effort.optimistic_hours) .. "h")
    append(lines, "  pessimistic:effort " .. integer(effort.pessimistic_hours) .. "h")
    append(lines, "]")
    append(lines, "")
  end
end

local function emit_factory_resource(lines)
  append(lines, "shift factory_utc " .. quote("Factory UTC workday") .. " {")
  append(lines, "  timezone " .. quote("UTC"))
  append(lines, "  workinghours mon-fri 09:00-15:00")
  append(lines, "}")
  append(lines, "")
  append(lines, "resource me " .. quote("Little Ant user") .. " {")
  append(lines, "  shifts factory_utc")
  append(lines, "  limits { dailymax 6h }")
  append(lines, "}")
  append(lines, "")
end

local function emit_release(lines, task)
  if task.not_before == nil then return nil end
  local release_id = "release_" .. task.id
  append(lines, "task " .. release_id .. " " .. quote("Release " .. task.handle) .. " {")
  append(lines, "  start " .. utc_taskjuggler(task.not_before))
  append(lines, "  milestone")
  append(lines, "}")
  append(lines, "")
  return release_id
end

local function emit_task(lines, task, release_id)
  append(lines, "# LANT-BRICK: " .. task.brick_id)
  if task.effort ~= nil then append(lines, "# LANT-EFFORT-MACRO: " .. task.effort.macro) end
  if task.remaining_effort ~= nil then append(lines, "# LANT-REMAINING-AS-OF: " .. task.remaining_effort.as_of) end
  if task.best_before ~= nil then append(lines, "# LANT-BEST-BEFORE: " .. task.best_before.utc .. " [advisory]") end
  append(lines, "task " .. task.id .. " " .. quote(task.title) .. " {")
  append(lines, "  priority " .. integer(task.taskjuggler_priority))

  local interval = task.scheduled_interval
  if interval ~= nil then
    append(lines, "  start " .. utc_taskjuggler(interval.starts_at))
    append(lines, "  end " .. utc_taskjuggler(interval.ends_at))
  elseif task.remaining_effort ~= nil then
    local remaining = microhours(task.remaining_effort.microhours)
    append(lines, "  effort " .. remaining)
    append(lines, "  optimistic:effort " .. remaining)
    append(lines, "  pessimistic:effort " .. remaining)
    append(lines, "  allocate me")
  elseif task.effort ~= nil then
    append(lines, "  ${" .. task.effort.macro .. "}")
    append(lines, "  allocate me")
  else
    append(lines, "  # No effort was recorded; no duration has been invented.")
  end

  if task.deadline ~= nil then append(lines, "  maxend " .. utc_taskjuggler(task.deadline)) end

  local dependencies = {}
  for _, dependency in ipairs(task.dependencies or {}) do table.insert(dependencies, dependency) end
  if release_id ~= nil then table.insert(dependencies, release_id) end
  if #dependencies > 0 then append(lines, "  depends " .. table.concat(dependencies, ", ")) end

  append(lines, "}")
  append(lines, "")
end

local function warning_messages(warnings)
  local messages = {}
  for _, warning in ipairs(warnings) do
    local suffix = ""
    if type(warning.brick_ids) == "table" and #warning.brick_ids > 0 then
      suffix = " [" .. table.concat(warning.brick_ids, ", ") .. "]"
    end
    table.insert(messages, warning.code .. ": " .. warning.message .. suffix)
  end
  return messages
end

return function(projection)
  local payload = require_projection(projection)
  local lines = {}
  emit_manifest(lines, payload)
  emit_project(lines, payload.project)
  emit_effort_macros(lines, payload.manifest)
  emit_factory_resource(lines)

  local releases = {}
  for _, task in ipairs(payload.tasks) do releases[task.id] = emit_release(lines, task) end
  for _, task in ipairs(payload.tasks) do emit_task(lines, task, releases[task.id]) end

  append(lines, "taskreport schedule " .. quote("Little Ant planning cut") .. " {")
  append(lines, "  formats csv")
  append(lines, "  columns id, name, start, end, effort, priority")
  append(lines, "  scenarios plan, optimistic, pessimistic")
  append(lines, "}")

  return {
    bytes = table.concat(lines, "\n") .. "\n",
    media_type = "text/x-taskjuggler; charset=utf-8",
    suggested_filename = "little-ant.tjp",
    warnings = warning_messages(payload.warnings),
    metadata = {
      format = "taskjuggler",
      projection = projection.schema,
      planning_manifest_sha256 = payload.manifest_digest,
      source_cursor = projection.dataset_cursor
    }
  }
end
