# Phase 1C — Android verification gate

**Status:** Pending real Godot import/export and physical Android tests. Adding a build script does not mean an APK exists.

## Requirements

- Godot **4.7.2** Windows editor/console binary and matching **Android export templates**, installed from Godot Editor → Manage Export Templates.
- Android SDK and OpenJDK configured in **Godot Editor Settings → Export → Android**. For Godot 4.7, follow [official Android setup](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html).
- Windows PowerShell, with Android `adb` on PATH for device installation.
- Android USB debugging enabled and authorized on the connected device.

## Local verification and debug APK build

From the repository root:

```powershell
git switch main
git pull --ff-only origin main
.\tools\build_android_debug.ps1 -GodotExe "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
```

The script runs a project import/parser pass, the two regression suites and an Android **debug** export to `build/parcel-pulse-debug.apk`. It stops on a nonzero exit code, a missing APK, or a suspiciously small APK.

To install on **exactly one** USB-authorized Android device:

```powershell
.\tools\build_android_debug.ps1 -GodotExe "C:\Godot\Godot_v4.7.2-stable_win64_console.exe" -InstallOnDevice
```

No GitHub Actions are triggered by either command. The script does not build a release AAB, provision a keystore, set Play billing, or upload the app.

## Device smoke-test checklist

Test one small Android phone and one larger Android device if available. Record device model, Android version, screen size, game build, and results.

| Case | Expected result | Status |
|---|---|---|
| Cold launch offline | Ready screen appears, Play works, no network needed | Not run |
| Portrait 19.5:9 and tall 20:9 | HUD and 2×2 buttons visible and tappable | Not run |
| Insets and cutout | No button hidden under status/nav bar or camera cutout | Not run |
| Junction tap | One tap advances exactly one outgoing route | Not run |
| Drag gesture | Dragging across junction does not accidentally toggle repeatedly | Not run |
| Parcel routing | Correct destinations increment score once | Not run |
| Mistake limit | Third wrong destination ends shift | Not run |
| Pause/Resume | Parcel position and spawn schedule freeze and resume | Not run |
| System Back | During shift: pause; from pause/result: return to ready | Not run |
| App background/resume | In-progress shift pauses rather than silently progressing | Not run |
| Retry/Exit | No duplicate parcels, timers, or score events | Not run |
| Rotation | Portrait remains usable | Not run |
| Results overlay | Results are readable, Replay and Back work | Not run |
| Performance | Stable 60 FPS target; 30 FPS minimum on test phone | Not run |
| Device sleep/wake | No unexpected simulation progress or crash | Not run |

Use a screenshot and the relevant Godot/Android log excerpt when a case fails. Check `adb logcat` for a reproducible crash; do not upload personal device logs without redaction.

## Release limitations

This is a debug **APK** preset for device testing only. Before Play Store submission, review the app ID, add licensed original launcher icons, use an Android **AAB** with Gradle export, verify target SDK/API requirements, configure a private upload keystore, and complete Store privacy/data-safety declarations. Do not commit signing keys or credentials.

The placeholder package ID `com.gauravprajapat23.parcelpulse` is not reserved or validated for Play Store uniqueness. Confirm it before publishing.

Do not declare this gate passed until the Godot import, both suites, APK export, and a real-device smoke checklist have completed successfully.
