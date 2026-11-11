# Phase 1C: local-only verification and Android debug packaging.
# Does NOT run CI workflows, sign a release build, or upload to Play.
[CmdletBinding()]
param(
    [string]$GodotExe = 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe',
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
    & $GodotExe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Step failed with exit code $LASTEXITCODE" }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $apk) | Out-Null
Invoke-Godot -Step 'Godot project import / parse' -Arguments @('--headless', '--path', $project, '--editor', '--import', '--quit')
Invoke-Godot -Step 'Core regression suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_phase1.gd')
Invoke-Godot -Step 'UI regression suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_ui_smoke.gd')
Invoke-Godot -Step 'Routing guide suite' -Arguments @('--headless', '--path', $project, '--script', 'res://tests/test_guidance.gd')
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
