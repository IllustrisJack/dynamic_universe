<#
.SYNOPSIS
  Toggle the development symlink between this repo and the X4 extensions folder.

.DESCRIPTION
  When developing, you want X4 to load the repo via a symlink at
  <X4>/extensions/deadair_scripts/. When testing the Steam Workshop
  build of the same mod, you must remove that symlink so the Workshop
  copy is the only one X4 sees — otherwise X4 finds the same
  content.xml id twice.

  -Link    Create the symlink (or recreate it if broken).
  -Unlink  Remove the symlink. Repo on disk is untouched.
  -Status  Print current state. (Default if no switch passed.)

.PARAMETER ExtensionsPath
  Override the destination. Default: auto-detect <SteamLib>/X4 Foundations/extensions/deadair_scripts
  under every Steam library on the machine.

.PARAMETER RepoPath
  Override the repo source. Default: this script's grandparent dir
  (assumes scripts/dev-link.ps1 layout).

.NOTES
  Creating a symbolic link on Windows requires either an elevated
  PowerShell (Run as Administrator) or Developer Mode enabled
  (Settings → System → For developers → Developer Mode = On).

  After -Link, X4 must be restarted (or save-reloaded for MD scripts)
  to pick up the directory swap. After -Unlink, same — and the Workshop
  version will then be the active copy if subscribed.

.EXAMPLE
  .\scripts\dev-link.ps1 -Link
  .\scripts\dev-link.ps1 -Unlink
  .\scripts\dev-link.ps1 -Status
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
    Write-Error "Repo path '$RepoPath' has no content.xml — not a valid mod source."
    exit 1
}

if (-not $ExtensionsPath) {
    $extDir = Find-X4ExtensionsDir
    if (-not $extDir) {
        Write-Error "Could not auto-detect X4's extensions folder. Pass -ExtensionsPath '<X4>\extensions\$ModName'."
        exit 1
    }
    $ExtensionsPath = Join-Path $extDir $ModName
}

# Default to -Status if nothing specified
if (-not ($Link -or $Unlink -or $Status)) { $Status = $true }

function Show-Status {
    Write-Host "Repo:        $RepoPath" -ForegroundColor DarkGray
    Write-Host "Target:      $ExtensionsPath" -ForegroundColor DarkGray
    if (-not (Test-Path $ExtensionsPath)) {
        Write-Host "State:       NOT LINKED (Workshop copy would be the active version if subscribed)" -ForegroundColor Yellow
        return
    }
    $item = Get-Item $ExtensionsPath -Force
    if ($item.LinkType -eq "SymbolicLink") {
        $tgt = $item.Target
        if ($tgt -is [array]) { $tgt = $tgt[0] }
        if ((Resolve-Path $tgt -ErrorAction SilentlyContinue).Path -eq (Resolve-Path $RepoPath).Path) {
            Write-Host "State:       LINKED to this repo ✓" -ForegroundColor Green
        } else {
            Write-Host "State:       LINKED to a different path: $tgt" -ForegroundColor Yellow
        }
    } else {
        Write-Host "State:       EXISTS as a real directory (not a symlink) — likely a Workshop install or manual copy" -ForegroundColor Yellow
    }
}

if ($Status) {
    Show-Status
    exit 0
}

if ($Link) {
    if (Test-Path $ExtensionsPath) {
        $item = Get-Item $ExtensionsPath -Force
        if ($item.LinkType -eq "SymbolicLink") {
            $tgt = $item.Target
            if ($tgt -is [array]) { $tgt = $tgt[0] }
            if ((Resolve-Path $tgt -ErrorAction SilentlyContinue).Path -eq (Resolve-Path $RepoPath).Path) {
                Write-Host "Already linked to this repo. Nothing to do." -ForegroundColor Green
                exit 0
            }
            Write-Host "Removing existing symlink pointing to $tgt ..." -ForegroundColor DarkGray
            (Get-Item $ExtensionsPath -Force).Delete()
        } else {
            Write-Error "$ExtensionsPath exists as a real directory. Refusing to overwrite. Move or rename it first."
            exit 1
        }
    }
    Write-Host "Creating symlink: $ExtensionsPath -> $RepoPath" -ForegroundColor Cyan
    New-Item -ItemType SymbolicLink -Path $ExtensionsPath -Target $RepoPath | Out-Null
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
    if ($item.LinkType -ne "SymbolicLink") {
        Write-Error "$ExtensionsPath is a real directory (not a symlink). Refusing to delete contents. Move or rename it manually if intentional."
        exit 1
    }
    Write-Host "Removing symlink: $ExtensionsPath" -ForegroundColor Cyan
    $item.Delete()
    Write-Host "Done. X4 will now load the Steam Workshop copy (if subscribed)." -ForegroundColor Green
    exit 0
}
