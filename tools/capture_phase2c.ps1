# Local Godot screenshot tool: no network, no CI and no player save mutation.
[CmdletBinding()]
param(
    [string]$GodotExe = 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe',
    [string[]]$Resolutions = @('360x780', '540x960')
)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
if (!(Test-Path -LiteralPath $GodotExe -PathType Leaf)) {
    throw "Godot executable not found: $GodotExe"
}
foreach ($resolution in $Resolutions) {
    if ($resolution -notmatch '^\d{3,4}x\d{3,4}$') {
        throw "Invalid Godot resolution: $resolution (expected e.g. 360x780)"
    }
    Write-Host ">>> Capturing five stage previews at $resolution" -ForegroundColor Cyan
    & $GodotExe --path $project --windowed --resolution $resolution --script 'res://tools/capture_phase2c.gd'
    if ($LASTEXITCODE -ne 0) {
        throw "Phase 2C screenshot capture failed at $resolution (exit $LASTEXITCODE)"
    }
}
$folder = Join-Path $project 'build\phase2c_visual'
$images = @(Get-ChildItem -LiteralPath $folder -Filter 'stage_*.png' -File -ErrorAction Stop)
if ($images.Count -lt 5) {
    throw "Expected at least five stage screenshots, found $($images.Count)"
}
Write-Host "Review screenshots in: $folder" -ForegroundColor Green
