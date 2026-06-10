# Development Toolchain

This document covers the development tools used to maintain the mod. None of these ship inside the mod itself — they live outside the repo and produce artifacts (validator reports, vanilla snapshots) the maintainer references.

For the codebase architecture, see `architecture.md`. For player-facing info, see `README.md`.

Paths shown below use placeholders: `<TOOLCHAIN>` for wherever you keep these dev tools, `<VANILLA>` for the vanilla-snapshot root, `<MOD>` for this repo's checkout. Pick directories that make sense on your machine.

---

## 1. Overview

| Tool | Where | Purpose |
|---|---|---|
| **XRCatTool.exe** | Egosoft "X Tools" (Steam, free) | Extract vanilla X4 `.cat`/`.dat` archives so we have the unmodified XML to diff against. |
| **extract-vanilla.ps1** | `<TOOLCHAIN>/scripts/extract-vanilla.ps1` | PowerShell wrapper around XRCatTool. Builds a versioned snapshot of vanilla. |
| **x4-xpath-validator** | `<TOOLCHAIN>/xpath-validator/` (Rust, separate repo) | Validates every `<add sel="…">`, `<replace sel="…">`, `<remove sel="…">` in the mod's diff files against an extracted vanilla snapshot. Catches xpath drift between X4 versions. |
| **Vanilla snapshot** | `<VANILLA>/<version>/` | The extracted vanilla XML. Filtered to the file types the mod touches. |

---

## 2. Why this toolchain exists

X4 mods are not built against a stable API. They patch live vanilla XML with xpath diffs. When X4 patches, Egosoft can rename, restructure, or remove nodes the mod targets. Without the validator, the only way to catch that drift is in-game testing, which is slow and incomplete.

The toolchain:

1. **Extracts a known-good vanilla snapshot** per X4 version.
2. **Validates every diff xpath in the mod** against that snapshot.
3. **Reports broken xpaths** that need re-anchoring before shipping against a new X4 version.

This is the foundation that made the M1 9.0 compatibility pass take an hour instead of a full day of in-game debugging.

---

## 3. One-time setup

### 3.1 Install X Tools

Either:

- **Steam** (preferred): Library → Tools → install "X Tools" (free for X4 owners). Locate `XRCatTool.exe` in the install folder (e.g., `<Steam>/steamapps/common/X Tools/XRCatTool.exe`).
- **Egosoft direct**: <https://www.egosoft.com/download/x4/bonus_en.php> → "X Catalog Tool" → unzip to a convenient location.

Update the default path in `extract-vanilla.ps1` if needed:

```powershell
[string]$CatTool = "<Steam>/steamapps/common/X Tools/XRCatTool.exe"
```

### 3.2 Build the validator

The validator is a separate Rust project (not in this repo).

```powershell
cd <TOOLCHAIN>/xpath-validator
cargo build --release
```

Produces `target/release/x4-xpath-validator.exe`. Rust 1.94+. Build dependencies: `sxd-document`, `sxd-xpath`, `clap`, `walkdir`, `anyhow`, `serde`, `serde_json`, `winapi`.

---

## 4. Refreshing the vanilla snapshot for a new X4 version

When a new X4 version drops:

```powershell
<TOOLCHAIN>/scripts/extract-vanilla.ps1 `
    -X4Install "<X4Install>" `
    -SnapshotName "9.0_rc4"
```

Arguments:

- `-X4Install <path>` — your X4 install root (the folder with `X4.exe` and `01.cat`, `02.cat`, …).
- `-SnapshotName <name>` — produces `<VANILLA>/<name>/`. Use the X4 version as the name.
- `-CatTool <path>` (optional) — override the XRCatTool location.
- `-IncludeDLC $true` (default) — also extract `extensions/ego_dlc_*/ext_*.cat`.
- `-FilterToModSurface $true` (default) — keep only the file types this mod patches. Cuts ~3 GB of irrelevant content. Filter regex: `^(aiscripts|md|libraries|t|index|assets/wares|assets/equipmentmods|maps)/.+\.xml$`.

The output layout matches mod-relative paths so the validator's lookup is trivial:

```
<VANILLA>/9.0_rc4/
├── aiscripts/
├── libraries/
├── maps/xu_ep2_universe/
├── md/
├── t/
├── extensions/ego_dlc_split/maps/xu_ep2_universe/
├── extensions/ego_dlc_terran/maps/xu_ep2_universe/
└── _snapshot.json     (metadata: install path, extraction date, version)
```

Expect ~1500 XML files for a filtered snapshot.

---

## 5. Running the validator

```powershell
<TOOLCHAIN>/xpath-validator/target/release/x4-xpath-validator.exe `
    --mod-root  <MOD> `
    --vanilla   <VANILLA>/9.0_rc4 `
    --quiet `
    --json-out  <VANILLA>/_diffs/9.0_rc4_validation.json
```

Arguments:

- `--mod-root` — the mod folder.
- `--vanilla` — the snapshot to validate against.
- `--quiet` (optional) — only print non-OK rows + summary.
- `--json-out <path>` (optional) — write full report as JSON for tooling consumption.

### Exit codes

- `0` — all xpaths resolved, no parse errors.
- `1` — at least one broken xpath or parse error.

### Output format

Each diff op in the mod produces one row:

```
[OK        ] aiscripts/order.build.recycle.xml  replace sel=…  -- matched 1 node(s)
[BROKEN    ] libraries/modules.xml              replace sel=…  -- matched 0 nodes
[NO VANILLA] (file not in snapshot)              add sel=…
[PARSE     ] mod/vanilla parse error            (details)
```

### Parser strictness

The validator uses **two** XML parsers in sequence:

1. **`quick-xml`** in strict mode (`check_end_names = true`) — catches close-tag name mismatches. This is the same strictness libxml2 enforces at X4 load time. Reports as `[PARSE]` rows.
2. **`sxd-document` + `sxd-xpath`** — used only after strict parse passes, for xpath evaluation.

The strict pass exists because `sxd-document` alone accepts mismatched close tags as long as the global open/close counts balance.

### Diff engine

The validator applies each mod diff op to the in-memory vanilla tree before evaluating the next op, and pre-applies DLC overlays. Two consequences:

- **Sequential diff chains validate correctly.** `libraries/modules.xml`'s refinedmetals chain (op N+1 references the attribute op N just rewrote) reports `OK` for both.
- **DLC-defined targets validate correctly.** `extensions/ego_dlc_split/libraries/mapdefaults.xml` mod diffs targeting Split DLC clusters resolve against the DLC's own `<defaults>` document; mod diffs in `extensions/ego_dlc_terran/libraries/jobs.xml` resolve against base + Terran's `<diff>` overlay.

A clean run on the current mod is `ok=24 broken=0 missing-vanilla=0 parse-errors=0`. Any non-OK row is a real bug.

---

## 6. The maintainer workflow for an X4 version bump

1. **Update X4**, note the new version (e.g., 8.0 → 9.0).
2. **Cut a baseline branch** if you want to preserve support for the old version:
   ```sh
   git checkout master
   git checkout -b x4-8.x
   git checkout master
   ```
3. **Extract a new vanilla snapshot:**
   ```powershell
   ./extract-vanilla.ps1 -X4Install "..." -SnapshotName "9.0"
   ```
4. **Run the validator** against the new snapshot. Triage `BROKEN` rows.
5. **Patch xpaths** that broke. Typical causes:
   - Egosoft restructured a nested `do_if` chain → the xpath needs an extra or one-fewer segment.
   - A `<replace sel="…/@attr=value">` whose attribute value changed → update the value.
   - A parameter renamed → update the parameter selector.
6. **Bump `content.xml`**:
   ```xml
   <dependency version="900"/>     <!-- new X4 minimum -->
   ```
7. **Re-run validator. Verify** `broken=0 parse-errors=0`.
8. **Smoke test** in-game.
9. **Commit + merge.**

---

## 7. Validator source

The validator lives at <https://github.com/IllustrisJack/xpath-validator>. Build instructions and the full op support matrix are in that repo's README.

---

## 8. Iterating on MD changes in-game

Confirmed by observation: **loading a save from the main menu re-parses MD scripts**. A full X4 process restart is NOT required to pick up MD edits.

Workflow:

1. Edit `md/dynamicuniverse.xml` (or any other MD file).
2. Make sure the change is on disk at `<X4>/extensions/<modname>/md/...` — if your repo is symlinked into the extensions folder, that's automatic.
3. In-game: ESC → Main menu → Load save.
4. The new MD code is active for the loaded session. `event_game_loaded` cues fire against the new code.

Caveats:

- **aiscripts may differ.** Not verified either way. If an `aiscripts/` change doesn't seem to take effect after a save-reload, do a full X4 restart and retest.
- **New cues parsed on load.** If a new `event_game_loaded` cue you just wrote doesn't fire on save-reload, the parse may have failed silently. Check `debuglog.txt` filtered to `[General]` / `[Scripts]` for parse errors before assuming the cue logic is wrong.
- **Save state persists.** New on-load handlers (e.g. the vassal-table sanitizer) run against state that was saved before they existed; they can fix things at load time but never at save time.
