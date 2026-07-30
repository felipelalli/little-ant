# Standard Template catalog

Status: **release-review ledger**

This catalog tracks the declarative BrickTemplates considered for the offline
Little Ant 1.0 standard library. It does not add domain branches to the core.
Every Template expands validated Natures and capabilities, records provenance,
and loses authority after creation.

Status meanings:

- `confirmed` — the Template and its root Nature are current 1.0 commitments;
- `candidate` — useful review baseline, not yet a release commitment.

A Template remains built-in only when it provides a meaningful creation recipe
beyond renaming its root Nature. A broader companion Pack may carry useful
specialized recipes that do not justify the offline standard-library cost.

## `atomic_task`

| Template | Status | Example or purpose |
|---|---|---|
| `bug_fix` | candidate | Fix one bounded defect and optionally record verification evidence. |
| `one_off_errand` | candidate | Pick up, return, deliver, or obtain one thing under Place conditions. |
| `one_off_purchase` | candidate | Buy one independently focusable item rather than maintain a list. |
| `scheduled_appointment` | candidate | Attend one appointment inside a concrete time window. |
| `document_review` | candidate | Review one document with an attached Raw or SourceLink. |
| `contact_someone` | candidate | Make one call, visit, message, or other contact. |
| `quick_repair` | candidate | Repair one bounded physical item. |
| `application_submission` | candidate | Complete and submit one application or form. |

## `project`

| Template | Status | Example or purpose |
|---|---|---|
| `software_feature` | candidate | Specify, implement, and verify one independently managed feature. |
| `product_validation` | candidate | Define a hypothesis, gather evidence, run an experiment, and decide. |
| `migration_project` | candidate | Inventory, plan, move, reconcile, and verify a migration. |
| `research_project` | candidate | Frame a question, gather sources, synthesize evidence, and conclude. |
| `event_planning` | candidate | Plan and deliver one event. |
| `trip_planning` | candidate | Decide and arrange one trip; a trip checklist remains separate. |
| `home_improvement` | candidate | Plan and complete one bounded improvement outcome. |
| `learning_project` | candidate | Reach one finite learning outcome through separately tracked work. |
| `incident_follow_up` | candidate | Investigate an incident, define remediations, and verify closure. |

## `collection`

| Template | Status | Example or purpose |
|---|---|---|
| `reading_list` | confirmed | Keep independently focusable books or other reading Bricks. |
| `feature_backlog` | confirmed | Keep each feature as an independently focusable child Brick. |
| `wishlist` | candidate | Keep independently evaluated purchase candidates. |
| `bills_to_pay` | confirmed | Group recurring-obligation series without flattening their occurrences. |
| `idea_backlog` | candidate | Keep independently developable ideas as Bricks. |
| `watchlist` | candidate | Keep independently focusable films, talks, or videos. |
| `places_to_visit` | candidate | Keep each destination independently selectable. |
| `people_to_visit` | candidate | Keep each intended visit as independent work. |
| `geocaching_targets` | candidate | Keep each cache or route independently selectable. |
| `recipes_to_try` | candidate | Keep each recipe as an independently focusable experiment. |
| `home_maintenance_plan` | candidate | Group independent repeatable maintenance Bricks. |

## `finite_checklist`

| Template | Status | Example or purpose |
|---|---|---|
| `trip_checklist` | confirmed | Show all remaining entries for one specific trip together. |
| `moving_checklist` | candidate | Show all remaining entries for one move together. |
| `release_checklist` | candidate | Verify one concrete software or operational release. |
| `event_checklist` | candidate | Complete one event's bounded checklist. |
| `onboarding_checklist` | candidate | Complete one bounded onboarding scope. |
| `audit_checklist` | candidate | Complete one bounded audit or inspection. |
| `application_checklist` | candidate | Assemble all entries for one application. |
| `departure_checklist` | candidate | Complete one bounded departure or closing procedure. |

## `living_checklist`

| Template | Status | Example or purpose |
|---|---|---|
| `grocery_list` | confirmed | Keep a reusable grocery list that sleeps when empty. |
| `household_restock_list` | candidate | Keep reusable household-supply entries together. |
| `outing_errands` | candidate | Show the whole current errand batch during one outing. |
| `one_on_one_agenda` | candidate | Accumulate and resolve topics for recurring one-on-one conversations. |
| `family_agenda` | candidate | Accumulate and resolve topics for family discussion. |
| `questions_for_next_appointment` | candidate | Accumulate questions, clear them after use, and retain the list. |

## `repeatable`

| Template | Status | Example or purpose |
|---|---|---|
| `article_reading` | confirmed | Read linked material and optionally return after a completion-relative delay. |
| `periodic_review` | candidate | Review the same subject again after completing the previous review. |
| `maintenance_task` | candidate | Repeat one maintenance action after a completion-relative delay. |
| `backup_verification` | candidate | Recheck a backup after the previous verification. |
| `subscription_review` | candidate | Reconsider one subscription later without accumulating missed periods. |
| `geocaching_outing` | candidate | Suggest another outing after a completed one without recording missed windows. |
| `decluttering_session` | candidate | Offer another session after the previous session is completed. |
| `personal_retrospective` | candidate | Revisit a personal retrospective after completion. |

## `recurring_obligation`

| Template | Status | Example or purpose |
|---|---|---|
| `bill_payment` | candidate | Release independently resolvable bill occurrences. |
| `rent_payment` | candidate | Release monthly rent occurrences that may remain overdue. |
| `subscription_renewal` | candidate | Preserve each renewal decision or payment until resolved. |
| `periodic_filing` | candidate | Release independently resolvable filings for each period. |
| `scheduled_report` | candidate | Release one report obligation per required period. |
| `prescription_refill` | candidate | Preserve each required refill until resolved or explicitly closed. |
| `vehicle_registration` | candidate | Preserve each registration renewal occurrence. |
| `insurance_renewal` | candidate | Preserve each insurance renewal occurrence. |
| `medical_checkup` | candidate | Preserve each required checkup occurrence until handled. |
| `birthday_greeting` | candidate | Preserve an annual greeting until done or explicitly closed. |

## `habit`

| Template | Status | Example or purpose |
|---|---|---|
| `physical_activity` | confirmed | Track the fed activity through fixed slots or quota windows. |
| `keep_in_touch` | confirmed | Maintain one habit Brick for one specific ExternalEntity target. |
| `social_time` | confirmed | Maintain social contact without requiring one fixed target. |
| `reading_habit` | confirmed | Complete boolean reading opportunities on a fixed-slot or quota schedule. |
| `study_habit` | candidate | Complete study opportunities for a chosen subject. |
| `meditation_habit` | candidate | Complete meditation opportunities and preserve outcomes. |
| `journaling_habit` | candidate | Complete journaling opportunities and preserve outcomes. |
| `sleep_routine` | candidate | Track a recurring sleep-related intention and missed windows. |
| `housekeeping_habit` | candidate | Track recurring housekeeping opportunities without overdue accumulation. |
| `outdoor_time` | candidate | Track regular time outdoors. |

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

## Review checklist

Review one root Nature at a time. For each Template, decide:

1. whether its root Nature is correct;
2. whether it adds a real recipe rather than only a label;
3. which inputs are required at creation and which remain lazy;
4. whether it creates child Bricks, ListEntries, relationships, or schedule
   configuration;
5. whether it belongs in the offline standard library or a companion Pack;
6. whether another Template overlaps enough that one should be removed rather
   than retained as an alias.
