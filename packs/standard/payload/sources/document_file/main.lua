local formats = {
  ["text/markdown; charset=utf-8"] = {label = "Markdown file", format = "markdown", shape = "note"},
  ["text/html; charset=utf-8"] = {label = "HTML file", format = "html", shape = "note"},
  ["application/json"] = {label = "JSON file", format = "json", shape = "other"},
  ["text/csv; charset=utf-8"] = {label = "CSV file", format = "csv", shape = "other"},
  ["text/org; charset=utf-8"] = {label = "Org file", format = "org", shape = "note"}
}

return function(request)
  if request.schema ~= "little-ant/source-preflight-request@1" then
    error("unsupported source request schema")
  end
  if request.mode ~= "snapshot" and request.mode ~= "migrate" then
    error("document files support only snapshot and migrate")
  end

  local input = request.input
  local format = formats[input.media_type]
  if format == nil then
    error("unsupported document media type")
  end

  local bytes = lant.input_bytes()
  if #bytes ~= input.byte_count then
    error("host input byte count does not match the request")
  end

  return {
    source_label = format.label,
    account_label = "",
    identity = {content_sha256 = input.digest, format = format.format},
    supported_modes = {"snapshot", "migrate"},
    cleanup_supported = false,
    containers = {},
    objects = {
      {
        external_id = input.digest,
        locator = "sha256:" .. input.digest,
        container_id = "",
        title = input.label,
        shape = format.shape,
        completed = false,
        attachment_count = 0,
        content = {kind = "text", text = bytes},
        duplicate_keys = {input.digest}
      }
    },
    unsupported_fields = {},
    warnings = {}
  }
end
