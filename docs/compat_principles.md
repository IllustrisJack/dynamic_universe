# Mod compatibility principles

How we write diffs and additions so this mod plays well with other X4 mods. These rules are why our current changes (this fork) touch a smaller surface than the original DeadAir Scripts did, and where the remaining tradeoffs sit.

## Operation preferences

**Prefer additive over modifying.** Order from most compatible to least:

1. `<add sel="X">child</add>` — never collides. Two mods can both add to the same parent.
2. `<replace sel="X/@attr">value</replace>` — collides only with mods that change the same attribute.
3. `<replace sel="X">whole element</replace>` — collides with any mod that changes any attribute or child of X.
4. `<remove sel="X"/>` — most fragile. Other mods may have hooked behavior to X.

## Selector rules

- **Always predicate.** `[@id='specific_id']` not `[1]`. Indexed selectors break the moment any other mod inserts a sibling.
- **Never replace a root node.** No `<replace sel="/jobs">`, no `<replace sel="/factions">`. Wipes every other mod's additions.
- **Match on stable attributes.** `[@id]` is stable. `[@name]` and `[@text]` rot when other mods translate or rename.

## Multi-attribute changes

When a single logical change touches multiple attributes of one element:

- **Wrong:** `<replace sel="X">whole element with all new attrs</replace>` — overwrites any other mod's tweaks to that element.
- **Right:** one `<replace>` per attribute. Each one independent, validator-friendly, compat-friendly.

Sequential `<replace>` operations whose selectors depend on a previous one's *result* (e.g. `[@race='[A, B]']` after another replace just changed `@race`) are forbidden — they're unverifiable and break under merge with other mods.

## Adding new attributes

X4's diff syntax for *adding* an attribute that didn't exist (rather than replacing an existing one's value) is uncertain. The clean ways to express it:

- `<add sel="X" type="@newattr">value</add>` — works in some cases, untested across versions.
- `<replace sel="X">whole element with the new attr</replace>` — works but is overbroad.

When this comes up (rare), we accept the whole-element replace and document the tradeoff in a comment. Currently true for the Terran and Split police job filter swaps.

## Namespacing

Everything we *add* gets a recognizable prefix so other mods can't accidentally collide with our names:

- MD cue names: `Event*`, `Library_*`, `Menu_*` rooted under our mdscript name (`DynamicUniverse`)
- Variable names: `$DU*` (e.g. `$DUDVT`, `$DUMVT`, `$DUVassalTable`)
- Job ids: `da_*` prefix retained from upstream where present; new jobs should use `du_*`
- Ware/area tags: `daxenoncore` and similar `da` legacy tags retained for save compatibility; new tags should use `du_*`
- Construction plan ids / station macros: not currently used; if added, `du_*` prefix
- t-file page: `33232474` (a unique numeric page id)
- t-string ids within that page: dense range starting at 100; no duplicates across the page

## DLC layering

Anything specific to a DLC goes in `extensions/<dlc_id>/...`, not in the base file. Players without that DLC won't see the diff at all, and won't even attempt to validate the xpath. This is also how X4's runtime layers diffs sanely.

## Validator coverage

Our `xpath-validator` Rust tool runs every diff sel against a vanilla snapshot. CI-clean means zero `BROKEN` and zero `PARSE` reports. The engine pre-applies DLC overlays and re-evaluates after each op, so sequential-diff chains and DLC-defined targets both resolve correctly.

## Things we deliberately don't do

- **No `<replace>` of vanilla MD cues** — we don't override vanilla story logic. We add new MD scripts (`md/dynamicuniverse.xml`, `md/dynamicuniversemenus.xml`) that signal vanilla cues.
- **No `<replace>` of vanilla libraries' root** — additions only.
- **No vanilla file we don't touch.** Every diff file we ship is one we have a specific reason to modify.
- **No relation changes between pairs marked `isdiplomacyexcluded`** — silent vanilla failure, we guard for it everywhere.
- **No relation changes against `$DUDynamicWarPermaExcludedFactions` / `DisabledFactions`** — respected across every code path.
