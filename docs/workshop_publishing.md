# Steam Workshop Publishing — X4 Foundations

Local mirror of [Egosoft's Workshop guide](https://steamcommunity.com/sharedfiles/filedetails/?id=245117855), filtered down to the X4-relevant bits, plus our mod-specific notes.

---

## Prerequisites

- **X Tools** (free, from Steam Library — installs to `.../steamapps/common/X Tools/`).
- A mod folder under `<X4>/extensions/<modname>/` containing a valid `content.xml`.
- A preview image (JPG or PNG, **≥ 640×360**, widescreen recommended).
- An active Steam login.

## Folder name rules

- Valid chars: `a-z 0-9 . _ - space`
- Max 32 chars, auto-lowercased.
- Cannot start with `ego_` (reserved).
- The folder name shipped to subscribers defaults to your local folder name (override with `-foldername <name>`).

## content.xml requirements

Required attributes on `<content>`:
- `name` — display title.
- `description` — short summary. Use `&#10;` for line breaks (not `\n`).
- `version` — integer, version × 100 (e.g. `version="250"` for v2.50).
- `id` — overwritten with the Workshop ID after first publish.

Optional:
- `author` — defaults to your Steam community name.

Dependencies:
- On another Workshop item: `<dependency id="ws_12345" version="100"/>`
- Minimum X4 version (no `id`): `<dependency version="900"/>` (= 9.0)

DLC IDs (use `optional="true"` for compatibility):
- `ego_dlc_split` — Split Vendetta
- `ego_dlc_terran` — Cradle of Humanity
- `ego_dlc_pirate` — Tides of Avarice
- `ego_dlc_boron` — Kingdom End
- `ego_dlc_timelines` — Timelines

## What actually gets uploaded

**Only these file types in the mod root are uploaded directly:**
`.cat`, `.dat`, `.cur`, `.txt`, `.pdf`, `.mkv`

Everything else (`.xml` scripts, `t/`, `aiscripts/`, `libraries/`, `md/`) MUST be bundled into a catalog. `-buildcat` does this automatically — produces `ext_01.cat/.dat` from the source tree and uploads those.

Placement rules:
- `.cur` (mouse cursors) — root folder only, no subfolders.
- `.mkv` (videos) — root or `videos/` only.

## Commands

```
publishx4   Initial publish of a new Workshop item.
update      Push new version of an existing item.
updatepreview   Update preview image only.
updatetags      Update tags only.
showpage    Open the Workshop page in browser.
help        Tutorial page + this help text.
```

Switches:
- `-path <path>` — extension folder (always required).
- `-preview <file>` — preview image (required for `publish*` and `updatepreview`).
- `-foldername <name>` — override subscriber-side folder name.
- `-contentdef <file>` — alternate content.xml path (e.g. for cross-game publishing).
- `-namedesc up|down` — **on `update` only**: `up` pushes content.xml's name/description over the Steam page; `down` pulls Steam page text back into content.xml. **Default: name/description are IGNORED on update.** Steam-side description edits persist across updates.
- `-tags <a,b,c>` — Workshop tags.
- `-changenote <text>` — required for `update` (empty string allowed).
- `-minor` — allow `update` without a version bump.
- `-buildcat` — bundle non-uploadable files into `ext_01.cat/.dat`.
- `-buildvcat` — same but also build `ext_v###.cat/dat` from `v###/` subfolder for multi-version support.
- `-keepcatfiles` — keep built catalogs after upload (default: cleaned).
- `-batchmode` — non-interactive (no `y/n` prompt).

## First publish

```
WorkshopTool.exe publishx4 -path "<X4>/extensions/<modname>" \
                           -preview "<X4>/extensions/<modname>/preview.png" \
                           -buildcat
```

Steps:
1. Steam login active.
2. Tool validates `content.xml`.
3. Tool prompts `y/n` (skip with `-batchmode`).
4. On success, `id` in `content.xml` is replaced with the Workshop ID and `sync="false"` is set so subscribers' future Workshop updates won't overwrite your local copy.
5. Open the new Workshop item page in browser → accept Workshop Legal Agreement → set visibility (default is hidden) → optionally edit title/description with BBCode.

## Updating

```
WorkshopTool.exe update -path "<X4>/extensions/<modname>" \
                        -buildcat \
                        -changenote "what changed"
```

- Bump `version` in `content.xml` first, OR pass `-minor`.
- Steam page title/description NOT overwritten by default. Edit on Steam web UI and it persists.
- To force-push content.xml metadata: add `-namedesc up`.
- To pull Steam-side edits back into content.xml: add `-namedesc down`.

## Multi-version catalog

To support older X4 versions alongside the newest:
1. Put older-version files under `v###/` (e.g. `v900/` for 9.0).
2. Make changes for the newest version in the root.
3. Set `<dependency version="..."/>` to the minimum supported.
4. Build with `-buildvcat` (not `-buildcat`).

Resulting layout:
```
extensions/mymod/
├── content.xml
├── ext_01.cat/dat       <- newest-version files
├── ext_v900.cat/dat     <- v9.0-version files
└── v900/                <- source tree for v9.0
```

X4 loads the version catalog if it matches the running game version; else falls back to `ext_01`.

## Publishing rules

- Only publish content you authored or have explicit permission for.
- No duplicate uploads — verify success first.
- Document dependencies and incompatibilities clearly in description.
- English in title/description; per-language translations are not visible on the Workshop page.

---

## Our setup — adjustments needed before first publish

### Dynamic Universe (`I:/Software/deadair_scripts`)

| Item | Status |
|---|---|
| `content.xml` id=`dynamic_universe` version=`100` | ✓ |
| `<dependency version="900"/>` for X4 9.0 | ✓ |
| SirNukes API dep (`ws_2042901274`) | ✓ |
| Preview image | `preview.png` (1920×1080) ✓ |
| Deployed folder name | `deadair_scripts` (legacy). For Workshop subscribers to get `dynamic_universe` as the folder name, either rename `<X4>/extensions/deadair_scripts` → `dynamic_universe` before first publish, **or** add `-foldername dynamic_universe` to the publish call in `publish.ps1`. |
| `DeadAir_Eco` dep | Optional, Nexus-only (not on Workshop). Subscribers using Nexus copy will resolve by local `id`; subscribers wanting Workshop-only DLC support won't auto-install. Acceptable as-is for an optional dep. |

### Blockades (`I:/Software/blockade_behavior`)

| Item | Status |
|---|---|
| `content.xml` id=`blockades` version=`100` | ✓ |
| `<dependency version="900"/>` for X4 9.0 | ✓ |
| Preview image | **Missing.** Drop a `preview.png` (≥ 640×360, widescreen) into the mod root before first publish. |
| Deployed folder name | `blockades` matches `id`. ✓ |

### `publish.ps1` (both repos)

- Auto-detect of `WorkshopTool.exe` walks Steam libraries via `libraryfolders.vdf`. Confirmed working with library at `L:\SteamLibrary\steamapps\common\X Tools\WorkshopTool.exe`.
- After first publish, `content.xml` `id` will be rewritten to `ws_NNN`. Commit the rewritten file or restore the original before re-publishing.
- Version bump or `-minor` required between updates — `publish.ps1 -Update` does not auto-bump.

## Resources

- [X Tools forum thread](https://forum.egosoft.com/viewtopic.php?t=363625)
- [X4 Modding Wiki](https://wiki.egosoft.com:1337/X4%20Foundations%20Wiki/Modding%20Support/)
- [XML Patch Guide](https://forum.egosoft.com/viewtopic.php?t=354310)
- [DebugLog documentation](https://forum.egosoft.com/viewtopic.php?t=366654)
