# 12. WIP, current focus, and delegation

## 12.1 WIP is not exclusive focus

There are two different concepts:

1. `work_state = idle | wip` is long-lived and may remain open for days;
2. current human focus is exclusive and points to zero or one Brick globally.

Confirmed behavior:

- Multiple human WIPs are allowed.
- The default soft WIP limit is **3**.
- A fourth or later WIP is allowed; it increases pressure for `review_wip`.
- `review_wip` offers keeping it open, returning it to idle, completing it,
  dropping it, or superseding it.
- WIP review must never fabricate completion.
- Focusing an idle Brick implicitly changes it to WIP.
- Focusing another Brick removes current attention from the previous one but
  leaves the previous Brick in WIP.
- Focus changes are recorded in the event log.
- Stale focus never clears silently.
- A `stale_focus` proposal asks whether to continue, unfocus, or resolve it.

The exact canonical commands for focus, unfocus, and returning WIP to idle
remain open. No compatibility aliases will be added to avoid making that
choice.

## 12.2 Standing-work executions

A standing Brick may have many execution occurrences without becoming
terminal. Focusing it may start a run; finishing the run records an execution
outcome, returns the Brick to idle, and clears current focus without setting
the Brick to `done`.

Terminal completion means retiring the standing responsibility. The exact
canonical commands and whether execution occurrences are explicit entities or
event-derived records remain open.

## 12.3 Delegation

- Delegated work does not consume the human WIP count or current focus.
- Many delegations may proceed in parallel.
- `digital` mode does not imply AI execution.
- Automation is represented by an active Delegation to a Party whose type is
  `ai_agent`.
- Delegated work returns to the human as follow-up, decision, or validation
  proposals.
- Before its initial external notice may be approved, every Delegation must
  declare exactly one follow-up policy: one scheduled follow-up, a repeating
  follow-up cadence, or explicit no follow-up.
- Omitting the policy is invalid. Explicit no follow-up is a deliberate,
  inspectable decision rather than the absence of data.
- A repeating policy schedules review and approval opportunities. It never
  authorizes automatic external messages.

Delegation scope is a core-validated `BrickNature` capability:

| Scope policy | Behavior |
|---|---|
| `brick_only` | Only the cited Brick is delegated; descendants remain independently eligible. |
| `whole_scope` | The Brick and its Nature-defined execution scope are delegated together. |
| `ask` | The user chooses the applicable concrete scope before the initial notice preview. |
| `disabled` | The Brick's execution cannot be delegated; applicable enabling Bricks may still be delegated separately. |

For `whole_scope`, existing and future descendant Bricks are covered
derivatively rather than copied into separate Delegations. Nature-owned
ListEntries are included because they are part of the parent's execution unit,
not independent Bricks. Covered descendants remain visible for tracking,
follow-up, and validation but are not offered as human execution while the
ancestor Delegation remains active.

Adding a descendant later therefore cannot leak delegated work back into the
human forecast. Existing human focus, WIP, a child Delegation, or another
incompatible assignment inside the proposed scope must appear in the preview
and block silent activation until reconciled. Delegation never cascades
completion: a reported whole-scope result still follows ordinary Nature-aware
validation and parent-review rules.

For `ask`, the selected concrete scope is stored on the Delegation so later
follow-ups do not repeat the question. For `disabled`, the typed error may
offer a concrete enabling Brick, such as delegating pool research for a
personal swimming practice, but it never fabricates or auto-delegates that
work.
