# 34 · v0.45.0 "Tunnel Boring Machine" (盾构机): bulk ore for cheap metal

Step 4 of the 2026-10-11 plan.

> 说到金属制品我们现在的金属制品好像有点耗费元素，我们可以考虑加入盾构机吗？

**Before this release**, 6 Fe (one carbon-steel batch) meant 2 hematite + 2 coal, and every ore was hand-dug:
- hematite only lies below y −12, about 9 pick hits per granite cell to get down there;
- a 4.5 % blob hunt once you arrive;
- a separate trip to the coal seams.

A rover alone needs about 18 Fe.

## The machine
- **Making it.** 盾构机 (`tbm`) is built at 载具总装厂 from 6 carbon-steel ingots, 3 motors, 2 battery packs and a control board (120 s). On the 装备 tab you send it to the planet and recall it. It has its own slot (`industry.tbm`, `tbm_state`), separate from the rover, and a deployed machine can't be sold.
- **Battery.**
  - 1200 Wh at 1 Wh per cut cell, so about 1200 cells per charge.
  - It recharges on the island in about 4 minutes.
  - Rules are in `industry.json` → `tbm`.
- **On the planet** (`planet_tbm.gd`):
  - It appears 3 m in front of you the first time, standing on the ground.
  - It fills a 3×3 section (3 wide, 3 tall) and bores one metre per step: level, 下潜 (one cell down per metre) or 上爬 (one up).
  - Each metre takes 0.5 s + 0.06 s per hit of the rock cut (`Geology.info(id).hits`), so granite is slower than limestone and open air is quick.
  - It turns in quarter turns and backs up only through open tunnel.
- **Controls** (it duck-types the walker like the rover):

  | Input | Action |
  |---|---|
  | E (beside it) | get in |
  | W | bore |
  | S | back up |
  | A / D | turn |
  | Space | cycle 水平 → 下潜 → 上爬 |
  | E (seated) | get out |

  You get out 3–4 m behind it, in the tunnel.
- **Dashboard.** It replaces the aim line and hides the hotbar while you bore. It shows the grade, the depth below ground and the battery, then what lies in the next metre (cells by mineral, seconds, Wh), then the haul so far and the last message.
- **Camera.** A chase camera sits inside the tunnel behind the machine and pulls in when rock is behind it, for example after a turn. The machine's headlight lights the face.
- **Refusals:**
  - outside the surface bounds;
  - bedrock (y ≤ −32): turn, or climb;
  - building blocks;
  - trees or facilities on a surface cell;
  - a drop with nothing under the next section;
  - a flat battery;
  - the planet's terrain-edit limit (16 384 cells, shared with hand digging).
- **Collecting.**
  - Every cut cell goes into the stores at once. Topsoil goes to 土方; every other cell goes to `nature.minerals` as its mineral, and granite, basalt and limestone also give 1 石料 (as hand quarrying does).
  - A mineral at its 999 cap drops the extra cell; boring continues, and the dashboard counts the loss (仓满丢弃).
  - New minerals are logged in the codex.
- **The tunnel.**
  - It is real terrain (`nature.set_voxel`), rebuilt once per metre (`touch`) rather than once per cell.
  - You can walk it. A dive leaves 1 m steps, which you jump (jump height 1.36 m).

## Cheaper metal: batch refining
New refinery processes (`refinery.json`). One coke reduces four ores, so coal stops being the bottleneck:

| Process | Inputs | Output | Time |
|---|---|---|---|
| 高炉炼铁 · 整炉 (`hematite_bulk`) | 4 hematite + 1 coal | 16 Fe | 80 s |
| 孔雀石炼铜 · 整炉 (`malachite_bulk`) | 4 malachite + 1 coal | 16 Cu | 70 s |
| 铝土矿炼铝 · 整槽 (`gibbsite_bulk`) | 4 gibbsite + 1 coal | 8 Al | 90 s |

A 20 m level run at hematite depth cuts about 180 cells. That is mostly granite (stone), plus whatever hematite blobs, coal seams and malachite the section crosses on the way down.

## Also fixed
**Rover parking (v0.42 regression).** Restoring a parked rover still checked the old 8 km disc (`length ≤ 8192`). A rover parked far north or south on the new planet would have made the save fail to load. It now checks the planet's bounds (|x| ≤ 8192, |z| ≤ 7600).

## Save
- `industry`: `tbm` (item id or ""), `tbm_charge` (0..cap).
- `planet.v2.tbm`: `{x, y, z, facing 0–3, grade −1..1}` (whole numbers, within bounds).
- Missing keys in old saves mean no machine.

## Test mode
「盾构机（派往地球）」 makes, charges and deploys one.

## Verification
- **`tests/test_tbm.gd`** (31 checks):
  - data, recipe and batch processes;
  - deploy without and with the machine, the reserved slot, recharge, save, bad slot rejected;
  - a 20 m dive: depth and position, every cell stored, building stone, Wh per cell, real terrain edits;
  - a level run cutting granite in bulk, hematite counted;
  - standing in the tunnel;
  - turning once per press; backing into rock refused, backing up the tunnel works;
  - bedrock, flat battery, buildings and the edit limit refused;
  - full-store overflow kept boring and reported;
  - planet save; far-north rover load (the fix); bad facing rejected;
  - 整炉 refining gives 16 Fe.
- **`tests/test_tbm_ui.gd`** (14 checks):
  - test kit; gear card;
  - the machine appears in front of you; close enough; E gets in and the input drives it;
  - dashboard; space dives; holding W bores forward and down; haul collected;
  - the place is kept; E gets out into the tunnel;
  - game save and load with the machine underground.
- **`tests/capture_tbm.gd`:** screenshots in `docs/screenshots/v0.45.0/` (parked, boring with the dashboard, the stepped tunnel with ore in the walls).
