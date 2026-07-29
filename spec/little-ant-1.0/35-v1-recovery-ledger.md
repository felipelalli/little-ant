# 35. Little Ant 1.0 recovery ledger

This chapter records decisions confirmed during the regression audit and
structured recovery of Little Ant 1.0. It exists so that a context compaction
or later consolidation cannot silently replace a nuanced decision with an
inference.

## 35.1 Method and authority

- Each confirmed decision is recorded immediately and committed as a small,
  reviewable change.
- Confirmed recovery entries override conflicting earlier design wording until
  the correction is deliberately propagated.
- Open implications remain explicitly open; they are not filled in during
  consolidation.
- The v0 implementation, tests, history, and current operator skill are
  evidence of existing capabilities, not authority for 1.0 terminology or
  behavior.
- The rewritten Allium garden, generated tests, failed v1 implementation, and
  gap-analysis branch are audit evidence, not automatic product authority.
- Allium is changed only after the surrounding behavioral slice has been
  reviewed coherently.

## 35.2 Canonical vocabulary: remove `priority`

Confirmed on 2026-07-28:

- `priority` is not a canonical Little Ant 1.0 term.
- It must not name a new core concept, command, projection, field, event,
  Allium declaration, or normative documentation concept.
- It may remain only when quoting v0 history or preserving the literal
  vocabulary of an external source.
- Natural language such as “prioritize this” is interpreted by the operator.
  If context does not distinguish importance from immediate focus, the
  operator asks instead of passing an ambiguous alias into the core.
- The persistent human judgment is currently called the **importance order**.
- The dynamic derived view is currently called the **focus forecast**.
- One outcome drawn from that view is currently called a **next suggestion**.

The three replacement names remain working terms until their complete
semantics and command grammar are reviewed. Removal of `priority` itself is
settled.

Propagation through older Markdown, Allium, generated tests, README, and the
operator skill is deliberately deferred until the importance/forecast slice is
coherent. Until then, this entry overrides their legacy vocabulary.

## 35.3 Probabilistic, replay-deterministic `next`

Confirmed on 2026-07-28:

- The focus forecast is a derived probability distribution, not a second
  persisted human order.
- `next` uses a weighted pseudo-random draw rather than always selecting the
  candidate with the greatest derived score.
- The stochastic choice must be deterministic under replay: the same
  authoritative state, configuration revision, candidate set, and recorded
  random evidence produce the same result.
- A useful long tail is intentional. Low-scoring or unusual eligible work
  should retain some opportunity to surface instead of being permanently
  hidden by the head of the distribution.
- A Brick excluded by a hard eligibility rule has probability zero in the
  ordinary work lottery.
- Every Brick admitted to that lottery has probability strictly greater than
  zero. Weight transformation, normalization, and tail controls must not turn
  a still-eligible Brick into an implicit exclusion.
- Viewing the forecast must not consume random evidence or change a future
  draw.
- A draw changes neither the importance order nor the underlying judgments.

The analogy with an LLM is motivational, not mathematical. LLM sampling is
normally based on transformed logits rather than a guaranteed normal
distribution. Little Ant therefore does not yet mandate a normal curve,
softmax, temperature, top-p, or another exact formula.

Calibration direction:

- tunable selection parameters should have validated factory defaults;
- users may revise calibratable parameters over time;
- forecasts and draws must identify the configuration revision that produced
  them;
- tests and simulations may sweep parameter sets and report calibration
  metrics;
- calibration must never silently alter hard eligibility rules, historical
  evidence, or semantic invariants.

Current proposal, not yet confirmed:

- expose the calibratable profile in a human-editable YAML file;
- define one or more explicit tail controls analogous to sampling temperature
  or probability-mass cutoffs.

Open implications:

- which conditions are hard exclusions before weighting;
- the exact scoring, normalization, tail, and aging functions;
- whether positive probability also needs a bounded service guarantee;
- configuration schema, validation ranges, revision storage, and migration;
- which calibration changes require explicit confirmation.

## 35.4 Contextual `?` and behavior-aware decomposition

Confirmed on 2026-07-28:

- A minimal `next` prompt does not need a separate `open project` action.
- `?` is the single progressive-disclosure entry point for more information
  about the pending suggestion. It may reveal the suggestion explanation,
  ancestry, relevant project or collection context, children, blockers,
  supporting evidence, and navigation actions.
- Requesting that context preserves the same pending suggestion. It consumes
  no random evidence, records no answer or skip, and performs no domain
  mutation.
- “Full context” means that all relevant canonical context remains reachable
  through bounded, paginated navigation. It does not mean dumping an entire
  sparse projection or event history onto the main prompt.
- A container selected during hierarchical sampling is resolved according to
  its `BrickBehavior`. A project-like finite outcome normally directs focus to
  an eligible descendant rather than being presented as vague executable
  work.
- If a project-like Brick has no suitable descendant, the system may propose
  reviewing or decomposing it. That is a distinct useful action, not an
  automatic child creation.
- Decomposition is never a universal reaction to a high-level title. It is
  available only when the Brick's resolved behavior has finite
  descendant-scope or another explicit decomposition capability.
- The operator skill and powered-up REPL may classify the input's likely
  nature and propose a concrete behavior or template. The dumb REPL uses the
  same core-provided candidates and asks a bounded deterministic question when
  the choice materially changes semantics. The core validates and records the
  chosen behavior; it does not infer a domain from title keywords.

Open implications:

- whether a project-like Brick may be directly focusable when it also has
  active descendants;
- the exact hierarchical allocation of probability between a container and
  its descendants;
- when uncertain behavior classification must be resolved rather than safely
  retaining the generic `standard` behavior.

Current blocked-work proposal, not yet confirmed:

- A blocked Brick is not returned as though it were an executable result.
- It remains visible in the focus forecast as blocked demand.
- Its derived demand may add bounded, explainable pressure to an actionable
  blocker, so selecting that blocker can also remind the user what it
  unlocks.
- A blocked Brick may separately produce a low-frequency review or reminder
  proposal. Such a result asks the user to inspect or change the blockage; it
  does not pretend that the blocked work can be executed.
- Dependency chains, multiple blockers, external waits, cycles,
  double-counting, attenuation, and pressure caps still require explicit
  rules.
