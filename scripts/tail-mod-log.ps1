<#
.SYNOPSIS
  Tails X4 debuglog.txt filtered for mod-related lines.

.DESCRIPTION
  Reads the user's most recent X4 debug log and prints lines tagged with
  "MOD: DA" (our mod's debug_text prefix), "DU-TEST", "DU-CHECK", or X4
  ERROR/WARNING lines that reference DA cues. Hides known noise.

  Defaults to the last 500 lines. Use -Live to follow.

.PARAMETER LogPath
  Override the auto-detected debug log path.

.PARAMETER Tail
  Lines to read from the end (default 500). Ignored with -Live.

.PARAMETER Live
  Follow the log (Get-Content -Wait). Ctrl-C to exit.

.PARAMETER ErrorsOnly
  Only print [=ERROR=] and [=WARNING=] lines that touch mod cues.

.EXAMPLE
  .\scripts\tail-mod-log.ps1
.EXAMPLE
  .\scripts\tail-mod-log.ps1 -Live -ErrorsOnly
#>

param(
    [string]$LogPath,
    [int]$Tail = 500,
    [switch]$Live,
    [switch]$ErrorsOnly
)

if (-not $LogPath) {
    $dir = Join-Path $env:USERPROFILE 'Documents\Egosoft\X4'
    if (-not (Test-Path $dir)) { Write-Error "X4 user dir not found: $dir"; exit 1 }
    $userId = Get-ChildItem $dir -Directory | Where-Object { $_.Name -match '^\d+$' } | Select-Object -First 1
    if (-not $userId) { Write-Error "No X4 user id folder under $dir"; exit 1 }
    $LogPath = Join-Path $userId.FullName 'debuglog.txt'
}
if (-not (Test-Path $LogPath)) { Write-Error "Log not found: $LogPath"; exit 1 }

Write-Host "Reading $LogPath" -ForegroundColor DarkGray

$keep = {
    param($line)
    if ($ErrorsOnly) {
        return ($line -match '\[=ERROR=\]|\[=WARNING=\]') -and `
               ($line -match 'DynamicUniverse|DUDynamic|DUVassal|DU-TEST|DU-CHECK|md\.Diplomacy')
    }
    # Drop known unrelated noise
    if ($line -match 'gatedistance\.\{component\.\{0x0L\}\}') { return $false }
    if ($line -match 'OnlineGetUserItems') { return $false }
    return ($line -match 'MOD:|DU-TEST|DU-CHECK|DUDynamic|DUVassal|DynamicUniverse|md\.Diplomacy') -or `
           (($line -match '\[=ERROR=\]|\[=WARNING=\]') -and ($line -match 'DU[A-Z_]|DynamicUniverse|md\.Diplomacy'))
}

if ($Live) {
    Get-Content $LogPath -Wait -Tail 50 | Where-Object { & $keep $_ }
} else {
    Get-Content $LogPath -Tail $Tail | Where-Object { & $keep $_ }
}
