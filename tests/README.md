# Parcel Pulse — Phase 1 verification

## Requirements

Godot 4.3 or newer, with a Godot 4.x editor or headless executable on PATH.

## Automated tests

From the repository root:

```bash
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/test_phase1.gd
godot --headless --path . --script res://tests/test_ui_smoke.gd
```

Successful tests print `Parcel Pulse Phase 1: N passed, 0 failed.` and return exit code 0. A failed assertion reports `FAIL` and returns exit code 1.

The suite checks movement, branching, correct and incorrect deliveries, invalid destinations, mistake limits, completion, pause/resume, restarts, duplicate scoring, and a full guided 12-delivery run.

## Run the game

```bash
godot --path .
```

Windows PowerShell (replace with your actual path):

```powershell
$godot = "C:\\Godot\\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Import failed" }
& $godot --headless --path . --script res://tests/test_phase1.gd
if ($LASTEXITCODE -ne 0) { throw "Core tests failed" }
& $godot --headless --path . --script res://tests/test_ui_smoke.gd
if ($LASTEXITCODE -ne 0) { throw "UI smoke tests failed" }
& $godot --path .
```

## Manual Android smoke test (not automatable headlessly)

1. Install a Godot Android export template matching your Godot version.
2. Export to an Android test APK and install it on a physical device.
3. In portrait mode, tap PLAY; confirm parcels move from the depot.
4. Tap each of the three junctions; verify the white route arrow switches.
5. Route a red diamond, blue circle and green triangle to their matching homes.
6. Verify PAUSE freezes movement, RESUME continues it, RETRY resets it, and EXIT returns to the ready screen.
7. Send three parcels to the wrong destination, then retry from the results overlay.
8. Check narrow/large devices, display cutouts, rotations and offline launch.

Do not treat this checklist as executed until results from actual devices are recorded.

## Touch-input policy

The project enables `input_devices/pointing/emulate_mouse_from_touch=true` so Android taps reach normal Godot Buttons and BoardView as mouse clicks. The board deliberately ignores a raw ScreenTouch event to avoid a single touch toggling the same switch twice. Headless synthetic-event checks do not replace a real-device touch test.
