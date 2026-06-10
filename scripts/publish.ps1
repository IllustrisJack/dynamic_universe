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
  Override the deployed mod path. Default: auto-detect under every Steam
  library on the machine via libraryfolders.vdf.

.PARAMETER WorkshopTool
  Override the WorkshopTool.exe path. Default: auto-detect under every
  Steam library on the machine via libraryfolders.vdf.

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
    [string]$ModPath,
    [string]$WorkshopTool
)

$ErrorActionPreference = "Stop"

# Source folder on disk (legacy from the DeadAir Scripts upstream).
$ModName = "deadair_scripts"

# Folder name shipped to Workshop subscribers. Matches content.xml id so
# subscribers' extensions/ tree is clean and matches the mod's published name.
# WorkshopTool's -foldername switch overrides destination folder at upload
# time without renaming our local copy.
$PublishedFolderName = "dynamic_universe"

function Get-SteamLibraries {
    $roots = @(
        "$env:ProgramFiles(x86)\Steam",
        "$env:ProgramFiles\Steam"
    )
    $libs = @()
    foreach ($s in $roots) {
        $vdf = Join-Path $s "steamapps\libraryfolders.vdf"
        if (Test-Path $vdf) {
            foreach ($m in (Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' -AllMatches).Matches) {
                $libs += ($m.Groups[1].Value -replace '\\\\','\')
            }
        }
    }
    return $libs
}

function Find-WorkshopTool {
    foreach ($lib in (Get-SteamLibraries)) {
        $candidate = Join-Path $lib "steamapps\common\X Tools\WorkshopTool.exe"
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Find-X4Extension {
    param([string]$Name)
    foreach ($lib in (Get-SteamLibraries)) {
        $candidate = Join-Path $lib "steamapps\common\X4 Foundations\extensions\$Name"
        if (Test-Path $candidate) { return $candidate }
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

if (-not $ModPath) {
    $ModPath = Find-X4Extension -Name $ModName
}
if (-not $ModPath -or -not (Test-Path $ModPath)) {
    Write-Error "Mod path not found. Deploy/symlink the mod to <SteamLibrary>\steamapps\common\X4 Foundations\extensions\$ModName first, or pass -ModPath '<path>'."
    exit 1
}

$contentXml = Join-Path $ModPath "content.xml"
if (-not (Test-Path $contentXml)) {
    Write-Error "content.xml missing at $contentXml — not a valid X4 mod folder."
    exit 1
}

$previewPath = $null
foreach ($ext in @("preview.png", "preview.jpg")) {
    $candidate = Join-Path $ModPath $ext
    if (Test-Path $candidate) { $previewPath = $candidate; break }
}
if (-not $Update -and -not $previewPath) {
    Write-Error "preview.png/jpg missing in $ModPath. Required for first publish. Drop a 640x360+ JPG/PNG into the mod folder."
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
    & $WorkshopTool update -path $ModPath -foldername $PublishedFolderName -buildcat -changenote $ChangeNote
} else {
    Write-Host "First-publishing Workshop item..." -ForegroundColor Cyan
    & $WorkshopTool publishx4 -path $ModPath -foldername $PublishedFolderName -preview $previewPath -buildcat
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "WorkshopTool exited with code $LASTEXITCODE."
    exit $LASTEXITCODE
}

Write-Host "Done. If this was a first publish, open the new Workshop item in your browser and set visibility to Public." -ForegroundColor Green
