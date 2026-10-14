# Little Ant 1.0.0-alpha.2

This prerelease promotes the reviewed development line to `main`. The complete
1.0 product remains the target: powered-up mode, the v1 Skill, local web, and
other outstanding beta obligations remain in the [beta backlog](v1-beta.md).
The [alpha contract](v1-alpha.md) remains the supported daily-use boundary.

## Changes

- Guided REPL navigation, task-context assistance, direct exit gestures, and
  completion followed by the next opportunity.
- Importance and forecast browsing with pinned controls, local Ctrl+F search,
  categories containing nested projects and subtasks, and selection context
  above and below paginated rows.
- Markdown styling, readable wrapping, and mouse-wheel scrolling.
- The Forte+ forecast curve, preserving confidence dilution and immutable
  historical selections.
- Disposable fold snapshots, immutable hot/cold event storage, complete
  historical diagnostics, and corrected retired-dependency handling.
- An offline HTML explorer with category/part trees and separate composition
  and dependency sections, plus fixes at the reviewed integration boundaries.

## Data and installation

Install from `main` or the signed `v1.0.0-alpha.2` tag. The CLI and Nix artifact
both report `1.0.0-alpha.2`. Existing canonical event identities are retained;
snapshots are rebuildable caches and archived event segments remain immutable.
An older executable that reads only the hot event directory cannot replay a
rotated dataset. Keep a complete pre-upgrade backup when retaining the ability
to return to an older executable; always run this release against its updated
storage layout.

Private test datasets, completion-migration receipts, credentials, and the
hypothetical demonstration Bricks are outside the release source tree. User
completion migration is a separate, selective operation on the existing
profile, rather than publication of test data.

## Validation

The complete local CI gate covers conformance, canonical specification audits,
Pack archive authentication, formatting and lint, Haskell suites, CLI behavior,
and real PTY tests. Additional review checks exercise the tree and selection
context in 80- and 28-column terminals and the offline HTML in desktop and
mobile widths. See the [review record](../reviews/2026-10-10-spec-and-repl.md)
for the evidence boundary and outstanding coverage gaps.
