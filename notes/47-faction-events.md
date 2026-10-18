# 47 · v0.58.0 "Faction Events" (派系事件): rare trophies and post-raid demands

Builds on v0.56 "Diplomacy". Two additions that make each faction feel distinct beyond
raider count and health: faction-specific rare trophy drops and post-raid demand events.

## Faction-specific rare trophies

When the player defeats the last raider of a real raid, two separate rolls fire:

| Faction | Common drop | Rare drop | Rare chance |
|---|---|---|---|
| 野营部落 | 战斧碎片 (100%) | 骨牙护符 | 40% |
| 猎火部落 | 战斧碎片 (100%) | 火焰羽毛 | 40% |
| 铁骨部落 | 战斧碎片 (100%) | 铁骨臂章 | 50% |

Rare items are defined in `river_field.json` (trophy_bone, trophy_feather, trophy_badge).
`_award_trophy()` now tries the common drop first, then the rare drop independently.

## Post-raid demand events

After an abstract raid resolves (when the player is not present), each faction has a chance
to leave a demand — requiring a specific resource within 5 days. Meeting it gains friendship:

| Faction | Resource demanded | Amount | Chance | Friendship gain |
|---|---|---|---|---|
| 野营部落 | 食物 | 4 | 50% | +0.15 |
| 猎火部落 | 木料 | 5 | 50% | +0.15 |
| 铁骨部落 | 石料 | 6 | 60% | +0.15 |

A `pending_demand` dictionary stores the active demand (faction id, resource, amount,
deadline day, news strings). `_new_day()` expires it silently when the deadline passes.
The chief panel shows a highlighted banner with the resource name, amount, and days
remaining. A "满足要求" button dispatches `v2_native_fulfill_demand`, which calls
`fulfill_demand(field)` to deduct the resource and post the news note.

Only one demand can be pending at a time — a new abstract raid skips the demand roll if
one is already active.

## Save compatibility

Serialization bumped to version 5. `restore()` accepts versions 1–5; `pending_demand`
defaults to `{}` for older saves.

## Files changed

- `data/river_field.json` — trophy_bone, trophy_feather, trophy_badge items.
- `data/river_natives.json` — rare_trophy/rare_trophy_chance and demand_event blocks on all
  three factions.
- `scripts/river_natives.gd` — pending_demand field; setup() resets it; _award_trophy()
  handles rare drop; abstract resolution rolls demand_event; _new_day() expires overdue
  demand; fulfill_demand(field); serialize v5, restore 1–5, loads pending_demand.
- `scripts/planet_v2_panel.gd` — demand banner with days-remaining and fulfill button.
- `scripts/planet_program.gd` — v2_native_fulfill_demand command.
