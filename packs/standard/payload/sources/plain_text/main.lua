return function(request)
  if request.schema ~= "little-ant/source-preflight-request@1" then
    error("unsupported source preflight request schema")
  end

  local input = request.input
  local bytes = lant.input_bytes()
  if #bytes ~= input.byte_count then
    error("host input byte count does not match the request")
  end

  return {
    source_label = "Plain text file",
    account_label = "",
    supported_modes = {"snapshot", "migrate"},
    cleanup_supported = false,
    containers = {},
    objects = {
      {
        external_id = input.digest,
        locator = "sha256:" .. input.digest,
        container_id = "",
        title = input.label,
        shape = "note",
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
