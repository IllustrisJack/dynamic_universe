# Dynamic Universe — Codebase Architecture

This document is for maintainers and contributors. It explains how the mod is organized, the conventions every feature follows, and the X4 hooks the mod relies on. Read this before adding a new feature or making non-trivial changes to an existing one.

For player-facing feature descriptions, see `README.md`. For the design spec of a specific feature, see `docs/<feature>.md`.

---

## 1. File layout

```
dynamic_universe/
├── content.xml                          mod manifest (version, dependencies, name)
├── LICENSE                              GPL v3
├── README.md                            player-facing
├── docs/                                maintainer + design docs
│   ├── architecture.md                  this file
│   ├── compat_principles.md             diff rules for other-mod compatibility
│   ├── md_9.0_gotchas.md                MD scripting pitfalls (X4 9.0)
│   ├── migrations.md                    save-migration catalogue
│   ├── test_plan.md                     manual smoke-test checklist
│   ├── toolchain.md                     extraction script, validator, snapshots
│   └── vassal_system.md                 vassal feature design spec + decision log
├── md/                                  mission director scripts (the brains)
│   ├── dynamicuniverse.xml              main script (~13k lines). Init, all feature
│   │                                    cues, libraries, save migration scaffolding.
│   ├── dynamicuniversemenus.xml         all UI menus (~10k lines). Uses Simple_Menu_API.
│   └── factionlogic_economy.xml         tiny diff to vanilla faction logic
├── aiscripts/                           AI behavior overrides
│   ├── order.build.recycle.xml          diff: ships don't use cover when recycling
│   └── order.move.recon.xml             diff: police scan signalling for BP system
├── libraries/                           diff-style additions to vanilla data tables
│   ├── colors.xml                       UI colors
│   ├── jobs.xml                         police-patrol diff for Suzerain Presence
│   ├── mapdefaults.xml                  sector tag additions (xenon core anomalies)
│   └── modules.xml                      tweaks to refinedmetals module
├── extensions/                          DLC-scoped diffs (split, terran)
├── scripts/                             repo-side helpers (tail-mod-log.ps1)
└── t/0001.xml                           localization. Page id 33232474.
```

The mod is loaded by X4 from a folder named `dynamic_universe` inside `<X4 install>/extensions/`.

---

## 2. The shared variable tables

Almost every piece of mod state lives in two tables, both initialized in the Init cue of `dynamicuniverse.xml`:

- **`md.$DUDynamicVarTable`** — aliased as `$DUDVT`. Module-scoped. Most settings and feature state live here.
- **`global.$DUVarTable`** — aliased as `$DUGVT`. Globally scoped. Used for features that need to be visible to other mdscripts or are conceptually game-wide (Trader Profit, Infestation).

Every cue that touches mod state begins with:

```xml
<do_if value="(not $DUDVT?) or ($DUDVT == null)">
    <set_value name="$DUDVT" exact="md.$DUDynamicVarTable"/>
</do_if>
```

This defends against the alias being missing on save load. The verify-on-load cue (see §4) re-initializes both shortcuts each time the game loads.

### Why the table-with-aliases pattern

X4's MD has no namespacing primitive. Without this, every feature's variables would live at the top level of `md.*` and collide with other mods. Putting everything under `$DUDynamicVarTable.$DUFeatureFoo` gives the mod a single namespace and one variable to verify on save load.

### Naming convention

Within `$DUDVT`, feature-specific variables are prefixed with the feature short code:

| Prefix | Feature |
|---|---|
| `$DUDynamicWar*` | Dynamic War |
| `$DUDynamicNews*` | Dynamic News |
| `$DUDynFav*` | Dynamic Favors |
| `$DUBP*` | Blueprint Analysis |
| `$DUVassal*` | Vassal System (Galactic Politics) |
| `$DUFactionTreasury` | Per-vassal virtual treasury |
| `$DURebellionLog` | Recent-rebellion cooldown ledger |
| `$DUPoliceContract`, `$DUPoliceOutsourcing*` | Police Outsourcing |
| `$DURelFix*` | Relations-fix loop (DW relation capping) |

When adding a new feature, pick a short prefix and use it consistently.

---

## 3. Cue / Library conventions

The cues and libraries in `md/dynamicuniverse.xml` follow a layered naming pattern:

### Timers
- `Timer<Feature>Events`, `Timer<Feature>Checks`, etc.
- Run on a `checkinterval="Xmin" checktime="Ymin"` schedule.
- Conditioned on `<check_value value="$DUDVT.$DU<Feature>Enable"/>` so they no-op when the feature is off.
- Signal one or more Event cues via `<signal_cue_instantly>`.

### Event cues
- `Event<Feature>SomethingHappened`.
- Triggered by `<event_cue_signalled/>` or X4-native events (`<event_object_changed_owner>`, `<event_game_loaded>`, etc.).
- Do the actual work for one tick or one event.

### Functional libraries
- `Library<Feature><Verb>` or `Library_<Feature><Verb>` (mixed styles; both are present in the existing code).
- Reusable action blocks called via `<include_actions ref="Library<Name>"/>`.
- Take inputs through local variables the caller sets (`$LocFaction`, `$LocSuzerain`, etc.) and output through local variables the library sets in the caller's scope.
- Clean up their own temp vars at the end.

### Variable-check libraries
- `LibraryCheck<Feature>Variables`.
- Run on save load via the central `VerifyVariablesExist` cue.
- Initialize missing variables with sane defaults.
- Increment `$MissingVarCount` and log when something was missing.
- Pattern for every variable:

```xml
<do_if value="(not $DUDVT.$DUFooEnable?) or (not ((typeof $DUDVT.$DUFooEnable == datatype.integer) and (($DUDVT.$DUFooEnable == 1) or ($DUDVT.$DUFooEnable == 0))))">
    <set_value name="$DUDVT.$DUFooEnable" exact="false"/>
    <set_value name="$MissingVarCount" exact="1" operation="add"/>
</do_if>
```

For tables: `<do_if value="(not $DUDVT.$DUFooTable?) or ($DUDVT.$DUFooTable == null)"><set_value … exact="table[]"/></do_if>`.

For numerics: `<do_if value="(not $DUDVT.$DUFoo?) or (not ($DUDVT.$DUFoo ge 0))"><set_value … exact="N"/></do_if>`.

---

## 4. Save migration

X4 persists `md.$DUDynamicVarTable` across saves. When a save is loaded, the table is restored — but if the mod has *added new variables* between the version the player saved with and the version they're loading with, those new variables won't be there.

The mod handles this through `VerifyVariablesExist` in `dynamicuniverse.xml`:

```xml
<cue name="VerifyVariablesExist" instantiate="true">
    <conditions>
        <check_any>
            <event_universe_generated/>
            <event_game_loaded/>
            <event_cue_signalled/>
        </check_any>
    </conditions>
    <actions>
        <!-- ... defensive init of top-level tables ... -->
        <include_actions ref="LibraryCheckDynamicWarVariables"/>
        <include_actions ref="LibraryCheckDynamicNewsVariables"/>
        <!-- ... one include per feature ... -->
        <include_actions ref="LibraryCheckVassalVariables"/>
        <include_actions ref="LibraryCheckMiscVariables"/>
    </actions>
</cue>
```

When you add a new feature:

1. Add an `Init` block of `<set_value name="$DUDVT.$DU<Feature>*" exact="..."/>` for new-game defaults.
2. Add a new `LibraryCheck<Feature>Variables` library that defensively re-initializes each variable if missing.
3. Add an `<include_actions ref="LibraryCheck<Feature>Variables"/>` line inside `VerifyVariablesExist`.

When you add a new variable to an *existing* feature:

- Add the init line.
- Add a check in `LibraryCheck<Feature>Variables`.
- Reads of the variable in feature code should use the `@` safe-access prefix (`@$DUDVT.$DUFooNewVar`) for one release cycle, so old saves loading the new version don't throw.

---

## 5. Localization

All UI strings live in `t/0001.xml` on page id `33232474`. References use `{33232474, NNNN}` format.

Slot allocation by feature (loose; check the file for the current state):

| Range | Feature |
|---|---|
| 100-109 | Submenu titles (Dynamic War, Dynamic News, etc.) |
| 110-499 | Dynamic War menu labels and tooltips |
| 500-799 | Other feature menu labels |
| 800-1999 | (various) |
| 2000-2459 | Existing pre-Vassal content (news, evolution, infestation, etc.) |
| 2700-2799 | Vassal news + menu labels (current as of F2) |

When adding new strings, claim the next available block and document it here.

---

## 6. X4 hooks we use and what they can / can't do

The full available event vocabulary in vanilla X4 9.0 MD is enormous (see `event_*` grep), but the mod uses a focused subset:

### Lifecycle
- `event_universe_generated` — new game start. Init runs once per universe.
- `event_game_loaded` — every save load. Verifies/re-aliases shared tables, runs migrations, runs feature-specific recovery (e.g., vassal ledger self-heal).
- `event_game_saved` — fires **after** a save is written to disk. The success/failure outcome is known by then. Limited usefulness — cannot modify the just-written file.
- **No pre-save or game-exit hook exists.** State cleanup that must happen before a save writes to disk has to be triggered manually by the player via a menu button. See `docs/vassal_system.md` §16 for the design pattern used to mitigate this.

### Object events
- `event_object_changed_owner` — used by Dynamic News and Vassal conquest trigger for sector ownership changes.
- `event_object_attacked`, `event_object_destroyed`, etc. — used by various ai scripts; not heavily by the main md.
- `event_cue_signalled` — internal mod cue-to-cue messaging.

### Faction events
- `event_faction_*` — vanilla provides these; the mod has not yet had a strong need.

---

## 7. Cross-mdscript library calls

A library in one mdscript can be invoked from another via fully-qualified reference:

```xml
<include_actions ref="md.DynamicUniverse.Library_VassalCreate"/>
```

Used by the menus script (`dynamicuniversemenus.xml`) to call libraries defined in the main script. Variables set by the caller before the include are visible inside the library, and variables the library sets are visible to the caller — same as same-mdscript includes.

---

## 8. Adding a new feature (the template)

Use the F1→F8 build pattern from the Vassal spec:

1. **Write a design spec** in `docs/<feature>_system.md` with sections for scope, data model, mechanics, UI, localization budget, decision log.
2. **Branch** off master as `feat/<feature>`.
3. **Implementation chunks**, each one commit:
   - Data substrate + variables + `LibraryCheck<Feature>Variables` (mod must still load with zero behavior change).
   - Helper libraries.
   - One trigger / mechanic at a time. Each chunk leaves the validator green.
4. **Validator** (`docs/toolchain.md`) must pass after every commit.
5. **In-game smoke test** at the end of the feature.
6. **Merge** to master.

See the Vassal commit history (`git log feat/politics-substrate`) for a worked example.

---

## 9. Conflicts with other mods

The mod uses xpath diffs in `libraries/*.xml`, `aiscripts/*.xml`, `maps/*.xml`, etc. A mod that uses sloppy xpaths (replacing parent nodes wholesale, for instance) will collide. The original README's "Files Adjusted and Possible Conflicts" section enumerates the specific paths and risk levels for each file.

The mod expects:
- `Simple_Menu_API` (Sir Nukes' framework) — required, used for all UI menus
- `ego_dlc_split`, `ego_dlc_terran`, `ego_dlc_pirate`, `ego_dlc_boron`, `ego_dlc_timelines` — optional but supported
- `DeadAir_Eco` — optional; Vassal treasury → God tie-in (chunk 6) functions whether or not Eco is present, since it operates on the mod's own God system

---

## 10. Where to find things in a hurry

- "How does feature X get enabled?" → `$DUDVT.$DU<Feature>Enable` boolean. Toggled by `ExecuteOption_<Feature>Enable` in the menus file.
- "What runs on each interval?" → `Timer<Feature>*` cues. `checkinterval` + `checktime` attributes set the cadence.
- "What's the data model for feature X?" → look in Init for `$DUDVT.$DU<Feature>*` set_value lines. Comment block near the top of each feature section describes the schema.
- "Where do I add a localization string?" → `t/0001.xml`, in the next free slot in §5's allocation table.
- "Why does X behave weirdly across mod versions?" → check the corresponding `LibraryCheck<Feature>Variables` for missing default initializations.
