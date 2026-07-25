# 11. Dates and urgency

Three distinct date concepts are retained:

```text
not_before
best_before
deadline
```

- `not_before` is a hard eligibility constraint before its date.
- `best_before` is a soft target whose pressure rises before and after it.
- `deadline` is a hard deadline with strong approaching and overdue pressure.
- Dates never reorder the human priority tree.
- Dates affect forecast, `next`, warnings, and planning export.
- An earlier `due_at + delay_cost` proposal is superseded by these three
  explicit meanings.
