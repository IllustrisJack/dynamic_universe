# Vassal System — Design Spec (F2 v1)

**Status:** v1 implemented and tested. Significant post-v1 extensions in §0 below.
**Branch:** `feat/politics-substrate` (merged) + iterative changes on `main`.

This is the v1 design for the vassal + rebellion system. Section 0 catalogs everything that was changed, added, or rebalanced after v1 went in — the original spec sections (1+) describe the v1 baseline and are kept for historical reference. When the two disagree, **section 0 is authoritative**.

> ### ⚠ Major architectural drift since v1
>
> The **virtual treasury / virt-balance accumulator** described throughout sections 1.x, 2.3, E2, and E2-tie-in was **removed entirely** in a later refactor. Tribute no longer moves credits between virtual ledgers; `$DUFactionTreasury` retains only the live-computed `$Worth` (sum of ship.value + station.value, recomputed per tick). AI gift affordability is gated on suzerain Worth directly (cost ≤ 1% of Worth per fire). The chunk-6 "virtual treasury → God expansion rate" tie-in was never wired in live code.
>
> Tribute is now a happiness lever + player-payout (5 M Cr/tick cap when player is suzerain). For the as-built behavior, see `README.md § Galactic Politics` and §0 entries below.

---

## 0. Post-v1 changes log

All entries are implementation deltas applied after v1 design lock. Restart-required for any MD script change — X4 only re-parses scripts on full process launch, not on save reload. New text strings in `t/0001.xml` likewise need a restart to be visible.

### 0.1 Initial happiness, drain, and rebellion timing rebalance

- **Initial happiness:** 50 → **60** (gives a buffer so brand-new vassalages don't slide into rebellion within a few ticks if a few drains stack)
- **Tribute drain:** `-(pct - 3.0) × 1.5` → `× 0.75` (halved). Default 5% tribute now costs `-1.5/tick` instead of `-3/tick`.
- **Vassal-too-strong penalty:** `-5/tick` → `-3/tick` when V's combined-bloc military ≥ S's military
- **Cultural mismatch penalty:** **new factor** — `-$DUVassalCulturalMismatchPenalty/tick` (default `1.0`) when V's primary race ≠ S's primary race. Splinter factions (Argon/Antigone, Terran/Pioneers, Teladi/Ministry, Paranid/Holy Order/Trinity, Split/FreeSplit) share race so 0 penalty; cross-race vassalages drift hostile over time.
- **Ship-loss penalty:** **new factor** — drop in V's fight-purpose threatscore since last tick contributes `-min(5.0, lossRatio × 50)` once per tick. Cause-agnostic (Xenon, suzerain crossfire, friendly fire all count). Gated by `$DUVassalShipLossHappinessEnable`.
- **Net effect:** rebellions on default-config cross-race player-suzerain vassalages now take ~35-40 minutes instead of ~15.

### 0.2 AI auto-gift loop

`EventVassalHappinessTick` now: when suzerain is AI, vassal happiness post-delta < 40, vassal happiness > 0 (not terminal), and suzerain's virtual treasury balance ≥ gift cost, apply `+5` to delta and deduct `vassal_worth / 2000` virt-Cr from the suzerain's `$DUFactionTreasury.{S}.$VirtBalance`.

Anti-peg safeguards (per user direction "don't peg to max"):
- +5 boost intentionally modest — keeps happiness in the 35-45 range under heavy drain, doesn't push it to 100
- Cost scales with vassal worth so wealthy vassals are expensive to placate
- Skipped if suzerain virt-balance < cost → broke suzerains lose vassals to rebellion (no infinite stabilization)
- Skip threshold of 40 means content vassals don't receive unneeded gifts

Field: `$DUVassalTable.{V}.$LastAIGiftAt` (timestamp, debug only). Master toggle: `$DUVassalAutoGiftEnable` (default true).

### 0.3 Dynamic tribute (policy review model)

Earlier prototype used per-tick smooth drift; replaced with **decision-sized periodic review** for realism:

- Per-vassal `$DynamicTribute` flag, defaulted true for AI suzerains, false for player suzerains (player keeps manual slider). Per-vassal toggle in Manage menu.
- Review cadence: every `$DUVassalTributeReviewMinutes` (default 20) per vassal, tracked via `$DUVassalTable.{V}.$LastTributeReview`.
- Step: **±1.0%** per review (not 0.25%).
- Target band based on current happiness: 8% (>70), 5% (40-70), 2% (<40).
- **War-pressure modifier:** each ongoing suzerain claimspace war beyond the first adds +1% to target. So a suzerain at 3 wars sets target = base + 2. Hard cap 12%.
- **Self-balancing loop:** more wars → higher tribute → faster happiness drain → suzerain spends more virt-Cr on auto-gifts → war chest drains. Aggressive empires pay an internal cost to hold themselves together.

Master toggle: `$DUVassalDynamicTributeEnable` (default true). When off, `$TributePct` stays where it was set.

### 0.4 Broker cost rework

Original formula `1M + (suzMil/1M) × 100k` clamped 1M-500M produced ~1M Cr for almost every faction (regardless of size).

New per-candidate formula:
```
base = 50M
worth_factor = cached_treasury_worth / 10000   (or 25M × owned_sector_count if no treasury cache)
mil_factor = suzerain_threatscore
raw_cost = base + worth_factor + mil_factor
hostility_multiplier:
  rel >= 0.5    → 1.0×
  rel ∈ [0.25, 0.5)  → 1.5×
  rel ∈ [0, 0.25)    → 2.0×
  rel ∈ [-0.25, 0)   → 3.0×
  rel < -0.25        → 5.0×
clamp [50M, 2G]
```

- Eligibility threshold lowered from `relation >= 0.5` to `relation >= -0.5` (cost reflects hostility instead of hard blocking).
- Cap raised from 500M to 2G (megafactions stop hitting cap immediately).

### 0.5 Conquest vassalization improvements

**Triggers extended:**
- Original: only fires when defeated faction is reduced to 1-3 sectors after a sector change.
- Added: **HQ-loss** also triggers regardless of sector count (`find_station factionheadquarters="true" owner=oldOwner` returns null → HQ destroyed/captured).

**Chance scaling** on top of base `$DUVassalConquestChance` (default 35):
- 3 sectors remaining → `base × 1`
- 2 sectors → `base × 1.5`
- 1 sector → `base × 2`
- HQ lost (any sector count) → `+25` absolute
- Clamp 0-100

So a 1-sector + HQ-lost defeat rolls ~95% capitulation chance; a 3-sector defeat with HQ intact stays at 35%.

**Source-tagging:** `$SourceTrigger` now distinguishes `'Conquest'` (territorial reduction) vs `'ConquestHQ'` (HQ destruction). Logbook gets per-trigger text. Manage menu shows the badge.

**Conquest-specific start state:**
- Initial happiness = `$DUVassalConquestInitialHappiness` (default 35) instead of 60 — they just lost territory, they're not happy.
- Grace window `$DUVassalConquestGraceMinutes` (default 30 min) during which rebellion check skips the vassal — gives the AI auto-gift loop time to stabilize them before any rebellion roll fires. Tracked via `$DUVassalTable.{V}.$ConquestGraceUntil`.

### 0.6 Multi-sector garrison + reinforcement

- Original: 1 fleet of 7 ships in HQ sector.
- Now: up to `$DUVassalGarrisonSectorCount` (default 3) fleets, one per vassal-owned sector (HQ first, then arbitrary). Tracked in `$GarrisonSectors`.
- **Reinforcement** in happiness tick: prune destroyed ships from `$GarrisonShips`; if alive count < `$GarrisonExpectedCount × $DUVassalGarrisonReinforceThresholdPct%` (default 50%), dispatch a fresh 7-ship fleet from the suzerain's shipyard. Skipped for player suzerain.

Master toggles: `$DUVassalGarrisonReinforceEnable` (default true), `$DUVassalGarrisonSectorCount` slider (1-8).

### 0.7 Post-vassalize combat cleanup

On vassalize, cancel any active attack orders between the two factions' ships whose `target.owner` is the other side. Prevents in-progress engagements continuing after relation lock. Story safeguards:
- Skip player-owned ships unless player IS the suzerain (don't break agent missions)
- Skip ships with `@$ship.assignedcontrolentity` (mission-controlled)

Master toggle: `$DUVassalCombatCleanupEnable` (default true).

### 0.8 Vassal expeditions

`EventVassalExpeditionTick` runs each DW interval. Per vassal, rolls `$DUVassalExpeditionChance%` (default 20%) to dispatch a fleet against one of the suzerain's currently hostile claimspace targets. Same fleet structure as garrison (1 destroyer + 2 frigates + 4 fighters from suzerain's shipyard). Expires after `$DUVassalExpeditionDurationMinutes` (default 30); cleanup destroys remaining ships.

Tracked as `[shipsList, targetSector, expiresAt]` tuples in `$DUVassalTable.{V}.$Expeditions`. Released vassals also clean up their expedition fleets in `Library_VassalRelease`.

Master toggle: `$DUVassalExpeditionEnable` (default true).

### 0.9 Police authority + Suzerain Presence

On vassalize, transfer vassal's police authority to **suzerain's own policefaction** (not the suzerain directly). This handles vanilla delegation correctly:

| Suzerain | Vassal.policefaction set to |
|---|---|
| Argon (self-polices) | Argon |
| Teladi (delegates to Ministry) | Ministry |
| Alliance (delegates to Paranid) | Paranid |
| Antigone (self-polices) | Antigone |
| Player | _skipped_ (player has no faction police) |
| Pirate without policefaction defined | _skipped_ |

Original police snapshot stored as `$DUVassalTable.{V}.$OriginalPolice` and restored on release/rebellion.

**Combined with jobs.xml diffs** (`libraries/jobs.xml`, `extensions/ego_dlc_terran/libraries/jobs.xml`, `extensions/ego_dlc_boron/libraries/jobs.xml`, `extensions/ego_dlc_split/libraries/jobs.xml`): five isolationist factions' police patrol jobs are swapped from `faction=X relation=self` to `policefaction=X relation=ally comparison=ge`. Affected factions:
- Antigone, Holy Order (base game `libraries/jobs.xml`)
- Terran (`ego_dlc_terran`)
- Boron (`ego_dlc_boron`)
- Zyarth Patriarchy / Split (`ego_dlc_split`)

The diff is permanent but harmless when no vassalages exist (default state has each faction polices only its own sectors so the filter still matches the original scope). When a vassalage sets policefaction to a non-self target, the suzerain's police jobs match those sectors and patrol them automatically — alongside the garrison fleet our mod spawns.

Argon, Paranid, Trinity, Ministry already use the extension pattern in vanilla, so no diff needed.

Pirate factions (Buccaneers, Scaleplate, Yaki), Pioneers, FreeSplit, Hatikvah, Alliance have no `policefaction`-filtered police job in vanilla and no diff was added for them. Vassalages with these as suzerain still transfer authority (so player gains scan rights) but no automatic patrol extension happens. Deliberate flavor: isolationist/outsider suzerains get the garrison fleet only.

Master toggle: `$DUVassalSuzerainPresenceEnable` (default true) gates the police authority transfer at vassalize time and on the reconcile cue.

**Reconcile cue (`EventVassalReconcilePoliceOnLoad`):** fires on `event_game_loaded` and on master-toggle flip. Walks `$DUVassalTable`, snapshots `$OriginalPolice` if missing (pre-feature saves), computes the desired police target under current settings, applies via `set_faction_police` only when different from current. Handles three migration cases: pre-feature saves, pre-fix saves (old direct-suzerain routing), toggle-off restoration.

### 0.10 isdiplomacyexcluded respected everywhere

Vanilla's `set_faction_diplomacy_exclusion` marks lore-locked faction pairs (Argon↔Antigone, Terran↔Pioneers, Teladi↔Ministry, etc.) whose relations must not change. All relation-mutating paths in the mod now check `isdiplomacyexcluded` before calling `set_faction_relation` / `set_faction_police`:

- `Library_VassalCreate` — aborts on excluded pair
- T1 random vassalize candidate filter
- Conquest vassalize candidate filter (in `Library_VassalCreate` downstream)
- Broker menu candidate filter
- `EventVassalRebellionCheck` rebellion relation reset to -0.5
- `EventVassalWarAlignmentTick` both backward (vassal→suzerain-enemy) and forward (suzerain→vassal-enemy) drift
- `LibraryDynamicWarEventExecute` (`$LocDWExclSkip`)
- `EventDynamicWarRelationsFix` loop (capping AI relations at limit)
- Teladi/Ministry sync sweep
- DynamicWarTracking war-fatigue restoration
- Change Relations menu handlers (show player notification on attempted bypass)

DLC story scripts that clear specific exclusions (e.g., Terran Covert Operations clearing `dlc2_1` Terran↔Argon when the arc concludes) naturally unlock new vassalize pairs over time — no mod intervention needed.

### 0.11 Suzerain-defends-vassal alignment (forward war alignment)

Extension of `EventVassalWarAlignmentTick`. After the existing backward alignment (vassal→suzerain-enemy):

For each vassal V with non-player suzerain S, for each claimspace faction F that V is currently hostile to (`relationto.F <= -0.1`): if S is not yet at war with F (`relationto.F > -0.4`) and the S↔F pair isn't lore-locked, drift `S.relationto.F` down by 0.02 per tick toward -0.4 floor. Slow ramp (~2 hours to reach floor from neutral).

Player suzerain skipped — player picks their own wars. Vanilla AI handles the actual combat response once the relation drops.

Models "the suzerain comes to defend their vassal" without forcing immediate war declarations.

### 0.12 Permanent Subordinates documentation

Hardcoded display-only section in Galactic Politics menu above the active vassals list. Currently lists one entry: *Ministry of Finance — police subordinate of Teladi Company*. Gated on both factions being `isactive`. No mechanics — vanilla's `set_faction_diplomacy_exclusion` and Teladi's `policefaction=Ministry` declaration already lock the relationship at engine level.

Lore research narrowed the candidate set: Teladi/Ministry is the only true subordinate per faction descriptions in `t/0001-l044.xml` page 20203. Antigone (page id 301), Alliance (801), Pioneers, etc. are described as independent factions despite using another faction's police. The display section is extensible if future DLC adds more genuine subordinate pairs.

### 0.13 Menu polish

- Tooltip (`$mouseOverText`) on every politics menu row.
- Localization strings 2795-2833 in `t/0001.xml` page 33232474.
- Per-vassal Manage menu shows: Cultural Fit indicator (same race / different race friction), Auto-adjust Tribute toggle, Origin badge (Random / Conquest / Capital Lost / Player Broker / Debug), Conquest Grace countdown when active.
- Master toggles in Galactic Politics: vassal master, garrison sectors slider, garrison reinforcement, reinforce threshold, ship loss penalty, combat cleanup, expeditions, AI auto-gifts, dynamic tribute master, cultural mismatch penalty slider, suzerain presence.

### 0.14 Migrations and pre-existing-save behavior

`LibraryCheckVassalVariables` migrations added for every new config knob from this session. All default-true toggles will be set on first load.

Existing vassal-table entries from older saves are forward-compatible:
- Missing fields are safe-read with `@$X` or `if X? then ... else default` patterns
- `$DynamicTribute` defaults to off for old entries (player can toggle in Manage menu)
- `$GarrisonExpectedCount` / `$GarrisonSectors` missing → no reinforcement (one-time loss until re-vassalize)
- `$LastThreatScore` missing → first tick after load sets baseline, no ship-loss penalty that tick
- `$OriginalPolice` missing → reconcile cue snapshots current value at load
- `$ConquestGraceUntil` missing → no grace; rebellion check runs normally
- `$SourceTrigger` missing → Manage menu shows "Random (Dynamic War)" as fallback

### 0.15 Deferred (logged as tasks for future work)

- **Cooperation station spawn** (#51) — at vassalize time, spawn a suzerain-owned diplomatic-presence station in vassal HQ sector with custom naming. Needs macro selection work for cross-race fallback.
- **Police outsourcing** (#54) — pay another faction to police your sectors for a fee scaling with sector count. Independent of vassalage; pure trade arrangement under its own menu.
- **Validator DLC-merge support** (#8) — current xpath validator can't merge DLC `<diff>` documents into vanilla before checking mod xpaths. Boron/Terran jobs.xml diffs show as false-positive BROKEN in validator output. Runtime works correctly because X4 layers diffs in the right order.

---

## 1. Scope summary

A vassal-suzerain relationship is a directional political bond between two AI factions. The vassal pays virtual tribute, aligns militarily, and loses some autonomy. The suzerain gains virtual wealth (which feeds the God economy expansion rate) and influence. The player can monitor vassal happiness and act on it via gifts and tribute adjustment. Rebellion is the natural exit when happiness collapses, with a combined-vassal-pressure mechanic preventing galactic dominance.

**What's in v1:**
- Politics substrate (vassal-only, directed single-row table)
- Virtual treasury substrate (computed faction worth + accumulator)
- Three vassalization triggers: auto-DW, conquest-driven, player-initiated
- Four mechanical effects: relation lock, virtual tribute, war alignment, suspended expeditions
- Vassal happiness system (5 factors)
- Rebellion as transient event with persistent fallout
- One real-effect tie-in: virtual treasury → God expansion rate
- Player UI: galactic politics overview, gift, tribute slider
- Localization, news events, save migration

**What's deferred:**
- Tributaries (separate political type)
- Banks/loans (separate entity system)
- Player-as-faction integration (F6)
- Tech progression for vassals (F7)
- Breakaway sectors for non-vassal rebellions
- Multiple virtual-treasury tie-ins (Jobs SST, Expedition costs) — only God expansion rate in v1

---

## 2. Data model

### 2.1 Politics table (vassal-only)

```
$DUDVT.$DUVassalTable : table[]    keyed by vassal_faction
    -> {
         $Suzerain          : faction
         $Since             : player.age
         $SourceTrigger     : 'DW' | 'Conquest' | 'PlayerBroker'
         $TributePct        : numeric   # default 5.0; player-adjustable per vassal
         $LastTributePaid   : player.age
         $TributeTotalVirt  : credits   # lifetime virtual tribute, for menus
         $Happiness         : numeric   # 0..100, default 50
         $LastHappinessCalc : player.age
         $WarAlignmentSnapshot : list[faction]   # suzerain's enemies at vassalage start
       }
```

Directed single-row: stored only at `[vassal] → {suzerain, ...}`. Reverse lookup ("who are S's vassals") iterates via helper `Library_PoliticsGetVassalsOf`. Faction count is small (≤15) so O(n) iteration is acceptable.

### 2.2 Rebellion log

```
$DUDVT.$DURebellionLog : table[]    keyed by [rebelling_faction]
    -> {
         $FormerSuzerain  : faction
         $RebelledAt      : player.age
         $CooldownUntil   : player.age   # ~60 min after rebellion
         $Reason          : string       # for menu / news
       }
```

Used for cooldown enforcement (rebelled faction cannot be vassalized again until cooldown expires) and recent-rebellions menu display. Entries older than 24 in-game hours get GC'd.

### 2.3 Virtual treasury

```
$DUDVT.$DUFactionTreasury : table[]    keyed by faction
    -> {
         $Worth          : credits      # cached, recomputed per interval
         $WorthCalcAt    : player.age
         $VirtualBalance : credits      # accumulator: tribute flows in/out here
       }
```

`$Worth` is **derived** (sum of ship values + station values, recomputed every 30 min DW interval).
`$VirtualBalance` is **state** (carries tribute, gifts, etc.; not reset by recompute).

### 2.4 New `$DUDVT` settings

```
$DUDVT.$DUVassalEnable               : bool   default false
$DUDVT.$DUVassalConquestChance       : 35     # T2 trigger probability
$DUDVT.$DUVassalDefaultTributePct    : 5.0    # default % at vassalage creation
$DUDVT.$DUVassalTreasuryGodTieIn     : bool   default true
$DUDVT.$DUVassalDetailedDebug        : bool   default false
$DUDVT.$DUVassalCooldownMinutes      : 60
```

---

## 3. Triggers — how vassalage is created

### T1. Auto via Dynamic War event

Add a new event type `Vassalize` to the existing DW weighted roll alongside Besties / BigBoost / SmallBoost / SmallBlow / BigBlow / Nemesis / Nothing.

- New weight slot in `$DUDVT.$DUDynamicWarEventWeights` (now 8 slots, default weight 4).
- Candidate filter at event-time:
  - Both factions adjacent (share ≥1 border sector)
  - Stronger in top-3 by `militarystrength`, weaker in bottom-3
  - Current relation ≥ +0.25
  - Neither already in `$DUVassalTable`
  - Neither in `$DUPoliticsExcludedFactions`
  - Weaker faction not in `$DURebellionLog` cooldown
- If no candidate pair: event silently skipped, no log spam.

### T2. Conquest-driven

Hook the existing `event_sector_changed_owner` listener (Dynamic News already subscribes).

After ownership transfer A←B:
- Check via `signal_cue_instantly` deferred to next frame (avoids race conditions during X4's ownership update).
- If B's sector count ∈ [1, 3] AND B not already in `$DUVassalTable` AND B not in cooldown AND A is not a vassal of any of B's enemies:
- Roll `random.value < $DUVassalConquestChance` (default 35%).
- On success: vassalize B under A.

### T3. Player-initiated via menu

New menu entry: **DA Dynamic Universe → Politics → Broker Vassalage**.

- Player selects suzerain and vassal from dropdowns.
- Gate: relation between the two ≥ +0.5.
- Cost: `1_000_000 + (suzerain.militarystrength / 10_000) * 100_000` credits + 1 favor of each faction.
- No success roll — if you can pay, it happens.
- Faction.player filtered out of dropdowns (F6 dependency).

---

## 4. Mechanical effects

### E1. Relation lock at ally level
- Append `[vassal, suzerain]` to `$DUDynamicWarLockedRelationFactions` (existing mod infra).
- Force relation to +0.5 at vassalage creation.
- DW pipeline already respects the locked list.

### E2. Virtual tribute payment
- Per DW interval, transfer `$TributePct%` of vassal's `$DUFactionTreasury.$Worth` from vassal's `$VirtualBalance` to suzerain's `$VirtualBalance`.
- Increment `$TributeTotalVirt` on the vassal table row.
- Clamp transfer if vassal's virtual balance would go below `-Worth * 0.5` (prevents catastrophic debt spirals).
- **No effect on real X4 economy.** Real impact comes via E2-tie-in below.

### E2-tie-in. Virtual treasury → God expansion rate
- The God system (`$DUDVT.$DUGodEnable`) already manages faction module expansion.
- When God evaluates a faction for expansion: read `$DUFactionTreasury.$VirtualBalance`.
- If `$VirtualBalance > $Worth * 0.5`: God's per-cycle build chance for this faction +25%.
- If `$VirtualBalance < 0`: God's per-cycle build chance for this faction -25%.
- This makes virtual tribute matter: suzerain accumulates → suzerain expands faster → suzerain gets richer (bounded by combined-vassal-pressure rebellion).

### E3. War alignment (pressure, not force)
- At vassalage creation: snapshot suzerain's enemies (relation ≤ -0.1) into `$WarAlignmentSnapshot`.
- Per DW interval: for each enemy in snapshot, push vassal's relation with that enemy down by 0.02, capped at -0.4 (not full enemy).
- Vassal cannot enter a positive DW event (Besties, BigBoost) toward a current suzerain-enemy.
- This is *pressure* — other events can counteract.

### E4. Suspended expeditions
- Jobs Expeditions target-selection filter: skip suzerain and suzerain's allies.
- Bonus: vassal expeditions against suzerain's enemies get +1 quota in addition to base.
- Single-spot change in existing Expeditions code path.

---

## 5. Happiness system

Per-vassal score 0–100, default 50, recomputed each DW interval.

### 5.1 Five factors

| Factor | Δ Happiness per interval | Notes |
|---|---|---|
| **Tribute pressure** | `-($TributePct - 3) * 1.5` | At 5% (default): -3/interval. At 3%: 0/interval (player-set neutral). At 10%: -10.5/interval. |
| **Time as vassal** | `-min(2, hours_as_vassal / 30)` | Slow erosion; never more than -2/interval. Acclimatisation effect could be added later. |
| **Suzerain protection** | `-3 per vassal sector lost in last 60 min` | Failed-protector grievance. Read from existing sector-change tracking. |
| **Combined vassal pressure** | `+ if combined < suzerain.military, - if greater` | When combined vassal military matches suzerain: -5/interval. When combined ≤ 50% suzerain: +3/interval. |
| **Forced wars** | `-2 per active suzerain-enemy that vassal traditionally allied with` | Cultural friction. "Traditional ally" = faction-primary-race match. |

Sum capped: `Δ ∈ [-15, +5] per interval` to prevent runaway swings.

### 5.2 Player happiness levers

- **Send Gift** (menu): one-shot `+10` happiness on chosen vassal. Costs player `5M credits + 1 favor` with that vassal. Once per 6 in-game hours per vassal.
- **Adjust Tribute** (menu slider): per-vassal `$TributePct` adjustable in 1% steps from 0% to 15%. Setting below 3% pushes happiness up (formula above); above 5% pushes down.

### 5.3 Happiness gates events

- `Happiness ≥ 70`: "Loyal" — happiness erosion factors halved. Tribute always paid in full.
- `30 ≤ Happiness < 70`: "Content" — default behaviour.
- `Happiness < 30`: "Discontent" — rebellion check active each interval.

---

## 6. Rebellion mechanic

Vassal-only in v1. Triggered by happiness + combined-pressure check.

### 6.1 Per-interval check (each vassal whose `Happiness < 30`)

```
individual_chance =
      ((30 - Happiness) / 30) * 30%         # 0..30% based on how unhappy
    + 15% if vassal lost >= 2 sectors in last 60 min
    + 20% if vassal.militarystrength >= suzerain.militarystrength

combined_chance =
    let combined = sum(v.militarystrength for v in suzerain.vassals)
    if combined >= suzerain.militarystrength:
        scale = (combined / suzerain.militarystrength) - 1.0
        return min(40%, scale * 25%)
    else:
        return 0

total = min(60%, individual_chance + combined_chance)
if random < total: REBELLION FIRES
```

### 6.2 Rebellion effects (all of)
- Clear vassal row.
- Set former-vassal ↔ suzerain relation to **-0.5**.
- Insert into `$DURebellionLog` with `$CooldownUntil = player.age + $DUVassalCooldownMinutes`.
- Fire a Dynamic War "Big Blow" event between them (one-shot war intensification).
- Player notification + news ("X has rebelled against Y. Suzerain too weak / too oppressive / [reason].").
- Logbook entry.

### 6.3 Cooldown rules
- During cooldown, the rebelled faction is filtered out of T1 / T2 / T3 candidate lists.
- Cooldown rows older than 24 in-game hours get GC'd from `$DURebellionLog`.

---

## 7. Exit conditions (in addition to rebellion)

| Exit | Trigger | Effect |
|---|---|---|
| **X1. Suzerain destroyed** | Suzerain's sector count drops to 0 | Clear vassal row, fire news "X is now independent — Y has fallen". |
| **X1a. Suzerain near-destroyed** | Suzerain has ≤ 2 sectors AND lost ≥ 1 in last DW interval | Pre-emptive release: clear vassal row before suzerain dies (prevents vassal going down with sinking ship). |
| **X2. Suzerain releases (DW event)** | New `ReleaseVassal` event in DW roll, weight 2 | Clear vassal row, +0.1 relation, news. |
| **X2-menu. Suzerain releases (player broker)** | Menu action | Cost ~50% of T3 cost. |
| **X3. Rebellion** | Per-interval check, see §6 | See §6.2. |
| **X4. Suzerain attacks vassal** | A DW Big Blow / Nemesis event fires with both as parties | Intercepted before applying: relation pushed to -0.3, vassal row cleared, news "Vassalage broken!". |
| **X5. Suzerain becomes a vassal** | If a faction that is already someone's suzerain is selected as a vassalization target | The new vassalage is **rejected**. The existing relationship stays intact. (Spec originally said "release existing vassals"; implementation rejects instead — see decision log row 2026-06-08 reject-vs-cascade.) |

---

## 8. Player UI

### 8.1 New menu: DA Galactic Politics
Top-level menu under DA Dynamic Universe.

**Section A — Active Vassalages**
- One row per active vassal: vassal name | suzerain name | happiness bar | tribute % | time as vassal | "Manage" button.

**Section B — Recent Rebellions**
- Read `$DURebellionLog`, show last 5: faction | former suzerain | when | reason.

**Section C — Broker Actions**
- "Broker Vassalage" — T3 above.
- "Broker Release" — X2-menu.

### 8.2 Per-vassal Manage page
- Send Gift button.
- Tribute % slider (0-15%).
- Happiness factor breakdown (read-only, shows each contribution).
- Lifetime virtual tribute counter.

### 8.3 Existing menus to extend
- **DA Dynamic War options**: add `Vassalize` and `ReleaseVassal` weight sliders.
- **DA Faction details menu** (if exists): show vassal status.

---

## 9. Localization budget

Mod uses page id `33232474`. Reserve a contiguous block for vassal/politics:

| ID range | Purpose |
|---|---|
| 2700–2799 | Menu labels (Galactic Politics, Manage, etc.) |
| 2800–2899 | News event templates (vassalization, release, rebellion) |
| 2900–2999 | Tooltip / hover text |
| 3000–3099 | Logbook entry titles |

Allocate as needed during implementation.

---

## 10. Save migration

Extend `VerifyVariablesExist` (existing pattern):
- New `<include_actions ref="LibraryCheckVassalVariables"/>` block.
- Initialize all `$DUVassalTable`, `$DURebellionLog`, `$DUFactionTreasury` tables if missing.
- Initialize all `$DUDVT.$DUVassal*` settings to defaults if missing.
- Each missing var emits `MOD: DADynamicUniverse -- ERROR -- ...` to debug log per existing convention.

---

## 11. Implementation order

Each chunk = one git commit. Sized to be testable in isolation.

1. **Data substrate** — Add data-model entries to Init, add `LibraryCheckVassalVariables`, hook into VerifyVariablesExist. No mechanics yet. Code loads cleanly.
2. **Helper cues** — `Library_PoliticsGetVassalsOf`, `Library_TreasuryRecomputeWorth`, etc. Debug menu showing tables.
3. **T1 (auto-DW) + X1 (suzerain destroyed)** — minimum viable vassalization + cleanest exit.
4. **E1 (relation lock) + E4 (expedition filter)** — pure substrate-respecting effects, no UI changes.
5. **E2 + treasury substrate** — virtual tribute flowing.
6. **E2-tie-in (God expansion rate)** — one real effect proves the system works.
7. **E3 (war alignment pressure)**.
8. **Happiness substrate (§5)** — score computed, no consequences yet.
9. **Rebellion (§6) + cooldown**.
10. **T2 (conquest-driven)**.
11. **T3 (player-initiated) + Broker menu**.
12. **Galactic Politics overview menu (§8.1)**.
13. **Per-vassal Manage menu (§8.2) + Send Gift + Tribute slider**.
14. **X2 / X2-menu (release events)**, **X4 (attack interception)**, **X1a (pre-emptive release)**, **X5 (recursive vassal cleanup)**.
15. **News events + localization (§9)**.
16. **DetailedDebug logging passes — verify every state transition logs cleanly**.

Each commit must leave the mod loadable. The xpath validator should pass on every commit.

---

## 12. Open decisions deferred

- Exact balance numbers (happiness deltas, cooldown duration, T2 probability) will likely need tuning after in-game testing. Treat the numbers in this doc as v1 starting points.
- "Traditional ally" definition (§5 forced-wars factor) currently = same primary race. Could be replaced with explicit allegiance table later.
- Virtual treasury GC: do we ever zero out balances? Default: no, balances persist for history.

---

## 13. Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-06-08 | Vassals-only v1, tributaries deferred | YAGNI; user wants vassals working before extending |
| 2026-06-08 | Directed single-row politics table | Simpler invariants; reverse lookup acceptable at faction scale |
| 2026-06-08 | Uncapped vassals per suzerain | User wants pure simulation; combined-vassal-pressure rebellion is the natural cap |
| 2026-06-08 | 35% conquest-driven probability | Suggested default; tunable |
| 2026-06-08 | Tribute = % of computed faction worth | AI factions don't have real credit balances in X4; virtualize via worth |
| 2026-06-08 | Virtual treasury tie-in = God expansion rate | Wealth → economic growth is the most natural mapping; user choice |
| 2026-06-08 | β scope: substrate + one tie-in + player gift/tribute | Right balance between cheap and complete |
| 2026-06-08 | Happiness system with 5 factors | User wants strategy-game style happy/unhappy vassal mechanics |
| 2026-06-08 | Rebellion fires from happiness + combined pressure | Anti-snowball: cannot hold many vassals without proportional military |
| 2026-06-08 | Rebellion is transient event, not persistent state | Simpler than maintaining a "rebelling" type; cooldown captures fallout |
| 2026-06-08 | X5 = reject, not cascade-release | Cascade-release made one new vassalage trigger many surprise releases; rejecting feels more predictable to the player. Existing suzerains are too important to subordinate further. |
| 2026-06-08 | EventVassalCheckExits also handles vassal destroyed | Symmetry with X1 (suzerain destroyed); avoids stale rows with no sectors. |
| 2026-06-08 | War alignment snapshot excludes faction.player | Until F6 player-as-faction ships, player must not be auto-drifted toward by vassals. |
| 2026-06-08 | Auto-DW vassalize depends on DW timer | Documented via tooltip on the enable button; T2 and T3 work independently. |
| 2026-06-08 | T1/T2/T3 all respect $DUDynamicWarPermaExcludedFactions + $DUDynamicWarDisabledFactions | Single source of truth for "factions the player doesn't want involved." Story-faction concerns are addressed by the player adding the relevant factions to DW's existing Ignored Factions menu — no separate vassal exclusion list. |

## 14. Implementation divergences from spec

- **X2 auto-release:** implemented as a 3% chance per DW interval inside EventVassalCheckExits rather than as a 9th weight slot in the DW event roll. Avoids bloating the existing weighted roll; effective rate is similar.
- **X1a pre-emptive release:** fires whenever suzerain has ≤ 2 sectors (chunk 14), not coupled with the "lost in last DW interval" clause from §7 X1a. Less strict, but suzerains rarely sit at 2 sectors for long without further loss.
- **Adjacency check:** deferred. T1 / T2 do not currently require suzerain–vassal sector adjacency. Vassalage across the galaxy is permitted in v1; revisit if it feels wrong in testing.
- **War alignment vs. relation lock interaction:** the vassal is globally relation-locked via `set_faction_relation_locked`. Whether MD `set_faction_relation` from the war-alignment tick bypasses that lock is unverified — needs smoke-test confirmation. If blocked, the war-alignment factor still influences happiness via factor 5 (cultural friction) but actual relation drift won't happen.
- **Source trigger naming:** `$SourceTrigger` stored as 'DW' (chunk 3), 'Conquest' (chunk 10), or 'PlayerBroker' (chunk 11).
- **Broker cost:** charges credits only (1M base + (suzMil/10k)*100k). Spec §3.3 also required 1 favor of each faction; deferred since the favor model needs design work for the player-broker path. Player at any relation ≥ +0.5 between the two factions can pay credits to broker.
- **Manage menu fields:** spec §8.2 mentions a happiness factor breakdown read-only display. v1 just shows the absolute happiness number; per-factor breakdown deferred.
- **Treasury display:** the spec didn't call out a virtual treasury balance/worth display in the manage menu. v1 omits it; lifetime tribute total is shown instead.

## 15. Enable/disable lifecycle

The `$DUVassalEnable` toggle is **pure pause/resume**. It does not clean up state.

- **Disable while vassals exist:** active vassal rows freeze in place. Timers stop firing. The relation lock on each vassal (`set_faction_relation_locked`) **persists** because it is X4-native state, not mod state. Expedition filter continues to apply for as long as a vassal row exists in `$DUVassalTable`.
- **Re-enable later:** timers resume. Existing vassals start receiving tribute/happiness/rebellion checks again.
- **Cleanup is explicit:** a separate **Release All Vassals (N)** button in the politics overview menu (visible only when vassals exist, *regardless* of enable state) walks every row in `$DUVassalTable` and runs `Library_VassalRelease` against each. That unlocks the X4 relation lock, fires the release news, and clears the row. Use this before uninstalling the mod to avoid leaving orphaned relation locks in the save.

**Convention rationale:** the existing mod features (Dynamic War, Evolution, Fill, …) treat enable toggles as pure switches. Vassal system follows the same convention so the menu behavior is predictable. The dedicated cleanup button captures the destructive intent without conflating it with the timer toggle.

## 16. Uninstall safety

X4 saves can run for thousands of hours; the mod **must not** leave persistent state that other systems can't reverse.

### What persists vs disappears when the mod is uninstalled

| State | Persists? | Recoverable? |
|---|---|---|
| MD cues, libraries, event listeners | No, gone with the script | n/a |
| `md.DynamicUniverse.$DUDVT.*` saved variables | Yes, as orphaned blobs in the save | Self-evident, inert |
| News/logbook entries already written | Yes, as static text | No harm |
| `set_faction_relation_locked` we applied | **Yes, persist on faction objects indefinitely** | **No** — no code remains to unlock them |
| `$DUJobsEXPEnemiesTable` modifications | No (same mod) | n/a |
| Sector listener subscriptions | No (cues gone) | n/a |

### The only real risk: orphaned relation locks

`set_faction_relation_locked faction=X locked=true` writes to X4's native faction state. It survives the mod's removal. Once our code is gone, **no path exists to unlock those factions** from inside the save. They stay locked for the rest of that save's lifetime.

The player wouldn't see an obvious break — relations on locked factions just silently won't change anymore, by any system. This is the kind of subtle corruption that catches up to a player hundreds of hours later.

### Mitigations shipped

1. **In-menu warning** (id 2738) appears whenever `$DUVassalTable` is non-empty:
   > "Active vassals leave persistent faction relation locks. Release all before uninstalling this mod."
2. **Two cleanup buttons** in the politics overview, both visible only when vassals exist, *regardless* of `$DUVassalEnable` state:
   - **Release All Vassals (N):** unlocks each vassal via `Library_VassalRelease`, clears `$DUVassalTable`. Keeps the system enabled.
   - **Safe Uninstall:** does Release All, then sets `$DUVassalEnable = false`, clears `$DURebellionLog` and `$DUFactionTreasury`, writes a logbook confirmation. Leaves the mod in a state safe to remove.
3. **README guidance** (see project README) describing the proper uninstall procedure.

### Self-healing ledger

`$DUDVT.$DUVassalLockLedger` is a flat list of every faction we have called `set_faction_relation_locked(true)` on. It survives save/load and is the only state that lets us distinguish "our orphan locks" from "another mod's locks."

- `Library_VassalCreate` appends to the ledger when it applies a lock.
- `Library_VassalRelease` removes from the ledger when it unlocks.
- `EventVassalLedgerSelfHeal` fires on `event_game_loaded`. For each faction in the ledger, if it is no longer in `$DUVassalTable`, we unlock it and remove it from the ledger.

This catches:
- **Reinstall after a forgotten cleanup:** X4 preserves orphaned MD vars across uninstall/reinstall for absent extensions. When the mod returns, the ledger reflects the locks we left behind; the self-heal pass unlocks them since no vassal row backs them up.
- **Manual save edits that wiped `$DUVassalTable`:** ledger still names the factions we locked; self-heal recovers them.
- **Mod-version skips where vassal state was migrated away:** self-heal cleans up.

### What we still cannot fix

The "player uninstalls and never reinstalls" path. Without our code in the save, no path remains to unlock those factions. This is the residual gap that the in-menu warning and **Safe Uninstall** button exist to prevent. Realistically most users uninstall by disabling the extension in X4's launcher, not by deleting the folder; re-enabling triggers the self-heal.

### What we deliberately do *not* do

- **Auto-unlock unknown locked factions:** we only unlock factions our ledger names. Other mods may have locked the same faction for their own reasons; we don't touch theirs.
- **Pre-uninstall detection hook:** X4 provides no signal that a mod is being unloaded. The player must trigger cleanup manually.
- **Periodic auto-cleanup of "stale" vassals during play:** the X1 exit logic and `$DURebellionLog.$CooldownUntil` GC handle in-mod lifecycle; the ledger self-heal only runs on game load.
