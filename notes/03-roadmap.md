# 03 · Rollout roadmap

Each release = its own branch + annotated tag, all tests green (or pre-existing failures documented),
save-compatible. Status markers: ⬜ todo · 🟨 in progress · ✅ done.

## v0.22.0 "Juice" — the island finally feels alive  ✅
Goal: same systems, 10× the feel. Lowest risk, highest payoff.

- ✅ **Audio foundation**: first autoload `Sfx` (pooled players, pitch variance, buses Master/SFX/Music,
  mute + volume persisted in `user://settings.cfg`).
- ✅ **Synthesized sound bank** (`dev/gen_audio.py` → `assets/audio/*.wav`): tap, coin, harvest, sell,
  build, upgrade, perfect-fit chord, error, UI click, whoosh, discovery fanfare, chop, dig, step, pop;
  plus 2 looping ambiences (island pad, river water+birds).
- ✅ **Juice autoload `Fx`**: floating text, coin burst that flies to the coin counter, button punch,
  screen flash; all tween-based (cheap on mobile).
- ✅ **Wire feedback into the island**: tap/click, harvest (single & all), sell/deliver, build,
  expand, upgrade, blind box, hire, errors.
- ✅ **Tap-combo**: rapid taps build a small combo (rising pitch + bigger popups + 连击 meter; feel only, no economy change).
- ✅ **Tap a reactor in the 3D world to harvest it** (keep sidebar button).
- ✅ **Atom editor feel**: match meter colour ramp, pitch-rising tick while dragging, PERFECT FIT
  celebration at ≥ 98 %, star rating display.
- ✅ **River feel (first pass)**: chop/dig/gather/place sounds, ambient loop, camera kick on hit.
- ✅ Settings: sound toggle button in the top bar.
- ✅ Tests: new `tests/test_juice.gd` (autoloads load, sounds exist & import, combo math, no errors).

## v0.23.0 "Goals" — always know what's next  ✅
- ✅ Data-driven milestone track (`data/milestones.json`, 20 goals) with rewards, quest-bar progress and a claim button.
- ✅ Goal list dialog (doubles as the "firsts" record; a separate achievement page was folded into it).
- ✅ Reactor buffer 5 → 12 base; capped offline catch-up (2 h at 50 %), "welcome back" summary.
- ✅ Edits no longer wipe stock (this was already true: the old batch goes to the toolbox).
- ⏭ Collapse science caveats in the HUD into ⓘ tooltips → moved to v0.25 "Looks".
- ✅ Save v22 + migration test (reached goals settle without payout).

## v0.24.0 "Discovery" — collect the periodic table  ✅
- ✅ Structure codex: 4-column card grid, rarity by atom count (常见/稀有/珍贵/传说), locked "？？？" cards
  with unlock hints, tap a card for its entry.
- ✅ First-synthesis card-flip reveal (face down → flip to rarity/formula/stars, sparkles + tinted flash).
- ✅ 1–3 stars per structure from the best *harvested* batch fit; the editor shows the codex best.
- ✅ Star total hands out 8 decoration gifts (into the toolbox; exploration props unlock).
- ✅ Save v23 + migration (codex seeded from current samples, reachable gifts settle without payout).
- ⏭ Element sticker book / element deposits in frontier biomes → v0.26 "Frontier with purpose".

## v0.25.0 "Looks" — a world worth screenshotting  ✅
- ✅ Slow cosmetic day/night on the island (16 min, ~70 % daylight, wall-clock based, never saved):
  sun pitch/yaw/colour, ambient and sky follow keyframes. Glow materials and reactor glass brighten at night.
- ✅ Stylized island sea (replaces the studio floor): shore foam and shallows come from a baked
  distance mask that follows every expansion. Glass/fresnel shader for reactor chambers.
- ✅ Tree/bush sway shader that still merges into static batches.
- ✅ Time of day in the LIVE badge; editor rules caveat folded behind ⓘ.
- ⏭ River: sea/water shader, fullscreen 3D + overlay HUD, tap-to-interact, per-chunk caches → later
  (the river scene is large and has its own pre-existing touch-test failures to fix first).
- ⏭ Limbed animals/villagers with walk swing → v0.26 (fits the frontier villagers).

## v0.26 → v0.36: Earth, timelines, specimens, more planets  (new direction, 2026-09-30)
The user asked for island materials that reshape a planet's environment, huge worlds, per-planet timelines
(ice age → AI future) with era events and wars, natives who build and repair, and specimen/model collecting
as a core pillar. Earth comes first. The full breakdown and release slicing is in **[06-planets.md](06-planets.md)**.

- **Order (user OK'd v0.26 Bedrock first, 2026-09-30):** see [07-world-blocks.md](07-world-blocks.md) and [08-chemistry-loop.md](08-chemistry-loop.md).
- ✅ v0.26 "Bedrock" (tag `v0.26.0`): voxel ground (cube/slab), dig/place any cell, real-mineral geology, analyser, mineral codex. Slopes deferred.
  Stabilise the river touch tests first.
- ✅ v0.27 "Hometown" (tag `v0.27.0`), inserted at the user's request (2026-10-01; see [09-island-town.md](09-island-town.md)):
  a tile grid with several buildings per plot, build mode, a coin courtyard shop, pedestals, tier looks and a 400-plot cap.
- ✅ v0.28 "Refinery" (tag `v0.28.0`; see [10-refinery.md](10-refinery.md)): minerals → real processes → elements; seawater/air trickle
  on the island; **element shop removed**. Also reactor tiers (flask → kettle → autoclave → plasma), the visible doctor install,
  phase visuals, return-where-you-came-from navigation and first-time tours.
- ✅ v0.29 "Index" (tag `v0.29.0`; see [11-index.md](11-index.md)): offline chemistry index from Materials Project and PubChem
  (COD deferred); real properties, 3D structures and sources in the codex; substitution reaches real compounds.
- ✅ v0.30 "Fabricator" (tag `v0.30.0`; see [12-fabricator.md](12-fabricator.md)): crystals → pick heads (hardness from
  MP elastic moduli, Chen 2011) and refinery solar panels (Shockley–Queisser at the MP gap); rocks slow a soft pick;
  Fe and Sn smelting. Machines and emitters move to v0.31.
- ✅ v0.31 "Builder" (tag `v0.31.0`; see [13-builder.md](13-builder.md)), inserted at the user's request: seamless
  12×12 plots with items crossing plot edges, undo/Ctrl+Z, eraser and one-click recycle, doctor and element gates
  for reactors, templates and element swaps.
- ✅ v0.32 "Earth" (tag `v0.32.0`; see [15-earth.md](15-earth.md)): a 64×64 climate field over the 16 km planet,
  five biomes, four environment machines from the workshop (sprinkler, O₂ tower, CO₂ tower, fertiliser spreader),
  global CO₂ warming (3 °C per doubling), biome-tinted ground and decor, and the 环境图 overlay map.
- ✅ v0.33 "Polish" (tag `v0.33.0`; see [16-polish.md](16-polish.md)), user request: day-cycle sky and sun shadows, shaded
  first-person hands and tools, chibi island residents by role, rigged planet animals/villagers/visitors with gaits, birds,
  and a flowing water shader. Display only.
- ✅ v0.33.1 "Test build + Earth usability" (tag `v0.33.1`; see [17-testbuild-earth-ux.md](17-testbuild-earth-ux.md)), user
  request: 测试版 with its own save and test panel; depot by E, era rows with action buttons, 微缩器 preview, god view
  that follows you, beacons, walked trail, 世界地图; floating sky-blue springs and tundra ice fixed.
- ✅ v0.33.2 "Terrain & caves" (tag `v0.33.2`; see [18-terrain-caves.md](18-terrain-caves.md)), user request: real
  relief beyond the start area, ridged mountains, a river valley, karst caves with open mouths; old far builds keep their ground.
- ✅ v0.34 "Starforge Isle" 星锻岛 (tag `v0.34.0`; see [19-starforge.md](19-starforge.md)): phase-2 slot I1 —
  岛主 XP bar, 工业信用, island Ⅱ deck, metallurgy + polymer works, trade hub, steel drill bit, Blender models.
- ✅ v0.35 "Home & Market" (tag `v0.35.0`; see [21-home-market.md](21-home-market.md)): promotions with 延毕 and approval,
  星锻公寓, senior staff, home goods studio, contracts + airship.
- ✅ v0.36 "Weather & Specimens" (tag `v0.36.0`; see [22-incidents-specimens.md](22-incidents-specimens.md)): era framework in data,
  storm/flood/drought incidents with a day of warning and measured preparation, PVC pipes, 标本图鉴.
- Next: v0.37 industry — Si/Ca/P, MP refetch (more fields), ceramics/glass, silicon foundry, material property model v1.
- Backlog the user listed on 2026-10-07 (to fold into the interleaved plan in [14-industry-island.md](14-industry-island.md)):
  more element ores (P from apatite etc.; Cs exists but is very rare), gear upgrades, settlement/community upgrades,
  and the remaining eras.
- Phase 2 "浮岛2.0 / Starforge Isle" (see [14-industry-island.md](14-industry-island.md)): a second island with an
  industry chain molecule → material → chip → energy → goods → vehicles → gear → space; products go to the backpack
  for use on the planet. Draft numbering v0.34–v0.41; how it interleaves with the eras below is an open question.
- "Specimens": extractor on creatures and native buildings, island museum, specimen codex.
- v0.32 "Ice Age": timeline framework, mammoths and a tribe, time gate.
- v0.33 "Settlers" · v0.34 "Bronze" (tech diffusion) · v0.35 "Clash" (event director, first wars).
- v0.36–0.38 more eras · v0.39 wrap-around big world · v0.40+ star map and a second planet.
- The old v0.26 "Frontier with purpose" items fold in: landmarks → era events, element deposits → L1/L5,
  village orders → L4, light-bridge warp → time gate.

## Later / ideas parking lot
- Shareable miniature codes (export a build as a short string/QR).
- Weekly "molecule challenge" seeds (deterministic, offline).
- Haptics on Android (`Input.vibrate_handheld`).
- Fix the 17 pre-existing touch/click UI test failures (see CHANGELOG baseline).
- Split `lab_state.gd` / `main.gd` into modules as features touch them (opportunistic refactor).
