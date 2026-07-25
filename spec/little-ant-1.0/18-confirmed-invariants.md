# 18. Confirmed invariants at a glance

1. Every active Brick has one parent scope and one sibling position from birth.
2. Every active sibling set has a total priority order.
3. Priority comparisons are valid only between siblings.
4. Global priority display is lexicographic by tree path.
5. Dependencies affect eligibility and pressure, never human priority position.
6. Every active Brick has one phase; phase does not sort priority.
7. Human judgments prevail over AI judgments.
8. All judgment history is retained; current judgment favors newer applicable
   evidence within authority rules.
9. Contradictions lower confidence or reliability and trigger local validation
   or recalibration rather than invalidating state.
10. Raw is material, never directly prioritized or focused.
11. Raw use is non-consuming and many-to-many.
12. Multiple WIPs may exist; current human focus is zero-or-one.
13. Forecast is derived and read-only; `next` records a reproducible draw.
14. Served-Brick skip, ordering skip, and classification skip are distinct
    core operations.
15. Impact means expected impact and uses
    `VERY_LOW < LOW < MEDIUM < HIGH < VERY_HIGH < CRITICAL`.
16. Only roots are directly classified for impact; descendants inherit their
    root assessment.
17. Public impact evidence maturity is
    `SPECULATIVE < SUPPORTED < VALIDATED < OBSERVED`; it is not probability of
    success.
18. Purposeful impact validation may be a real `validation`-phase Brick, and
    completing it never silently changes the target assessment.
19. Effort means total work for the current scope, not remaining work.
20. Effort uses a discrete, ordered, versioned EffortProfile. There is no
    public effort float or global effort list.
21. Progress never lowers total effort. Remaining effort is derived only from
    conservative evidence.
22. Parent effort includes descendant scope. Decomposition coverage must be
    explicitly confirmed and structural changes reopen it.
23. The core may suspect scope change mechanically, but only a human or
    operator confirms a semantic scope revision.
24. Hours never belong to canonical Brick state.
25. A planning cut is non-overlapping, so no plan counts effort at both a
    Brick and its descendant.
26. Every planning-cut item uses one macro that expands into all scenarios.
27. Every confirmed simulation has an immutable reproducible planning manifest
    outside operational domain state.
28. The core never calls AI or the network for judgment.
29. External actions remain explicit and human-approved.
30. The core has one canonical English vocabulary and no compatibility aliases.
31. The 1.0 REPL uses the same canonical command semantics as the CLI and never
    answers a human decision automatically.
32. Finite choices in the REPL execute on one keypress; text entry is an
    explicit mode.
33. REPL recovery state is stored separately from the domain event log, and a
    stale keypress is never applied to a different prompt.
