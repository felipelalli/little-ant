# 16. Core, operator, and adapter boundary

## 16.1 Core responsibilities

The core must remain deterministic, offline-capable, and replayable. It owns:

- the append-only event log and upcasting;
- canonical English commands and values;
- entity state and lifecycle invariants;
- tree structure and total sibling orders;
- comparison history and authority rules;
- discrete impact and effort classifications, versioned EffortProfiles, and
  deterministic confidence or internal reliability calculations;
- decomposition coverage, scope-change suspicions, and explicitly confirmed
  scope revisions;
- pseudo-random selection with recorded seeds or cursors;
- cooldown, aging, and proposal mechanics;
- projections, including priority and forecast;
- non-overlapping planning-cut proposals;
- explicit evidence ingestion with author, source, reason, and confidence.

The core may implement sophisticated statistics. “Deterministic” does not mean
“mathematically simplistic.”

## 16.2 Core prohibitions

The core must not:

- call an AI model;
- call the network to obtain judgment;
- own API keys;
- infer semantic analogies through a vendor service;
- keep public compatibility aliases for removed commands or concepts;
- silently perform external side effects.

## 16.3 Operator responsibilities

The operator skill owns:

- understanding free-form and legacy human vocabulary;
- mapping it to one canonical core operation;
- translating non-English interaction into canonical English data;
- proposing titles, descriptions, phases, parents, and comparison reasons;
- finding semantic analogs;
- deciding whether a mechanical edit represents a semantic scope revision;
- proposing an appropriate validation method when impact uncertainty deserves
  real work;
- invoking AI or external planning tools;
- obtaining human confirmation where inference changes structure or authority;
- injecting explicit, attributed evidence into the core;
- explaining low confidence and asking useful questions;
- drafting external actions for approval.

Adapters own translation between Little Ant evidence and external tool formats,
including immutable planning manifests and confirmed actual imports.

## 16.4 REPL surface

The REPL is a deterministic first-party surface over the same canonical
command runner as the ordinary CLI. It owns guided dialog, terminal rendering,
and a separate atomic UI checkpoint. It does not gain operator authority,
change domain semantics, or place unconfirmed presentation state in the event
log.

See [Deterministic REPL harness](24-repl-harness.md).
