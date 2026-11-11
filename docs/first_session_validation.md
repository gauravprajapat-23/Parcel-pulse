# Phase 1D: first-session usability and routing-guide validation

**Purpose:** Verify that players understand the three routes before introducing new levels, economy, or advertising.

## Minimum environment

Use `tools/build_android_debug.ps1 -InstallOnDevice` after import and all three headless suites pass. Check on at least one actual Android phone. This document defines manual tests only; it is not evidence that they passed.

## Critical first-session route flow

1. Launch offline; inspect the ready-screen explanation and START/PLAY control.
2. Press PLAY. The first red diamond should be spawned immediately after the first simulation tick; the live guide should focus HUB and show it is already correctly routed toward WEST.
3. Tap HUB while the red package approaches. The arrow should point EAST and the guide must say TAP HUB to WEST, without changing the score. Tap again to restore WEST.
4. When the red package travels toward WEST, the guide must highlight the WEST junction and show READY WEST to RED.
5. First red package reaches RED: score +100, zero mistakes, single feedback message. Confirm no double scoring.
6. For a blue circle, change WEST to BLUE before its arrival. For a green triangle, change HUB to EAST (and ensure EAST routes GREEN).
7. Toggle GUIDE OFF: the guide and highlight disappear, while package movement and scoring continue normally. Toggle on: guidance resumes.
8. Pause, background, resume, restart, and system Back; verify guide state stays consistent with board state and never changes the routing itself.
9. Let three mistakes occur; confirm the results panel, then retry and verify a clean reset.
10. Complete 12 correct deliveries and verify the win overlay; record actual session duration and errors.

## User comprehension test

Ask 5–10 first-time testers to play without verbal guidance, then ask:
- Can you explain what tapping a junction does?
- What does READY vs TAP mean?
- Which color/shape goes to which house?
- What did you find confusing?
- Would you choose to replay another shift?

Record how many understood the first decision without verbal help and how many voluntarily replay. Do not claim D1 retention from a single sitting.

## Acceptance checks

- No errors in the Godot debugger or Android logcat during a complete shift.
- Live guide never gives an illegal path or changes the game state.
- Colorblind-safe shape symbols remain legible on small screens.
- No touch input causes duplicate route toggles.
- First mistake has a clear explanation and no unfair penalty.
- Player can hide help at any time without losing progress.
- No results overlay hides important restart controls.
- Frame pacing remains acceptable on a low-end Android device.

**Release gate remains blocked until a real Godot import, headless suites, debug APK build, and physical-device smoke test pass.**
