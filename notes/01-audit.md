# 01 · Audit of Atom Atelier at v0.21.0-interiors-18

Scanned 2026-09-29. Godot 4.7.2, GDScript, GL Compatibility renderer, ~190 scripts, 62 headless tests.

## What the game is

1. **Floating island (core loop).** Tap for coins → reactors auto-produce molecules → drag atoms in a
   3D editor to match real geometry (better match = more coins/s) → sell to visiting buyers → spend
   catalysts/materials to upgrade reactors and expand plots → hire engineers/doctors/professors.
2. **River bay / frontier (3D, first person).** Chop/plant trees, dig terrain, voxel-build with parts
   crafted on the island, ranch animals, villagers, organic fertilizer chemistry, three "eras",
   8 km streamed terrain, walkable residence interiors, and a *miniaturizer* that shrinks your build
   and puts it on a shelf back home.

## What is genuinely great (keep & amplify)

- **"Science is the skill."** Tuning bond lengths/angles directly raises income
  (`atom_editor.gd:392`, scoring `lab_state.gd:478-518`). Nobody else has this hook.
- **Element swaps as discovery** (H₂S, HCl, perovskites…) — a natural collection game.
- **Living diorama.** Residents walk roads, buyers bike in with order bubbles, buildings can be
  long-press moved. The isometric island already *looks* charming.
- **Miniaturizer** — build something in the wild, shrink it, display it at home. Very shareable.
- **Material provenance** — every block remembers the batch it came from.
- **The light-bridge shader** (`island_light_bridge.gd`) shows the visual ceiling is higher than
  the rest of the game currently reaches.
- **Engineering discipline.** Versioned saves with migration, 60+ tests, reproducible builds.

## What is hurting fun (evidence)

### A. Zero game feel ("juice")
- **No audio at all** — no AudioStreamPlayer, no sound files in the repo.
- **No particles**, only 3 tweens in the whole island UI. Coin gains are a text toast
  (`main.gd:541`). Hitting trees = an unshaded sphere pulse; no hit-stop, shake, sound.
- Harvest is a sidebar button; the in-world "ready" marker is not tappable (`campus_view.gd:332`).

### B. Spreadsheet UI and disclaimer fatigue
- 7 toolbar buttons + 5 left-panel buttons + 15 dialogs in `main.gd`. Everything is a panel.
- Main surfaces show raw numbers (`%.2f 金币/秒`, fingerprints, "编辑费 0", ledgers) and repeated
  scientific caveats. The caveats are honest and valuable — but they belong in a codex, not in the
  player's face every second.
- Era progress in the river is a list of `1.0 / 3.0` checkboxes in a side panel.

### C. Pacing punishes the player
- Reactors hold 5 units and **stop** when full (`lab_state.gd:577`); ~2 min to fill; no offline
  progress → chores, not decisions.
- Expansion needs 2+ of *each* of 3 materials at a 20 % drop rate → ~10 min per plot early.
- Editing wipes the reactor's stock → experimenting feels risky instead of playful.
- Once a molecule hits ~98 % match it is "solved"; thin skill ceiling.

### D. Weak goals
- Onboarding = 4 hard-coded quest steps + a static help dialog. No achievements/milestones.
- The 16 km frontier is repeated noise; every 64 m cell spawns the same site
  (`river_population.gd:32-43`). Nothing out there is worth bringing home. River → island economy
  is almost one-way.
- You can permanently kill villagers (`river_combat.gd`) — grim for a cozy game, adds no loop.

### E. Visuals below the concept
- Everything is vertex-coloured primitive boxes; flat background (no sky), water = stacked cubes,
  rigid single-mesh animals ("resting" = halve `scale.y`), 60-second days make light pulse.
- 3D views are fixed-size SubViewports inside absolute-pixel UI (1440×900) — never fullscreen.

### F. Tech debt that slows every feature
- God objects: `lab_state.gd` (1562 lines — economy, plots, market, campus, saves, validation),
  `main.gd` (1328 lines — all UI, input, dialogs, a 210-line visual test).
- No autoloads, no signals bus: UI polls `notice` strings every frame; every action rebuilds the
  whole sidebar and world.
- Hot-path perf issues in the river (aim ray-march 125 samples × chunk dict rebuilds, every 0.12 s;
  full island rebuild on LOD change).
- Scope creep: ~20 releases of breadth (ecology, WWI/WWII, dinosaurs… later retired) instead of depth.

### G. Pre-existing test status at baseline
See `CHANGELOG.md` → "Baseline" for the exact pass/fail list captured before any change.
