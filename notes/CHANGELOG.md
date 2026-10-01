# Changelog (fun pass)

Old versions are never overwritten. See `04-versioning.md` for where each one lives.

## Baseline: `archive/v0.21.0-interiors-18` (commit `7db2272`)
This is the uncommitted v0.20.0 + 0.21.0 preview work, snapshotted as it was found before any fun-pass change.
Test run: `bash dev/run_tests.sh` in a clean worktree at the tag gives **39 passed, 17 failed**.
These failures already existed and are not caused by the fun pass:

| test | first error |
|---|---|
| test_bridge_scroll_ui | could not create `res://artifacts` (only in a fresh worktree; the dir exists in the main tree) |
| test_factory_ui | available action 投放 标准水箱 |
| test_first_person_editor_ui | touch cancel: same first-person scene returns |
| test_interaction14_ui | left click with default gloves hits exactly once without opening details |
| test_organic14_ui | touch application affects only aimed crop and consumes bottle once |
| test_organic15_ui | native touch submits one real reactor installation at fixed level fee |
| test_organic16_ui | touch starts paid doctor installation of selected organic |
| test_planet_retirement | Parse JSON failed |
| test_planet_v2_ui | map click selects the projected terrain region |
| test_residence_ui | touch anchors observer on chair |
| test_river_exploration | walking stops before expanded world edge |
| test_river_field_ui | mobile action button advances gathering once without an emulated duplicate |
| test_river_inventory_ui | touch selects an owned component |
| test_river_play_ui | toolbar click selects an equipped tool without teleporting |
| test_river_wilderness_ui | E collects once and cannot duplicate forage |
| test_state | seven science templates including substitution discoveries |
| test_touch_scroll | finger starting on purchase button scrolls element list |

Most of these are touch/click UI tests. They probably depend on real input timing or window focus that the
batch runner doesn't provide. They are worth a dedicated fix pass later (see roadmap "Later").

## v0.32.0 "Earth": a planet whose climate you can change
The user asked to build Earth after v0.31 (2026-10-01). Full notes: [15-earth.md](15-earth.md).
- **Climate field.** The 16 km planet is a 64×64 grid of 256 m cells with water, temperature, nutrients and pollution.
  - The start area (300 m) is unchanged; further out the land ramps into five biomes: 草原, 森林, 湿地, 荒漠, 冻原.
  - Cold north, dry east, wet west; the 千米林海 is forest.
- **Environment machines.** Four new workshop lines, each gated by a real sample:
  - 喷淋塔 (water): wets and cools its cell and a share of the neighbours; two can green a desert.
  - 制氧塔 (O₂ sample): raises global O₂, which feeds the regions' oxygen target.
  - 温室气体塔 (CO₂ sample): raises global CO₂; warming is 3 °C per doubling (IPCC AR6 best estimate, game-time compressed) and crops grow up to 25 % faster.
  - 氨肥撒播机 (NH₃ sample): richer soil with a little pollution.
  - They are built from the backpack like solar panels, have tall distinctive models and animated effects, and fade back when removed.
- **The land follows.** Ground tint blends between cells; biome decor (cacti, reeds, ferns, flowers, snow mounds); dry or snowy trees; forest sites spawn boars; deep desert is not habitable.
- **环境图.** A camera-bar button opens a 16 km map with biome/water/temperature/nutrient/pollution channels, landmarks, machines, your position and the atmosphere.
- Saves: planet v2 gains an optional `environment` key (validated on load); workshop program v12 adds the four kits. Older saves load untouched.
- Tests: new `test_earth` (37 checks) and `test_earth_ui` (18 checks, 8 screenshots).

## v0.31.0 "Builder": easier building, real doctor and element gates
The user asked for a tidy pass before Earth (2026-10-01). Full notes: [13-builder.md](13-builder.md).
- **Seamless island.**
  - All 12×12 tiles of a plot can be built on, and the grass of neighbouring plots meets edge to edge.
  - Items (and extra buildings) may cross a plot edge onto unlocked land; an item belongs to the plot holding its anchor.
  - Reactor plots now accept decor and extra buildings on their rim.
- **Undo.** ↶ 撤销 in the build HUD and the plot sidebar, plus Ctrl+Z. It covers placing, moving, storing, recycling and whole drag strokes.
- **Eraser and one-click recycle.**
  - 擦除 drags paths/decor into the toolbox.
  - 回收本地块装饰与小路 (two taps) and 回收全岛小路; both are undoable.
- **Doctor gate.** Building a reactor, changing a template, swapping elements or changing a sandbox composition needs an installing doctor (post 自动/物流).
  - Without one, only coordinate tuning works, and banners explain how to get a doctor.
- **Element gate.**
  - A new reactor costs 100 coins plus its template's atoms; a template change costs 25 coins plus the net new atoms (refunded on cancel).
  - The template list shows the stock per element and disables what you can't afford.
  - Palettes disable elements with 0 stock and point to the refinery source.
- Save **v27** (items may spill across plots); v26 and older load.
- Tests: new `test_builder` and `test_builder_ui`; tests that build reactors now hire a doctor and stock elements.

## v0.30.0 "Fabricator": real properties become gear
The user asked for the next version after the v0.29 APK. Full notes: [12-fabricator.md](12-fabricator.md).
- **制造台 (Fabricator).** Stored crystals the index recognises become gear, with numbers from their real data.
  - **Pick heads**: Vickers hardness from MP elastic moduli (Chen et al. 2011). Ductile metals, alkali/halide compounds and inconsistent elastic data are refused with the reason.
  - **Solar panels**: Shockley–Queisser limit at the MP band gap; up to 3 on the refinery roof speed refining.
  - A rock table shows the hits each rock needs with the current pick. There is a sources overlay, a 5-step tour, and help entry 08.
- **Digging.** Rock hardness from Mohs via measured Vickers values of the Mohs minerals (Broz et al. 2006).
  - The starter pick (5.43 GPa, a game value) is slower in granite, basalt, cassiterite, spodumene and pollucite (up to ×3), never blocked.
- **Iron and tin.** New elements Fe and Sn, with blast-furnace (hematite) and cassiterite smelting in the refinery.
  - The MP index was rebuilt for 16 elements: 1 835 crystals.
- New batches remember their index key. Save **v26** (`fabricator`); older saves load with the starter pick.
- Tests: new `test_fabricator` (40) and `test_fabricator_ui` (20); `test_state` expects save v26.

## v0.29.0 "Index": a real chemistry database inside the game
The user supplied a Materials Project API key and asked for the planned index. Full notes: [11-index.md](11-index.md).
- **Offline pipeline** `dev/chem_index/`:
  - 1 090 Materials Project crystals: game elements only, ≤ 24 sites, E_hull ≤ 0.1 eV/atom; 496 experimentally observed.
  - 106 curated PubChem molecules with bond graphs.
  - Bundled as JSON with attribution. No key in the repo or the APK, and no network at runtime.
- **Honest matching.**
  - Molecules match by exact bond graph.
  - Crystals match by reduced composition, and by prototype space group for rock-salt/perovskite templates.
  - Same atoms but different bonds is only an isomer hint. Everything else stays "未收录 · 假说".
- **Gameplay.**
  - Element substitution now reaches real compounds (LiCl, HBr, thiourea…), which are named for what they are.
  - They earn 2× the exploration stipend, and the first harvest pays a one-time index reward with a banner.
  - Save v25 (`index_found`). v24 saves settle without a windfall.
- **Browser.** The codex gains a 化学索引 browser: molecule/crystal tabs, element filters, pages and found cards.
  - Entry pages have a turning 3D structure (conformer or unit cell), sourced properties ("未测" when missing) and how to make it.
  - A 数据来源与致谢 screen, a reactor sidebar line with a link, the live index line in the structure workshop, and an `index` first-time tour.
- Fix: the coach tour's screen check holds a weak reference, so closing a screen mid-tour no longer logs "Lambda capture … was freed".
- Tests: new `test_chem_index` (35) and `test_chem_index_ui` (23); `test_state` expects save v25; `test_island_loop` counts the one-time index reward on the first water harvest. Suite 69/0.

## v0.28.0 "Refinery": elements from the ground, reactors that look their level, first-time tours
The user asked for distinct looks for reactor tiers, a visible doctor install that shows the compound's state
change, tidier navigation, and proper onboarding for synthesis. Full notes: [10-refinery.md](10-refinery.md).
- **Navigation.** Screens opened from the planet or a walk return there, with camera and position intact. They never drop you on the island.
  - Close buttons name their destination.
  - ESC closes details → first person → planet, in that order.
- **Refinery replaces the element shop.**
  - Mined minerals are refined by real processes (Downs cell, malachite smelting, fluorite → HF → F …).
  - Seawater, air and water trickle H, C, N, O, Na, Cl, Br.
  - Every missing element says where to get it.
  - Save v24 (`refinery`). Older saves load with a fresh refinery.
- **Reactor tiers.** Lv.1 glass flask, Lv.5 jacketed kettle, Lv.10 autoclave (live gauge), Lv.15 plasma chamber (orbiting rings).
  - A banner shows on each new look, and the sidebar shows the next unlock.
- **Phases.** Sourced room-temperature phases fill the chamber: crystals, liquid with bubbles, or a gas cloud.
  - The sidebar has a phase badge.
  - An install that changes the phase shows a "物态变化" banner.
- **Visible doctor install.** CPK-coloured element orbs circle the crown and sink in as the doctor works, with no geometry rebuilds.
- **First-time tours.** Coach marks cover the island, atom workbench, refinery, organic reactor and structure workshop.
  - Tours are skippable, saved and replayable from 怎么玩？.
- **Safety.** Script-driven runs (tests, screenshot helpers) never load or write the player's save slot.
  - During development, a direct run of the new coach test (without `--release-ui-test`) wrote to `saves/save.json` once before this guard existed. See the release report.
- Tests: new `test_navigation_ui`, `test_refinery`, `test_reactor_looks`, `test_coach_ui`. Updated shop-based tests now refine instead of buying.
- Known and unchanged: the legacy `main.gd --visual-test` smoke run stops at "Editor must charge on confirmed change". It fails the same way on v0.27.1 and is not part of `dev/run_tests.sh`.

## v0.27.1 "Hometown tidy": automatic paths, toy-scale first person
The user found laying roads confusing and asked for it to be removed. They also asked for a first-person
scale that matches the smaller v0.27 houses.
- **Paths are automatic.** `campus_layout.road_links` links every opened plot.
  - `campus_road`/`store_road` are free no-ops kept for old callers. New plots are saved with `road=true`.
  - The road button, the 星砂小路 toolbox card and every "请铺路 / 未连通" hint are gone.
  - Residents still walk plot to plot along the drawn edge paths.
- **First-person island walk at toy scale** (`island_walk_surface.gd`, `island_walk_panel.gd`):
  - eye 1.12 → 0.6 (villager eye level), body 0.68, radius 0.09
  - walk/run/jump 1.5/2.4/2.6, step 0.32, gravity 12
  - reach 1.9, near plane 0.02
  - House interiors keep their own human scale.
- `tests/capture_walk_scale.gd`: a screenshot helper, not a test.
- Suite 63 passed, 0 failed. The APK version code is still 27 (no APK built).

## v0.27.0 "Hometown" (家园): many buildings per plot, a courtyard shop and pedestals
The top-level save stays v23. Plots gain `at` (main building anchor) and `items` (uid-keyed courtyard
list); storage gains `decorations`. Older saves pin their buildings once to a default anchor when they
load. A v0.27 save does not load in v0.26. Plan and rationale: [09-island-town.md](09-island-town.md).

**Tile grid** (`scripts/island_town.gd`, `data/town_items.json`)
- Each 3 m plot is a 12×12 grid of 0.25 m tiles. The last row and column stay clear for the edge road.
- Footprints: small buildings 5×5, institute/villa 8×8, reactor keeps the central 8×8.
- Placement is atomic. Bounds, overlap, the plaza, reactor centres and locks are checked before any
  coin is spent. Saved plots are re-validated on load (duplicate uids, overlaps, orphan exhibits).
- Island cap raised from 128 to 400 unlocked plots. There is no far-plot culling yet (not needed at
  current sizes). An infinite island stays out of scope: the planet is the infinite frontier.

**Several buildings per plot** (`lab_state.gd` town API, `campus_layout.gd`, `campus_panel.gd`)
- `town_place / town_move / town_store / town_sell / town_upgrade`. The first building on an empty plot
  becomes the main building. Later buildings are extra items with their own level.
- Buildings of one kind on one plot pool their beds and posts and are listed once with a count.
- Buildings move only inside their plot, so residents keep their address. Decorations move anywhere.
- Selling refunds 50 % of build + upgrade spending.

**Courtyard shop** (`scripts/town_decor.gd`, `main.gd` `_show_town_shop`)
- 25 coin items in six tabs: buildings, paths (stone/boardwalk/crystal), fences (wood, picket,
  stone wall, hedge, gate), plants, small items (bench, lamp, signpost, flag, swing, pond, fountain,
  windmill) and pedestals. Premium items name their unlock condition.
- Fences, hedges and paths auto-join with their neighbours. Paths, fences and small plants paint by
  dragging.
- Stored items wait in the toolbox and come back for free.

**Build mode** (`scripts/town_build_mode.gd`)
- The camera zooms onto the plot. A tile grid appears, and a ghost follows the pointer tile by tile
  with a green or red footprint. The HUD shows name, price, count placed, the error, ↻ rotate (R)
  and 完成 (Esc).
- Tapping in the world selects single items with move, upgrade, store and sell actions. The main
  building gets a 挪动位置 action.

**Pedestals** (stone, plinth, turntable, glass case)
- They show a mined v0.26 mineral (it leaves the backpack) or a river miniature. The miniature is marked
  `plot = -2`, so it cannot also be unfolded on the planet.
- A floating card shows the name and formula. Selling or clearing a pedestal returns the exhibit.
- The visitor-appeal bonus from the plan is deferred to the Specimens release.

**Tier looks and effects** (`campus_view.gd`, `campus_architecture.gd`)
- Every building has three looks across its levels: wood, brick and glass/solar. The name of the look
  is in the upgrade message.
- New items pop in with a squash-and-stretch and a dust puff. Upgrades add a scaffold, a pop and stars.
- Island walk collisions follow real footprints and items. Paths, parks and gardens stay walkable.

**Known trade-off:** small buildings render at 5/8.6 of their old size, so several fit on one plot.

Tests: new `test_hometown` (48 model checks) and `test_hometown_ui` (21 UI checks).
`test_state` fills 400 plots. Full suite: see the v0.27 tag message.

## v0.26.0 "Bedrock": the planet ground becomes blocks with real geology
Top-level save stays v23. Inside it, planet nature goes to version 2 (sparse voxels, mined minerals,
codex) and the hotbar to version 2. Every older save loads; a v0.26 save does not load in v0.25.

**Voxel ground** (`scripts/river_terrain.gd`, `scripts/river_nature.gd`)
- The ground is a 1 m grid from the surface down to bedrock at y = −32. The natural top keeps the old
  landscape floored to half metres, so the top cell is a full block or a 0.5 m slab.
- Only edits are stored: `nature.voxels` (cell → material, "" = dug) plus a per-column index.
  Putting the original material back erases the edit, slabs included, so a repaired world saves as pristine.
- Old whole-column height edits migrate to cells. The floor of the old ground is kept exactly, so every
  existing building stays on its base cell (checked on 40 probe columns in tests).
- Walking, jumping, construction rays and aiming all use the same cell queries. The walker collides with
  walls and ceilings and auto-jumps a single-block step. Animals now cross 0.5 m steps (0.42 → 0.55).

**Real geology** (`data/minerals.json`, `scripts/planet_geology.gd`)
- 18 materials with formulas and Mohs hardness from mindat.org / the IMA list. Rocks and soils are
  labelled as mixtures and never get an invented single formula.
- Layers: topsoil → clay/sand with bauxite (gibbsite) → limestone (malachite, halite, sulfur, coal seams,
  galena, fluorite) → granite from −12 m (spodumene, cassiterite, hematite, rare pollucite below −17 m)
  → basalt from −22 m → bedrock. Ore bodies come from a deterministic hash, so nothing is saved for them.

**Tools**
- 地形铲 is now 采掘镐 (pick): hits depend on hardness (topsoil 1 … granite 5), progress shows in the HUD;
  bedrock refuses it. Topsoil goes to the soil stock; everything else becomes a `rock:<id>` backpack item.
- New 分析仪 (analyser): E on rock, trees or forage reads composition, formula, hardness and layer.
- Mined rocks can be placed on any face (up to 16 blocks above the original ground). You can't place them
  inside your own body, on a building column, under trees or on the public paths.
- New mineral codex (年鉴 → 矿物图鉴 x/18); first finds are announced.
- Pre-v0.26 hotbars get the pick and analyser once, in free slots only.

**Rendering** (`scripts/river_chunk_stream.gd`)
- A voxel column mesher: untouched columns take a heightmap fast path; edited columns emit exposed faces
  per cell with mineral colours, cave ceilings and slabs. It averages 3.5 ms per 16×16 chunk headless,
  faster than the old heightmap (6.4 ms). A chunk with 16 deep shafts takes about 11 ms.
- The sea plane moved from y −1.3 to below bedrock, so dug pits no longer fill with "sea".

**Tests**
- New `tests/test_bedrock.gd` (114 checks) covers:
  - formulas vs elements and the textbook reference values;
  - every material occurring near home, and determinism;
  - aim → voxel, hits, codex and scan;
  - place/restore, bedrock, building-column and self-entombing refusals, the edit cap;
  - save v2 round trip and rejection of bad saves;
  - v1 migration keeping building bases;
  - pit walls, auto-jump and a roof capping a jump;
  - mesher faces and budget.
- Updated tests for slab-aware digging and the half-metre ground: sandbox12, frontier17 and organic14/15/16
  aim heights. The test doubles got `water_at`/`overlaps`/`floor_below`.
- Full suite: **61 passed, 0 failed**.

### v0.26 step 1: test suite repair
v0.26 in progress: fixed tests. The full suite is now **60 passed, 0 failed** (it was 44 / 16):
- **Headless input (11 tests).** Headless Godot has a 0×0 window. The root viewport is then 64×64 with
  a ~0.044 `canvas_items` stretch transform, so scripted events given in 1440×900 canvas coordinates
  missed every control. The new `scripts/core/test_input.gd` maps events forward through the root
  transform. It is identity in a real window. Tests and main.gd's test helpers use it.
- **Game fix: codex cards.** They used `MOUSE_FILTER_STOP`, so a finger swipe that started on a card could
  not scroll the codex on phones (test_touch_scroll).
- **Game fix: hand foraging.** Since the hotbar rework, E went through the selected slot, so wild foraging
  was only reachable from a side-panel button. E with the hand and nothing aimed now forages nearby ripe
  wild plants (test_river_wilderness_ui).
- **Outdated expectations:**
  - 17 templates instead of 14 (test_state);
  - the world edge follows the 8192 m data radius (test_river_exploration);
  - the residence walk-out waits on real time instead of 90 frames;
  - the bag tab is the grid backpack (test_factory_ui, test_river_wilderness_ui);
  - wild-site fixtures need grid keys (test_interaction14_ui).

## v0.25.0 "Looks": a world worth screenshotting
Save format is unchanged (still v23). Everything here is cosmetic and never touches the economy.

**Day and night** (`scripts/core/day_cycle.gd`)
- A 16-minute cycle driven by the wall clock: dawn, a long day, lilac dusk, a mild blue night.
  About 70 % of it is daylight. It is never saved; `world.day_phase_override` pins it for tests and screenshots.
- Sun pitch, yaw (shadows sweep across the island), colour and energy, ambient light and sky blend
  between keyframes with smoothstep.
- At night lamps, reactors and other glowing materials get up to 3.2× brighter, and the reactor glass rim lights up.
- The LIVE badge shows 清晨 / 白天 / 黄昏 / 夜晚 / 黎明.

**Sea** (`assets/shaders/sea.gdshader`)
- The island now floats on a stylized sea instead of the matte studio floor.
- Shallows, animated foam bands hugging the shore and a foam edge come from a small distance-to-island
  mask baked on the CPU (`_update_shore`). It is only re-baked when the set of parcels changes, so it follows every expansion.
- Soft ripple glints; the sea glows faintly at night.

**Materials**
- Reactor chambers: unshaded fresnel glass with a rising shimmer (`glass.gdshader`).
- Trees and bushes sway in a breeze, weighted by height (`foliage.gdshader`). Leaf materials are marked so
  `StaticGeometry` still merges them into batches.
- The frontier label over the sea gets a dark outline so it stays readable in any light.

**UI**
- The atom editor's rules caveat is folded behind an "ⓘ 规则说明" toggle.

**Tests**
- New `tests/test_looks.gd` (37 checks): keyframes ordered, complete and wrapping, labels, mostly daylight,
  sea shader present, studio floor gone, shore mask bright at the shore and dark in open sea, no re-bake for
  an unchanged island but a re-bake after expansion, night dims the sun and brightens glow and glass,
  leaves batch, the LIVE badge label, and the ⓘ toggle.
- `dev/capture_looks.gd` screenshots day, dusk, night, dawn and a close-up into `artifacts/looks/`.

**Deferred:** river water shader, fullscreen river HUD and river perf (later); limbed animals (v0.26).

## v0.24.0 "Discovery": every structure is a card worth polishing
Save format **v23** (adds `best_fit` and `star_rewards`). v1–v22 saves still load. The codex is seeded from
the island's current samples of discovered structures; star gifts already within reach are marked handed out
**without** paying them (same no-windfall rule as the v0.23 goals).

**Codex** (`data/codex.json` and `scripts/codex.gd`)
- 「结构图鉴」 is now a 4-column card grid. Card border and label show rarity by atom count:
  2–3 常见, 4–5 稀有, 8–9 珍贵, 14–15 传说. Undiscovered cards show "？？？" and how to unlock them.
- Tap a card for its entry: best stars and fit, how to earn the next star, the science text and source,
  and your current samples with their live fit.
- **Stars**: each structure remembers the best geometry fit of a batch you actually *harvested*
  (★ 80 %, ★★ 93 %, ★★★ 98 %, the same thresholds as the editor), so up to 51 stars.
  The atom editor shows "最佳 ★★☆" next to the live match.
- **Star gifts**: at 3/6/10/15/21/28/36/45 stars the codex hands out decorations (flowers, bench, lamps,
  原子风铃, 月亮夜灯, 晶晶小狐狸…). They go straight into the toolbox; exploration props are unlocked.
  The harvest toast says "图鉴奖励 …" and a lilac popup floats under the coin counter.

**First-synthesis reveal**
- The first harvest of a new structure no longer shows a text banner. A card slides in face down,
  flips to show rarity, formula, name and stars, then sparkles, flashes in the rarity colour and floats away (`Fx.card_reveal`).

**Tests**
- New `tests/test_codex.gd` (53 checks): rarity tiers, star thresholds shared with the editor, gift table
  sanity, best-fit only rises, undiscovered structures don't count, gifts are ordered and paid once, the harvest
  path records the fit and announces gifts, the reveal card, v23 round-trip, validation, v22 migration
  without payout, and the codex dialogs.
- `test_state` expects save v23. `test_goals` accepts ≥ v22.

**Test run:** 43 pass / 16 fail. Every failure has the same error lines as the baseline (diffed per test).
- `dev/capture_codex.gd` screenshots the grid, an entry, both faces of the reveal, and the editor.

**Moved:** element sticker book and frontier element deposits → v0.26, where the frontier gets its purpose.

## v0.23.0 "Goals": always know what's next
Save format **v22** (adds `milestones_claimed` and `saved_at`). v1–v21 saves still load; goals the player has
already reached are marked done **without** paying out again, so old islands don't get a windfall.

**Goal track** (`data/milestones.json` and `scripts/milestones.gd`)
- 20 ordered goals: tune, harvest, crate, stars, expand, hire, build, deliver, discover, upgrade, perfect fit, and so on.
  Each pays coins, building materials or catalysts.
- Progress is read live from state; only the ids of claimed goals are saved, so nothing can drift.
- The quest bar shows goal n/20 with a gold progress bar. A finished goal shows a **领取** button (placed
  left of the toast so it's never covered) and gets its own feedback: banner, fanfare, coins flying to the counter.
- A **目标** button opens the full list (✓ done / ★ current / · upcoming).
- After material-journey players (planet joined) claim everything that's ready, the bar goes back to the journey text.

**Idle loop**
- Reactor buffer: 5 → **12** base units (+2 per level, unchanged). A reactor now runs ~5 min unattended, not 2.
- **Offline catch-up**: on load, reactors run for half the time away, capped at 2 hours. They still stop when full.
  Payroll, campus and planet stay paused, keeping the existing promise "离线不计薪".
  A compact **欢迎回来！** dialog summarizes the time away, new units and coins waiting.

**Fixes**
- The toast no longer swallows clicks (it covered part of the world view and the quest bar for 4 s after
  every action).
- `_dialog()` takes an optional height for short dialogs.
- Coin-burst callbacks hold the coin counter weakly. In v0.22.0, coins still in flight when the main scene was
  freed (tests, quitting) raised a script error. There was no gameplay impact, but it showed up in `test_material_visitor_ui`.

**Test run:** 41 pass / 17 fail. The 17 failures are the same tests with the same error lines as the baseline
(diffed per test). `test_planet_retirement` only fails in a fresh worktree.

**Already true, dropped from the plan:** "edits no longer wipe stock". `apply_structure_edit` already collects
the old batch into the toolbox before changing the structure.

**Tests**
- New `tests/test_goals.gd` (92 checks): data sanity, ordered claiming and no double payout, v22 round-trip,
  validation, v21 migration without payout, offline half-speed/cap/no payroll/idempotence, quest bar, claim
  button, dialogs.
- `test_island_loop` now reads the capacity from rules instead of the literal 5; `test_state` expects save v22.
- `dev/capture_goals.gd` screenshots the quest bar, goal list and welcome dialog.

## v0.22.0 "Juice": the island finally feels alive
Save format is unchanged (still v21), so old saves load as-is.

**Sound**
- New `Sfx` autoload: 14 pooled voices, SFX/Music buses, per-sound mix and pitch variance, and a retrigger guard
  (harvest-all sounds like one harvest, not twenty). Settings persist in `user://settings.cfg`.
- 19 synthesized one-shots and 2 seamless ambience loops (island pad, river water + birds). All are generated by
  `python dev/gen_audio.py`, so there are no third-party assets or licences.
- Ambience cross-fades between the island and the river. A ♪ toggle sits in the top bar.
- Every `UI.button` clicks.

**Motion**
- New `Fx` autoload: floating numbers, coins that fly on arcs into the coin counter, sparkles, elastic punch,
  screen flash, banners and an in-place counter. It is capped at 160 live nodes and cleans up after itself.
- The coin counter rolls toward the real value instead of jumping.

**Island feedback** (`scripts/island_feedback.gd`)
- Feedback comes from a per-frame state snapshot diff, so it only celebrates what actually happened.
  A failed action buzzes and shakes the toast; it never shows fake coins.
- Covered actions: tap, harvest (single and all), empty harvest, sale (premium catalyst callout), build, expand,
  upgrade (banner and flash), blind box, hire, spend, and new discovery (banner).
- **Tap combo**: rapid taps raise the pitch, grow the "+2" and show a 连击 ×N meter, with sparkles every 10.
  It is feel only; the economy is untouched.
- **Tap a reactor in the 3D world to harvest it** when it has output. If it's empty, the tap just selects it,
  as before.

**Atom editor**
- The match meter ramps from coral to gold to mint and ticks with rising pitch as you drag.
- Stars (★ ≥ 80 %, ★★ ≥ 93 %, ★★★ ≥ 98 %) appear next to the match percentage.
- Reaching ≥ 98 % plays the "完美契合！" celebration: chord, mint flash, banner and a glowing atom pop.
  It re-arms below 96 % so it can't spam.

**River (first pass)**
- Chop, dig, fill, strike, build, plant, gather, water, feed, pack and unfold each get their own sound.
- Tool impacts give a short first-person camera dip. Footsteps play while walking.
- A failed command buzzes instead of playing the success sound.

**Tooling**
- `dev/run_tests.sh`: batch runner. UI tests that need a renderer run windowed; the rest run headless.
- `dev/capture_juice.gd`: screenshots of the combo, harvest and perfect-fit effects (to `artifacts/juice/`).
- `tests/test_juice.gd`: autoloads, sound imports, node cap, classify table, stars, combo, tap-harvest,
  rolling counter, and river action→sound mapping.
