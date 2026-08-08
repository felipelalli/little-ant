# S06 — Structure, lifecycle composition, and checklists

Status: **planned**

## Outcome

Implement universal Brick decomposition and the complete closed Nature
capability matrix: child-owning structures, ListEntry-owning checklists,
reclassification, merge, supersession, archive scope, and parent closure.

## Canonical flow rows owned

- Atomic break/reclassification and part addition
- Merge/supersede/subtree outcome
- Behavior and Nature reclassification
- Living-checklist run
- Finite-checklist run
- Nature capability matrix

Generate all owning-row references plus MOD-025..047, MOD-060..064,
MOD-077..089, WRK-066, WRK-106..122, WRK-129..133,
FOC-039..040, UX-B00..B02, UX-NAT01, UX-L00..L01,
UX-LC00..LC05, and SCN-LC-001.

## Work

1. Implement direct `/break` and symptom-origin decomposition with draft
   parts, assisted-provenance placeholders, preview, atomic commit, local
   initial order, and parent suppression until scope review.
2. Implement project, collection, finite checklist, living checklist,
   repeatable, recurring obligation, habit, and scheduled commitment capability
   records without Nature-specific primary screen forks.
3. Generate and verify the complete 9×9 reclassification matrix from the
   canonical capability profile, including structure, standing state, focus,
   builders, and compensation.
4. Implement owner-scoped ListEntry identity, parsing, quantity, lifecycle,
   complete-list focus surfaces, and run completion distinctions.
5. Implement parent-only/subtree archive, mixed child outcomes, scope closure,
   reparenting, and review invalidation.
6. Implement merge's closed transfer matrix and supersession's explicit
   non-transfer policy as atomic batches with conflict previews.

## Gate

- generated capability and all-pairs reclassification tests cover all 81
  source/target combinations;
- child Bricks never convert to ListEntries and vice versa;
- a decomposed finite parent is not proposed as ordinary Work while active
  children exist;
- terminal children release a review but never auto-complete the parent;
- merge and supersede retain distinct lineage and semantics;
- every structure/lifecycle batch is all-or-none under crash, stale, dry-run,
  and undo injection.
