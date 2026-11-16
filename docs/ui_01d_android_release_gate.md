# UI-01D — Android Responsive Polish & Release Gate

**Status: implementation committed; native Godot tests, screenshots and physical-device validation are NOT yet verified.**

## Implemented source changes

- Three layout profiles selected from the current logical viewport: FULL, COMPACT and SMALL.
- HUD card dimensions, header fonts, title-row controls, guide height, spacing, board minimum and action-button height adapt to compact portrait sizes.
- Gameplay retains a large tappable board, independent SFX and Motion controls, and the same shift/restart/game-over rules.
- Android safe-area helper consumes physical `DisplayServer.get_display_safe_area()` and window dimensions, converts additional overlap to viewport units, and avoids double padding where system bars are already excluded. In the current Android preset `screen/edge_to_edge=false`. Because device/window insets vary, these calculations still require physical verification.
- **MOTION OFF** disables decorative junction ripples, animated route shimmer, floating text travel and result fades. Correct deliveries still show readable reward text and actual parcels still redraw.
- The dynamic road overlay and feedback layer cap redraw requests to about 30 FPS. Gameplay simulation remains on the physics tick.
- UI-01D headless regression checks validate layout profiles, safe-inset math, control state and reduced-motion behavior.
- The existing local Android build gate offers `-TestsOnly` to run import and all test suites without needing Android export tools.

## Why the layout profiles matter

The game was initially authored for 540 × 960 with a fixed 340px-minimum board and four bottom actions. On short portrait windows, the HUD and controls could crowd the playfield. Layout profiles now trade decorative subtitles and excess spacing for useful game area without changing actual routing logic.

The minimum-content estimate is a **policy test**, not an automated measurement of pixel-perfect text fitting. Visual screenshots and real touch QA are required before release.

## Required local commands

From the project root, with Godot 4.7.2 configured:

```powershell
git switch main
git pull --ff-only origin main

# Import + every regression suite; does not require an Android SDK/export:
.\tools\build_android_debug.ps1 -TestsOnly -GodotExe "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

# Run the interactive game on the PC:
& "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" --path .

# With matching Android export templates and Android SDK configured:
.\tools\build_android_debug.ps1 -GodotExe "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"

# To install on exactly one authorized USB-debugging device:
.\tools\build_android_debug.ps1 -InstallOnDevice -GodotExe "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
```

Any failing import, regression or APK export remains a blocker. The script does not trigger CI or upload to Google Play.

## Screen/device matrix — execute and record

| Reference size / device | Verify | Status |
|---|---|---|
| 320×640 logical / compact desktop simulation | Board, HUD and buttons do not overlap; minimum touch region | Not run |
| 360×780 portrait device | Compact layout, large enough junction targets, four buttons visible | Not run |
| 393×852 Android phone | No clipped score, guide, or title; result modal fits | Not run |
| 412×915 Android phone | Full-size board, alignment and responsive transitions | Not run |
| 540×960 project base | Full design still resembles reference; no regressions | Not run |
| 720×1280 logical / larger device | Layout remains centered and readable | Not run |
| Punch-hole/notched Android | No tap target under camera or status bar | Not run |
| Gesture navigation Android | Bottom actions remain above navigation/gesture bar | Not run |
| Android display/font-size enlarged | Labels and controls do not collide; text readable | Not run |
| Foldable/window resize | Resized layout, no stale board or result sizing | Not run |

### Manual interaction checklist

1. Cold launch offline, press PLAY, route red/blue/green parcels. Make sure a tap toggles exactly one junction.
2. Test close-together touch targets, rapid taps, and taps outside the board; score and routes must not double-change.
3. Tap **MOTION OFF** while active: roads stop shimmering, tap rings stop, parcels continue moving, correct deliveries show static +100 labels. Turn MOTION ON to restore effects.
4. Tap **SFX OFF**: audio stops immediately; sound and motion controls operate independently.
5. Pause/resume, background/resume, restart, Android system Back and retry from the result overlay. Confirm no duplicate packets, points or sound effects.
6. Complete twelve deliveries and lose after three mistakes. The result card remains centered, button taps work, and no controls are blocked.
7. Test for at least 5 minutes on a low-end Android phone. Target 60 FPS gameplay with acceptable 30 FPS visual updates; record actual FPS, battery/thermal observations and crashes.
8. Run the complete headless suite and debug APK build with zero failures. Capture screenshots and any relevant redacted logs.

### Capture device evidence (optional)

```powershell
adb devices
adb shell wm size
adb shell wm density
adb shell screencap -p /sdcard/parcel-pulse-ui01d.png
adb pull /sdcard/parcel-pulse-ui01d.png .
```

Record device model, Android version, navigation style, notch type, logical screen density, build commit and screenshot path. Redact personal device identifiers from any shared logs.

## Unresolved release blockers

- **Native engine checks not run here.** No Godot executable is available in this environment, so the source test suite has been authored but not executed in Godot.
- **Android APK not produced here.** Android SDK/export templates and an authorized physical Android phone are not present.
- UI must be checked visually against the original Parcel Pulse concept screenshot and adjusted if clipped or overly crowded.
- The current export preset creates a debug APK, not a signed release AAB. Production package ID, icon assets, signing, Play policy/data safety and store testing remain separate launch requirements.

### Suggested next work

After the import, all suites, screenshots and device test pass: **UI-REL-01 — Final Visual Acceptance & Release Candidate**. Only then begin more route maps or progression.
