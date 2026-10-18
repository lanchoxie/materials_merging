# 44 · v0.55.0 "Clash II" (两族战争): two raider factions, supply defense, warning, trophies

Builds directly on v0.54 Clash I. Four changes that make tribal conflict feel like a real event
rather than a periodic debuff.

## Two raider factions

| Faction | Raiders | HP | Trophy |
|---|---|---|---|
| 野营部落 | 3 野营战士 | 2 HP each | 战斧碎片 × 1 |
| 猎火部落 | 4 猎火战士 | 3 HP each | 战斧碎片 × 1 |

Factions alternate every raid: first raid = 野营, second = 猎火, third = 野营 again, and so on.
The faction data lives in `river_natives.json` under `clash.factions[]` — adding a third faction
later is a data-only change.

## Supply-based abstract defense

When you are not present for a raid the tribe resolves it alone. How much they lose now depends on
their total supplies (food + timber + stone):

| Supply score | Stock-loss multiplier |
|---|---|
| ≥ 30 (well-stocked) | × 0.5 — loses half the normal amount |
| 10–29 (normal) | × 1.0 |
| < 10 (struggling) | × 1.5 — takes heavier losses |

This makes gifting the tribe and keeping them supplied between raids strategically meaningful.

## One-day raid warning

One day before a raid the tribe's lookouts send word. A news note appears in the log:
> 侦察者来报：猎火部落明天将来袭，备好存粮！

The chief panel shows a highlighted warning banner while the warning is active, and a separate
"raid in progress" banner while real raiders are on the field.

## Trophy drops

When the player helps fight off a real raid, defeating the last raider awards one **战斧碎片**
to the backpack (if there is room). The item is defined in `river_field.json`.

## Save compatibility

Serialization bumped to version 3. `restore()` accepts versions 1, 2, and 3, so existing saves
load fine; the new fields default to safe values (next_warn_day = -1, current_faction_id = "",
last_faction_idx = -1).

## Files changed

- `data/river_natives.json` — `clash` block expanded: `factions[]`, `supply_defense`, `warning_days`.
- `data/river_field.json` — added `trophy_axe` resource.
- `scripts/river_natives.gd` — `_pick_faction()`, `_supply_score()`, `_award_trophy()`, updated
  `_tick_clash()`, `strike_raider(field=null)`, `_current_faction()`, `_new_day()` warning note,
  new fields `next_warn_day` / `current_faction_id` / `_last_faction_idx`, serialize v3.
- `scripts/river_combat.gd` — passes `v.field` to `strike_raider()`.
- `scripts/planet_v2_panel.gd` — warning and active-raid banners in the chief panel.
