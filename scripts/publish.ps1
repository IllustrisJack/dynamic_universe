<#
.SYNOPSIS
  Publish or update Dynamic Universe on the Steam Workshop.

.DESCRIPTION
  Wraps Egosoft's WorkshopTool.exe (ships with the free "X Tools" Steam
  package). First run does a first-publish; pass -Update for subsequent
  releases.

  Note: the mod's `id` in content.xml is `dynamic_universe`. The mod
  folder on disk under <X4>/extensions is currently named `deadair_scripts`
  (legacy from upstream). X4 loads via content.xml id, so it works either
  way, but for consistency you may want to rename / re-symlink the
  extension folder to `dynamic_universe` before first publish.

  Make sure the deployed copy is current before running; this script
  publishes from the deployed path, not the workspace repo.

.PARAMETER Update
  Update an existing Workshop item instead of first-publish.

.PARAMETER ChangeNote
  Required when -Update. Short description of what changed.

.PARAMETER ModPath
  Override the deployed mod path. Defaults to the symlinked extension dir.

.PARAMETER WorkshopTool
  Override the WorkshopTool.exe path. Default: auto-detect under any
  Steam library on the machine.

.EXAMPLE
  # First publish (one-time)
  .\scripts\publish.ps1

.EXAMPLE
  # Tagged release update
  .\scripts\publish.ps1 -Update -ChangeNote "v1.0.1: rename + diff-engine validator + docs cleanup"
#>
param(
    [switch]$Update,
    [string]$ChangeNote,
    [string]$ModPath = "<STEAM_LIBRARY>\steamapps\common\X4 Foundations\extensions\deadair_scripts",
    [string]$WorkshopTool
)

$ErrorActionPreference = "Stop"

function Find-WorkshopTool {
    $candidates = @()

    $steamRoots = @(
        "$env:ProgramFiles(x86)\Steam",
        "$env:ProgramFiles\Steam",
        "C:\Steam"
    )
    foreach ($s in $steamRoots) {
        $vdf = Join-Path $s "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($m in (Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches).Matches) {
                $libPath = $m.Groups[1].Value -replace '\\\\','\'
                $candidates += (Join-Path $libPath "steamapps\common\X Tools\WorkshopTool.exe")
            }
        }
    }

    $candidates += @(
        "<STEAM_LIBRARY>\steamapps\common\X Tools\WorkshopTool.exe",
        "${env:ProgramFiles(x86)}\Steam\steamapps\common\X Tools\WorkshopTool.exe",
        "${env:ProgramFiles}\Steam\steamapps\common\X Tools\WorkshopTool.exe"
    )

    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    return $null
}

if (-not $WorkshopTool) {
    $WorkshopTool = Find-WorkshopTool
}
if (-not $WorkshopTool -or -not (Test-Path $WorkshopTool)) {
    Write-Error "WorkshopTool.exe not found. Install Egosoft's free 'X Tools' from Steam Library, then re-run or pass -WorkshopTool '<path>'."
    exit 1
}

if (-not (Test-Path $ModPath)) {
    Write-Error "Mod path not found: $ModPath. Deploy/symlink the mod to the X4 extensions folder first."
    exit 1
}

$contentXml = Join-Path $ModPath "content.xml"
if (-not (Test-Path $contentXml)) {
    Write-Error "content.xml missing at $contentXml — not a valid X4 mod folder."
    exit 1
}

$previewJpg = Join-Path $ModPath "preview.jpg"
if (-not $Update -and -not (Test-Path $previewJpg)) {
    Write-Error "preview.jpg missing at $previewJpg. Required for first publish. Drop a 640x360+ JPG/PNG into the mod folder."
    exit 1
}

if ($Update -and -not $ChangeNote) {
    Write-Error "-Update requires -ChangeNote ""...""."
    exit 1
}

Write-Host "WorkshopTool: $WorkshopTool" -ForegroundColor DarkGray
Write-Host "Mod path:     $ModPath" -ForegroundColor DarkGray

if ($Update) {
    Write-Host "Updating Workshop item..." -ForegroundColor Cyan
    & $WorkshopTool update -path $ModPath -buildcat -changenote $ChangeNote
} else {
    Write-Host "First-publishing Workshop item..." -ForegroundColor Cyan
    & $WorkshopTool publishx4 -path $ModPath -preview $previewJpg -buildcat
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "WorkshopTool exited with code $LASTEXITCODE."
    exit $LASTEXITCODE
}

Write-Host "Done. If this was a first publish, open the new Workshop item in your browser and set visibility to Public." -ForegroundColor Green
