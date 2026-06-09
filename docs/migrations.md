# Save migrations

One-shot or defensive-fallback code that lets older saves load cleanly under newer mod versions. Catalogued here so it can be retired when no longer needed.

Each entry says: what it does, why it was added, and when it's safe to remove.

## Active migrations

### `LibraryCheckVassalVariables`
**What:** Defensive `do_if (not $DUDVT.$X?)` blocks for every config variable. If a flag is missing on a save, set it to its default; if it exists but is invalid type, reset.
**Why:** Players upgrade across versions; new config knobs land in every chunk.
**Remove when:** Never. This is permanent — it also handles fresh-install init for newly-added options going forward.

### `EventVassalLedgerSelfHeal`
**What:** On `event_game_loaded`, walks `$DUVassalLockLedger` and unlocks any faction in the ledger that has no corresponding entry in `$DUVassalTable`.
**Why:** A pre-9.0 / pre-Safe-Uninstall save could have orphaned `set_faction_relation_locked` state because a vassal entry was removed without unlocking.
**Remove when:** Probably never. Cost is one walk per game load; safer to keep as a defensive backstop.

### `EventVassalReconcilePoliceOnLoad`
**What:** Snapshots `$OriginalPolice` if missing; routes `vassal.policefaction` to `suzerain.policefaction` if Suzerain Presence is enabled and the route differs from current; restores from snapshot if toggle is off.
**Why:** Added when Suzerain Presence + the police-authority transfer shipped. Pre-feature saves had vassal entries with no police snapshot. Pre-Teladi-fix saves had vassals routed to suzerain directly instead of suzerain.policefaction (so Ministry never picked up Teladi-vassal sectors).
**Remove when:** Never (handles the menu-toggle re-application path too — same cue is signalled from the toggle handler).

### `EventVassalTreasuryMigrate` *(new this session)*
**What:** On game load, for each treasury entry: if a stale `$VirtBalance` field exists, copy its value to `$VirtualBalance` (when the latter is missing) then delete `$VirtBalance`.
**Why:** Two field names were used interchangeably across the codebase (`$VirtBalance` in AI auto-gift + fleet gift, `$VirtualBalance` in tribute tick). Saves from before the unification could have stale `$VirtBalance` rows that the runtime no longer reads.
**Remove when:** Once enough time has passed that no player is loading a pre-unification save. Realistically: when this mod ships its first release tag, drop this cue.

### Obsolete-key cleanup in `LibraryCheckVassalVariables`
**What:** `<do_if value="@$X"><remove_value name="$X"/></do_if>` for `$DUWarExhaustionTracker`, `$DUVassalWarExhaustionHoursThreshold`, `$DUVassalWarExhaustionSectorLossThreshold`.
**Why:** War Exhaustion was refactored from hours+sectors heuristic to DW Fatigue. Old saves carry the obsolete variables.
**Remove when:** Same as treasury migrate — first release tag.

### Inline `@$X` and `if X? then ... else default` reads
**What:** Throughout vassal cues, fields that didn't exist in v1 are read with `@` (safe-read returning null) or guarded with `?` (existence check), falling back to a default.
Examples: `@$DUDVT.$DUVassalTable.{V}.$GarrisonExpectedCount`, `@$DUDVT.$DUVassalTable.{V}.$DynamicTribute`, `@$DUDVT.$DUVassalTable.{V}.$LastTributeReview`, `@$DUDVT.$DUVassalTable.{V}.$OriginalPolice`, `@$DUDVT.$DUVassalTable.{V}.$IsKindred` (deleted), etc.
**Why:** Older vassal-table rows don't have these fields. We can't backfill at vassalize time because the entry already exists.
**Remove when:** Each individual safe-read can be removed when *no* save predating the corresponding field's introduction is supported. Practically: when the mod hits a major version that explicitly breaks save compat. Cheaper to keep them than to audit which is safe to drop.

## Removal policy

Note: the v1.0.0 release that accompanied the DeadAir → DynamicUniverse identifier rename was itself a save-compat break (mod id changed from `DeadAir_Scripts` to `dynamic_universe`, all `$DA*` variables renamed to `$DU*`). Saves from the upstream mod do not carry forward. So:

1. `EventVassalTreasuryMigrate` and the obsolete-key cleanup (`$DUWarExhaustionTracker` + siblings in `LibraryCheckVassalVariables`) can be dropped at the next minor — they only matter for pre-v1.0 fork saves.
2. The inline `@` / `?` safe-reads on per-vassal fields can also be dropped, since v1.0 starts a fresh `$DUVassalTable` schema.

In practice we've kept all the above through v1.0.0 itself as a defensive backstop. Drop them in a follow-up release once smoke testing confirms no pre-v1.0 saves are in play.

## How to find migrations in source

Grep for these markers in `md/dynamicuniverse.xml`:
- `EventVassal*Migrate` — explicit migration cues
- `EventVassal*SelfHeal` — self-healing fixups
- `LibraryCheckVassalVariables` — defensive config init
- `<do_if value="@$DUDVT` followed by a `<remove_value>` — obsolete-key removal
