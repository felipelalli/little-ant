# 9. Impact and evidence maturity

Impact is independent from priority, dates, phase, and effort.

## 9.1 Meaning and scope

Impact means **expected impact**: the magnitude already accounts for the
chance that the outcome will occur. It is not the conditional upside assuming
success.

- Only root Bricks receive direct impact classifications.
- Descendants inherit their root's impact.
- Reparenting may make old impact evidence inapplicable while preserving it
  in history.
- A root's impact may change when its scope or evidence changes, but neither
  priority position nor phase silently changes with it.

## 9.2 Public impact classes

Impact uses one ordered, discrete vocabulary:

```text
VERY_LOW < LOW < MEDIUM < HIGH < VERY_HIGH < CRITICAL
```

There is no public `impact_score` float. The exact assisted classification
dialog and the default class when no reasonable basis exists remain open.

Direct human classification and comparison evidence may both contribute to a
current class. The core retains the full evidence history and gives greater
weight to newer judgments within the authority rules.

## 9.3 Evidence maturity

Impact confidence is represented publicly as evidence maturity, not as a
decimal:

```text
SPECULATIVE < SUPPORTED < VALIDATED < OBSERVED
```

| Maturity | Meaning |
|---|---|
| `SPECULATIVE` | A bet, prior, or opinion that has not been deliberately tested. This is the normal starting point for innovation. |
| `SUPPORTED` | Comparisons, analogs, or signals consistently support the assessment, but no deliberate validation has occurred. |
| `VALIDATED` | A questionnaire, experiment, POC, MVP, homologation, or another purposeful validation produced relevant evidence. |
| `OBSERVED` | The impact or damage is occurring or has been measured directly, such as an active production incident. |

Maturity is about the quality and directness of evidence. It is **not** the
probability that a speculative product will succeed. That probability already
belongs in the expected-impact judgment.

The core may derive an internal selection-reliability signal from maturity,
recency, consistency, and provenance. That internal signal is not a second
public impact rating.

Evidence can become stale, contested, or inapplicable after a scope change.
The core must never silently downgrade the public maturity. A human or
operator must explicitly confirm any downgrade, and the older evidence remains
in history. Exact evidence requirements for promotion and demotion remain
open.

## 9.4 Comparison, contradiction, and recalibration

Comparison history remains useful for classifying impact and validating the
current assessment. Ties, reversals, and cycles are valid evidence states,
not invalid domain state.

- Newer evidence weighs more than older evidence.
- Direct human judgment has greater authority than AI evidence.
- Contradictions reduce internal reliability and create validation pressure.
- The core may ask provocative questions that directly test a relation implied
  by earlier comparisons.
- A contradiction starts or schedules local recalibration; it does not justify
  an opaque automatic rewrite.

The exact wording, answer grammar, comparison selection algorithm, cooldown,
and mapping from comparison evidence to the six classes remain open.

## 9.5 Validating uncertain impact

A quick comparison is an `impact_probe` proposal. Purposeful real-world
validation is actual work and therefore may become a Brick.

Examples include:

- design and run a customer questionnaire;
- perform market research;
- build and evaluate a proof of concept;
- release an MVP and measure its reception;
- homologate a proposed solution.

Such work is an ordinary Brick:

- it may use phase `validation` when phase is applicable, but phase is not
  required to make the work legitimate;
- it may have children, dependencies, dates, and its own priority;
- generic provenance or `about` relationships may connect its evidence to the
  assessment without introducing a special validation-work entity;
- its concrete method remains external judgment.

Completing a validation Brick does not automatically change the target's
impact class or maturity. Its result must first be recorded as evidence; a
human or operator can then confirm a new assessment, preserve the current one,
or decide to drop or supersede the target.

Little Ant should propose investigation work only when the expected value
of information is high: evidence maturity is low, the uncertainty could
change a relevant decision, and the work is sufficiently important or close
to execution. The core may identify this condition but must not invent a
method or create the Brick automatically.
