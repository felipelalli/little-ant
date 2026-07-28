# Contract Changes

## Blocked — needs owner decision

None. Every 1.0 obligation is satisfied, and the sampled mutation audit found
no stayed-green behavior requiring contract clarification.

## v0-v1-atomic-cutover — real archive reader input

- **Scenario:** `v0-v1-atomic-cutover`
- **File:** `test-v1/scenarios/14-v0-v1-atomic-cutover.json`
- **Affected assertions:** `planning-does-not-change-active-dataset`, `archive-mismatch-fails-without-projection`, `legacy-title-derived-id-is-not-reused`, `legacy-stage-maps-to-active-positioned-brick`, `verification-precedes-activation`, `commit-switches-to-clean-v1-log`, `v0-archive-remains-byte-identical`, `committed-cutover-has-receipt`
- **Before:** The scenario named a nonexistent absolute source, declared symbolic archive/log hashes, and supplied aggregate counts (4,200 events, 250 entities, and 3,400 evidence records) without any archived v0 bytes from which the named legacy Brick or event could be projected.
- **After:** The scenario names `fixtures/v0-v1-atomic-cutover.jsonl`, declares its exact inspected byte count, event count, and SHA-256 hash, maps the opaque ID allocated from that archive, and binds the staged clean-log hash returned by `ProjectV1State` into verification and activation assertions. The mismatch assertion now forks from the real planned checkpoint.
- **Why the contract was wrong:** `ProjectV1State` is required to fold archived v0 state, but the old protocol input contained neither a readable source nor bytes. A conforming implementation could only produce `sha256:old-seed-title`, `event-17`, and the requested aggregate counts by hardcoding the checked-in scenario. The correction preserves all eight assertions and makes each fail when the reader, projector, verifier, or atomic activator stops using actual archive/log bytes.

## v0-v1-atomic-cutover — synthetic mixed-history coverage

- **Scenario:** `v0-v1-atomic-cutover`
- **Files:** `fixtures/v0-v1-atomic-cutover.jsonl`, `test-v1/scenarios/14-v0-v1-atomic-cutover.json`
- **Affected assertions:** `planning-does-not-change-active-dataset`, `archive-mismatch-fails-without-projection`, `legacy-title-derived-id-is-not-reused`, `legacy-stage-maps-to-active-positioned-brick`, `verification-precedes-activation`, `commit-switches-to-clean-v1-log`, `v0-archive-remains-byte-identical`, `committed-cutover-has-receipt`
- **Before:** The fixture contained 141 bytes and one `brick_captured` event. The scenario declared one event, one projected entity, one retained evidence record, SHA-256 `c132733bec3d288288ba18d3c9cbb8844ba8adeed0f0c79823242d673516439d`, and one Brick identity map.
- **After:** The fixture contains 2,125 bytes and 11 wholly synthetic events of six event kinds. They retain an ordinary Brick, recurring-work metadata, delegated work with a synthetic Party, already-completed work, one Raw input, and two distinct Bricks with the same synthetic title. The scenario declares 11 events, eight projected entities, 11 retained evidence records, SHA-256 `38156acd5f5222ce93282f41695938ef0e8a2f1cf6f9f9893304555e69a62bb6`, and all eight concrete opaque Brick/Raw/Party identity maps.
- **Why the contract was wrong:** A one-event archive could prove only that the reader opened a file. It could not fail on loss of mixed entity kinds, terminal-state projection, event ordering, retained evidence multiplicity, or same-title identity collisions. The replacement does not remove or loosen any assertion: all eight IDs remain, exact metadata is still checked, every projected identity must be mapped before verification, and the archive hash still binds activation to the checked-in bytes.
