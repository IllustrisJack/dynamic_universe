# Diplomacy UI integration — investigation notes (2026-06-08)

Recorded so we don't have to re-discover this if the question comes back.

## Goal

Surface vassal status inside vanilla's Diplomacy / Relations menu, ideally as a fifth category alongside `enemy / ally / friend / neutral`.

## What we found

X4 9.0's diplomacy menu lives in `ui/addons/ego_detailmonitor/menu_diplomacy.lua` (4125 lines). The faction bucketing happens inside `menu.createFactionDetailsContext(frame)` starting at line 1559, specifically the `relations` tab branch around line 1863.

```lua
local relations = {}
for _, range in ipairs(config.factions.relationCategories) do
    relations[range] = {}
end
for _, otherrelation in ipairs(menu.relations) do
    if relation.id ~= otherrelation.id then
        for _, range in ipairs(config.factions.relationCategories) do
            if range == "hostile" then
                if C.IsFactionHostileToFaction(...) then
                    table.insert(relations[range], { id = ..., name = GetFactionData(...) })
                    break
                end
            elseif C.IsFactionInRelationRangeToFaction(relation.id, otherrelation.id, range) then
                table.insert(relations[range], { id = ..., name = GetFactionData(...) })
                break
            end
        end
    end
end
```

`config.factions.relationCategories` is a **file-local Lua table** declared at the top of `menu_diplomacy.lua` (around line 226). It is not exposed via the `menu` table that gets registered with `Helper.registerMenu`. Other Lua modules cannot reach it.

`C.IsFactionInRelationRangeToFaction(...)` is a **C-level engine binding**, not a Lua function. It cannot be monkey-patched.

`GetFactionData(...)` is also not defined in any extracted Lua file — also a C-level binding.

## What this means for integration

| Approach | Feasible | Notes |
|---|---|---|
| Patch `config.factions.relationCategories` from a separate Lua mod | No | File-local, sealed inside the vanilla file's `local` scope |
| Wrap / monkey-patch `GetFactionData` | No | C-level binding, not a Lua function |
| Wrap / monkey-patch `C.IsFactionInRelationRangeToFaction` | No | C-level binding |
| Override `menu.createFactionDetailsContext` entirely | Yes — but requires re-implementing the whole 350-line function against the registered `menu` table. Breaks every X4 patch that touches the menu. | High maintenance |
| Add a separate "Vassal Status" overlay / tab via Simple_Menu_API | Yes | Doesn't touch vanilla; UX is a sibling tab rather than integrated bucketing |
| Stay in DA Galactic Politics submenu (current) | Yes — shipped | No vanilla diplomacy panel presence |

## Recommendation

If integration is wanted: do the **separate overlay** approach. Add a "Vassal Status" button on the diplomacy menu (via Simple_Menu_API's existing patterns) that opens a Simple_Menu showing all vassals. Doesn't depend on patching vanilla's bucketing.

Hard "integrated category" integration would require a full vanilla file replacement, which we'd lose every X4 patch.

## Open follow-ups

- If we ever want to do the separate overlay, the X4 UI hook for "add a button to vanilla menu X" is via Simple_Menu_API's `Add_Button_To_Custom_Menu` (or similar; check vanilla 9.0 API surface). Out of scope for v1.
- Re-validate this whole conclusion against any future X4 release that refactors `menu_diplomacy.lua` significantly. Egosoft has refactored this file at least once per major version.
