local function decode_xml_text(value)
  return (value
    :gsub("&lt;", "<")
    :gsub("&gt;", ">")
    :gsub("&quot;", "\"")
    :gsub("&apos;", "'")
    :gsub("&amp;", "&"))
end

local function element_text(block, name)
  local value = block:match("<" .. name .. ">(.-)</" .. name .. ">")
  if value == nil then return "" end
  return decode_xml_text(value)
end

local function count_plain(block, needle)
  local count = 0
  local offset = 1
  while true do
    local found = string.find(block, needle, offset, true)
    if found == nil then return count end
    count = count + 1
    offset = found + #needle
  end
end

return function(request)
  if request.schema ~= "little-ant/source-preflight-request@1" then
    error("unsupported source request schema")
  end
  if request.mode ~= "snapshot" and request.mode ~= "migrate" then
    error("Evernote ENEX supports only snapshot and migrate")
  end
  if request.input.media_type ~= "application/vnd.evernote.enex+xml" then
    error("Evernote input must be an ENEX document")
  end

  local bytes = lant.input_bytes()
  if #bytes ~= request.input.byte_count then
    error("host input byte count does not match the request")
  end
  if not string.find(bytes, "<en-export", 1, true) then
    error("Evernote ENEX root element is missing")
  end

  local objects = {}
  local offset = 1
  while true do
    local note_start = string.find(bytes, "<note>", offset, true)
    if note_start == nil then break end
    local note_end = string.find(bytes, "</note>", note_start + 6, true)
    if note_end == nil then error("Evernote ENEX contains an unterminated note") end
    note_end = note_end + 6

    local block = string.sub(bytes, note_start, note_end)
    local digest = lant.sha256(block)
    local guid = element_text(block, "guid")
    local title = element_text(block, "title")
    if title == "" then title = "Untitled Evernote note" end
    local external_id = guid ~= "" and ("guid:" .. guid) or ("sha256:" .. digest)

    table.insert(objects, {
      external_id = external_id,
      locator = "enex:" .. request.input.digest .. "#" .. external_id,
      container_id = "",
      title = title,
      shape = "note",
      completed = false,
      attachment_count = count_plain(block, "<resource>"),
      content = {kind = "text", text = block},
      duplicate_keys = {digest}
    })
    offset = note_end + 1
  end

  if #objects == 0 then
    error("Evernote ENEX contains no notes")
  end

  return {
    source_label = "Evernote ENEX export",
    account_label = "",
    identity = {archive_sha256 = request.input.digest, note_count = tostring(#objects)},
    supported_modes = {"snapshot", "migrate"},
    cleanup_supported = false,
    containers = {},
    objects = objects,
    unsupported_fields = {},
    warnings = {}
  }
end
