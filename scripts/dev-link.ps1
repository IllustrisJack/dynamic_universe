<#
.SYNOPSIS
  Toggle the development symlink between this repo and the X4 extensions folder.

.DESCRIPTION
  When developing, X4 loads the repo via a symlink at
  <X4>/extensions/deadair_scripts/. When testing the Steam Workshop build
  of the same mod, that symlink must be removed so the Workshop copy is
  the only one X4 sees - otherwise X4 finds the same content.xml id in
  two places.

  -Link    Create the symlink (or recreate if pointed elsewhere).
  -Unlink  Remove the symlink. Repo on disk is untouched.
  -Status  Print current state. (Default if no switch is given.)

.PARAMETER ExtensionsPath
  Override destination. Default: auto-detect under every Steam library.

.PARAMETER RepoPath
  Override repo source. Default: this script grandparent dir.

.NOTES
  Symlink creation on Windows needs an elevated PowerShell OR Developer
  Mode (Settings -> System -> For developers -> Developer Mode = On).

.EXAMPLE
  .\scripts\dev-link.ps1 -Status
  .\scripts\dev-link.ps1 -Unlink
  .\scripts\dev-link.ps1 -Link
#>
param(
    [switch]$Link,
    [switch]$Unlink,
    [switch]$Status,
    [string]$ExtensionsPath,
    [string]$RepoPath
)

$ErrorActionPreference = "Stop"

$ModName = "deadair_scripts"

function Get-SteamLibraries {
    $roots = @()
    # Registry (most reliable: HKCU\Software\Valve\Steam SteamPath)
    try {
        $reg = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name SteamPath -ErrorAction Stop).SteamPath
        if ($reg) { $roots += $reg }
    } catch {}
    # Conventional fallbacks
    $roots += @(
        "$env:ProgramFiles(x86)\Steam",
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

function Find-X4ExtensionsDir {
    foreach ($lib in (Get-SteamLibraries)) {
        $candidate = Join-Path $lib "steamapps\common\X4 Foundations\extensions"
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

if (-not $RepoPath) {
    $RepoPath = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
}
if (-not (Test-Path (Join-Path $RepoPath "content.xml"))) {
    Write-Error ("Repo path " + $RepoPath + " has no content.xml.")
    exit 1
}

if (-not $ExtensionsPath) {
    $extDir = Find-X4ExtensionsDir
    if (-not $extDir) {
        Write-Error "Could not auto-detect the X4 extensions folder. Pass -ExtensionsPath instead."
        exit 1
    }
    $ExtensionsPath = Join-Path $extDir $ModName
}

if (-not ($Link -or $Unlink -or $Status)) { $Status = $true }

function Show-Status {
    Write-Host ("Repo:        " + $RepoPath) -ForegroundColor DarkGray
    Write-Host ("Target:      " + $ExtensionsPath) -ForegroundColor DarkGray
    if (-not (Test-Path $ExtensionsPath)) {
        Write-Host "State:       NOT LINKED. Workshop copy will be loaded if subscribed." -ForegroundColor Yellow
        return
    }
    $item = Get-Item $ExtensionsPath -Force
    if (($item.LinkType -eq "SymbolicLink" -or $item.LinkType -eq "Junction")) {
        $tgt = $item.Target
        if ($tgt -is [array]) { $tgt = $tgt[0] }
        $resolved = (Resolve-Path $tgt -ErrorAction SilentlyContinue).Path
        $repoResolved = (Resolve-Path $RepoPath).Path
        if ($resolved -eq $repoResolved) {
            Write-Host "State:       LINKED to this repo. OK." -ForegroundColor Green
        } else {
            Write-Host ("State:       LINKED to a different path: " + $tgt) -ForegroundColor Yellow
        }
    } else {
        Write-Host "State:       Real directory exists (not a symlink). Likely a Workshop install or manual copy." -ForegroundColor Yellow
    }
}

if ($Status) {
    Show-Status
    exit 0
}

if ($Link) {
    if (Test-Path $ExtensionsPath) {
        $item = Get-Item $ExtensionsPath -Force
        if (($item.LinkType -eq "SymbolicLink" -or $item.LinkType -eq "Junction")) {
            $tgt = $item.Target
            if ($tgt -is [array]) { $tgt = $tgt[0] }
            $resolved = (Resolve-Path $tgt -ErrorAction SilentlyContinue).Path
            $repoResolved = (Resolve-Path $RepoPath).Path
            if ($resolved -eq $repoResolved) {
                Write-Host "Already linked to this repo. Nothing to do." -ForegroundColor Green
                exit 0
            }
            Write-Host ("Removing existing symlink pointing to " + $tgt) -ForegroundColor DarkGray
            (Get-Item $ExtensionsPath -Force).Delete()
        } else {
            Write-Error ($ExtensionsPath + " exists as a real directory. Refusing to overwrite. Move or rename it first.")
            exit 1
        }
    }
    # Junction preferred on Windows for directories: doesn't require admin
    # or Developer Mode. SymbolicLink fallback if Junction fails (e.g.
    # cross-volume, which Junction doesn't support).
    Write-Host ("Creating link: " + $ExtensionsPath + " -> " + $RepoPath) -ForegroundColor Cyan
    try {
        New-Item -ItemType Junction -Path $ExtensionsPath -Target $RepoPath | Out-Null
    } catch {
        Write-Host "Junction failed; falling back to SymbolicLink (may need admin or Developer Mode)..." -ForegroundColor Yellow
        New-Item -ItemType SymbolicLink -Path $ExtensionsPath -Target $RepoPath | Out-Null
    }
    Write-Host "Done." -ForegroundColor Green
    Show-Status
    exit 0
}

if ($Unlink) {
    if (-not (Test-Path $ExtensionsPath)) {
        Write-Host "Already unlinked. Nothing to do." -ForegroundColor Green
        exit 0
    }
    $item = Get-Item $ExtensionsPath -Force
    if (-not ($item.LinkType -eq "SymbolicLink" -or $item.LinkType -eq "Junction")) {
        Write-Error ($ExtensionsPath + " is a real directory (not a symlink/junction). Refusing to delete. Move or rename it manually if intentional.")
        exit 1
    }
    Write-Host ("Removing symlink: " + $ExtensionsPath) -ForegroundColor Cyan
    $item.Delete()
    Write-Host "Done. X4 will now load the Steam Workshop copy if subscribed." -ForegroundColor Green
    exit 0
}
