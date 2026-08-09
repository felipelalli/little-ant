local function projection_payload(projection)
  if type(projection) ~= "table" or projection.schema ~= "little-ant/structure@1" then
    error("tree requires little-ant/structure@1")
  end
  if type(projection.payload) ~= "table" or type(projection.payload.bricks) ~= "table" then
    error("tree received an invalid structural payload")
  end
  return projection.payload
end

local function single_line(value)
  value = tostring(value or "")
  value = string.gsub(value, "\\", "\\\\")
  value = string.gsub(value, "\r", "\\r")
  value = string.gsub(value, "\n", "\\n")
  value = string.gsub(value, "\t", "\\t")
  return string.gsub(value, '"', '\\"')
end

local function forest(bricks)
  local by_id, children, roots = {}, {}, {}
  for _, brick in ipairs(bricks) do
    by_id[brick.id] = brick
    children[brick.id] = {}
  end
  for _, brick in ipairs(bricks) do
    if brick.parent_id ~= nil and by_id[brick.parent_id] ~= nil then
      table.insert(children[brick.parent_id], brick)
    else
      table.insert(roots, brick)
    end
  end
  return roots, children
end

return function(projection)
  local payload = projection_payload(projection)
  local roots, children = forest(payload.bricks)
  local lines = {}

  local function emit(brick, depth)
    local details = brick.nature
    if brick.phase ~= nil then details = details .. " · " .. brick.phase end
    table.insert(lines, string.rep("  ", depth) .. brick.handle .. ' "' .. single_line(brick.title) .. '" · ' .. details)
    for _, child in ipairs(children[brick.id]) do emit(child, depth + 1) end
  end

  for _, root in ipairs(roots) do emit(root, 0) end
  return {
    bytes = (#lines == 0 and "" or table.concat(lines, "\n") .. "\n"),
    media_type = "text/plain; charset=utf-8",
    suggested_filename = "little-ant-tree.txt",
    warnings = {},
    metadata = {format = "tree", projection = projection.schema}
  }
end
