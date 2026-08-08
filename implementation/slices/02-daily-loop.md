# S02 — Daily loop: Raw to usable Work

Status: **implemented**

## Outcome

Complete the first useful dumb loop: an Inbox Raw is drawn for triage, may
become ordinary Work or a ListEntry/attached Raw, receives the required Nature
and initial sibling position, and can reach a singleton Focus/done path. S04
later generalizes selection to the complete forecast.

## Canonical flow rows owned

- Nature discovery
- Template selection/proposal
- Raw triage and disposition
- Duplicate suspicion
- Parent/owner/Domain choice
- Initial importance insertion
- Complete Raw-to-Work materialization

Generate the owning flow references plus MOD-002..018, MOD-019..029,
MOD-049, MOD-052..057, MOD-062..072, FED-010..029, FED-042..056,
IMP-001..010, IMP-030, IMP-040..046, FOC-037, FOC-051..054,
WRK-001..006, WRK-047..049, UX-K01..K06, UX-T01..T10, UX-RA00,
UX-C01, and the relevant S01 registry cases.

## Work

1. Add Brick, Nature, Template provenance, RawShelf, RawLink, Domain,
   ListEntry, direct parent, and sibling-position records with their exact
   identity/cardinality invariants.
2. Add factory Natures and Templates as inspectable versioned data, not
   hardcoded UI branches or hidden runtime policy.
3. Implement Raw triage as its own lottery opportunity and preserve the Raw
   through every disposition.
4. Implement the mechanical `[?] I don't know` Nature tree and explicit final
   confirmation before materialization.
5. Implement duplicate suspicion separately for repeated Raw receipts,
   existing Work, and owner-scoped ListEntry quantity/reuse.
6. Implement sibling-only binary insertion, nearby-comparator skip behavior,
   provisional midpoint placement, and cancellation without durable allocation.
7. Commit Raw-to-Work creation, links, Nature/Template facts, parent/Domain,
   initial position, handles, and lazy review claims as one atomic command group.
8. Add the minimum singleton Work proposal, Focus consent, current-focus
   resting screen, direct done, and useful post-completion result needed to
   exercise the vertical loop. S04 owns complete multi-subject forecast
   verification.

## Acceptance path

Use SCN-FED-001..005 and SCN-IMP-001, including:

```text
Feed "fix a bug on website" → restart → Raw triage → Work
→ Nature discovery/confirmation → initial local order → next
→ Focus? → current focus → done → useful next/empty result
```

Also replay `milk, coffee, bread` through recent-Raw evidence, grocery
ListEntry ownership, repeated `milk`, quantity addition, keep-separate, and
Raw receipt preservation.

## Gate

- every accepted Feed still has an inspectable Raw receipt;
- every active Brick is born with exactly one Nature and sibling position;
- only siblings are compared;
- description is an ordinary RawLink role, never a scalar field;
- assisted provenance types may exist, but no model runs yet;
- all mutations have dry-run, stale, crash/replay, and declared undo evidence.
