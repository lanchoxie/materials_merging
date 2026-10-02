# 17 · v0.33.1 "Test build + Earth usability" (测试版 · 地球易用性)

## Why
After v0.33 the user asked for a test version for trying features. While it was being built, they
reported problems on Earth (2026-10-01):
- **Era requirements.** Things like the 公共仓库 were confusing, and it wasn't clear how to put anything in.
- **微缩器.** They didn't know how to use it.
- **God view.** It couldn't show the walked route, beacons or their own buildings.
- **Terrain.** There was no real terrain and there were no caves.
- **Sky-blue things.** Unexplained sky-blue objects lay on the ground.

This release fixes the first, second, third and fifth problems. Real terrain and caves are a bigger
world-generation change, so they get their own release (v0.33.2). See the bottom of this note.

## 测试版 (test build)
- **When it is on.** `scripts/test_mode.gd` reports `enabled()` when:
  - the export has the `testbuild` feature, or
  - the game runs with `--test-mode` (desktop).
- **Separate save.** A test session reads and writes `save_test.json` (`state.save_name`) and never touches `save.json`.
- **Test panel.** A gold 「测试」 button sits in the top bar, and another sits in the planet view's top-right corner.
  - **Resources:**
    - coins +100k;
    - each building piece +500;
    - every element +500 (cap 9999);
    - every mineral +50 (stock cap);
    - planet raw stock, seeds and 口粮 +50.
  - **Island:**
    - open +9 plots, paying their real cost from granted pieces;
    - max the refinery;
    - hire a doctor or engineer;
    - fast-forward 1 h or 8 h through the real offline catch-up.
  - **Earth:**
    - +1 day or +1 season, using the real simulation in 60 s steps;
    - force the next era (`advance_era(..., force=true)`);
    - teleport to camp and to the nearest grassland, forest, wetland, desert and tundra 1.5–7.6 km out.
  - Every grant respects the save validator's caps, so a test save always reloads.
- **Android.** Run `build_android.ps1 -Version X -Test`.
  - It temporarily rewrites the Android preset with custom feature `testbuild`, app id `org.atomatelier.demo.test` and name 「原子工坊 测试版」, then restores it afterwards.
  - The result is `builds/AtomAtelier-X-test-android.apk`.
  - It installs beside the normal game, with separate storage.

## Earth usability
- **公共仓库 (the camp depot) is now usable in the world.**
  - Aim at the crates beside the camp and press E (any hand-type tool). This stores up to 5 food from the pack (口粮 first, then 谷穗, then 野果), plus 1 water sample or water crate while the depot holds less than the era needs.
  - The aim prompt shows the depot's food and water.
  - The crates have no collision, so they only take the aim when nothing else is under the crosshair.
- **Naming.**
  - 「星球粮仓 / 粮仓口粮 / 饲料」 all meant the same thing: food in the player's own pack. They are now just **口粮**.
  - 「公共仓库」 is the shared store that villagers eat from.
- **时代 page.**
  - Each requirement is its own row: ✓/○, value/required, a progress bar and the hint.
  - Each row has buttons that do it or start it: go to the workshop for walls, roofs, planters or PV; open the backpack; go home or to the gathering slope; store into the depot; pour a water sample into the meadow.
  - The summary line lists what is still missing.
- **Goal tracker.** While walking, the top-left shows the next unfinished era requirement and the first clause of its hint.
- **微缩器.**
  - Aiming previews the whole connected build as a translucent box: green if it can be packed, red if not.
  - The prompt shows either 「这座作品N块 · E 装进微缩盒」 or the exact reason it can't: aim at your own build, over 64 blocks, larger than 8×8×8, still supporting other builds, or crops still in a planter.
  - Logic: `river_miniatures.survey()`, which is now shared with `pack()`.
- **God view follows you.**
  - Leaving first person more than 40 m from home centres the god view on where you stood. The terrain chunks, your buildings and nearby life load there.
  - The region buttons return to the classic home overview.
- **Beacons.** Waypoints (路标) are stone cairns with a tall gold light beam and a name label.
  - In first person they are visible up to 900 m.
  - In the god view they are visible within 220 m.
- **Walked route.** `journey.trail` records a point every 8 m while walking.
  - A fast travel or teleport starts a new segment.
  - It is capped at 4000 points; the older half is thinned instead of dropped.
  - It is saved as a flat int array; saves without it still load.
  - The god view draws it as gold dashes on the ground.
- **世界地图 (new, `planet_world_map.gd`).**
  - **Opening it:**
    - 「地图」 button in first person;
    - 「世界地图」 in the god-view camera bar;
    - the 远行 tab.
  - **What it shows:**
    - smooth biome colours over the 8 km disc, with sea outside;
    - the river and landmarks;
    - beacons (tap to travel);
    - your buildings, clustered per 6 m;
    - the trail as gold dashes;
    - you as a mint arrow.
  - **Controls:**
    - zoom buttons: whole map, 4 km, 1 km, 250 m;
    - wheel zoom and drag pan;
    - tap empty ground to read its coordinates and biome.
  - Labels never overlap. The map draws into a clipping canvas.
  - The v0.32 环境图 (climate channels) stays as it was.

## The sky-blue things
They came from three sources:
- **Spring pools.** Every wild site had a 1.5 × 1.1 m spring slab floating 2.5 cm over uneven half-metre steps. With the v0.33 water shader's fresnel it read as a pale sky-blue tile. It is now:
  - a one-cell pool with a muddy rim;
  - a ring of eight stones and three reeds;
  - deeper water colour.
- **Meadow pond.** The meadow and highland "water level" pond floated 9 cm up. It now sits flush.
- **Tundra.** The snow drifts were 12 cm slabs with pale-blue ice cubes on top. They are now:
  - flat drifts;
  - grey boulders with snow caps.

The water shader's sky tint was also lowered from 0.45 to 0.3.

## Verification
- **New tests:**
  - `tests/test_test_mode.gd` (17 checks): caps, plots, refinery, planet time, forced era, biome teleports, save round-trip.
  - `tests/test_earth_ux.gd`: trail, segments and thinning, save round-trip and rejection, old saves; depot quick deposit; miniature survey and pack.
- **Updated tests:** the era-text checks in `test_frontier17_ui` and `test_river_play_ui` now read the row widgets. `test_river_field_ui` follows the 口粮 rename.
- **Screenshot helper:** `tests/capture_earth_ux.gd` (biome spots, beacon, god view at the ridge, world map, era tab, depot aim). Screenshots are in `docs/screenshots/v0.33.1/`.

## Next: v0.33.2 "Terrain & caves"
Today the far world is a gentle ±2 m swell everywhere. The plan:
- **Relief.** Real relief from cheap deterministic noise:
  - rolling hills;
  - ridged mountains in cold and high land;
  - dunes in deserts;
  - flat wetlands;
  - a carved river valley.
- **Home stays unchanged.** Relief fades in beyond the start area, so home is unchanged.
- **Old saves.** Columns players already built or dug on in the far world keep their old height. Saves without a terrain version record "legacy pads" once, at load.
- **Caves.** Caves are analytic tunnels and rooms (capsules and spheres) per cave cell, with a hillside entrance.
  - The chunk mesher asks each column for its carved y-intervals, so only cave columns cost extra.
  - The walker, digging and aim already work on voxels.
  - Cave walls show the real geology (coal, galena, fluorite…).
