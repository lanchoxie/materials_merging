# 18 · v0.33.2 "Terrain & caves" (地形与洞穴)

## Why
After v0.33.1 the user reported that Earth had no terrain and no caves. The far world was a gentle
±2 m swell everywhere, and every column was solid from bedrock to the top.

## Relief (`river_terrain.gd`: `relief`, `legacy_height`)
- **Where it starts.** Relief is added on top of the old ground and fades in between `relief_begin` (120 m) and +`relief_fade` (180 m). The start bend, the river, the home buildings and the field nodes keep their exact old heights.
- **Shape.** It is the sum of three parts, floored to whole metres:
  - rolling hills (`relief_hills` 10 m);
  - small detail (`relief_detail` 3 m);
  - ridged mountains (`relief_ridge` 30 m). Their sharp crests are made with `(1−|sin·cos|)³` and limited to broad bands across the map.
- **Slopes.** Neighbouring columns usually differ by at most one block, so the walker's auto-jump climbs hillsides. A few ridge crests form cliffs of 2 m or less.
- **River valley.** Relief tapers to zero within 90 m of the river line, so the river runs in a valley.
- **Rock.** Geology still uses absolute depth, so hills and mountains are mostly limestone (karst), with granite and deeper ores below.

## Caves (`cave`, `_cave_at`, `column_has_cave`, `cave_mouth`)
- **Where.** Beyond `cave_begin` (180 m), cells between 2 m and 14 m (`cave_depth`) below the surface are carved where two sine tunnel fields meet (`cave_width`).
- **Mouths.** In sparse `cave_mouth` patches the 2 m roof is removed, so tunnels open to the sky as gorges you can walk down into.
- **Never carved:** river columns, legacy pads, the start area and bedrock.
- **What sees caves.**
  - `natural_solid` treats carved cells as air. Collision, `floor_below`, `overlaps`, aiming and digging therefore all see them.
  - `top_at` drops to the first solid cell under a mouth.
  - The chunk mesher sends cave columns (and their neighbours) to the slow voxel path and scans down to cave depth.
- **Caching.** `column_has_cave` and `natural_height` are cached per column (bounded). A far chunk builds in about 16–25 ms, against about 80–125 ms before the cache.

## Old saves: legacy pads
- **The problem.** Relief would bury or float anything an old save built or dug beyond the start area. The construction validator would then reject the save (`c.y >= base(c)`).
- **The fix.** When a save has no `terrain` key, `planet_v2.restore` collects every placed block and every edited voxel column, and turns the far chunks among them into **pads**.
  - Relief and caves ease back to the old flat ground within 24–64 m of a pad.
  - Pads are saved (`terrain: {version 1, pads: [x, z, …]}`), so they stay put.
  - Builds made after v0.33.2 simply use the new ground.

## Map and fixes
- **世界地图.** The map is hill-shaded from the real relief and lit from the north-west. Peaks above about 26 m fade to snow.
- **River water.** The continued-river water strips only draw on real river cells. They no longer float as stray blue tiles.
- **God view.** The trail and beacons show within 700 m of the god-view centre (was 150 m and 220 m).
- **公共仓库.** The ranch-page card now says it is the 「公共仓库／粮仓」 from the era checklist and explains how to store food.

## Elements (user question, 2026-10-07)
- **Sources today.** All 16 game elements have a source.
  - Br and N come from the refinery's 溴素吹出塔 and 空气分离塔, as in reality.
  - Cs comes from 铯榴石 (pollucite). It is very rare: about 1 % of blocks, only in granite deeper than y ≈ −17.
- **Planned.** New elements and ores (P from apatite, and others) follow the plan in [14-industry-island.md](14-industry-island.md) (v0.37).

## Backlog the user added (2026-10-07)
- More element ores.
- Gear upgrades.
- Settlement/community upgrades.
- The remaining eras (Ice Age, Bronze, Clash…).

These fold into the interleaved plan in 14-industry-island.md.

## Verification
- `tests/test_terrain_caves.gd` (14 checks):
  - home has no relief or caves;
  - far relief of at least 20 m, with rare cliffs of 2 m or less;
  - a river valley;
  - caves exist and a mouth breaks the surface; ground drops into it, and the walker stands inside;
  - deep cave cells are air, and bedrock is intact;
  - an old save with a far build loads, its pad suppresses relief locally, and pads survive a round trip.
- `tests/capture_terrain.gd` (screenshot helper): hills, a cave mouth, inside the gorge, the god view, and the hill-shaded map at 4 km and in full.
