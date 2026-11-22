# FUN-01 — Focus Boost and Combo Deliveries

Parcel Pulse now has two meaningful decisions besides turning junctions:

1. **Build a delivery streak**: consecutive correct destinations earn increasing bonus points (up to +100 extra per delivery).
2. **Spend a Focus Boost**: every third correct delivery grants one charge, up to two stored. Press **FOCUS** while running to slow parcel travel and incoming spawns to 45% for five real seconds. Pause freezes the gameplay and countdown. Focus cannot be stacked or used twice while active.

A wrong delivery resets the streak. Streak, best streak, Focus charges and countdown reset on retry and on stage changes. Bonuses, charges and Focus are entirely offline and deterministic; no randomness, monetization, or server dependency.

## Acceptance
- First two deliveries give +100 each; third gives +125 and one Focus.
- Fourth, fifth and sixth give +150, +175 and +200 respectively, with a second Focus granted at six.
- Maximum combo bonus is +100 per delivery, including after six.
- A mistake resets the streak but does not take away already-earned Focus.
- While Focus runs, 1 second of wall time advances the simulation by 0.45 seconds, then automatically returns to normal.
- Boost cannot activate when paused, finished, uncharged or already boosted.
- Reset/retry clears all Focus and streak state.
- Narrow Android viewport keeps the Focus button and combo label clickable and readable.

## Test commands
```powershell
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/test_fun_focus.gd
godot --headless --path . --script res://tests/test_phase1.gd
godot --headless --path . --script res://tests/test_phase2b_progression.gd
```
Native testing and Android screenshot acceptance are required before merging. This work lives on `feature/fun-01-focus-combo`; `main` remains untouched.
