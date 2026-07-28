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
