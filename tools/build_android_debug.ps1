# Phase 1C: local-only verification and Android debug packaging.
# Does NOT run CI workflows, sign a release build, or upload to Play.
[CmdletBinding()]
param(
    [string]$GodotExe = 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe',
    [switch]$TestsOnly,
    [switch]$InstallOnDevice
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$apk = Join-Path $project 'build\parcel-pulse-debug.apk'

if (!(Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
    throw "Godot executable was not found: $GodotExe"
}
if (!(Test-Path -LiteralPath (Join-Path $project 'export_presets.cfg'))) {
    throw 'Android export preset is missing.'
}

function Invoke-Godot {
    param([string[]]$Arguments, [string]$Step)
    Write-Host ">>> $Step" -ForegroundColor Cyan

    # Godot can log SCRIPT ERROR / ERROR but still return process exit code 0.
    # Capture both streams so every test is genuinely gated on engine failures.
    # PowerShell 5.1 can turn redirected native stderr into ErrorRecord objects.
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $captured = @(& $GodotExe @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldPreference
    }

    $textLines = @($captured | ForEach-Object { [string]$_ })
    foreach ($line in $textLines) {
        Write-Host $line
    }
    if ($code -ne 0) {
        throw "$Step failed with exit code $code"
    }

    # Include the prefix seen when Windows PowerShell wraps native stderr;
    # WARNINGS are still displayed, but are not confused with script errors.
    $engineFailures = @($textLines | Where-Object {
        $_ -match '(?i)(?:^|\s)(?:SCRIPT ERROR:|ERROR:|FATAL ERROR:|CRASH:)'
    })
    if ($engineFailures.Count -gt 0) {
        throw "$Step reported $($engineFailures.Count) Godot engine error line(s), despite exit code 0."
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $apk) | Out-Null
Invoke-Godot -Step 'Godot project import / parse' -Arguments @('--headless', '--path', $project, '--editor', '--import', '--quit')
Invoke-Godot -Step 'Core regression suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_phase1.gd')
Invoke-Godot -Step 'UI regression suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_ui_smoke.gd')
Invoke-Godot -Step 'Routing guide suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_guidance.gd')
Invoke-Godot -Step 'UI-01A design suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_ui_design.gd')
Invoke-Godot -Step 'UI-01B city board suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_ui_city_board.gd')
Invoke-Godot -Step 'Board full-rect and arrow rotation suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_board_fill_arrow.gd')
Invoke-Godot -Step 'UI-01C game feel suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_ui_juice.gd')
Invoke-Godot -Step 'UI-01D mobile responsive suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_ui_responsive.gd')
Invoke-Godot -Step 'Phase 2 maps and progression suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_phase2_levels.gd')
Invoke-Godot -Step 'Phase 2B five-map progression and difficulty suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_phase2b_progression.gd')
Invoke-Godot -Step 'Phase 2C touch and compact-junction suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_phase2c_touch.gd')
if ($TestsOnly) {
    if ($InstallOnDevice) { throw 'TestsOnly cannot be combined with InstallOnDevice.' }
    Write-Host 'All Godot regression commands returned success; Android export was intentionally skipped.' -ForegroundColor Green
    return
}
Invoke-Godot -Step 'Android debug APK export' -Arguments @('--headless', '--path', $project, '--export-debug', 'Android', $apk)

if (!(Test-Path -LiteralPath $apk -PathType Leaf)) {
    throw "Godot reported success but no APK exists at $apk"
}
$bytes = (Get-Item -LiteralPath $apk).Length
if ($bytes -lt 1000000) { throw "Exported APK is suspiciously small ($bytes bytes)" }
Write-Host "Debug APK created: $apk ($bytes bytes)" -ForegroundColor Green

if ($InstallOnDevice) {
    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if (!$adb) { throw 'adb not found. Add Android SDK platform-tools to PATH.' }
    $devices = @(& adb devices | Select-String -Pattern '^([A-Za-z0-9.:_-]+)\s+device$')
    if ($LASTEXITCODE -ne 0 -or $devices.Count -ne 1) {
        throw 'Exactly one authorized Android device must be attached (adb devices).'
    }
    Write-Host '>>> Installing debug APK to attached Android device'
    & adb install -r $apk
    if ($LASTEXITCODE -ne 0) { throw "adb install failed with exit code $LASTEXITCODE" }
    Write-Host 'Installed successfully. Launch Parcel Pulse on the device and follow the manual checklist.' -ForegroundColor Green
} else {
    Write-Host 'Device install skipped. Re-run with -InstallOnDevice when one authorized Android phone is connected.'
}
