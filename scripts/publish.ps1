<#
.SYNOPSIS
  Publish or update Dynamic Universe on the Steam Workshop.

.DESCRIPTION
  Wraps Egosoft's WorkshopTool.exe (ships with the free "X Tools" Steam
  package). First run does a first-publish; pass -Update for subsequent
  releases.

  Important: the mod's content.xml id is "dynamic_universe" but the
  source folder on disk is "deadair_scripts" (legacy). The script
  always passes -foldername dynamic_universe so subscribers' Workshop
  install lands in extensions/dynamic_universe/. Skipping that flag
  silently flips the subscriber-side folder name.

  WorkshopTool defaults to an interactive y/n prompt. -batchmode is
  passed below so the script can run unattended.

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
  .\scripts\publish.ps1 -Update -ChangeNote "v1.0.1: rename + validator + docs cleanup"
#>
param(
    [switch]$Update,
    [string]$ChangeNote,
    [string]$ModPath,
    [string]$WorkshopTool
)

$ErrorActionPreference = "Continue"

# Source folder on disk (legacy from the DeadAir Scripts upstream).
$ModName = "deadair_scripts"

# Folder name shipped to Workshop subscribers. Matches content.xml id.
$PublishedFolderName = "dynamic_universe"

function Get-SteamLibraries {
    $roots = @()
    try {
        $reg = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name SteamPath -ErrorAction Stop).SteamPath
        if ($reg) { $roots += $reg }
    } catch {}
    $roots += @(
        "${env:ProgramFiles(x86)}\Steam",
        "$env:ProgramFiles\Steam"
    )
    $libs = @()
    foreach ($s in $roots) {
        if (-not $s) { continue }
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
    Write-Error "WorkshopTool.exe not found. Install 'X Tools' from Steam, or pass -WorkshopTool."
    exit 1
}

if (-not $ModPath) {
    $ModPath = Find-X4Extension -Name $ModName
}
if (-not $ModPath -or -not (Test-Path $ModPath)) {
    Write-Error "Mod path not found. Deploy to extensions\$ModName or pass -ModPath."
    exit 1
}

$contentXml = Join-Path $ModPath "content.xml"
if (-not (Test-Path $contentXml)) {
    Write-Error "content.xml missing at $contentXml."
    exit 1
}

$previewPath = $null
foreach ($ext in @("preview.png", "preview.jpg")) {
    $candidate = Join-Path $ModPath $ext
    if (Test-Path $candidate) { $previewPath = $candidate; break }
}
if (-not $Update -and -not $previewPath) {
    Write-Error "preview.png/jpg missing in $ModPath. Required for first publish."
    exit 1
}

if ($Update -and -not $ChangeNote) {
    Write-Error "-Update requires -ChangeNote."
    exit 1
}

Write-Host "WorkshopTool: $WorkshopTool"
Write-Host "Mod path:     $ModPath"
Write-Host "Foldername:   $PublishedFolderName"

if ($Update) {
    Write-Host "Updating Workshop item..." -ForegroundColor Cyan
    & $WorkshopTool update -path $ModPath -foldername $PublishedFolderName -buildcat -batchmode -changenote $ChangeNote
} else {
    Write-Host "First-publishing Workshop item..." -ForegroundColor Cyan
    & $WorkshopTool publishx4 -path $ModPath -foldername $PublishedFolderName -preview $previewPath -buildcat -batchmode
}

if ($LASTEXITCODE -ne 0) {
    Write-Error "WorkshopTool exited with code $LASTEXITCODE."
    exit $LASTEXITCODE
}

Write-Host "Done." -ForegroundColor Green
