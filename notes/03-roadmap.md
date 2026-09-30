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

## v0.26.0 "Frontier with purpose"  ⬜
- Unique landmarks instead of repeated sites; boars guard rich deposits; villagers non-lethal.
- Village orders (reuse island buyer system) → coins/catalysts flow back to the island.
- Walkable light-bridge warp; miniaturizer shrink-ray effect.
- Element deposits in frontier biomes feeding island reactors; element sticker book (moved from v0.24).

## Later / ideas parking lot
- Shareable miniature codes (export a build as a short string/QR).
- Weekly "molecule challenge" seeds (deterministic, offline).
- Haptics on Android (`Input.vibrate_handheld`).
- Fix the 17 pre-existing touch/click UI test failures (see CHANGELOG baseline).
- Split `lab_state.gd` / `main.gd` into modules as features touch them (opportunistic refactor).
