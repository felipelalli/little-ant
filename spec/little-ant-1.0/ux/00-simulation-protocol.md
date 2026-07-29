# UX simulation protocol

## Purpose

The simulation validates comprehension, action grammar, cognitive load, and
cross-surface consistency before Allium or code freezes accidental UX.
Behavioral rules remain in the canonical chapters; scenarios cite them and
may expose missing or contradictory rules.

## Method

- **SCN-001 — One screen per turn.** Present exactly one canonical screen.
  The user may press/type an action or critique wording, density, visibility,
  shortcut, default, context, or transition before state advances.
- **SCN-002 — Hesitation is evidence.** Confusion between `yes`, `no`, `skip`,
  `done`, `later`, or `?` is recorded as a UX defect or semantic question,
  not explained away.
- **SCN-003 — Fixed state.** Every synthetic run declares clock, timezone,
  configuration profile, random seed/cursor, active Domain, focus, and fixture
  revision.
- **SCN-004 — Exact envelope.** The transcript preserves subject, screen kind,
  valid action IDs, shortcut letters, default, secondary context, and
  provenance. Prose summary is not a substitute.
- **SCN-005 — Almost-literal renderings.** Once the canonical screen is
  accepted, record REPL, web/mobile, and skill renderings. Differences are
  allowed only under `UX-003`.
- **SCN-006 — State transition.** After an accepted action, record the
  canonical command, observable result, resulting revision, and next envelope.
- **SCN-007 — No silent invention.** If the target behavior is unresolved,
  stop the scenario at the decision boundary and resolve or record one
  `OPEN-*` item. Do not improvise a product rule.
- **SCN-008 — Commit-backed learning.** After a coherent accepted screen or
  flow, update the screen catalog, scenario, canonical rule if needed, and
  traceability in one small documentation commit.
- **SCN-009 — Dumb REPL first.** Every new flow begins with the complete dumb
  REPL, including header/status, command or key input, main envelope,
  secondary context, and transition. It cannot rely on model judgment.
- **SCN-010 — Paired powered-up replay.** When powered-up behavior is relevant,
  replay the accepted dumb flow from the same state, clock, configuration, and
  random stream. Record exactly which screens were removed, which default or
  proposal was added, and its AI provenance.
- **SCN-011 — Mirrors last.** Only after the REPL pair is accepted, render the
  same envelopes in the operator skill and web/mobile composition. Those
  mirrors do not supply missing core decisions.

## Critique labels

Each issue uses one or more labels:

```text
meaning       — the available actions do not express the intended decision
wording       — canonical English is unclear or inconsistent
hierarchy     — primary and secondary information compete
density       — useful context is too much or too little
shortcut      — letter placement or reuse is surprising
transition    — the next screen or back path is unexpected
provenance    — the user cannot understand why or who suggested something
parity        — surfaces no longer feel like the same product
accessibility — meaning depends only on color, emoji, geometry, or key chord
```

## Decision record

Every resolved finding records:

```text
scenario step
screen revision before
observed hesitation or critique
accepted change
affected UX/rule IDs
screen revision after
commit
```

The chronological chat is not the only copy of a decision.

## Completion criteria

A scenario passes only when:

- the primary question is understandable without a prominent explanatory
  paragraph;
- every visible action has one distinct consequence;
- `?` can reveal sufficient context and return without mutation;
- Escape/back and semantic undo are distinguishable;
- the resulting state and next screen are predictable after explanation;
- the three surface renderings preserve the approved composition;
- the flow ends in a useful proposal, result, recovery, or explicit safe end.
