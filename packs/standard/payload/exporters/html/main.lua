local function projection_payload(projection)
  if type(projection) ~= "table" or projection.schema ~= "little-ant/structure@1" then
    error("html requires little-ant/structure@1")
  end
  if type(projection.payload) ~= "table" or type(projection.payload.bricks) ~= "table" or type(projection.payload.domains) ~= "table" then
    error("html received an invalid structural payload")
  end
  return projection.payload
end

local function html(value)
  value = tostring(value or "")
  value = string.gsub(value, "&", "&amp;")
  value = string.gsub(value, "<", "&lt;")
  value = string.gsub(value, ">", "&gt;")
  value = string.gsub(value, '"', "&quot;")
  value = string.gsub(value, "'", "&#39;")
  return value
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
  for _, identity in ipairs(brick.domain_ids or {}) do table.insert(values, html(domains[identity] or identity)) end
  return table.concat(values, " › ")
end

return function(projection)
  local payload = projection_payload(projection)
  local domains = {}
  for _, domain in ipairs(payload.domains) do domains[domain.id] = domain.path end
  local roots, children = forest(payload.bricks)

  local function render(brick)
    local domain = domains_for(brick, domains)
    local phase = brick.phase ~= nil and ('<span class="chip">' .. html(brick.phase) .. '</span>') or ""
    local context = domain ~= "" and ('<div class="domain">' .. domain .. '</div>') or ""
    local nested = ""
    if #children[brick.id] > 0 then
      local values = {}
      for _, child in ipairs(children[brick.id]) do table.insert(values, render(child)) end
      nested = "<ul>" .. table.concat(values) .. "</ul>"
    end
    return '<li id="brick-' .. html(brick.id) .. '"><code>' .. html(brick.handle) .. '</code> <strong>' .. html(brick.title) .. '</strong> <span class="chip">' .. html(brick.nature) .. '</span>' .. phase .. context .. nested .. '</li>'
  end

  local items = {}
  for _, root in ipairs(roots) do table.insert(items, render(root)) end
  local css = "body{background:#f7f7f5;color:#242424;font:16px system-ui,sans-serif;line-height:1.5;margin:0}main{max-width:72rem;margin:auto;padding:2rem}header{border-bottom:1px solid #bbb;margin-bottom:1.5rem}ul{list-style:none;padding-left:1.5rem}li{margin:.65rem 0}code{color:#176b54}.chip{background:#e5e5df;border-radius:1rem;font-size:.78rem;margin-left:.45rem;padding:.15rem .5rem}.domain{color:#666;font-size:.85rem;margin-left:1rem}@media(prefers-color-scheme:dark){body{background:#171918;color:#eee}.chip{background:#343735}.domain{color:#aaa}}@media print{body{background:white;color:black}main{max-width:none}}"
  local document = '<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Little Ant</title><style>' .. css .. '</style></head><body><main><header><h1>Little Ant</h1><p>' .. #payload.bricks .. ' bricks · cursor <code>' .. html(projection.dataset_cursor) .. '</code></p></header><ul>' .. table.concat(items) .. '</ul></main></body></html>\n'
  return {
    bytes = document,
    media_type = "text/html; charset=utf-8",
    suggested_filename = "little-ant.html",
    warnings = {},
    metadata = {format = "self-contained-html", projection = projection.schema}
  }
end
