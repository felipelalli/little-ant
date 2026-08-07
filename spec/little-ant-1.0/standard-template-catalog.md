# Standard Template catalog

Status: **Little Ant 1.0 offline standard library**

This catalog defines the declarative BrickTemplates shipped in the offline
Little Ant 1.0 standard library. It does not add domain branches to the core.
Every Template expands validated Natures and capabilities, records provenance,
and loses authority after creation. Later behavior updates change Nature under
MOD-058..059; they never edit or falsify Template provenance.

A Template remains built-in only when it provides meaningful declarative
classification guidance, creation defaults, or structure beyond renaming its
root Nature. The offline library intentionally covers many
common situations. Companion Packs remain available for highly specialized
domains, integrations, or recipes rather than carrying ordinary everyday
choices by default.

Each Template may also publish declarative classification guidance: varied
examples, positive semantic or structural cues, counterexamples, and relevant
source shapes. These are aids for catalog-wide Skill or powered-up judgment,
not a finite keyword classifier and not prompt text that a Pack can execute.
The catalog examples below explain recipes; they do not delimit what the
classifier can recognize.

## `atomic_task`

| Template | Status | Example or purpose |
|---|---|---|
| `bug_fix` | confirmed | Fix one bounded defect and optionally record verification evidence. |
| `one_off_errand` | confirmed | Pick up, return, deliver, or obtain one thing under Place conditions. |
| `one_off_purchase` | confirmed | Buy one independently focusable item rather than maintain a list. |
| `document_review` | confirmed | Review one document with an attached Raw or SourceLink. |
| `contact_someone` | confirmed | Make one call, visit, message, or other contact. |
| `quick_repair` | confirmed | Repair one bounded physical item. |
| `application_submission` | confirmed | Complete and submit one application or form. |

## `scheduled_commitment`

All Templates in this family ship in the offline standard library.

| Template | Status | Example or purpose |
|---|---|---|
| `flight` | confirmed | Preserve zoned departure and arrival facts plus optional check-in, boarding, booking, and airport context. |
| `scheduled_transport` | confirmed | Preserve a train, bus, ferry, or similar ticketed journey with origin, destination, departure, and arrival. |
| `appointment` | confirmed | Attend one externally scheduled appointment with its ExternalEntity, place or link, interval, and optional preparation. |
| `meeting` | confirmed | Attend one meeting with participants, agenda, place or link, interval, and follow-up context. |
| `event_attendance` | confirmed | Attend a show, talk, conference session, ceremony, or similar event with venue and admission context. |
| `reservation` | confirmed | Honor a timed reservation with place, participants, confirmation, and cancellation context. |
| `class_session` | confirmed | Attend one class or lesson with instructor, place, materials, and interval. |
| `exam` | confirmed | Attend one rigidly scheduled examination with place, duration, and entry requirements. |
| `work_shift` | confirmed | Preserve one externally scheduled work interval and applicable place context. |
| `service_window` | confirmed | Be available for a technician, delivery, or other external visit during a bounded arrival window. |
| `hotel_stay` | confirmed | Preserve zoned check-in and check-out boundaries plus property and booking context. |

### Preparation structures

Scheduled-commitment Templates may propose ordinary preparatory Bricks with
relative temporal constraints. Examples include:

- a `flight` may propose document/visa review, insurance review, packing,
  check-in, and travel to the airport;
- a `meeting` may propose one preparation Brick before the meeting;
- an `exam` may propose a study project whose own descendants remain
  independently focusable.

The proposal distinguishes the first eligible instant (`not_before`), the
preferred completion instant (`best_before`), and any true external limit
(`deadline`). Exact factory offsets and optional parts require Template-by-
Template review rather than pretending that values such as 60 days or two
hours fit every case. Rescheduling behavior remains `OPEN-SCH-002`.

## `project`

| Template | Status | Example or purpose |
|---|---|---|
| `software_feature` | confirmed | Specify, implement, and verify one independently managed feature. |
| `product_validation` | confirmed | Define a hypothesis, gather evidence, run an experiment, and decide. |
| `migration_project` | confirmed | Inventory, plan, move, reconcile, and verify a migration. |
| `research_project` | confirmed | Frame a question, gather sources, synthesize evidence, and conclude. |
| `event_planning` | confirmed | Plan and deliver one event. |
| `trip_planning` | confirmed | Decide and arrange one trip; a trip checklist remains separate. |
| `home_improvement` | confirmed | Plan and complete one bounded improvement outcome. |
| `learning_project` | confirmed | Reach one finite learning outcome through separately tracked work. |
| `incident_follow_up` | confirmed | Investigate an incident, define remediations, and verify closure. |

## `collection`

| Template | Status | Example or purpose |
|---|---|---|
| `reading_list` | confirmed | Keep independently focusable books or other reading Bricks. |
| `feature_backlog` | confirmed | Keep each feature as an independently focusable child Brick. |
| `wishlist` | confirmed | Keep independently evaluated purchase candidates. |
| `bills_to_pay` | confirmed | Group recurring-obligation series without flattening their occurrences. |
| `idea_backlog` | confirmed | Keep independently developable ideas as Bricks. |
| `watchlist` | confirmed | Keep independently focusable films, talks, or videos. |
| `places_to_visit` | confirmed | Keep each destination independently selectable. |
| `people_to_visit` | confirmed | Keep each intended visit as independent work. |
| `geocaching_targets` | confirmed | Keep each cache or route independently selectable. |
| `recipes_to_try` | confirmed | Keep each recipe as an independently focusable experiment. |
| `home_maintenance_plan` | confirmed | Group independent repeatable maintenance Bricks. |

## `finite_checklist`

| Template | Status | Example or purpose |
|---|---|---|
| `trip_checklist` | confirmed | Show all remaining entries for one specific trip together. |
| `moving_checklist` | confirmed | Show all remaining entries for one move together. |
| `release_checklist` | confirmed | Verify one concrete software or operational release. |
| `event_checklist` | confirmed | Complete one event's bounded checklist. |
| `onboarding_checklist` | confirmed | Complete one bounded onboarding scope. |
| `audit_checklist` | confirmed | Complete one bounded audit or inspection. |
| `application_checklist` | confirmed | Assemble all entries for one application. |
| `departure_checklist` | confirmed | Complete one bounded departure or closing procedure. |

## `living_checklist`

| Template | Status | Example or purpose |
|---|---|---|
| `grocery_list` | confirmed | Keep a reusable grocery list that sleeps when empty. |
| `household_restock_list` | confirmed | Keep reusable household-supply entries together. |
| `outing_errands` | confirmed | Show the whole current errand batch during one outing. |
| `one_on_one_agenda` | confirmed | Accumulate and resolve topics for recurring one-on-one conversations. |
| `family_agenda` | confirmed | Accumulate and resolve topics for family discussion. |
| `questions_for_next_appointment` | confirmed | Accumulate questions, clear them after use, and retain the list. |

## `repeatable`

| Template | Status | Example or purpose |
|---|---|---|
| `article_reading` | confirmed | Read linked material and optionally return after a completion-relative delay. |
| `periodic_review` | confirmed | Review the same subject again after completing the previous review. |
| `maintenance_task` | confirmed | Repeat one maintenance action after a completion-relative delay. |
| `backup_verification` | confirmed | Recheck a backup after the previous verification. |
| `subscription_review` | confirmed | Reconsider one subscription later without accumulating missed periods. |
| `geocaching_outing` | confirmed | Suggest another outing after a completed one without recording missed windows. |
| `decluttering_session` | confirmed | Offer another session after the previous session is completed. |
| `personal_retrospective` | confirmed | Revisit a personal retrospective after completion. |

## `recurring_obligation`

| Template | Status | Example or purpose |
|---|---|---|
| `bill_payment` | confirmed | Release independently resolvable bill occurrences. |
| `rent_payment` | confirmed | Release monthly rent occurrences that may remain overdue. |
| `subscription_renewal` | confirmed | Preserve each renewal decision or payment until resolved. |
| `periodic_filing` | confirmed | Release independently resolvable filings for each period. |
| `scheduled_report` | confirmed | Release one report obligation per required period. |
| `prescription_refill` | confirmed | Preserve each required refill until resolved or explicitly closed. |
| `vehicle_registration` | confirmed | Preserve each registration renewal occurrence. |
| `insurance_renewal` | confirmed | Preserve each insurance renewal occurrence. |
| `medical_checkup` | confirmed | Preserve each required checkup occurrence until handled. |
| `birthday_greeting` | confirmed | Preserve an annual greeting until done or explicitly closed. |

## `habit`

| Template | Status | Example or purpose |
|---|---|---|
| `physical_activity` | confirmed | Track the fed activity through fixed slots or quota windows. |
| `keep_in_touch` | confirmed | Maintain one habit Brick for one specific ExternalEntity target. |
| `social_time` | confirmed | Maintain social contact without requiring one fixed target. |
| `reading_habit` | confirmed | Complete boolean reading opportunities on a fixed-slot or quota schedule. |
| `study_habit` | confirmed | Complete study opportunities for a chosen subject. |
| `meditation_habit` | confirmed | Complete meditation opportunities and preserve outcomes. |
| `journaling_habit` | confirmed | Complete journaling opportunities and preserve outcomes. |
| `sleep_routine` | confirmed | Track a recurring sleep-related intention and missed windows. |
| `housekeeping_habit` | confirmed | Track recurring housekeeping opportunities without overdue accumulation. |
| `outdoor_time` | confirmed | Track regular time outdoors. |

### Confirmed recipe: `physical_activity`

- Root Nature: `habit`.
- The existing Feed title names the activity, such as `Walk`, `Swim`, or
  `Go geocaching`; the Template does not replace it with a generic title.
- Required creation input: one structured fixed-slot or quota-window schedule
  under `WRK-038`.
- Lazy optional enrichment: Place, preferred time, weather, season, blockers,
  and other ordinary metadata.
- No compatibility alias is defined.

### Confirmed recipe: `reading_habit`

- Root Nature: `habit`.
- Required creation input: one structured fixed-slot or quota-window schedule.
- The fed title or completion criterion may say `Read for 30 minutes` or
  `Read 20 pages`.
- Each applicable opportunity records only the ordinary discrete habit
  outcome. Pages, duration, or other quantities are not target-versus-observed
  progress fields in the 1.0 core.

## Recipe validation checklist

Every built-in recipe is validated against this checklist:

1. whether its root Nature is correct;
2. whether it adds a real recipe rather than only a label;
3. which inputs are required at creation and which remain lazy;
4. whether it creates child Bricks, ListEntries, relationships, or schedule
   configuration;
5. that it remains useful in the offline standard library rather than needing
   privileged domain logic;
6. whether another Template overlaps enough that one should be removed rather
   than retained as an alias;
7. which examples, positive cues, counterexamples, and source shapes make its
   classification guidance useful without pretending to define recognition
   exhaustively.

Every expansion also validates each created structure against the receiving
Brick's MOD-062 capability. A root may create a child checklist that owns its
own ListEntries, but no Template can make an incapable root own child parts or
entries, or hide both ownership families under one root.
