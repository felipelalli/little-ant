local api_root = "https://api.github.com"

local function require_string(value, label)
  if type(value) ~= "string" or value == "" then
    error(label .. " must be a nonempty string")
  end
  return value
end

local function require_integer(value, label)
  if type(value) ~= "number" or value < 1 or value % 1 ~= 0 then
    error(label .. " must be a positive integer")
  end
  return value
end

local function validate_source(source)
  if type(source) ~= "table" then error("source must be an object") end
  local expected = {
    provider = true,
    account_id = true,
    account_label = true,
    include_closed = true
  }
  for key, _ in pairs(source) do
    if not expected[key] then error("unknown GitHub Issues source field: " .. tostring(key)) end
  end
  if source.provider ~= "github_issues" then error("provider must be github_issues") end
  require_string(source.account_id, "account_id")
  require_string(source.account_label, "account_label")
  if source.include_closed == nil then return false end
  if type(source.include_closed) ~= "boolean" then error("include_closed must be a boolean") end
  return source.include_closed
end

local function issue_pages(include_closed)
  local state = include_closed and "all" or "open"
  local values = {}
  local page = 1
  while true do
    local url = api_root .. "/issues?direction=desc&filter=all&page=" .. tostring(page)
      .. "&per_page=100&sort=updated&state=" .. state
    local response = lant.http.request({
      method = "GET",
      url = url,
      headers = {accept = "application/vnd.github+json"}
    })
    if response.status ~= 200 then
      error("GitHub Issues request failed with HTTP " .. tostring(response.status))
    end
    if type(response.json) ~= "table" then error("GitHub Issues response must be an array") end
    local count = 0
    for _, issue in ipairs(response.json) do
      if type(issue) ~= "table" then error("GitHub Issues response contains a non-object value") end
      table.insert(values, issue)
      count = count + 1
    end
    if count > 100 then error("GitHub Issues returned more than the requested page size") end
    if count < 100 then return values end
    page = page + 1
  end
end

local function repository_identity(issue)
  local repository = issue.repository
  if type(repository) ~= "table" then error("GitHub issue repository must be an object") end
  local node_id = require_string(repository.node_id, "repository node_id")
  local full_name = require_string(repository.full_name, "repository full_name")
  local owner, name = string.match(full_name, "^([^/]+)/([^/]+)$")
  if owner == nil or name == nil then error("repository full_name must contain owner/name") end
  return repository, node_id, full_name, owner, name
end

local function normalized_title(title)
  local value = string.lower(title)
  value = string.gsub(value, "%s+", " ")
  value = string.gsub(value, "^%s+", "")
  return string.gsub(value, "%s+$", "")
end

local function issue_object(source, issue)
  local node_id = require_string(issue.node_id, "issue node_id")
  local title = require_string(issue.title, "issue title")
  local number = require_integer(issue.number, "issue number")
  local state = require_string(issue.state, "issue state")
  if state ~= "open" and state ~= "closed" then error("issue state must be open or closed") end
  local repository, repository_node_id, full_name, owner, name = repository_identity(issue)
  local external_id = "issue:" .. node_id
  local container_id = "repository:" .. repository_node_id
  local locator = "github://" .. lant.url.encode_path_segment(source.account_id)
    .. "/repos/" .. lant.url.encode_path_segment(owner)
    .. "/" .. lant.url.encode_path_segment(name)
    .. "/issues/" .. tostring(number)
  local snapshot = {
    schema = "github/issue@1",
    provider = "github_issues",
    account_id = source.account_id,
    identity = {
      issue_node_id = node_id,
      repository_node_id = repository_node_id,
      repository_full_name = full_name,
      number = tostring(number)
    },
    repository = repository,
    issue = issue
  }
  local duplicate_keys = {"github_issue:" .. source.account_id .. ":" .. node_id}
  local title_key = normalized_title(title)
  if title_key ~= "" then table.insert(duplicate_keys, "title:" .. title_key) end
  return {
    external_id = external_id,
    locator = locator,
    container_id = container_id,
    title = title,
    shape = "task",
    completed = state == "closed",
    attachment_count = 0,
    content = {kind = "structured", schema = "github/issue@1", json = lant.json.encode(snapshot)},
    duplicate_keys = duplicate_keys
  }, container_id, full_name
end

return function(request)
  if request.schema ~= "little-ant/source-provider-request@1" then
    error("unsupported source provider request schema")
  end
  if request.mode ~= "snapshot" and request.mode ~= "synchronize" then
    error("GitHub Issues supports snapshot and synchronize")
  end
  if type(request.selected_containers) ~= "table" or next(request.selected_containers) ~= nil then
    error("GitHub Issues does not accept explicit container selection")
  end

  local source = request.source
  local include_closed = validate_source(source)
  local returned = issue_pages(include_closed)
  local objects = {}
  local repository_labels = {}
  local pull_request_count = 0
  local open_count = 0
  local closed_count = 0
  for _, issue in ipairs(returned) do
    if issue.pull_request ~= nil then
      if type(issue.pull_request) ~= "table" then error("issue pull_request marker must be an object") end
      pull_request_count = pull_request_count + 1
    else
      local object, container_id, repository_label = issue_object(source, issue)
      if repository_labels[container_id] ~= nil and repository_labels[container_id] ~= repository_label then
        error("one GitHub repository identity has conflicting names")
      end
      repository_labels[container_id] = repository_label
      table.insert(objects, object)
      if object.completed then closed_count = closed_count + 1 else open_count = open_count + 1 end
    end
  end

  table.sort(objects, function(left, right) return left.external_id < right.external_id end)
  local containers = {}
  for external_id, label in pairs(repository_labels) do
    table.insert(containers, {external_id = external_id, label = label})
  end
  table.sort(containers, function(left, right) return left.external_id < right.external_id end)

  local unsupported = {}
  if pull_request_count > 0 then
    table.insert(unsupported, tostring(pull_request_count) .. " pull request record(s) returned by GitHub's shared issues endpoint")
  end

  return {
    source_label = "GitHub Issues",
    account_label = source.account_label,
    identity = {
      provider = "github_issues",
      account_id = source.account_id,
      repository_count = tostring(#containers),
      included_issue_count = tostring(#objects),
      open_issue_count = tostring(open_count),
      closed_issue_count = tostring(closed_count),
      omitted_pull_request_count = tostring(pull_request_count)
    },
    supported_modes = {"snapshot", "synchronize"},
    cleanup_supported = false,
    containers = containers,
    objects = objects,
    unsupported_fields = unsupported,
    warnings = {}
  }
end
