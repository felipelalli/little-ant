local function projection_payload(projection)
  if type(projection) ~= "table" or projection.schema ~= "little-ant/structure@1" then
    error("org requires little-ant/structure@1")
  end
  if type(projection.payload) ~= "table" or type(projection.payload.bricks) ~= "table" or type(projection.payload.domains) ~= "table" then
    error("org received an invalid structural payload")
  end
  return projection.payload
end

local function one_line(value)
  return string.gsub(tostring(value or ""), "[\r\n]", " ")
end

local function forest(bricks)
  local by_id, children, roots = {}, {}, {}
  for _, brick in ipairs(bricks) do by_id[brick.id] = brick; children[brick.id] = {} end
  for _, brick in ipairs(bricks) do
    if brick.parent_id ~= nil and by_id[brick.parent_id] ~= nil then
      table.insert(children[brick.parent_id], brick)
    else
      table.insert(roots, brick)
    end
  end
  return roots, children
end

local function domains_for(brick, domains)
  local values = {}
  for _, identity in ipairs(brick.domain_ids or {}) do table.insert(values, domains[identity] or identity) end
  return table.concat(values, " | ")
end

return function(projection)
  local payload = projection_payload(projection)
  local domains = {}
  for _, domain in ipairs(payload.domains) do domains[domain.id] = domain.path end
  local roots, children = forest(payload.bricks)
  local lines = {"#+TITLE: Little Ant", "#+SEQ_TODO: TODO WIP | DONE", ""}

  local function emit(brick, depth)
    local keyword = brick.work_state == "wip" and "WIP" or "TODO"
    table.insert(lines, string.rep("*", depth) .. " " .. keyword .. " " .. one_line(brick.handle) .. " " .. one_line(brick.title))
    table.insert(lines, ":PROPERTIES:")
    table.insert(lines, ":BRICK_ID: " .. one_line(brick.id))
    table.insert(lines, ":NATURE: " .. one_line(brick.nature))
    if brick.phase ~= nil then table.insert(lines, ":PHASE: " .. one_line(brick.phase)) end
    local paths = domains_for(brick, domains)
    if paths ~= "" then table.insert(lines, ":DOMAINS: " .. one_line(paths)) end
    table.insert(lines, ":END:")
    for _, child in ipairs(children[brick.id]) do emit(child, depth + 1) end
  end

  for _, root in ipairs(roots) do emit(root, 1) end
  return {
    bytes = table.concat(lines, "\n") .. "\n",
    media_type = "text/org; charset=utf-8",
    suggested_filename = "little-ant.org",
    warnings = {},
    metadata = {format = "org", projection = projection.schema}
  }
end
