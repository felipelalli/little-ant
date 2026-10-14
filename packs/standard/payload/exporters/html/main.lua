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

local function forest(values)
  local by_id, children, roots = {}, {}, {}
  for _, value in ipairs(values) do by_id[value.id] = value; children[value.id] = {} end
  for _, value in ipairs(values) do
    if value.parent_id ~= nil and by_id[value.parent_id] ~= nil then
      table.insert(children[value.parent_id], value)
    else
      table.insert(roots, value)
    end
  end
  return by_id, roots, children
end

local function count_label(count, singular, plural)
  return tostring(count) .. " " .. (count == 1 and singular or plural)
end

local nature_names = {
  atomic_task = "Task", project = "Project", collection = "Collection",
  finite_checklist = "Checklist", living_checklist = "Living checklist",
  repeatable = "Repeatable", recurring_obligation = "Recurring obligation",
  habit = "Habit", scheduled_commitment = "Scheduled commitment"
}

local chevron = '<svg class="chevron" viewBox="0 0 16 16" aria-hidden="true"><path d="m6 3 5 5-5 5"/></svg>'
local leaf = '<svg class="leaf-mark" viewBox="0 0 16 16" aria-hidden="true"><circle cx="8" cy="8" r="2"/></svg>'

return function(projection)
  local payload = projection_payload(projection)
  local bricks, roots, children = forest(payload.bricks)
  local domains, domain_roots, domain_children = forest(payload.domains)
  table.sort(domain_roots, function(a, b) return a.path < b.path end)
  for _, siblings in pairs(domain_children) do
    table.sort(siblings, function(a, b) return a.path < b.path end)
  end
  local members, uncategorized = {}, {}
  for _, domain in ipairs(payload.domains) do members[domain.id] = {} end
  for _, brick in ipairs(payload.bricks) do
    if #(brick.domain_ids or {}) == 0 then table.insert(uncategorized, brick) end
    for _, identity in ipairs(brick.domain_ids or {}) do
      if members[identity] then table.insert(members[identity], brick) end
    end
  end

  local prerequisites, dependency_count, blocked_count = {}, 0, 0
  for _, edge in ipairs(payload.dependencies or {}) do
    if bricks[edge.blocked_brick_id] then
      if not prerequisites[edge.blocked_brick_id] then
        prerequisites[edge.blocked_brick_id] = {}; blocked_count = blocked_count + 1
      end
      table.insert(prerequisites[edge.blocked_brick_id], edge.blocker_brick_id)
      dependency_count = dependency_count + 1
    end
  end

  local function brick_link(brick)
    return '<a class="brick-link" href="#brick-' .. html(brick.id) .. '"><code>' .. html(brick.handle)
      .. '</code><span>' .. html(brick.title) .. '</span></a>'
  end

  local function member_row(brick)
    return '<li class="tree-node"><div class="node-row">' .. leaf .. brick_link(brick)
      .. '<span class="node-note">' .. html(nature_names[brick.nature] or brick.nature) .. '</span></div></li>'
  end

  -- Show parts in their project's visual context while retaining direct Domain
  -- membership. References in multiple categories still denote one Brick.
  local function group_roots(values)
    local present, result = {}, {}
    for _, brick in ipairs(values) do present[brick.id] = true end
    for _, brick in ipairs(values) do
      local ancestor, nested = bricks[brick.parent_id], false
      while ancestor do
        if present[ancestor.id] then nested = true; break end
        ancestor = bricks[ancestor.parent_id]
      end
      if not nested then table.insert(result, brick) end
    end
    return result
  end

  local function render_category_brick(brick)
    local metadata = nature_names[brick.nature] or brick.nature
    if #(brick.domain_ids or {}) == 0 then
      metadata = metadata .. ' · no direct category'
    else
      local paths = {}
      for _, identity in ipairs(brick.domain_ids) do
        if domains[identity] then table.insert(paths, domains[identity].path) end
      end
      metadata = metadata .. ' · ' .. table.concat(paths, ' / ')
    end
    local note = '<div class="brick-meta">' .. html(metadata) .. '</div>'
    local nested = {}
    for _, child in ipairs(children[brick.id]) do table.insert(nested, render_category_brick(child)) end
    local row = '<div class="node-row">' .. leaf .. brick_link(brick) .. '</div>' .. note
    if #nested > 0 then
      row = '<details open><summary class="node-row">' .. chevron .. brick_link(brick)
        .. '<span class="node-note">' .. count_label(#nested, "part", "parts") .. '</span></summary>'
        .. note .. '<ul class="tree">' .. table.concat(nested) .. '</ul></details>'
    end
    return '<li class="tree-node" data-brick-id="' .. html(brick.id) .. '">' .. row .. '</li>'
  end

  local function domain_count(domain)
    local identities = {}
    local function parts(brick)
      identities[brick.id] = true
      for _, child in ipairs(children[brick.id]) do parts(child) end
    end
    local function visit(current)
      for _, brick in ipairs(members[current.id]) do parts(brick) end
      for _, child in ipairs(domain_children[current.id]) do visit(child) end
    end
    visit(domain)
    local count = 0
    for _ in pairs(identities) do count = count + 1 end
    return count
  end

  local function render_domain(domain)
    local nested = {}
    for _, child in ipairs(domain_children[domain.id]) do table.insert(nested, render_domain(child)) end
    for _, brick in ipairs(group_roots(members[domain.id])) do table.insert(nested, render_category_brick(brick)) end
    local body = #nested == 0 and '<li class="empty-node">No Bricks in this category.</li>' or table.concat(nested)
    return '<li class="tree-node"><details open><summary class="node-row">' .. chevron
      .. '<span class="branch-name">' .. html(domain.name) .. '</span><span class="node-note">'
      .. count_label(domain_count(domain), "Brick", "Bricks") .. '</span></summary><ul class="tree">'
      .. body .. '</ul></details></li>'
  end

  local categories = {}
  for _, domain in ipairs(domain_roots) do table.insert(categories, render_domain(domain)) end
  local unclassified_roots = {}
  for _, brick in ipairs(group_roots(uncategorized)) do
    local ancestor, classified = bricks[brick.parent_id], false
    while ancestor do
      if #(ancestor.domain_ids or {}) > 0 then classified = true; break end
      ancestor = bricks[ancestor.parent_id]
    end
    if not classified then table.insert(unclassified_roots, brick) end
  end
  if #unclassified_roots > 0 then
    local rows = {}
    for _, brick in ipairs(unclassified_roots) do table.insert(rows, render_category_brick(brick)) end
    table.insert(categories, '<li class="tree-node"><details open><summary class="node-row">' .. chevron
      .. '<span class="branch-name">Without a category</span></summary><ul class="tree">'
      .. table.concat(rows) .. '</ul></details></li>')
  end

  local function render_composition(brick)
    local contexts = {}
    for _, identity in ipairs(brick.domain_ids or {}) do
      if domains[identity] then table.insert(contexts, html(domains[identity].path)) end
    end
    local metadata = html(nature_names[brick.nature] or brick.nature)
      .. (brick.work_state == "wip" and ' · In progress' or '')
      .. (brick.phase ~= nil and (' · ' .. html(brick.phase)) or '')
    if brick.sibling_position ~= nil then
      metadata = 'Importance position ' .. string.format("%d", brick.sibling_position) .. ' within siblings · ' .. metadata
    end
    if #contexts > 0 then metadata = metadata .. '<br>' .. table.concat(contexts, ' / ') end
    local heading = '<code>' .. html(brick.handle) .. '</code><span class="brick-title">' .. html(brick.title) .. '</span>'
    local note = '<div class="brick-meta">' .. metadata .. '</div>'
    local body
    if #children[brick.id] > 0 then
      local nested = {}
      for _, child in ipairs(children[brick.id]) do table.insert(nested, render_composition(child)) end
      body = '<details open><summary class="node-row">' .. chevron .. heading
        .. '<span class="node-note">' .. count_label(#children[brick.id], "part", "parts") .. '</span></summary>'
        .. note .. '<ul class="tree">' .. table.concat(nested) .. '</ul></details>'
    else
      body = '<div class="node-row">' .. leaf .. heading .. '</div>' .. note
    end
    return '<li id="brick-' .. html(brick.id) .. '" class="tree-node brick-node">' .. body .. '</li>'
  end

  local composition = {}
  for _, brick in ipairs(roots) do table.insert(composition, render_composition(brick)) end
  local dependency_rows = {}
  for _, brick in ipairs(payload.bricks) do
    local targets = prerequisites[brick.id]
    if targets then
      local rows = {}
      for _, identity in ipairs(targets) do
        local blocker = bricks[identity]
        table.insert(rows, blocker and member_row(blocker)
          or '<li class="tree-node"><div class="node-row">' .. leaf .. '<span>Prerequisite outside this export</span></div></li>')
      end
      table.insert(dependency_rows, '<li class="tree-node"><details open><summary class="node-row">' .. chevron
        .. '<code>' .. html(brick.handle) .. '</code><span class="brick-title">' .. html(brick.title)
        .. '</span><span class="node-note">needs ' .. count_label(#targets, "prerequisite", "prerequisites")
        .. '</span></summary><ul class="tree">' .. table.concat(rows) .. '</ul></details></li>')
    end
  end

  local empty = '<p class="empty">No active Bricks in this export.</p>'
  local composition_note = #roots == #payload.bricks and 'No parent–child links exist within this export; all Bricks are shown at root.'
    or 'Parents and parts follow your importance order. Positions are local to each sibling group.'
  local css = [=[
:root{color-scheme:light dark;--page:#f5f5f0;--surface:#fff;--text:#242b29;--muted:#59645f;--line:#cbd3ce;--accent:#176b54;--hover:#edf4ef;--select:#cce7d5}
*{box-sizing:border-box}html{scroll-padding-top:2rem}body{margin:0;background:var(--page);color:var(--text);font:16px/1.5 system-ui,sans-serif}::selection{background:var(--select);color:var(--text)}a{color:var(--accent);text-underline-offset:.2em}a:hover{text-decoration:underline}a:focus-visible,summary:focus-visible{outline:2px solid var(--accent);outline-offset:3px;border-radius:3px}code{font:14px ui-monospace,monospace;font-variant-numeric:tabular-nums;color:var(--accent);white-space:nowrap}
.page{max-width:1240px;margin:auto;padding:2.5rem 2rem 4rem}.masthead{display:flex;align-items:baseline;justify-content:space-between;gap:1rem;padding-bottom:1.5rem;border-bottom:1px solid var(--line)}.brand{font-weight:650;font-size:1.125rem;letter-spacing:-.02em}.snapshot{color:var(--muted);font-size:.875rem}.layout{display:grid;grid-template-columns:190px minmax(0,1fr);gap:3rem;padding-top:2.5rem}aside{position:sticky;top:2rem;align-self:start}h1{font-size:2rem;line-height:1.2;font-weight:650;letter-spacing:-.03em;margin:0 0 .6rem}h2{font-size:1.25rem;font-weight:650;margin:0}p{margin:.5rem 0;color:var(--muted);max-width:70ch}.intro{margin-bottom:2rem}nav{display:grid;gap:.35rem}nav a{display:flex;justify-content:space-between;gap:1rem;padding:.75rem .8rem;border-radius:5px;text-decoration:none}nav a:hover{background:var(--hover);text-decoration:none}nav span{color:var(--muted);font-size:.875rem;font-variant-numeric:tabular-nums}.tip{font-size:.875rem;margin:1.5rem .8rem 0}.view{background:var(--surface);border:1px solid var(--line);border-radius:8px;padding:1.5rem;margin-bottom:2rem;scroll-margin-top:2rem}.view-heading{display:flex;justify-content:space-between;align-items:baseline;gap:1rem}.view-heading>span{font-size:.875rem;color:var(--muted)}.view>p{font-size:.875rem;margin:.4rem 0 1.3rem}
.tree{list-style:none;padding:0;margin:0}.tree .tree{margin-inline-start:.5rem;padding-inline-start:1.35rem}.tree-node{position:relative;margin:0;padding:.12rem 0}.tree .tree>.tree-node:before{content:"";position:absolute;border-inline-start:1px solid var(--line);inset-inline-start:-1.35rem;top:0;bottom:0}.tree .tree>.tree-node:last-child:before{bottom:auto;height:1.4rem}.tree .tree>.tree-node:after{content:"";position:absolute;inset-inline-start:-1.35rem;top:1.4rem;width:1.15rem;border-top:1px solid var(--line)}.node-row{display:flex;align-items:baseline;gap:.65rem;min-height:2.6rem;padding:.5rem .55rem;border-radius:4px;min-width:0}.node-row:hover{background:var(--hover)}summary.node-row{cursor:pointer;list-style:none}summary::-webkit-details-marker{display:none}.chevron,.leaf-mark{width:16px;height:16px;flex:0 0 16px;align-self:flex-start;margin-block-start:.25rem}.chevron{fill:none;stroke:var(--muted);stroke-width:1.6;transition:transform .15s ease-out}.leaf-mark{fill:var(--muted)}details[open]>summary .chevron{transform:rotate(90deg)}.branch-name{font-weight:650;overflow-wrap:anywhere}.brick-title{overflow-wrap:anywhere;white-space:pre-wrap;min-width:0}.node-note{margin-inline-start:auto;color:var(--muted);font-size:.8rem;flex-shrink:0}.brick-link{display:flex;gap:.65rem;align-items:baseline;min-width:0;text-decoration:none;color:var(--text)}.brick-link span{overflow-wrap:anywhere;white-space:pre-wrap}.brick-link:hover{color:var(--accent)}.brick-meta{margin:-.1rem .5rem .65rem 2.2rem;color:var(--muted);font-size:.8rem;overflow-wrap:anywhere}.brick-node:target{background:var(--hover);outline:2px solid var(--accent);outline-offset:2px;border-radius:4px}.empty{padding:.8rem 0}.empty-node{color:var(--muted);font-size:.875rem;padding:.6rem}.footer{border-top:1px solid var(--line);padding-top:1rem;font-size:.8rem;color:var(--muted);overflow-wrap:anywhere}.footer code{font-size:inherit;white-space:normal}body{scrollbar-color:var(--line) var(--page)}
@media(prefers-color-scheme:dark){:root{--page:#171c19;--surface:#1e2521;--text:#e8eee9;--muted:#abb9af;--line:#46554c;--accent:#86d6ae;--hover:#2c3e32;--select:#315b43}}
@media(max-width:760px){.page{padding:1.5rem 1rem 3rem}.layout{grid-template-columns:1fr;gap:1.5rem;padding-top:1.5rem}aside{position:static}nav{display:flex;flex-wrap:wrap;gap:.25rem}nav a{padding:.6rem .7rem}.tip{margin:.6rem .7rem 0}.intro{margin-bottom:1.5rem}.view{padding:1rem}.node-note{margin-inline-start:0}.node-row{flex-wrap:wrap;column-gap:.5rem}.node-row .node-note{margin-inline-start:1.5rem}.node-row>.brick-link{flex:1 1 70%}.brick-title{flex:1 1 60%}.masthead{flex-wrap:wrap}.view-heading{flex-wrap:wrap;gap:.25rem}h1{font-size:1.75rem}.tree .tree{padding-inline-start:1rem}.tree .tree>.tree-node:before,.tree .tree>.tree-node:after{inset-inline-start:-1rem}.tree .tree>.tree-node:after{width:.85rem}}
@media(prefers-reduced-motion:reduce){.chevron{transition:none}}
@media print{.page{max-width:none;padding:0}.layout{display:block}aside{display:none}.view{break-inside:auto}details>summary{break-after:avoid}body{background:white;color:black}.footer code{color:black}}
]=]
  local document = '<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
    .. '<title>Little Ant · Work explorer</title><style>' .. css .. '</style></head><body><div class="page">'
    .. '<header class="masthead"><span class="brand">Little Ant</span><span class="snapshot">Read-only snapshot · '
    .. count_label(#payload.bricks, "active Brick", "active Bricks") .. '</span></header><div class="layout"><aside><nav aria-label="Explore work">'
    .. '<a href="#categories">Categories<span>' .. #payload.domains .. '</span></a><a href="#composition">Composition<span>' .. #payload.bricks
    .. '</span></a><a href="#dependencies">Dependencies<span>' .. dependency_count .. '</span></a></nav><p class="tip">Click a branch to collapse it. Use Ctrl+F to find a Brick.</p></aside><main>'
    .. '<div class="intro"><h1>Explore your work</h1><p>See where your Bricks belong, how they fit together, and what they need before work can begin.</p></div>'
    .. '<section class="view" id="categories"><div class="view-heading"><h2>Categories + parts</h2><span>' .. count_label(#domain_roots, "root category", "root categories")
    .. '</span></div><p>Categories contain projects and their nested parts, as in the REPL tree. Parts retain their own direct categories; repeated references denote the same Brick. Click a title to inspect its composition.</p>'
    .. (#categories == 0 and empty or ('<ul class="tree">' .. table.concat(categories) .. '</ul>')) .. '</section>'
    .. '<section class="view" id="composition"><div class="view-heading"><h2>Composition</h2><span>' .. count_label(#roots, "root Brick", "root Bricks")
    .. '</span></div><p>' .. composition_note .. '</p>' .. (#composition == 0 and empty or ('<ul class="tree">' .. table.concat(composition) .. '</ul>')) .. '</section>'
    .. '<section class="view" id="dependencies"><div class="view-heading"><h2>Dependencies</h2><span>' .. count_label(blocked_count, "Brick with prerequisites", "Bricks with prerequisites")
    .. '</span></div><p>Each branch lists what its Brick needs. Shared prerequisites can appear in more than one branch; these are dependencies, not child parts.</p>'
    .. (#dependency_rows == 0 and '<p class="empty">No unresolved dependencies in this export.</p>' or ('<ul class="tree">' .. table.concat(dependency_rows) .. '</ul>')) .. '</section>'
    .. '<footer class="footer">Exported from Little Ant · dataset cursor <code>' .. html(projection.dataset_cursor)
    .. '</code><br>This file works offline. Opening or browsing it does not change your work.</footer></main></div></div></body></html>\n'
  return {
    bytes = document,
    media_type = "text/html; charset=utf-8",
    suggested_filename = "little-ant.html",
    warnings = {},
    metadata = {format = "self-contained-html", projection = projection.schema}
  }
end
