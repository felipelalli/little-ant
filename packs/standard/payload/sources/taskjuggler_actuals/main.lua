local DIGEST_PREFIX = "# LANT-MANIFEST-SHA256: "
local CHUNK_PREFIX = "# LANT-MANIFEST-JCS-BASE64URL-"

local function fail(message)
  error("taskjuggler_actuals: " .. message)
end

local function lines_of(bytes)
  local lines = {}
  for line in string.gmatch(bytes .. "\n", "(.-)\n") do
    if string.sub(line, -1) == "\r" then line = string.sub(line, 1, -2) end
    table.insert(lines, line)
  end
  return lines
end

local function four_digits(value)
  return string.format("%04d", value)
end

local function manifest_custody(lines)
  local digest_index = nil
  local digest = nil
  local chunk_indices = {}
  for index, line in ipairs(lines) do
    if string.sub(line, 1, #DIGEST_PREFIX) == DIGEST_PREFIX then
      if digest_index ~= nil then fail("more than one manifest digest") end
      digest_index = index
      digest = string.sub(line, #DIGEST_PREFIX + 1)
    end
    if string.sub(line, 1, #CHUNK_PREFIX) == CHUNK_PREFIX then table.insert(chunk_indices, index) end
  end
  if digest_index == nil then fail("missing manifest digest") end
  if string.match(digest, "^[0-9a-f]+$") == nil or #digest ~= 64 then fail("invalid manifest digest") end

  local chunks = {}
  local consumed = {}
  local sequence = 1
  local index = digest_index + 1
  while index <= #lines do
    local prefix = CHUNK_PREFIX .. four_digits(sequence) .. ": "
    local line = lines[index]
    if string.sub(line, 1, #prefix) ~= prefix then break end
    local chunk = string.sub(line, #prefix + 1)
    if chunk == "" then fail("empty manifest chunk") end
    table.insert(chunks, chunk)
    table.insert(consumed, index)
    sequence = sequence + 1
    index = index + 1
  end
  if #chunks == 0 then fail("missing manifest body") end
  if #consumed ~= #chunk_indices then fail("manifest chunks are not one contiguous ordered block") end
  for position, consumed_index in ipairs(consumed) do
    if consumed_index ~= chunk_indices[position] then fail("manifest chunks are not one contiguous ordered block") end
  end

  local manifest = lant.base64url_decode(table.concat(chunks))
  if lant.sha256(manifest) ~= digest then fail("manifest digest mismatch") end
  if string.find(manifest, '"schema":"little-ant/planning-manifest@1"', 1, true) == nil then
    fail("unsupported manifest schema")
  end
  local expected = {}
  for task_id in string.gmatch(manifest, '"task_id":"([A-Za-z_][A-Za-z0-9_]*)"') do
    if expected[task_id] then fail("duplicate task identity in manifest") end
    expected[task_id] = true
  end
  return digest, expected
end

local function structural_line(line)
  local output = {}
  local quoted = false
  local escaped = false
  for index = 1, #line do
    local character = string.sub(line, index, index)
    if quoted and escaped then
      escaped = false
    elseif quoted and character == "\\" then
      escaped = true
    elseif character == '"' then
      quoted = not quoted
    elseif not quoted and character == "#" then
      break
    elseif not quoted then
      table.insert(output, character)
    end
  end
  return string.match(table.concat(output), "^%s*(.-)%s*$")
end

local function semantic_line(line)
  local output = {}
  local quoted = false
  local escaped = false
  for index = 1, #line do
    local character = string.sub(line, index, index)
    if quoted and escaped then
      table.insert(output, character)
      escaped = false
    elseif quoted and character == "\\" then
      table.insert(output, character)
      escaped = true
    elseif character == '"' then
      table.insert(output, character)
      quoted = not quoted
    elseif not quoted and character == "#" then
      break
    else
      table.insert(output, character)
    end
  end
  return string.match(table.concat(output), "^%s*(.-)%s*$")
end

local function brace_count(line, needle)
  local count = 0
  for index = 1, #line do
    if string.sub(line, index, index) == needle then count = count + 1 end
  end
  return count
end

local function validate_hours(value)
  local number = string.match(value, "^([0-9]+%.?[0-9]*)h$")
  if number == nil or string.sub(number, -1) == "." then fail("actual effort must use nonnegative decimal hours") end
  local fraction = string.match(number, "%.([0-9]+)$")
  if fraction ~= nil and #fraction > 6 then fail("actual effort supports at most six decimal places") end
end

local function scan_actuals(lines, expected)
  local depth = 0
  local current_task = nil
  local in_project = false
  local project_seen = false
  local project_timezone_count = 0
  local tasks = {}
  local actual_field_count = 0
  local now_value = nil
  local now_count = 0

  for _, original in ipairs(lines) do
    local line = semantic_line(original)
    local structure = structural_line(original)
    local opens = brace_count(structure, "{")
    local closes = brace_count(structure, "}")
    if closes > depth + opens then fail("unbalanced closing braces") end

    local project_declared = string.match(line, "^project%s+.-{%s*$") ~= nil
    if string.match(line, "^project%s+") ~= nil and not project_declared then fail("malformed project declaration") end
    if project_declared then
      if depth ~= 0 or project_seen then fail("ambiguous project declaration") end
      in_project = true
      project_seen = true
    end

    local declared = string.match(line, "^task%s+([A-Za-z_][A-Za-z0-9_]*)%s+.-{%s*$")
    if string.match(line, "^task%s+") ~= nil and declared == nil then fail("malformed task declaration") end
    if declared ~= nil then
      if depth ~= 0 then fail("nested task declarations are ambiguous") end
      if tasks[declared] ~= nil then fail("duplicate task identity") end
      tasks[declared] = {done = false, left = false}
      current_task = declared
    end

    local actual_field, actual_value = string.match(line, "^actual:([A-Za-z_][A-Za-z0-9_]*)%s+(.+)$")
    if string.match(line, "^actual:") ~= nil then
      if actual_field == nil then fail("malformed actual field") end
      if current_task == nil then fail("actual field outside a top-level task") end
      if actual_field ~= "effortdone" and actual_field ~= "effortleft" then fail("unsupported actual field") end
      validate_hours(actual_value)
      local key = actual_field == "effortdone" and "done" or "left"
      if tasks[current_task][key] then fail("duplicate actual field") end
      tasks[current_task][key] = true
      actual_field_count = actual_field_count + 1
    end

    local observed_now = string.match(line, "^now%s+(.+)$")
    if observed_now ~= nil then
      if not in_project or depth ~= 1 then fail("project now is outside the top-level project body") end
      now_count = now_count + 1
      now_value = observed_now
    end
    if in_project and depth == 1 and string.match(line, '^timezone%s+"UTC"$') ~= nil then
      project_timezone_count = project_timezone_count + 1
    elseif in_project and depth == 1 and string.match(line, "^timezone%s+") ~= nil then
      fail("project timezone must be UTC")
    end

    depth = depth + opens - closes
    if depth == 0 then
      current_task = nil
      in_project = false
    end
  end

  if depth ~= 0 then fail("unbalanced opening braces") end
  if not project_seen or project_timezone_count ~= 1 then fail("exactly one UTC project timezone is required") end
  if actual_field_count == 0 then fail("no actual effort evidence") end
  if now_count ~= 1 or string.match(now_value or "", "^%d%d%d%d%-%d%d%-%d%d%-%d%d:%d%d$") == nil then
    fail("one explicit canonical UTC project now is required")
  end
  for task_id, _ in pairs(expected) do
    if tasks[task_id] == nil then fail("a manifest task is missing from the source") end
  end
  local actual_record_count = 0
  for task_id, fields in pairs(tasks) do
    if (fields.done or fields.left) and not expected[task_id] then fail("actuals reference a task outside the manifest cut") end
    if fields.done or fields.left then actual_record_count = actual_record_count + 1 end
  end
  return now_value, actual_record_count
end

return function(request)
  if type(request) ~= "table" or request.schema ~= "little-ant/source-preflight-request@1" then
    fail("unsupported source preflight request schema")
  end
  if request.mode ~= "snapshot" then fail("only snapshot mode is supported") end
  local input = request.input
  local bytes = lant.input_bytes()
  if type(input) ~= "table" or #bytes ~= input.byte_count or lant.sha256(bytes) ~= input.digest then
    fail("host input custody does not match the request")
  end
  local lines = lines_of(bytes)
  local digest, expected = manifest_custody(lines)
  local as_of, actual_record_count = scan_actuals(lines, expected)

  return {
    source_label = "TaskJuggler actuals",
    account_label = "",
    identity = {
      planning_manifest_sha256 = digest,
      actuals_as_of = as_of .. "Z",
      actual_record_count = tostring(actual_record_count)
    },
    supported_modes = {"snapshot"},
    cleanup_supported = false,
    containers = {},
    objects = {
      {
        external_id = "manifest:" .. digest .. "@" .. as_of .. "Z",
        locator = "manifest-sha256:" .. digest,
        container_id = "",
        title = input.label,
        shape = "other",
        completed = false,
        attachment_count = 0,
        content = {kind = "text", text = bytes},
        duplicate_keys = {input.digest, digest}
      }
    },
    unsupported_fields = {},
    warnings = {"Actual effort remains evidence; historical estimates are unchanged."}
  }
end
