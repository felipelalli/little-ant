# Contract Changes

## v0-v1-atomic-cutover — real archive reader input

- **Scenario:** `v0-v1-atomic-cutover`
- **File:** `test-v1/scenarios/14-v0-v1-atomic-cutover.json`
- **Affected assertions:** `planning-does-not-change-active-dataset`, `archive-mismatch-fails-without-projection`, `legacy-title-derived-id-is-not-reused`, `legacy-stage-maps-to-active-positioned-brick`, `verification-precedes-activation`, `commit-switches-to-clean-v1-log`, `v0-archive-remains-byte-identical`, `committed-cutover-has-receipt`
- **Before:** The scenario named a nonexistent absolute source, declared symbolic archive/log hashes, and supplied aggregate counts (4,200 events, 250 entities, and 3,400 evidence records) without any archived v0 bytes from which the named legacy Brick or event could be projected.
- **After:** The scenario names `fixtures/v0-v1-atomic-cutover.jsonl`, declares its exact inspected byte count, event count, and SHA-256 hash, maps the opaque ID allocated from that archive, and binds the staged clean-log hash returned by `ProjectV1State` into verification and activation assertions. The mismatch assertion now forks from the real planned checkpoint.
- **Why the contract was wrong:** `ProjectV1State` is required to fold archived v0 state, but the old protocol input contained neither a readable source nor bytes. A conforming implementation could only produce `sha256:old-seed-title`, `event-17`, and the requested aggregate counts by hardcoding the checked-in scenario. The correction preserves all eight assertions and makes each fail when the reader, projector, verifier, or atomic activator stops using actual archive/log bytes.
