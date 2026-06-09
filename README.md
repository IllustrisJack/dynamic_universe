# Dynamic Universe

> **Fork notice (2026-06-08):** This is a continued fork of DeadAir's "Dynamic Universe" / "Deadair Scripts" by IllustrisJack. The original was released under GPL-3 with the author's blessing to continue the work (see his retirement note below). Significant modifications since the original include X4 9.0 compatibility, a new Vassal System (F2), an XPath validator toolchain, and various edge-case hardening. See `git log` for the full change history and `docs/` for design specs.
>
> The internal mod ID (`DeadAir_Scripts`) and folder name (`deadair_scripts`) are intentionally **unchanged** so that existing save games and other mods referencing the original ID (notably DeadAir Eco) continue to work without modification.

## Original author's retirement note (2025-09-23)
> I have decided to completely retire from X4 Modding. I have added licenses to Eco, Scripts, and DeadTater if any persons are interested in using, modifying, or continuing my works. Thank you for all the support and interest in my work over these years.

## Dynamic Universe
Collection of scripts that aim to reduce the static nature of X4 Foundations and expand the sandbox experience.

**Active modules in this fork:** Dynamic War, Dynamic News, Galactic Politics (Vassal System — new in this fork).

**Removed entirely (no longer in codebase):** Jobs Expeditions (DAJobsEXP), Jobs Smart Sector Tags (DAJobsSST), Evolution, Fill, the original mass-jobs library — full deletion via the cleanup commits.

**Still in codebase but hidden from the mod menu:** Gate, God, Trader Profit, Infestation, Blueprint Analysis. Their `$DA*Enable` flags default to `false` so the mechanics are inert. Information Menus and Blueprint Analysis are planned as separate companion mods rather than being re-surfaced here.
## Menu Option Information
- Most menu entries will display text that may help understand the option or reason when hovered over.
## Dynamic War
- Scripted events at set intervals that change relations between two AI factions. The stronger a faction is, the more enemies it will likely have. The weaker a faction is, the more friends it will likely have.
- Uses the following factors to determine factions selected for event: Accrued chance from times not selected, Military strength, Sectors owned, Primary Race, Current Relations, and Shared Allies/Enemies Count.
- Adjustable interval, event weight, misc factors, and ignored factions.
- Relation change script can be disabled.
- Allows locking / unlocking relations for factions.
- Adds menus for improving or decreasing relations between factions.
- Can earn "favors" from factions that player has 20+ relation with for free relation changes.
- Has optional script that limits positive relation level between two factions to avoid them meeting the "self" requirement for job locations.
- Events for Dynamic War include: Best Friends (Instant max relations), Big Boost (+15 relation), Small Boost (+5 relation), Small Blow (-5 relation), Big Blow (-15 relation), and Nemesis (Instant max negative relations).
## Dynamic News
- Collects information from included scripts and events from around the galaxy to provide player with additional information.
- Supported events include: Major station destroyed, Economic station expanded, Economic station started, and Sector changed ownership.
- Outputs news events at adjustable interval and combines multiple reports per faction to avoid spam.
- Can enable/disable the script, notifications, logbook entries, and the recent news database.
## Blueprint Analysis
- Inspired by Jack the Strippers mod of the same name. Permission to rework and continue mod granted by author.
- Allows scanning of station modules and ships to gain blueprints.
- User adjustable settings for number of scans required for blueprint unlock.
- Player owned ships performing police behaviour grant credit for scans as well.
- Scan progress is affected by level of scanner on ship. Generic scanner grants one, police scanner grants two, etc.
## Vassal System

Off by default. Switch it on under Mod Menu → Galactic Politics. Once on, vassalages start forming three ways.

The first is a Dynamic War roll. On each DW interval the system sorts every claimspace faction by military strength and considers pairs drawn from the top three against the bottom three. If the top faction holds at least +0.25 relation with the bottom and the pair isn't diplomacy-excluded by vanilla (the lore locks — Argon↔Antigone, Terran↔Pioneers, Teladi↔Ministry, Trinity↔Holy Order/Paranid/Buccaneers, etc.), the pair is eligible. One is picked at random and the vassalage forms.

The second is conquest. Whenever a sector changes owner and the loser ends up with three or fewer sectors, the system rolls against the Conquest Chance setting (35% default) and turns the loser into a vassal of the conqueror instead of letting them collapse. This is what keeps late-game maps from rotting into a Xenon-and-Argon two-faction wasteland.

The third is the player, via Galactic Politics → Broker Vassalage. You pick a candidate suzerain and the menu lists potential vassals you can buy a vassalage into. Cost scales with the candidate vassal's worth (0.01% of its computed value) or its sector count when no treasury reading exists yet, plus a chunk for the suzerain's military. A friendly pair sits around 50M Cr; a hostile-leaning pair gets multiplied up to 5× and is capped at 2G total. The old +0.5 minimum relation gate is gone — anything down to -0.5 relation can be brokered, the math just costs more the worse the relation is.

When a vassalage forms, the suzerain's relation to the vassal is set to +1.0 and locked. Any active attack orders between the two factions get cancelled so the new "allies" stop shooting each other, with the exception of player-controlled ships currently bound to a mission control entity — those are left alone so vanilla story sequences don't break. The vassal's HQ sector plus up to two more of its owned sectors each get a garrison fleet: one destroyer, two frigates, four fighters, race-matched to the suzerain and built from the appropriate faction's ship line (Yaki and Pirate factions use their distinct hulls; the rest share primary-race designs). These ships spawn at the suzerain's actual shipyard or wharf — not at the vassal's HQ — and fly to the vassal sector under a Patrol order. If the suzerain has no shipbuilding capability anywhere, the spawn falls back to materializing in the target sector. Sector count and reinforcement threshold are both configurable; when alive garrison count drops below 50% of original, a fresh fleet dispatches from the shipyard on the next happiness tick.

Tribute runs every DW interval. X4's AI factions don't actually track credits internally, so tribute is a virtual ledger maintained by the mod. The vassal's "worth" is recomputed from its ships and stations, the tribute percentage (5% default) of that figure is added to the suzerain's virtual balance and subtracted from the vassal's. When the player is the suzerain, half the computed tribute is paid out as real credits, capped at 50M per tick so it doesn't break the economy. The player can't be vassalized.

The tribute percentage is dynamic for AI suzerains, but in policy moves rather than a continuous dial. Every ~20 minutes per vassal the suzerain reviews the rate and steps it ±1% toward a target. The base target is 5% in the middle band (happiness 40-70), 8% above 70 (squeeze a content vassal), 2% below 40 (loosen the leash on a restless one). On top of that, each ongoing claimspace war the suzerain is currently fighting beyond the first adds +1% to the target — a warring suzerain demands more from its vassals to feed the war effort. The hard cap is 12%. The whole loop is self-balancing: more wars → higher tribute → faster happiness drain → suzerain has to spend more virtual credits on auto-gifts to stabilize the vassal, depleting the war chest it just tried to fill. Aggressive empires pay an internal cost to hold themselves together. Player suzerains default to manual control — auto-adjust is off, the slider stays authoritative, but you can flip it on per-vassal under Manage.

Happiness starts at 60 and changes every ~5 minutes. The drains: tribute above 3% costs 0.75 happiness per percent above (so default 5% = -1.5/tick); cultural mismatch when vassal and suzerain don't share primary race is -1/tick by default (configurable, splinter factions like Argon/Antigone share race so this doesn't apply to them); the vassal's combined-bloc military meeting or exceeding the suzerain's is -3/tick (an overextended suzerain can't hold a stronger vassal); each sector the vassal lost this tick is -3; each ongoing suzerain war is -1 up to -4 total; vassals losing fight-purpose ships drains by loss ratio up to -5 (your protection isn't protecting). The lifts: each enemy that the vassal and suzerain both face is +1; suzerain military at 1.5× or more of combined vassals is +1; each sector the suzerain gained this tick is +2. Net per-tick delta clamps to [-15, +8].

When happiness drops under 40, AI suzerains automatically dip into their virtual treasury to stabilize: +5 happiness, costing vassal_worth/2000 in virt-Cr. The boost is intentionally modest — it brings a struggling vassal back from the brink, it doesn't peg them at 100. A rich AI suzerain can keep an unhappy vassal hovering in the high 30s to low 40s indefinitely. A broke AI suzerain whose virtual balance won't cover the gift skips the gift and the vassal continues down toward rebellion. The player can also gift manually: 5M Cr for +10 happiness, button per vassal under Manage.

Below 30 happiness a rebellion roll fires each tick. The math: an "individual" score scales from happiness (lower = more pressure, capped contribution +30) plus +20 if the vassal's own military exceeds the suzerain's, plus +15 if the vassal lost two or more sectors this tick. A "collective" score from how badly the combined-vassal military overshoots the suzerain's, capped at +40. Total chance is capped at 60% per check. When the roll succeeds, the vassal breaks free: relation lock is removed, both sides set to -0.5 toward each other (unless they're diplomacy-locked, in which case the change is silently skipped — a vanilla limitation), the existing garrison's ship ownership transfers to the rebel (they defect), and up to two claimspace factions hostile to the former suzerain each dispatch a 7-ship support fleet from their shipyards to the rebel's home sector. The rebel sits on a 60-minute cooldown before it can be vassalized again, plus a grace window where Dynamic War events skip it in negative rolls so it isn't kicked while down.

Each DW interval there's also a 20% chance per vassal that the vassal dispatches an expedition fleet against one of the suzerain's enemies. Same fleet shape as garrisons, same shipyard-dispatch model. Expeditions despawn after 30 minutes. This is what makes vassalage feel like a military partnership instead of a paper one.

Vassalage ends when: the player manually releases (button per vassal, or Release All / Safe Uninstall in bulk), the suzerain is destroyed (vassal frees itself), the suzerain shrinks to two or fewer sectors (auto-release), the vassal is destroyed (entry removed), happiness collapses into rebellion (above), or the 3%-per-tick random release roll fires.

See `docs/vassal_system.md` for the original design spec and `docs/architecture.md` for technical layout.
## Files Adjusted and Possible Conflicts

This fork's diff surface is smaller than the original DeadAir Scripts (no more baskets/equipmentmods/wares/maps changes, no more 8779-line jobs.xml) but adds five DLC override files. See `docs/compat_principles.md` for the rules we follow when writing diffs.

**Base-game files**
- `aiscripts/order.build.recycle.xml` — single attribute replace on the `usecover` param default, scoped by `[@id='Recycle']`. Removes cover usage for recyclers owned by non-economic non-claimspace factions (Xenon mostly).
- `aiscripts/order.move.recon.xml` — single `<add pos="before">` inside the police scan branch. Signals `policeassetscannedship` to the player when their police ships scan a non-player ship. Pure addition, no replacement.
- `libraries/colors.xml` — `<add>` of UI color mappings (prefix `da_*`). Pure addition.
- `libraries/diplomacy.xml` — `<add>` of one new agent diplomacy action `propose_vassalage` plus a `<patch>` for the relations table to enable the action. Additive only.
- `libraries/jobs.xml` — four surgical attribute swaps on Antigone + Holy Order police patrol job filters (`@relation` and `@comparison`). No element replacement, no full-job override.
- `libraries/mapdefaults.xml` — four attribute swaps on the `@tags` of four base-game cluster datasets, adding the `daxenoncore` tag for Xenon-anomaly sector flagging. Affects 4 sectors. Other mods that change those same `@tags` attributes will conflict.
- `libraries/modules.xml` — two attribute swaps on `prod_gen_refinedmetals`'s `@race` and `@faction` lists (removes Teladi/Ministry/Scaleplate). Non-sequential, validator-clean.
- `md/factionlogic_economy.xml` — three deep-nested `<add>` operations that signal Dynamic News when stations expand or start construction. Pure addition inside vanilla `Econ_Manager` library cues. Vulnerable to vanilla restructuring the Econ_Manager tree.
- `t/0001.xml` — uses page id `33232474` for all our localized strings. Should only conflict with someone who is too inspired by DeadAir4.

**DLC overrides** (each in `extensions/<dlc_id>/libraries/`)
- `ego_dlc_terran/libraries/jobs.xml` — one whole-element `<replace>` on `terran_police_patrol_s`'s `<location>` filter. Reason: vanilla element uses `faction="terran"`, our target uses `policefaction="terran"`. Attribute-name change requires element replace under current X4 diff syntax — documented tradeoff.
- `ego_dlc_terran/libraries/mapdefaults.xml` — one attribute swap on the `@tags` of cluster 112's sector dataset.
- `ego_dlc_split/libraries/jobs.xml` — same shape as Terran — whole-element `<location>` replace on `zyarth_police_patrol_s`. Same documented tradeoff.
- `ego_dlc_split/libraries/mapdefaults.xml` — two attribute swaps on `@tags` for clusters 415 and 424.
- `ego_dlc_boron/libraries/jobs.xml` — two surgical attribute swaps on `boron_police_patrol_s`'s `@relation` and `@comparison`. No element replacement.

**What we never do:** replace MD cue bodies, replace vanilla library roots, modify save-format files, override vanilla story content, change relations between `isdiplomacyexcluded` pairs.

**Maps directories no longer touched** — original DeadAir Scripts added zones to `maps/galaxy.xml`, `maps/sectors.xml`, `maps/zones.xml` (plus Split/Terran DLC variants). All removed in this fork via the cleanup commits. If you ran a save on the original DeadAir Scripts with anomalies in those added zones, those anomalies don't exist here.
## Dependencies
- Sir Nukes Mod Support API
- DeadAir Eco (optional but highly recommended)
## Installation Info
- This mod is not compatible and must not be used with the older versions of Dynamic War, Evolution, Fill, Jobs, and Gate.
- Folder should be named "deadair_scripts" in case of added assets in future.
## Vassal system and story missions

Two layers of story safety apply, one engine-level and one mod-level.

The first is `isdiplomacyexcluded`. X4 marks certain faction pairs as diplomacy-excluded so vanilla story scripts can hold relations stable — Argon↔Antigone, Terran↔Pioneers, Teladi↔Ministry, Trinity↔Holy Order/Paranid/Buccaneers, Paranid↔Holy Order, Buccaneers↔Holy Order/Paranid, Split↔Free Split, and the DLC-story pairs like Terran↔Argon while Covert Operations is mid-arc. Every vassalize path in the mod (DW roll, conquest roll, broker menu, even the debug Make-Me-Suzerain button) respects this marker. The relation-setting code in the rebellion path and the war-alignment drift respect it too. When a vanilla story clears a lock (Covert Operations clearing Terran↔Argon, for example), those pairs naturally become available without any mod intervention. You do not need to add anything to a list — the engine and the mod stay in sync.

The second is the DA Dynamic War Ignored Factions menu, which is a mod-side list. Anything you put on it is excluded from random DW vassalize, conquest vassalize, and the broker menu. Use this when a story has special meaning for a specific faction but no diplomacy lock to enforce it.

Vassal relations are locked at +1.0. If a story arc you care about depends on a specific relation between two factions that aren't diplomacy-locked, vassalizing one of them may break that story — the ignored-factions list is your tool.
## Uninstalling (important if you ever used the Vassal system)
- The Vassal system applies persistent X4 relation locks to vassal factions. Those locks survive removal of this mod and cannot be reversed once the mod's scripts are gone.
- Before uninstalling, open DA Galactic Politics and click either **Release All Vassals** or **Safe Uninstall**. Safe Uninstall also disables the vassal system and clears all related tables.
- If you never enabled the Vassal system, nothing special is needed.
- If you uninstalled and notice that certain factions never change relations, reinstall this mod and run the cleanup above — the vassal data persists across reinstall.
## Requesting Help
- It is very helpful to have a debug log with the debug options enabled.
- Include your mod list in any bug reports. There are a lot of poorly written mods out there.
- Best place to contact me is via @ on Egosoft Discord modding channel.
## Random Notes
- Can't believe I have to add this. No, you are not allowed to just copy my stuff and put it into your own mod or modpack WITHOUT permission.

