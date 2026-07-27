# 25. Brick behaviors and template library

## 25.1 One Brick model

Little Ant keeps one canonical Brick entity. Domain vocabulary such as grocery
list, reading list, wishlist, feature backlog, and packing list must not create
hard-coded branches in the core.

The earlier working term `BrickShape` is not introduced as another
user-configurable Brick field in 1.0:

- leaf and container structure can be derived from relationships;
- behavior differences belong to `BrickBehavior`;
- a genuinely new structural invariant requires a core and event-schema
  change, not an unchecked configuration value.

A human-facing “nature” may remain useful to the operator for classification,
search, or template selection. It does not silently activate core behavior.

## 25.2 BrickBehavior

`BrickBehavior` is the selected working name for a persistent, explicit policy
that tells the deterministic core how a Brick participates in interaction.
The qualified name avoids conflict with `EffortProfile`.

A behavior may select only capabilities implemented and validated by the core,
including:

- whether the Brick itself, its descendants, or a batch is normally focused;
- whether it owns structured entries;
- whether all open entries are rendered together;
- whether empty standing work is ineligible;
- whether phase and effort are applicable and may be collected lazily;
- how an execution occurrence affects the standing Brick;
- how completion, recurrence, future reactivation, and supported
  event-triggered opportunity mechanics are exposed.

Behavior is not arbitrary executable code. It must not contain scripts, network
calls, prompts whose semantics bypass the core, or hidden aliases.

Working generic factory behaviors include:

| Behavior | Purpose |
|---|---|
| `standard` | The Brick itself is an ordinary focusable unit. |
| `project` | The parent represents one finite outcome; descendant scope contributes to its reviewed completion. |
| `collection` | An open-ended set of independently focusable child Bricks ordered by importance; empty state is dormant. |
| `repeatable` | The Brick itself is executed repeatedly; completion may schedule the same Brick behind a future `not_before`. |
| `standing_checklist` | The parent is the focus unit; open ListEntries are shown together and empty state is dormant. |
| `finite_checklist` | The parent is a finite focus unit; its entries are shown together and closure is explicitly reviewed. |
| `recurring_obligation` | A standing series releases independently completable Brick occurrences. |
| `practice` | A standing Brick exposes expiring opportunities and execution history without overdue accumulation. |

Exact canonical IDs and capability fields remain open. Factory definitions
must be namespaced, inspectable, and versioned. A Brick keeps the applicable
version or a replay-safe resolved snapshot. Editing a definition must never
silently change existing Bricks.

## 25.3 BrickTemplate

`BrickTemplate` is a one-time creation recipe. It may:

- select a `BrickBehavior`;
- provide a default English title and description;
- create an initial Brick structure;
- provide default context, mode, entry fields, or recurrence configuration;
- record template provenance for explanation and future duplicate detection.

After expansion, the template has no hidden runtime authority. The resulting
Brick, behavior reference, entries, opportunity triggers, and relationships
are ordinary canonical state. Changing a template affects only future
creations unless an explicit migration is confirmed.

The standard library may ship opinionated domain templates as inspectable data:

| Template | Generic behavior |
|---|---|
| `grocery_list` | `standing_checklist` |
| `packing_checklist` | `finite_checklist` |
| `reading_list` | `collection` |
| `article_reading` | `repeatable` |
| `feature_backlog` | `collection` |
| `wishlist` | `collection` |
| `bills_to_pay` | `collection` with recurring-obligation children |
| `exercise_practice` | `practice` |

These mappings are illustrative working names, not final command grammar. The
core implements the generic behavior, never a branch such as “if grocery
list.”

For example, an `article_reading` template may create one self-focusable Brick,
attach a URL Raw with the `source` role, offer a completion note, ask whether
the article should return after each finished reading, and default that repeat
to six months plus or minus three months. After expansion:

- `repeatable` supplies only the validated runtime mechanics;
- the Brick's resolved configuration carries the chosen repeat defaults;
- execution history and a scheduled `not_before` are canonical state;
- template provenance explains the defaults but does not continue making
  decisions;
- `EffortProfile` remains solely an effort-calibration concept.

Templates may set only validated capability inputs. They cannot embed an
arbitrary prompt, script, hidden workflow, network call, or domain-specific
core branch.

`packing_checklist` is the finite case for preparing a trip, move, or event:
all entries are rendered together and the Brick may close after that packing
scope ends. `grocery_list` is the contrasting standing case: finishing one
shopping run does not retire the list.

`exercise_practice` is intentionally broader than walking and more idiomatic
than `sporting_practice`. It may configure walking, swimming, running, gym
work, or another physical practice while retaining the generic `practice`
mechanics.

## 25.4 Factory library and customization

The installed product should provide a small factory behavior library and may
provide a considerably broader standard template library. Both are distributed
with the product and available offline, but templates remain versioned data
rather than hard-coded domain branches. Canonical core surfaces let the REPL,
operator, and human inspect definitions, resolved configuration, and
provenance.

Users may:

- clone a factory behavior into a personal namespace;
- compose a custom behavior from supported capabilities;
- clone or create templates freely;
- override template defaults without defining a new core concept.

Adding a new behavior capability or fundamental structural invariant requires
an explicit core version. The exact definition format, commands, validation,
versioning, import, and migration rules remain open.

Factory and community definitions may be distributed in versioned Little Ant
Packs. The core owns the capability schema and validation; a pack supplies
inspectable definitions and never creates a provider- or domain-specific
branch. The standard pack remains available offline with the product, while a
broader `little-ant-packs` repository may evolve independently. See
[External imports, source views, and extension packs](32-external-imports-source-views-and-extension-packs.md).

## 25.5 Template discovery and custom construction

Standard and personal templates participate in a core-queryable catalog. A
template may carry deterministic discovery metadata such as an English display
name, category, concise purpose, search terms, examples, compatible targets,
required inputs, and the concrete structure it expands. Discovery metadata
helps retrieve candidates but never gains runtime authority.

The capture flow proposes a concrete route rather than persisting an abstract
guessed nature. A route may:

- add a ListEntry to an existing Brick;
- create a Brick from a specific template version;
- create an ordinary Brick with a selected behavior;
- preserve the input as Raw;
- enrich an existing compatible entity after duplicate review.

Original input remains preserved throughout routing. The core retrieves a
bounded, context-sensitive candidate set and validates every route and
template input. The operator skill or powered-up REPL may rank those candidates
and populate a structured proposal containing the route, target, template
version, inputs, confidence, reason, and AI provenance. It cannot submit an
arbitrary expansion or unsupported behavior.

A high-confidence attributed proposal still asks for confirmation when it
changes semantic structure. If it is rejected, or if no AI adapter exists, the
same state-scoped interaction envelope presents a deterministic shortlist:

- directly selectable compatible routes or templates;
- `other templates`, which opens categorized, searchable, paginated catalog
  browsing;
- `custom`, which opens a guided capability builder;
- contextual help that restores the same pending decision.

Every finite choice uses one keypress. Exact letters belong to the canonical
core grammar and remain open.

The custom builder asks only about observable mechanics, including the focus
unit, finite versus standing lifetime, entry or child structure, completion
effect, repetition or recurrence, and applicability of optional axes. It first
reuses an existing resolved behavior with the same capabilities. If no such
behavior exists, it may create a versioned personal behavior in a personal
namespace using only core-supported capabilities, then offer to save the
creation recipe as a personal template.

The full catalog is never required in permanent LLM context. Candidate
retrieval, filtering, and progressive disclosure keep powered-up mode and the
operator skill bounded as the standard library grows.

## 25.6 Capture and routing

`feed` remains the general capture intent, not a semantic guess embedded in the
core. The canonical operation after interpretation may create a Brick, capture
Raw, instantiate a template, or add a ListEntry.

- The operator or powered-up REPL may infer a likely behavior, template,
  parent, or entry target and present an attributed proposal.
- The dumb REPL may use deterministic dialog context, such as the currently
  open list, or offer a default when exactly one compatible target exists.
- Ambiguous global input must not be silently routed.
- Capture must remain fast; behavior, phase, and effort are not a mandatory
  form.
