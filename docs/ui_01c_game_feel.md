# UI-01C — Game feel and visual polish

**Status: source implemented; actual Godot import, test execution, Android audio/device testing and screenshot validation are pending.**

## What UI-01C adds

1. `GameJuice` is a noninteractive, event-driven `Control` above the city art and moving carts. It draws a short ring when a junction is switched, a floating `+100` for a successful parcel, and a visible `MISROUTE!` warning for an incorrect delivery. Each effect is capped in number and expires automatically.
2. Selected-road chevrons advance through the existing Bezier geometry, using a subtle shifting line opacity; the shimmer freezes when a shift is paused.
3. `SfxPlayer` generates five short, original PCM16 tones at runtime (tap, success, mistake, win, pause). There are no third-party music files, external assets, online services or monetization SDKs.
4. A visible **SFX ON/OFF** button controls sound in the title row. Sound defaults on but remains optional. The setting currently lasts for the running app session.
5. Results fade in using a short cubic Tween and show a simple 1–3-star success rating derived from remaining attempts. Failed results show an encouraging replay message.
6. Results/restarts/exits terminate active fade tweens and reset old visual feedback. No changes were made to `ShiftController`, `BoardState`, route geometry, scoring rules, or spawn schedules.

## Architecture boundaries

- Game state is authoritative in `ShiftController`.
- `BoardView` forwards junction and delivery events into the visual `GameJuice` layer and emits an input-feedback signal.
- `CityBoardOverlay` owns only the route animation clock and actual graphics.
- `GameScreen` coordinates sound, UI transitions, and existing controller signals.
- `SfxPlayer` generates no sound until played; muting stops all active cues.
- All effects are independently removable; score and route selection cannot be changed from them.

## Regression & Android test

```powershell
cd "C:\Users\gauravp\Projects\Parcel-pulse"
git switch main
git pull --ff-only origin main
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Godot import failed" }
& $godot --headless --path . --script res://tests/test_ui_juice.gd
if ($LASTEXITCODE -ne 0) { throw "UI-01C tests failed" }
& $godot --path .
```

For every test suite and debug APK export, run `tools/build_android_debug.ps1`.

### Physical-device checklist (not executed here)

- A single junction tap emits exactly one glow ring and one audible click, with no double toggle.
- Route chevrons move slowly while playing and freeze on Pause.
- A correct delivery displays one floating `+100` and a pleasant success cue; a wrong house displays a legible warning and a gentle lower tone.
- Twelve correct deliveries produce the result summary and short success melody.
- SFX OFF immediately stops sound, including during a delivery; SFX ON restores it.
- Retry and Exit clear old floating scores; rapid Retry after a result never resurrects the previous overlay.
- Test narrow phones, touch accessibility, scene scaling, background/resume, headphones and muted device audio.
- Observe CPU/GPU frame pacing on the actual target device. Reduce route shimmer or visual density if low-end performance is affected.

**UI-01D next:** phone-size/layout testing, cutout safe areas, optimized effects / reduced-motion controls, and release-gate cleanup.
