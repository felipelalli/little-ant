# 21. Documentation phase and implementation boundary

The agreed sequence is:

1. review this consolidation;
2. create the 1.0 root and review the existing Little Ant backlog Brick by
   Brick;
3. update the design record with each accepted idea and resolve the blocking
   questions that the review exposes;
4. complete a final conceptual consistency review;
5. revise `spec/little-ant.allium`;
6. revise `README.md`;
7. revise `skills/little-ant/SKILL.md`, `commands/lant.md`, Pack manifest and
   component-contract documentation, the TaskJuggler reference-exporter guide,
   and any contract-relevant mockups or projections;
8. validate the documentation and specification as a coherent English
   contract;
9. create an implementation plan and an explicit v0-to-1.0 data migration
   plan;
10. only then begin coding.

The documentation phase must not quietly implement behavior. The coding phase
is a separate, explicitly authorized stage.

The final README uses progressive disclosure and remains an entry point rather
than an architecture encyclopedia. It should state event-log authority and
canonical blob completeness in one short principle, then link to
the relevant chapter under `spec/little-ant-1.0/`. The Markdown specification
record owns storage, replay, upcasting, projection, checkpoint, manifest,
backup, and integrity explanations. `spec/little-ant.allium` owns only
externally observable behavior and must not prescribe SQLite or another
physical storage implementation.

The README's priority explanation must use the 1.0 model rather than the
current frontier-only v0 model. A concrete example should show that every
active Brick is positioned from birth, a blocked Brick may remain most
important, dependency affects eligibility and blocker pressure rather than
priority, and unblocking requires no new insertion.
