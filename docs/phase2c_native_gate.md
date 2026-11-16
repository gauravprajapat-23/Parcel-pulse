# Phase 2C — Native Godot, touch precision and difficulty verification

**Status:** Source fixes and test/capture tooling are committed. Godot execution, screenshot inspection and physical Android QA have NOT run in this environment. This is not a release sign-off.

## Implemented

- BoardView now uses the closest junction center within its existing generous hit radius. When the closest two switches are almost equally likely (within 8 logical pixels), a tap is ignored rather than toggling the wrong switch.
- The new headless test_phase2c_touch.gd checks each of the five maps at four board sizes: 215×250, 228×285, 260×340 and 480×570. It covers center taps, small offsets, out-of-board input, ambiguous Beacon Docks touches, pause, releases and emulated Android touch duplication.
- Stage 4 Riverside Switch has a 2.10 s spawn interval, and Stage 5 Beacon Docks has a 2.05 s interval. These are provisional balance improvements, not human playtest findings.
- A local screenshot tool captures all five stage previews using real Godot rendering, at two requested desktop window sizes by default. Captures are written only to git-ignored build/phase2c_visual.

## Run headless import and the complete regression gate

Open PowerShell from the project directory:

~~~powershell
git switch main
git pull --ff-only origin main
$godot = 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe'
.\tools\build_android_debug.ps1 -TestsOnly -GodotExe $godot
if ($LASTEXITCODE -ne 0) { throw 'Godot regression gate failed' }
~~~

Every suite must finish without script errors or failed assertions. This runs Godot's importer and test scripts locally, not GitHub Actions.

## Capture five map screenshots

~~~powershell
.\tools\capture_phase2c.ps1 -GodotExe $godot
~~~

This runs a visible Godot window at requested 360×780 and 540×960 resolutions, cycles through the five locked/unlocked stage previews and saves PNG screenshots in build\phase2c_visual. Do not use --headless for screenshots. Confirm actual saved resolution because a desktop window manager can enforce minimum sizes. The script sets an isolated progress path and never completes a shift.

Look at every screenshot and compare with the approved game design. Check the title and HUD, guide banner, three house symbols, depot, branch paths, gold switches, arrows, stage strip, buttons, route glow and clipping. On Stage 5, make sure north-west/west and north-east/east switches can be visually told apart.

## Build and install the Android debug APK

~~~powershell
.\tools\build_android_debug.ps1 -GodotExe $godot -InstallOnDevice
~~~

This requires the correct Godot Android export template, configured Android SDK and one authorized test phone. The script runs every headless test before export and install; do not bypass the failures.

On-device manual checklist:

1. Preview all five maps offline with screen cutout and gesture navigation enabled where available.
2. Start the stages and tap every gold junction, especially all five switches in Beacon Docks. Verify exactly one intended toggle per press.
3. Tap midway between close junctions; an ambiguous tap should not unexpectedly change either route.
4. Pause/resume, background/foreground, retry, system Back and results navigation without duplicate sound or scoring.
5. Win Stage 4 and Stage 5 with normal gameplay, measuring attempts, errors and perceived difficulty instead of relying on solver results.
6. Restart the app offline and verify stage unlocks, best scores and stars are preserved.
7. Check performance on a lower-end Android device. Compare a complete play session with Motion ON and OFF.

Optional Android screenshot capture:

~~~powershell
adb devices
adb shell screencap -p /sdcard/parcel-pulse-phase2c.png
adb pull /sdcard/parcel-pulse-phase2c.png .
~~~

## Evidence to retain

| Gate | Evidence | Current status |
| --- | --- | --- |
| Import and every GDScript regression | Console log with zero failures | Pending |
| Five screenshots at both sizes | PNGs from real Godot renderer | Pending |
| Physical junction accuracy | Phone name, OS, taps and failures | Pending |
| Real Stage 4–5 difficulty | Attempts, mistakes and player feedback | Pending |
| Android debug APK | Export file and installation confirmation | Pending |

Review log contents for parser/runtime errors even if an underlying command reports a zero exit code. The screenshot tool only helps create evidence; it does not itself judge visual quality.

## Next decision

Fix the specific Godot/Android problems found in this gate before adding additional levels. The current source is not claimed to be a tested release candidate.
