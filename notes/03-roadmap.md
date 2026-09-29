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

## v0.23.0 "Goals" — always know what's next  ⬜
- Data-driven milestone track (`data/milestones.json`) with rewards and an in-world pointer arrow.
- Achievements ("firsts") with a toast + Codex page.
- Reactor buffer 5 → 12 base; capped offline catch-up (e.g. 2 h at 50 %), "welcome back" summary.
- Edits no longer wipe stock (old batch is kept, tagged with its old fingerprint).
- Collapse science caveats in the HUD into ⓘ tooltips.
- Save v22 + migration test.

## v0.24.0 "Discovery" — collect the periodic table  ⬜
- Molecule Codex with cards (rarity by complexity), first-synthesis reveal animation + fanfare.
- 1–3 stars per molecule (best match remembered), star totals gate cosmetic rewards.
- Element sticker book; element deposits placed in frontier biomes feeding island reactors.

## v0.25.0 "Looks" — a world worth screenshotting  ⬜
- Procedural sky + slower day/night (10–20 min), sun direction follows time, fog tinted to sky.
- Water shader strip for the river & island sea; glass/fresnel shader for reactors.
- Tree sway vertex shader; limbed animals/villagers with walk swing.
- Fullscreen 3D + overlay HUD for the river; touch tap-to-interact.
- River perf: per-chunk tree cache, remesh only dirty chunk, incremental island LOD.

## v0.26.0 "Frontier with purpose"  ⬜
- Unique landmarks instead of repeated sites; boars guard rich deposits; villagers non-lethal.
- Village orders (reuse island buyer system) → coins/catalysts flow back to the island.
- Walkable light-bridge warp; miniaturizer shrink-ray effect.

## Later / ideas parking lot
- Shareable miniature codes (export a build as a short string/QR).
- Weekly "molecule challenge" seeds (deterministic, offline).
- Haptics on Android (`Input.vibrate_handheld`).
- Fix the 17 pre-existing touch/click UI test failures (see CHANGELOG baseline).
- Split `lab_state.gd` / `main.gd` into modules as features touch them (opportunistic refactor).
