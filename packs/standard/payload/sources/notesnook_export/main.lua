local function supported_extension(path)
  local lower = string.lower(path)
  return string.match(lower, "%.md$")
      or string.match(lower, "%.markdown$")
      or string.match(lower, "%.html$")
      or string.match(lower, "%.htm$")
      or string.match(lower, "%.txt$")
end

local function title_from_path(path)
  local filename = string.match(path, "([^/]+)$") or path
  return (string.gsub(filename, "%.[^%.]+$", ""))
end

local function parent_path(path)
  return string.match(path, "^(.*)/[^/]+$") or ""
end

return function(request)
  if request.schema ~= "little-ant/source-preflight-request@1" then
    error("unsupported source request schema")
  end
  if request.mode ~= "snapshot" and request.mode ~= "migrate" then
    error("Notesnook export supports only snapshot and migrate")
  end
  if request.input.media_type ~= "application/zip" then
    error("Notesnook export input must be a ZIP archive")
  end

  local entries = lant.input_zip_entries()
  local objects = {}
  local containers_by_id = {}
  local ignored = 0

  for _, entry in ipairs(entries) do
    if supported_extension(entry.path) then
      local parent = parent_path(entry.path)
      local container_id = ""
      if parent ~= "" then
        container_id = "path:" .. parent
        containers_by_id[container_id] = parent
      end
      local digest = lant.sha256(entry.bytes)
      table.insert(objects, {
        external_id = "path:" .. entry.path,
        locator = "zip:" .. request.input.digest .. "!/" .. entry.path,
        container_id = container_id,
        title = title_from_path(entry.path),
        shape = "note",
        completed = false,
        attachment_count = 0,
        content = {kind = "text", text = entry.bytes},
        duplicate_keys = {digest}
      })
    else
      ignored = ignored + 1
    end
  end

  if #objects == 0 then
    error("the Notesnook ZIP contains no supported Markdown, HTML, or plain-text notes")
  end

  local container_ids = {}
  for container_id, _ in pairs(containers_by_id) do
    table.insert(container_ids, container_id)
  end
  table.sort(container_ids)

  local containers = {}
  for _, container_id in ipairs(container_ids) do
    table.insert(containers, {
      external_id = container_id,
      label = containers_by_id[container_id]
    })
  end

  local unsupported_fields = {}
  local warnings = {}
  if ignored > 0 then
    table.insert(unsupported_fields, tostring(ignored) .. " non-note archive entries")
    table.insert(warnings, tostring(ignored) .. " unsupported archive entries were left unimported")
  end

  return {
    source_label = "Notesnook export",
    account_label = "",
    identity = {
      archive_sha256 = request.input.digest,
      note_count = tostring(#objects)
    },
    supported_modes = {"snapshot", "migrate"},
    cleanup_supported = false,
    containers = containers,
    objects = objects,
    unsupported_fields = unsupported_fields,
    warnings = warnings
  }
end
