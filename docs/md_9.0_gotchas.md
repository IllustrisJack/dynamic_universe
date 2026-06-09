# X4 9.0 MD scripting gotchas

Patterns we've hit (often more than once) while porting Dynamic Universe to X4 9.0.
Use this as a checklist before writing MD code. If you find a new pitfall, add it here.

## Numeric formatting

X4 has three competing patterns and **9.0 broke the one this codebase kept defaulting to**.

| Pattern | Works on | Breaks on | Verdict |
|---|---|---|---|
| `.cast.{datatype.integer}` | float | already-int values | Avoid; "Property lookup failed" on ints |
| `.formatted.{'%d'}` | (7.x: floats) | 9.0 floats | **Banned.** Use `'%.0f'` if you must format a float, but prefer the next row. |
| `(X)i` inline int-cast | int and float | (none observed) | **Use this.** Works everywhere we display a number. |
| `.formatted.{'%s %Cr'}` | money type | plain ints/floats | Only safe on actual money. Don't apply to `$TributePct`, `$Happiness`, `$TributeTotalVirt`, etc. |

**Rule of thumb:** display integers as `(X)i`, format with units via `'%s Cr'.[(X)i]`. Never call `.formatted` on a value that wasn't created as money/time.

## Existence checks

`@expr?` is **invalid** in 9.0 — `@` (safe-read) and `?` (defined check) can't combine. Pick one:

- `$X?` — boolean: true iff defined and non-null
- `@$X` — safe-read: returns null if undefined
- `if $X? then $X else null` — both at once

We had 6 occurrences of `@$X?` silently parsing as broken in 7.x; 9.0 rejects them outright.

## `<return/>` placement

`<return/>` only works inside `<library purpose="run_actions">`. It is **invalid** in:

- Any `<cue>` actions block
- Any `<library>` without `purpose="run_actions"` (those inline via `<include_actions>`, so return would mean "return from the caller" — undefined)

Pattern when you need early-exit in a regular library or cue:

```xml
<set_value name="$LocSkip" exact="false"/>
<do_if value="GUARD">
  <set_value name="$LocSkip" exact="true"/>
</do_if>
<do_if value="not $LocSkip">
  <!-- the rest of the actions -->
</do_if>
<remove_value name="$LocSkip"/>
```

The original DeadAir code had `<return/>` in a non-`run_actions` library — silently broken since 7.x.

## `<find_station>` / `<find_sector>` `space=` attribute

9.0 strictly requires `space="player.galaxy"` (or a specific sector) on `<find_station>`. Older code that omitted it parsed but produced empty results. Without `space`, 9.0 errors `Required attribute 'space' is missing`.

`<find_sector>` doesn't appear to require it yet but we add it defensively in new code.

## Cross-script `<include_actions>` lookup

When `<include_actions ref="LibFoo"/>` is inside library `X` in script `A`, and `X` is called from script `B` via `<include_actions ref="md.A.X"/>`, the inner `LibFoo` lookup happens in script `B`'s namespace — **not** `A`'s.

If `LibFoo` lives in `A`, this fails with `Property lookup failed: LibFoo`.

**Always fully qualify cross-script library calls:**
```xml
<include_actions ref="md.DynamicUniverse.Library_VassalGarrisonSpawn"/>
```

Even inside the defining script, the qualified form is safe — and survives being included from other scripts.

## `Simple_Menu_API.Make_Slider` is greedy

Sliders **claim the rest of the row from their `$col` to the end**, regardless of declared `$colSpan`. Adjacent cells (buttons, text) in higher columns trigger the lua validator:

```
CWidgetController::UpdateFrame() - Validation error: 'Script error: 'Invalid
cell content [row: N, col: M]. Button defined although excluded by other row
content. E.g. slidercell.''
```

The validator blocks the entire menu from rendering — the menu fails to open with no MD error in the log, only a Lua stack trace.

**Working pattern:** slider must start at `$col=1` and any other widgets must come **after** in cols ≥ slider's `$col + $colSpan`. The `$colSpan` is treated as the slider's drawn width, but the row range it locks is `[$col, end-of-row]`. So put labels (if any) in earlier rows or inside `$prefix`/`$suffix` of the slider.

## `set_faction_relation` on excluded pairs

9.0 silently fails (no error logged) when called on a `set_faction_diplomacy_exclusion`-locked pair. Always guard with `.isdiplomacyexcluded.{otherfaction}` before calling.

Vanilla-locked pairs include: Teladi↔Ministry, Paranid↔HolyOrder, Trinity↔(HolyOrder/Paranid/Buccaneers), Argon↔Antigone, Buccaneers↔(HolyOrder/Paranid).

## Protocol Null cohabitation

When the player has researched and enabled `enable_protocol_null`, vanilla autonomously generates diplomatic events every 40-60 min between random faction pairs. Mod random-DW events on the same pairs double-fire.

Detect with `@md.Diplomacy.Start.ProtocolNull.$ProtocolNullActive` (safe-read — variable doesn't exist if the player hasn't researched it yet).

## Deep-key `<set_value>` writes

Modern MD supports writing deep keys directly:
```xml
<set_value name="$Table.{$Key}.$Subfield" exact="VALUE"/>
```

This works **only after** `$Table.{$Key}` has been set to `table[]` (or another table). Otherwise the intermediate path is null and the write silently no-ops (no error logged, no value set). Initialize the parent table first:

```xml
<set_value name="$Table.{$Key}" exact="table[]"/>
<set_value name="$Table.{$Key}.$Subfield" exact="VALUE"/>
```

## Cue parse-time validation

X4 9.0 evaluates *both branches* of `if … then A else B` at script parse time. So even if at runtime only `B` runs, if `A` references a property that doesn't exist on the type, you get a parse warning every load.

These are **warnings, not errors** — but they pollute the log. Defensive pattern:

```xml
$start=if $X.$Y? then ($X.$Y)i else 50
```

instead of

```xml
$start=if @$X.$Y then $X.$Y.formatted.{'%d'} else 50
```

## Macro existence warnings

`macro.ship_par_m_corvette_01_a_macro` (or similar) can throw `Warning while parsing expression: Property lookup failed` at parse time if the macro isn't indexed at that exact name in the current X4 version. The script still runs and ships still spawn at runtime — these are noisy but not blocking. If you see one, double-check the macro name against `index/macros.xml`.

## `libraries/jobs.xml` — vanilla attribute set matters

X4 9.0 silently rejects jobs that have attributes/elements outside the vanilla shape. Symptoms: the job is in your jobs.xml on disk, but `get_suitable_job(tags=[X])` returns 0 results for that job and the job never appears anywhere in-game. No parse error, no log line — it just isn't loaded.

Attributes we hit that caused silent rejection on XL `<size>` jobs:
- `<modifiers commandeerable="true" rebuild="true"/>` — `rebuild="true"` not used by any vanilla XL patrol job; **drop it**.
- `<environment buildatshipyard="true" preferbuilding="true"/>` — vanilla XL uses only `buildatshipyard="true"`; **drop `preferbuilding`**.
- `<location ... matchextension="false"/>` — vanilla XL jobs don't include this; **drop it**.
- `<loadout><level min="0.7" max="1.0"/></loadout>` — old loadout syntax, replaced in modern vanilla by `<loadout><quantity exact="1.0"/><quality exact="0.85"><variation exact="0.15"/></quality></loadout>`.

When in doubt, find a structurally-similar vanilla XL military patrol job (e.g. `argon_carrier_patrol_xl_sector_phase2` in `libraries/jobs.xml`) and match its attribute set exactly.

**Test loop:** edit jobs.xml → fully close X4 → start X4 → check `get_suitable_job(tags=[your_tag])` count via debug_text. Neither `/refreshmd` (which only reloads `md/*.xml`) nor "Reload Save" reliably re-parses `libraries/*.xml`; only a full X4 process restart is guaranteed.

## `keys.list.count` is deprecated

`<table>.keys.list.count` works but logs a warning every parse: prefer `<table>.keys.count`. Mechanical sweep when we get around to it.

## Useful inspection tools in this repo

- `scripts/tail-mod-log.ps1` — filter X4's debuglog for mod-relevant lines. `-Live` to follow, `-ErrorsOnly` to skim.
- Galactic Politics → Detailed Debug → **Run Self-Check** — writes structured `[DU-CHECK]` block to player logbook.
- `x4-xpath-validator` (Rust, separate tool) — checks our diff xpaths against an extracted vanilla snapshot. See `docs/toolchain.md` for setup.
