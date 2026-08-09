local function projection_payload(projection)
  if type(projection) ~= "table" or projection.schema ~= "little-ant/structure@1" then
    error("csv requires little-ant/structure@1")
  end
  if type(projection.payload) ~= "table" or type(projection.payload.bricks) ~= "table" or type(projection.payload.domains) ~= "table" then
    error("csv received an invalid structural payload")
  end
  return projection.payload
end

local function csv(value)
  value = tostring(value or "")
  if string.find(value, '[",\r\n]') ~= nil then
    return '"' .. string.gsub(value, '"', '""') .. '"'
  end
  return value
end

local function domains_for(brick, domains)
  local values = {}
  for _, identity in ipairs(brick.domain_ids or {}) do
    table.insert(values, domains[identity] or identity)
  end
  return table.concat(values, " | ")
end

local function number_text(value)
  if type(value) == "number" and value == math.floor(value) then return string.format("%.0f", value) end
  return value
end

return function(projection)
  local payload = projection_payload(projection)
  local domains = {}
  for _, domain in ipairs(payload.domains) do domains[domain.id] = domain.path end

  local lines = {"id,handle,title,nature,parent_id,domains,sibling_position,status,work_state,phase,effort,impact_class,impact_maturity"}
  for _, brick in ipairs(payload.bricks) do
    local impact = brick.impact or {}
    local values = {
      csv(brick.id), csv(brick.handle), csv(brick.title), csv(brick.nature), csv(brick.parent_id),
      csv(domains_for(brick, domains)), csv(number_text(brick.sibling_position)), csv(brick.status),
      csv(brick.work_state), csv(brick.phase), csv(brick.effort), csv(impact.class), csv(impact.maturity)
    }
    table.insert(lines, table.concat(values, ","))
  end

  return {
    bytes = table.concat(lines, "\r\n") .. "\r\n",
    media_type = "text/csv; charset=utf-8",
    suggested_filename = "little-ant.csv",
    warnings = {},
    metadata = {format = "rfc4180-csv", projection = projection.schema}
  }
end
