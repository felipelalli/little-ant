# S00 — Bootstrap and conformance harness

Status: **completed**

## Outcome

Create the smallest honest greenfield Haskell build and the tooling that keeps
later sessions tied to exact canonical evidence. This slice implements no
product flow and claims no UX route.

## Required sources

- [`spec/little-ant-1.0.md`](../../spec/little-ant-1.0.md), especially
  Authority, Current closure state, Reading paths, and Maintenance rules
- [`traceability.md`](../../spec/little-ant-1.0/traceability.md), especially UX
  trace and downstream promotion trace
- [`open-release-decisions.md`](../../spec/little-ant-1.0/open-release-decisions.md)
- PRD-002, PRD-006..009, PRD-013, PRD-018..019
- MIG-018..023
- the canonical command catalog, including its rejected vocabulary

## Work

1. Replace the stale Cabal graph. Remove deleted source modules, removed
   Allium paths, removed generated-test paths, and the retired `la` executable.
2. Keep exactly one empty-but-buildable `lant` executable, one library, and
   separate unit/property, protocol, and end-to-end test suites.
3. Preserve GHC 9.10.3 and the Nix development shell unless a concrete package
   incompatibility requires a reviewed lock-file change.
4. Add the exact-ID `spec-packet` extractor and canonical ID/link audit.
5. Add a totality audit whose owner union equals the complete rule, screen,
   scenario, and flow catalogs. Ranges must expand unambiguously, each flow has
   exactly one slice owner, and every intentionally non-testable rule carries a
   reviewed rationale.
6. Add the contract-test descriptor and generated coverage-report skeleton,
   including required negative/boundary evidence for prohibitive, gate, and
   conditional rules.
7. Seed the public-vocabulary guard with canonical rejected terms and narrow
   migration-evidence allowlists.
8. Add deterministic fixture interfaces for clock, UUID allocation, random
   purpose streams, filesystem, terminal capabilities, and external facts.
9. Add a headless pure screen-model test seam and an engine-independent golden
   vector format for the deterministic calculation profile.
10. Implement the editorial-versus-normative spec-hash errata protocol and
    automatic demotion of stale verified evidence.
11. Run a bounded terminal-backend spike and record one ADR. The spike must
    demonstrate one-key input, editing, resize, Unicode width, selected text,
    theme-safe roles, no-color fallback, cleanup after interruption, and
    headless rendering. It must not design new screens.
12. Add CI commands for build, unit/property tests, protocol/golden tests,
    spec audit, coverage validation, vocabulary guard, and formatting/lint.

## Gate

- `nix develop` and `cabal build all` succeed from a clean checkout.
- `cabal test all` runs real empty harnesses rather than referencing deleted
  artifacts.
- every canonical rule ID and local Markdown link is uniquely discoverable;
- the generated packet-owner union equals every canonical catalog, and
  deleting any required ownership entry makes the audit fail;
- all 65 flow rows appear exactly once in `implementation/coverage.tsv`;
- deliberately inserting an unknown ID, duplicate ID, stale hash, rejected
  public alias, or missing negative obligation makes the appropriate check
  fail;
- `lant --help` identifies the build as pre-functional without claiming v1
  behavior or exposing `la`.

## Not in this slice

No event schema, Feed mutation, JSONL write, product screen, Allium garden,
generated semantic test, v0 implementation recovery, or README feature claim.
