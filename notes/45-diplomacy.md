# 45 · v0.56.0 "Diplomacy" (议和外交): third faction + tribute system

Builds on v0.55 Clash II. Two additions: a stronger third raider faction that unlocks after two
completed raid cycles, and a tribute path that lets the player pay off the current raid instead
of fighting.

## Third faction: 铁骨部落

| Faction | Unlocks (raid_cycle) | Raiders | HP | Tribute cost |
|---|---|---|---|---|
| 野营部落 | 0 (always) | 3 野营战士 | 2 HP | 食物 × 6 |
| 猎火部落 | 0 (always) | 4 猎火战士 | 3 HP | 食物 × 8 |
| **铁骨部落** | **2** | 5 铁骨勇士 | **4 HP** | 食物 × 12 |

`_pick_faction()` builds an eligible list from factions whose `min_cycle <= raid_cycle` and
cycles through it. After the first two raids complete (both abstract and fought raids increment
`raid_cycle`), 铁骨部落 joins the rotation.

## Tribute system

When real raiders are on the field the chief panel shows a **🤝 进贡求和** button listing the
required resources. Pressing it calls `negotiate_tribute(field)`, which:

1. Checks the player's backpack has the required food.
2. Deducts the cost and clears the raiders.
3. Delays the next raid by half the normal interval (peace bought, not permanent).
4. Increments `raid_cycle` (tribute counts as a completed clash).
5. Posts a faction-specific news note.

The tribute cost comes from the `tribute_cost` dict on each faction entry in
`river_natives.json`, so it's easy to tune per-faction.

## Save compatibility

Serialization bumped to version 4. `restore()` accepts versions 1–4; the new `raid_cycle` field
defaults to 0 for older saves so 铁骨部落 doesn't appear immediately for existing players.

## Files changed

- `data/river_natives.json` — third faction 铁骨部落 with `min_cycle: 2` and `tribute_cost`;
  `tribute_cost` and `tribute_news` added to all three faction entries.
- `scripts/river_natives.gd` — `raid_cycle` field; `_pick_faction()` filters by `min_cycle`;
  `negotiate_tribute(field)`; `setup()` resets `raid_cycle`; abstract path increments
  `raid_cycle`; `strike_raider()` already increments via `current_faction_id=""`; serialize v4,
  restore accepts v4, restore loads `raid_cycle`.
- `scripts/planet_v2_panel.gd` — tribute button shown when raiders are active; shows cost inline.
- `scripts/planet_program.gd` — `v2_native_tribute` command dispatched to
  `natives.negotiate_tribute(field)`.
