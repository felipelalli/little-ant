local function projection_payload(projection)
  if type(projection) ~= "table" or projection.schema ~= "little-ant/structure@1" then
    error("table requires little-ant/structure@1")
  end
  if type(projection.payload) ~= "table" or type(projection.payload.bricks) ~= "table" or type(projection.payload.domains) ~= "table" then
    error("table received an invalid structural payload")
  end
  return projection.payload
end

local function cell(value)
  value = tostring(value or "")
  value = string.gsub(value, "[\r\n\t]", " ")
  return value
end

local function domain_text(brick, domains)
  local values = {}
  for _, identity in ipairs(brick.domain_ids or {}) do
    table.insert(values, domains[identity] or identity)
  end
  return table.concat(values, "; ")
end

local function codepoint(value, index)
  local first = string.byte(value, index)
  if first < 0x80 then return first, index + 1 end
  if first < 0xe0 then
    return (first - 0xc0) * 0x40 + string.byte(value, index + 1) - 0x80, index + 2
  end
  if first < 0xf0 then
    return (first - 0xe0) * 0x1000 + (string.byte(value, index + 1) - 0x80) * 0x40 + string.byte(value, index + 2) - 0x80, index + 3
  end
  return (first - 0xf0) * 0x40000 + (string.byte(value, index + 1) - 0x80) * 0x1000 + (string.byte(value, index + 2) - 0x80) * 0x40 + string.byte(value, index + 3) - 0x80, index + 4
end

local function display_width(value)
  local width, index = 0, 1
  while index <= #value do
    local point
    point, index = codepoint(value, index)
    if (point >= 0x300 and point <= 0x36f) or (point >= 0xfe00 and point <= 0xfe0f) then
      width = width
    elseif (point >= 0x1100 and point <= 0x115f)
      or (point >= 0x2e80 and point <= 0xa4cf)
      or (point >= 0xac00 and point <= 0xd7a3)
      or (point >= 0xf900 and point <= 0xfaff)
      or (point >= 0xfe10 and point <= 0xfe6f)
      or (point >= 0xff00 and point <= 0xff60)
      or (point >= 0x1f300 and point <= 0x1faff) then
      width = width + 2
    else
      width = width + 1
    end
  end
  return width
end

return function(projection)
  local payload = projection_payload(projection)
  local domains = {}
  for _, domain in ipairs(payload.domains) do domains[domain.id] = domain.path end

  local rows = {{"brick", "title", "nature", "phase", "state", "domains"}}
  for _, brick in ipairs(payload.bricks) do
    table.insert(rows, {
      cell(brick.handle), cell(brick.title), cell(brick.nature),
      cell(brick.phase), cell(brick.work_state), cell(domain_text(brick, domains))
    })
  end

  local widths = {0, 0, 0, 0, 0, 0}
  for _, row in ipairs(rows) do
    for column, value in ipairs(row) do widths[column] = math.max(widths[column], display_width(value)) end
  end
  local function render(row)
    local values = {}
    for column, value in ipairs(row) do
      values[column] = value .. string.rep(" ", widths[column] - display_width(value))
    end
    return table.concat(values, "  ")
  end

  local lines = {render(rows[1])}
  local rule = {}
  for column, width in ipairs(widths) do rule[column] = string.rep("-", width) end
  table.insert(lines, render(rule))
  for index = 2, #rows do table.insert(lines, render(rows[index])) end

  return {
    bytes = table.concat(lines, "\n") .. "\n",
    media_type = "text/plain; charset=utf-8",
    suggested_filename = "little-ant-table.txt",
    warnings = {},
    metadata = {format = "table", projection = projection.schema}
  }
end
