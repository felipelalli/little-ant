# 28. Place conditions and location observations

## 28.1 Minimum 1.0 model

Little Ant 1.0 supports named places and time-bounded location observations so
physical work can become useful when the user is actually somewhere.

The working concepts are:

- `Place`: a stable canonical reference with an English label for a
  user-defined physical or logical place such as `Home`, `Office`, or
  `Supermarket`;
- place condition: an explicit relationship stating that a Brick is executable
  or particularly useful at one or more places;
- location observation: an attributed, time-bounded report that the user
  entered, left, or is currently at a named Place.

A Place is not a global real-world-object catalog. The minimum core does not
need street addresses, coordinates, maps, routes, store inventories, or
geofence geometry. Exact Place identity, hierarchy, and configuration fields
remain open.

## 28.2 Conditions and selection

A Brick's place condition may be hard or soft:

- a hard requirement makes the Brick ineligible while no applicable current
  observation exists;
- a soft affinity keeps the Brick eligible but may increase its forecast
  relevance while the observation is current.

These are working semantics; final field names remain open. A place condition
never changes the human priority tree. It affects only eligibility, forecast,
`next`, explanation, and optional grouping of compatible physical work.

An active observation may produce a derived proposal to show or group matching
errands for that Place. The working proposal name is `place_batch`; it is not a
Brick, a stored second priority list, or an instruction to execute every
matching item.

## 28.3 Observation contract

A location observation records at least:

```text
place
observation kind
observed_at
author and source
validity or expiry evidence
external observation identity when applicable
```

An entry or presence observation remains applicable only until an explicit
exit, replacement, or deterministic expiry. Stale location evidence must not
continue affecting selection. Replaying the same attributed external
observation is idempotent.

The same canonical ingestion path accepts a manual statement such as “I am at
the supermarket” and an adapter observation. Their provenance remains
different. An adapter report does not fabricate human testimony, and a manual
report does not pretend to be sensor evidence.

## 28.4 Core and adapter boundary

The core owns:

- Place identity and canonical labels;
- explicit Brick-to-Place conditions;
- attributed observation ingestion and idempotency;
- current-observation derivation and expiry;
- deterministic eligibility and forecast effects;
- explanations and derived grouping proposals.

The adapter or host owns:

- device permission and consent;
- GPS, Wi-Fi, Bluetooth, geofence, or other sensing;
- raw coordinates and geofence geometry;
- mapping sensor results to an already configured Place;
- transport and wake-up integration.

Raw coordinates are neither required nor stored by the minimum core. The core
does not poll a sensor or network and does not continuously track movement.
Without an adapter, manual observations provide the same domain behavior.

## 28.5 No silent action

A location observation may make work eligible or produce a proposal. It never
silently:

- changes human priority;
- starts, completes, skips, or delegates a Brick;
- resolves a wait or dependency unless that separate canonical operation is
  explicitly confirmed;
- sends a notification or performs another external effect.

Any future location-driven notification remains subject to the ordinary
external-action and approval boundary. Presence at a Place is evidence for
selection, not authorization to act.

## 28.6 Still open

- Final canonical names and persistence forms for Place, place condition, and
  location observation.
- Hard versus soft condition configuration, multi-place matching, and
  inheritance.
- Observation kinds, source authority, correction events, TTL defaults,
  replacement, and exit semantics.
- Privacy controls, retention, redaction, export, synchronization, and
  deletion of location history.
- Place aliases, duplicate suspicion, nesting, and adapter mapping.
- `place_batch` proposal ranking, grouping, interaction, and coexistence with
  context, mode, dates, waits, and ordinary forecast.
- Whether a configured adapter may wake a surface without issuing a
  notification, and the exact approval boundary for any push behavior.
