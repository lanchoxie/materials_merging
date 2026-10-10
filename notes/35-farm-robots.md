# 35 · v0.46.0 "Farm Robots" (农业机器人)

Step 5 of the 2026-10-11 plan.

> 我们种植和收获可以加入机器人吗？

## The robot
- **Making it.** 农业机器人 is a workshop recipe (`field_farm_robot`, 40 s): 1 timber for the base, plus 2 motors, 1 logic chip and 1 lead-acid battery from the 星锻岛 store (v0.44 `industry_inputs`). It is a placeable machine kind (`farm_robot`, 1 per pack).
- **The dock** is the placed block: a charging pad with a small solar mast. The robot itself is a separate little body (`river_field_view.gd`). It drives from the dock to the planter it is working on, works its arm there, sprays while watering, and drives back when idle. It rides on the real ground surface; natural ground can be half a cell above the block's cell.
- **Work** (`river_field.robot_tick(v)`, once per game second after the ranch tick; rules in `river_field.json` → `robots`):
  - Every 6 game seconds, staggered per robot, each robot does one thing to one planter within 8 m, picking the neediest:
    1. **harvest** a ripe box: the same rolled grain and seeds as the player's harvest, into the robot's hopper; it counts as a settlement harvest;
    2. **sow** an empty box from its seed bin;
    3. **water** a box below 0.35 moisture (+0.4; a built-in rain tank).
  - Boxes a settlement farmer is already walking to (`ranch.jobs` targets) are left to the farmer.
  - Ties go by block key, so the result is deterministic.
- **The hopper** (`field.robots[key]` = {grain ≤ 60, seeds ≤ 12}, saved). The robot never touches the backpack on its own; this keeps the ranch rule that automation doesn't quietly debit or credit the player.
  - **E on the robot** takes its grain into the backpack, sends seeds above 6 back to the backpack, and tops the seed bin up to 6 from the backpack.
  - A robot with anything in its hopper can't be dismantled until it is emptied (`construction.occupied`).
  - Removing the robot block forgets its hopper and work.
- **Aim prompt.** 「照看8米内的种植箱 · 收获/播种/浇水/待命 · 料斗 谷穗N 种子N · E 取出收成并补种子」. The backpack text explains it as well.

## Save
`field.robots` is optional. Each entry must sit on a `farm_robot` block and stay within its bin limits. Older saves load with no robots. `field.robot_work` (what each robot is doing) is not saved.

## Verification
- **`tests/test_farm_robots.gd`** (20 checks):
  - the machine and its parts; crafting refused without the parts, possible with them;
  - in priority order: harvest into the hopper (+ settlement harvest, action shown), sow, water;
  - a box out of range is untouched; the backpack is untouched; the farmer's target is respected;
  - the dismantle lock; E empties the hopper and loads seeds from the backpack;
  - hopper save; overfull or misplaced hoppers rejected; old saves load;
  - a removed robot leaves nothing behind;
  - the prompt; the body drives to its planter.
- **Existing tests** pass unchanged: `test_river_field(_ui)`, `test_wild_harvest`, `test_ranch13(_ui)`, `test_earth(_ui,_ux)`, `test_building_materials`, `test_river_inventory(_ui)`.
- **`tests/capture_robots.gd`:** screenshots in `docs/screenshots/v0.46.0/`.

## Next (agreed plan)
The airplane, with the curved-horizon shader; then the spaceship and a second planet.
