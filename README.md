# Dynamic Universe

> A mod for **X4: Foundations 9.0** that adds a vassal-state system on top of vanilla diplomacy plus the original DeadAir Dynamic War / Dynamic News mechanics. Continued fork of DeadAir's *Dynamic Universe / Deadair Scripts* by IllustrisJack — see [Attribution & License](#attribution--license) below.

---

## Modules

- **Dynamic War** — periodic AI-to-AI relation shifts driven by military strength, shared enemies, and primary race. Six event types from soft boosts to instant max-relation flips.
- **Dynamic News** — logbook + notification feed for galaxy-scale events (sector ownership changes, major station destroyed, economic stations expanded, all Galactic Politics events).
- **Galactic Politics** *(new in this fork)* — vassalage layer on top of vanilla diplomacy. Three vassalize paths (Dynamic War roll, conquest, player broker), tribute, happiness, garrison fleets, embassies, rebellions, coups, succession, war exhaustion.

Each module has its own toggle in the in-game mod menu.

---

## Differences from the original DeadAir Scripts

If you're coming from upstream *DeadAir Scripts / Dynamic Universe* (v1.13 / v7.5RC), here's what changed:

**New features (this fork only):**
- **Galactic Politics / Vassal System** — full vassalage mechanic with three vassalize paths (Dynamic War roll, conquest, player broker), tribute, happiness, rebellions, coups, succession, embassies, levies, war exhaustion, coalition rebellions. The headline feature of the fork. See [Modules § Galactic Politics](#galactic-politics-vassal-system).
- **X4 9.0 RC4 compatibility** — original was last shipped against 7.x. Patcher-side fixes for the 9.0 strict parser (`@expr?` syntax, `<return/>` placement, `find_station space=` required, `keys.list.count` deprecated, etc.), diplomacy API guards (`isdiplomacyexcluded`, Protocol Null), and vanilla shape changes in `aiscripts/order.move.recon.xml` + `md/factionlogic_economy.xml`.
- **Faction Dossier** — read-only menu summarizing per-faction sector count, military strength, treasury, vassalage status. Replaces the removed Information Menus with a narrower, vassal-aware view.
- **Suzerain Presence** — vassal sectors share the suzerain's police authority. Antigone and Holy Order police-patrol jobs extend through ally-relation sectors so policing flows along vassal lines.
- **Police outsourcing menu** — sell sector police rights to an AI faction for ongoing credit revenue.

**Removed entirely:**
- Trader Profit, Infestation, Gate, Evolution, God, Fill, Jobs Expeditions, Jobs Smart Sector Tags, the original 8779-line mass-jobs library, Information Menus, Blueprint Analysis. Diff surface dropped from ~hundreds of files to a small footprint (see [What we touch in vanilla](#what-we-touch-in-vanilla)).

**Renames / breaking changes:**
- Mod ID: `DeadAir_Scripts` → `dynamic_universe`. **This is a save-compat break** — vassal state stored under the old ID won't migrate. Anyone using the upstream vassal mechanic (there wasn't one) would have to restart.
- Internal identifiers: `DeadAir*` → `DynamicUniverse*`, `$DA*` → `$DU*` (~262 vars). Mostly cosmetic but affects any companion mod that read upstream's internal variables (none known to exist).
- User-facing menu text: "DA Mod" / "DA Dynamic War" → unprefixed.

**Documentation / tooling (new):**
- `docs/architecture.md`, `docs/vassal_system.md`, `docs/md_9.0_gotchas.md`, `docs/compat_principles.md`, `docs/migrations.md`, `docs/diplomacy_ui_investigation.md`, `docs/toolchain.md`.
- An external Rust **xpath validator** that checks every `<add>/<replace>/<remove>` diff selector against a vanilla snapshot, run on every X4 version bump. Source isn't in this repo; build instructions in `docs/toolchain.md`.
- `scripts/tail-mod-log.ps1` for filtered debuglog tailing.

**What stayed the same:**
- Dynamic War and Dynamic News mechanics are upstream's design and largely upstream's code with 9.0 polish + a few bug fixes (player-in-DW-dropdown, broker cost overflow, integer-typing on huge worth values, etc.).
- The `t/0001.xml` localization page id `33232474` is preserved — changing it would touch hundreds of `{33232474,N}` lookups for no user benefit.
- Original DeadAir GPL v3 license, original git history (v1.01 → v7.5RC2 → v1.13), and DeadAir's retirement note are all preserved verbatim. See [Attribution & License](#attribution--license).

---

## Compatibility

| Thing | Version |
|---|---|
| X4: Foundations | **9.0 RC4** (`<dependency version="900"/>` in `content.xml`) |
| Required dependency | [SirNukes Mod Support APIs](https://www.nexusmods.com/x4foundations/mods/503) (Steam ID `ws_2042901274`) |
| Optional dependencies | All Egosoft DLCs (split, terran, pirate, boron, timelines), [DeadAir Economy Overhaul](https://www.nexusmods.com/x4foundations/mods/2139) (community-adopted by Chem O'Dun for 9.0 — highly recommended) |
| Not compatible with | Old standalone versions of DeadAir's Dynamic War, Evolution, Fill, Jobs, Gate |

The diff surface is intentionally small (see [What we touch in vanilla](#what-we-touch-in-vanilla)). Mods that don't replace entire vanilla XML roots will coexist fine.

---

## Installation

1. Drop the mod into your X4 extensions folder — the directory name must match `content.xml id`:
   ```
   <X4 install dir>/extensions/dynamic_universe/
   ```
2. Enable in the in-game **Extensions** menu (main menu → Settings → Extensions).
3. Load a save. Open **Mod Menu → Galactic Politics** to switch features on.

> **Folder name matters.** The mod's internal id is `dynamic_universe`. If your folder is named `deadair_scripts` (the old upstream name) or anything else, X4 won't find it. Rename the folder.

---

## Modules

### Dynamic War

Periodic AI-to-AI relation shifts driven by military strength, shared allies/enemies, and primary race. Six event types — Best Friends (instant max relation), Big Boost (+15), Small Boost (+5), Small Blow (-5), Big Blow (-15), Nemesis (instant max negative). Strong factions accrue enemies; weak ones accrue allies. Adjustable interval, event weights, ignored-factions list, and a soft cap that prevents AI relations from meeting the "self" threshold required for shared job locations.

Player tools:
- **Increase / Decrease Relations** — credit-cost or favor-paid relation changes between two factions.
- **War History** — recent DW events.
- **Ignored Factions** — exclude factions from being picked by random events (also respected by Galactic Politics).

### Dynamic News

Logbook + notification feed for galaxy-scale events: major station destroyed, economic stations expanded/started, sector ownership changes, plus all Galactic Politics events (vassalize, rebel, release, coup, etc.). Combines reports per faction to avoid notification spam. Configurable interval, separate toggles for notifications / logbook / news-storage database.

### Galactic Politics (Vassal System)

New in this fork. Off by default; switch on under **Mod Menu → Galactic Politics**. Once on, vassalages form three ways:

- **Dynamic War roll** — every DW interval, the system considers pairs drawn from the top-3 strongest and bottom-3 weakest claimspace factions. If the strong one already has ≥ +0.25 relation with the weak one and the pair isn't a vanilla diplomacy-lock, the pair is eligible and one rolls into vassalage.
- **Conquest** — when a sector changes hands and the loser is left with ≤ 3 sectors, a 35% roll (configurable) converts them into a vassal of the conqueror instead of letting them collapse.
- **Player broker** — pick a suzerain, see candidate vassals with per-pair credit costs scaling with vassal worth (or sector count fallback), suzerain military, and hostility multiplier (1× friendly → 5× hostile, capped at 2G Cr).

Once a vassalage forms, a garrison fleet (1 destroyer + 2 frigates + 4 fighters, race-matched to the suzerain) dispatches from the suzerain's actual shipyard to the vassal's HQ sector plus up to two more vassal-owned sectors. Tribute is a virtual ledger — every DW interval the vassal's computed worth times the tribute % is transferred from vassal's virt-balance to suzerain's. When the player is the suzerain, half the computed tribute becomes real Cr (capped at 50M/tick).

Happiness ticks every ~5 min. Drains from high tribute, cultural mismatch, the vassal being stronger than the suzerain, sectors lost, the suzerain being at war. Lifts from shared enemies, a strong protective suzerain, sectors gained. AI suzerains auto-gift to stabilize unhappy vassals at the cost of their virtual treasury. Below 30 happiness, rebellion rolls fire — successful rebels defect with the garrison ships, get a 60 min cooldown, and may attract supporter fleets from hostile-to-former-suzerain factions.

A diplomatic **embassy** (defense station, owned by suzerain) is built in the vassal's HQ sector as a `componentstate.construction` site, so the suzerain's economy actually constructs it — it isn't spawn-cheated. Defense fleet ships dispatch from the suzerain's shipyard to protect it during the build.

Other features:
- **Coup d'état** (player broker) — flip a vassal between suzerains; the old suzerain's embassy + garrison stay in the new vassal's sector as enemy assets.
- **Vassal levy** — order existing vassal combat ships to patrol a sector for ~20 min at the cost of happiness. No new ships spawn.
- **Vassal expeditions** — 20% chance per DW interval that a vassal sends an expedition fleet against one of the suzerain's enemies.
- **Succession** — when a suzerain is destroyed and has multiple vassals, the strongest vassal inherits the others (refusal chance per sibling configurable).
- **Coalition rebellions** — when multiple vassals of the same suzerain rebel on the same tick, the news layer reports it as one coalition event instead of N solo ones.
- **War exhaustion** — long-running wars can drive a vassal toward capitulating to a third-party suzerain.
- **Police outsourcing** — separate mechanic; the player can sell sector police rights to an AI faction for credits.
- **Faction Dossier** — read-only menu showing per-faction sector count, military strength, treasury, vassalage status.

See [`docs/vassal_system.md`](docs/vassal_system.md) for full mechanics, exit conditions, and the trigger/event/exit tables.

---

## Save-game safety

The vassal system applies persistent X4 `relation_locked` flags. **Those locks survive uninstall** and cannot be reversed once the mod's scripts are gone. Before removing the mod:

1. Open **Mod Menu → Galactic Politics**.
2. Click **Release All Vassals** (clears vassalages but keeps the system on for future use), OR **Safe Uninstall** (releases everything *and* disables the system).

If you never enabled the vassal system, nothing special is needed for uninstall.

If you forgot and notice factions whose relations never change after uninstall, reinstall, run **Safe Uninstall**, then uninstall again. The vassal data persists across reinstall — this is intentional, it's how the cleanup works.

---

## Story-mission safety

Two layers, one engine-level and one mod-level:

1. **`isdiplomacyexcluded`** — X4 marks certain faction pairs as diplomacy-excluded so vanilla story scripts can hold relations stable (Argon↔Antigone, Terran↔Pioneers, Teladi↔Ministry, Trinity↔Holy Order, etc.). Every vassalize path in the mod respects this marker. When a vanilla story clears a lock (e.g. Covert Operations clearing Terran↔Argon), those pairs naturally become available without any mod intervention.
2. **DW Ignored Factions list** — mod-side, user-configurable under **Dynamic War → Ignored Factions**. Anything on this list is excluded from DW vassalize, conquest vassalize, and the broker menu. Use this for story arcs that don't have an engine-level diplomacy lock.

Vassal relations are locked at +1.0. If a story arc you care about depends on a specific relation between two factions that aren't diplomacy-locked, vassalizing one of them can break that story — the ignored-factions list is the safety valve.

---

## What we touch in vanilla

Surface is minimal by design. See [`docs/compat_principles.md`](docs/compat_principles.md) for the rules we follow.

**Base-game files:**
- `aiscripts/order.build.recycle.xml` — single attribute replace (recycler cover usage)
- `aiscripts/order.move.recon.xml` — single `<add pos="before">` (police scan signal)
- `libraries/colors.xml` — `<add>` of `da_*` UI colors
- `libraries/diplomacy.xml` — `<add>` of `propose_vassalage` agent diplomacy action + `<patch>` for the relations table
- `libraries/jobs.xml` — four attribute swaps on Antigone + Holy Order police patrol filters
- `libraries/mapdefaults.xml` — four `@tags` attribute swaps (Xenon-anomaly tagging on 4 sectors)
- `libraries/modules.xml` — two attribute swaps on `prod_gen_refinedmetals`
- `md/factionlogic_economy.xml` — three nested `<add>` ops for station event signalling
- `t/0001.xml` — uses page id `33232474` for all our localization strings

**DLC overrides** (`extensions/ego_dlc_*/libraries/`):
- `ego_dlc_terran/libraries/jobs.xml` + `mapdefaults.xml` — police patrol + sector tags
- `ego_dlc_split/libraries/jobs.xml` + `mapdefaults.xml` — police patrol + sector tags
- `ego_dlc_boron/libraries/jobs.xml` — police patrol

**Things we never do:** replace MD cue bodies, replace vanilla library roots, modify save-format files, override story content, change relations between `isdiplomacyexcluded` pairs.

---

## Contributing

Issues and PRs welcome. Some norms before opening one:

- **One topic per PR.** Small focused changes get merged faster than mega-refactors.
- **Conventional Commits** — `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, scope optional. Squash if needed before the merge so the history stays readable.
- **No `Co-Authored-By` AI / Claude / Anthropic trailers.** Drop them before pushing.
- **Run the validator before submitting changes that touch `libraries/*.xml`:** see [`docs/toolchain.md`](docs/toolchain.md) for setup. The validator is a separate Rust tool you build from source.
- **Test in-game before submitting MD changes.** XML parsing clean ≠ working. The Self-Check button under Galactic Politics → Detailed Debug helps; so does `scripts/tail-mod-log.ps1 -Live -ErrorsOnly`.
- **Check `docs/md_9.0_gotchas.md`** before writing new MD. The patterns there were hit by user testing; the doc catalogues each one with the fix.
- **Diff philosophy** — additive over replacement, scoped xpath selectors over root-level replaces. See [`docs/compat_principles.md`](docs/compat_principles.md).

If you want to take Dynamic Universe in a substantially different direction, fork it. GPL v3 explicitly protects that right. Send a heads-up though — happy to link forks from here.

### Repo layout

```
content.xml             Mod manifest (X4 reads this)
libraries/*.xml         Base-game diff patches
extensions/ego_dlc_*/   DLC-specific diff patches
md/dynamicuniverse.xml  Main MD script (~5500 lines — vassal system, dynamic war, dynamic news)
md/dynamicuniversemenus.xml   Menu MD script (~7700 lines — all Simple Menu API menus)
md/factionlogic_economy.xml   Extension hook into vanilla economy events
t/0001.xml              Localization strings, page id 33232474
scripts/tail-mod-log.ps1  Log filtering helper for development
docs/                   Architecture, gotchas, design spec, compat principles, migrations
```

---

## Reporting issues

When reporting a bug, please include:

1. **X4 version** (we target 9.0 RC4 — older versions are not supported).
2. **DLC list** (split, terran, pirate, boron, timelines).
3. **Other mods loaded.** Modlist conflicts are responsible for ~80% of "bug" reports.
4. **A debug log** with the relevant module's `DetailedDebug` toggle enabled (under that module's menu). The log file is `$USERPROFILE/Documents/Egosoft/X4/<userid>/debuglog.txt`. The Self-Check button writes a structured `[DU-CHECK]` block to the player logbook — paste that if vassal-system related.
5. **Save file** (if relevant and small enough to attach), or steps to reproduce.

Contact: GitHub issues preferred. Egosoft Discord modding channel works too.

---

## Attribution & License

Original "Dynamic Universe / Deadair Scripts" © DeadAir, released under GPL v3 in September 2025 with explicit permission to continue ([retirement note from 2025-09-23](#original-authors-retirement-note)):

> *"I have decided to completely retire from X4 Modding. I have added licenses to Eco, Scripts, and DeadTater if any persons are interested in using, modifying, or continuing my works. Thank you for all the support and interest in my work over these years."*

This fork is maintained by **IllustrisJack**, also under **GPL v3** (see [`LICENSE`](LICENSE)). Significant modifications since the original:

- X4 9.0 RC4 compatibility (parser strictness, diplomacy API changes, isdiplomacyexcluded, Protocol Null)
- New Galactic Politics / Vassal System (see above)
- XPath validator toolchain for diff-selector regression checks
- Removal of submods that didn't fit this fork's scope (Trader Profit, Infestation, Gate, Evolution, God, Fill, Jobs Expeditions, Jobs Smart Sector Tags, Information Menus)
- Internal identifier rename `DeadAir*` → `DynamicUniverse*` / `$DA*` → `$DU*`
- Extensive documentation under [`docs/`](docs/)

The original git history is preserved in this repo — every DeadAir commit from `Initial upload` (v1.01) through `v1.13` / `v7.5RC` is still in `git log`. Diffs from the fork point onward are this fork's contributions.

### Original author's retirement note

Quoted verbatim from upstream README, September 2025:

> *I have decided to completely retire from X4 Modding. I have added licenses to Eco, Scripts, and DeadTater if any persons are interested in using, modifying, or continuing my works. Thank you for all the support and interest in my work over these years.*

---

## Acknowledgements

- **DeadAir** for the original Dynamic Universe framework and for releasing it under GPL v3 with a clear go-ahead to continue.
- **SirNukes** for the [Mod Support APIs](https://www.nexusmods.com/x4foundations/mods/503) (Simple Menu API in particular makes the whole UI surface possible).
- **Jack the Stripper** for the original Blueprint Analysis concept (currently in-codebase but inert — planned as a separate companion mod).
- **Egosoft** for X4.
