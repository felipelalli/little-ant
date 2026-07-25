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

## 12.2 Delegation

- Delegated work does not consume the human WIP count or current focus.
- Many delegations may proceed in parallel.
- `digital` mode does not imply AI execution.
- Automation is represented by an active Delegation to a Party whose type is
  `ai_agent`.
- Delegated work returns to the human as follow-up, decision, or validation
  proposals.
