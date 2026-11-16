# UI-01A — Reusable Neon UI Foundation

Status: **implemented in source; native Godot validation and physical-device layout verification pending**.

This milestone is one stage of the design-reference matching work. The city board art, curved roads, rich 2D decorations, animations, and route effects belong to the next UI-01B/UI-01C milestones.

## Reusable components

| Scene / script | Responsibility |
|---|---|
| `scripts/ui/parcel_theme.gd` | Single palette, panel style, button variants and text styling |
| `scenes/ui/stat_card.tscn` + `scripts/ui/stat_card.gd` | One reusable icon/value/caption stat card |
| `scenes/ui/hud_panel.tscn` + `scripts/ui/hud_panel.gd` | Deliveries, score, remaining attempts; reads ShiftController totals |
| `scenes/ui/action_button.tscn` + `scripts/ui/action_button.gd` | Touch-sized button with built-in vector icon and gold/teal/quiet styles |
| `scenes/ui/action_bar.tscn` + `scripts/ui/action_bar.gd` | Four-button 2x2 bar with signal-based commands and phase-aware primary button |

`GameScreen` owns presentation composition and maps signals into the unchanged `ShiftController`. Routing, movement, scoring, deliveries, pausing and restarting continue in the existing gameplay model.

## Interface behavior

- Top title: **PARCEL PULSE**, with gold title accent and short subtitle.
- Three HUD cards: Deliveries (`n/12`), Score (raw points), Tries Left (`3 - mistakes`). The last value is remaining chances, not accumulated errors.
- The four bottom actions: **PLAY → PAUSE → RESUME**, **RETRY**, **GUIDE ON/OFF**, **EXIT**.
- The first action changes according to the shift phase; one button cannot trigger both a play and a pause event in the same press.
- The guide remains read-only; its toggle lives in the bottom bar rather than appearing twice.
- Result-screen actions use the same reusable button component.
- Design tokens and button states live in `ParcelTheme`; the board renderer can adopt them during UI-01B.

## Validation

Run:

```powershell
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
& $godot --headless --path . --script res://tests/test_phase1.gd
& $godot --headless --path . --script res://tests/test_ui_smoke.gd
& $godot --headless --path . --script res://tests/test_guidance.gd
& $godot --headless --path . --script res://tests/test_ui_design.gd
```

The build script in `tools/build_android_debug.ps1` executes these checks before Android export and stops if any returns a nonzero exit code.

## Manual Android checklist

1. Confirm the three stat cards fit a narrow portrait device and the score never overlays the hearts.
2. Confirm 4 buttons appear in a 2x2 grid and each has an easy touch target.
3. Confirm READY shows PLAY, a running shift shows PAUSE, and a paused shift shows RESUME.
4. Check Guide OFF/ON changes the guide only, never the parcel route itself.
5. Confirm Retry and Exit work once per tap, including after results.
6. Verify the bottom action bar remains above the system gesture/nav region.
7. Record screenshots at 360×780, 393×852, and a taller Android resolution.
8. Check color/shape distinction without relying only on hue.

Do not claim a fully matched visual design or completed Android device QA until the board art and native tests pass.
