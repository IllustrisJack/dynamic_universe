# Test plan — Dynamic Universe vassal system

Goal: exercise every gameplay path in minutes, not hours. All test entry points are under **Mod Menu → Galactic Politics**. Turn on **Detailed Debug** at the top of the panel to expose the debug grid + per-vassal debug row.

After most actions, click **Run Self-Check** (the wide blue button at the very bottom) and paste the `[DU-CHECK]` block from the player logbook into a message for verification.

## Logs

While testing, run in a separate PowerShell window from the repo root:

```powershell
.\scripts\tail-mod-log.ps1 -Live
```

Or check after the fact with `-Tail 500` and `-ErrorsOnly` flags.

## Quick test loop (5 min, covers ~80% of paths)

1. **Self-Check** baseline. Expect 0 PASS / 0 FAIL on a fresh save.
2. **Make Me Suzerain** — instantly makes the most-friendly major AI faction your vassal. Expect a notification + log entry.
3. **Self-Check** again. Expect 1 PASS for that vassal.
4. **Force Tribute Tick** — should immediately credit you ~½ of the vassal's computed tribute as real Cr. Watch your wallet.
5. **Pay Tribute** (per-vassal button in their row) — same payout, scoped to that one vassal.
6. **Force Rebel** (per-vassal button) — vassal rebels. Up to 2 supporter factions spawn 7-ship fleets each. Garrison ships (if any spawned for AI suzerain — none for player suzerain) defect.
7. **Trigger DW Event Now** during the 1-hour grace window. Confirm the rebel is *not* picked for negative DW events.
8. **Reset Cooldowns/Grace** to skip the cooldown for repeated tests.

## Feature-by-feature

### T1 — Random DW Vassalize (AI ↔ AI)

- **Force Vassalize Now** — random pick among eligible AI pairs. May produce no vassalage if no pair has rel ≥ 0.25 + isn't excluded. Toggle Detailed Debug to see rejection reasons in the log.

### T2 — Conquest-driven Vassalize

- Manually move a faction's last 2–3 sectors to a stronger faction (use vanilla Set Owner cheats or wait for natural war). Conquest-roll fires on sector ownership change.

### T3 — Player Broker (AI ↔ AI)

- **Submenu: Broker Vassalage** → pick a faction as suzerain. Eligible candidates show "Broker Vassalage (cost)". Cost capped to 1M–500M Cr. Click → vassalage forms instantly.

### T4 — Player as Suzerain (debug path)

- **Make Me Suzerain** button instantly grabs the most-friendly major. No agent mission, no cost — pure test path.

### T5 — Player as Suzerain (vanilla diplomacy)

- Open vanilla diplomacy panel (not the mod menu — vanilla, accessed via agent). Pick a friendly major faction's HQ. **Propose Vassalage** under Negotiation. Costs 50 influence + 50M Cr. 1-hour mission, 30% success.

### Tribute flow

- AI suzerain: tribute is theatre (virtual balance, no real currency moves).
- Player suzerain: half the computed tribute is paid as real Cr, capped at 50M per tick.

### Rebellion

- Happiness slider 0–100 sets directly. Below 30 = eligible for the periodic rebellion roll. **Force Rebel** sets to 0 and immediately runs the roll.
- Garrison ships transfer to the rebel (AI suzerain path). Up to 2 most-hostile-to-former-suzerain claimspace factions dispatch their own 7-ship fleets in support, owned by themselves.
- Rebel gets a Grace window (default 60 min) during which DW skips them in random negative events.

### Garrison spawning

- **Spawn Test Garrison Here** spawns 7 ships in the player's current sector for that sector's owner. Uses race-keyed macros (argon/paranid/teladi/split/terran/boron/xenon/khaak); falls back to argon for unknown races. Anchors within 5km of a nearby station, or the player.
- For real vassalages: spawned in the vassal's first owned sector, owned by the suzerain, Patrol order in that sector.

### Exits

- **Release** button (per-vassal) — normal release.
- **Release All Vassals** — bulk release for all current vassals.
- **Safe Uninstall** — bulk release, disables the system, clears all related tables. Run before removing the mod.
- Suzerain destroyed (vassal frees itself), Vassal destroyed (entry removed), Suzerain near-collapse (≤ 2 sectors → auto release), Random 3% per tick (auto release roll).

## Compat guards (9.0)

- **Diplomacy exclusion** — Teladi↔Ministry, Paranid↔HolyOrder etc. are skipped silently by DW + vassal-create + broker menu (vanilla locks).
- **Protocol Null** — when active and `$DADynamicWarRespectProtocolNull` is true (default), DW random event picker short-circuits to avoid dueling with vanilla's autonomous event generator.

## Reset / cleanup buttons

| Button | Effect |
|---|---|
| Reset Cooldowns/Grace | Zero `$CooldownUntil` and `$GraceUntil` on every rebellion log entry |
| Clear Treasury Data | Wipe `$DAFactionTreasury` (resets all virtual balances + worth caches) |
| Clear Rebellion Log | Wipe `$DARebellionLog` |
| Dump State to Logbook | Full structured dump of vassal table, rebellion log, treasury |

## Known gotchas

- `Force Vassalize Now` needs ≥ 4 eligible factions in claimspace AND a pair with relation ≥ +0.25. On heavily-warred saves it can produce 0 vassals — enable Detailed Debug to see why.
- Galactic Politics menu only refreshes between clicks. If a state change isn't visible, click a different submenu link and come back.
- Save/load mid-test: MD scripts re-parse on full process restart only. A regular save→load reuses the loaded script.
- Garrison ships are owned by the suzerain (for AI cases). They keep their loyalty even if you reload — only relevant if you're brokering vassalages between hostile-to-you factions.
