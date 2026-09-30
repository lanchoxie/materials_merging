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
- v0.28 "Refinery": minerals → real processes → elements; seawater/air trickle on the island; **element shop removed**.
  Also reactor tiers (flask → kettle → autoclave → plasma), the visible doctor install and phase visuals.
- v0.29 "Index": offline chemistry index from Materials Project / COD / PubChem; real properties in the codex.
- v0.30 "Fabricator": compounds → gear, machines, emitters; stats from real properties (closed loop).
- v0.31 "Earth": environment field (planet + region grid), emitters, biome shifts.
- v0.31 "Specimens": extractor on creatures and native buildings, island museum, specimen codex.
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
