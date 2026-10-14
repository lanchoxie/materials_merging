# 39 · v0.50.0 "Comfort" (顺手): position memory, a bigger box, random drops, block textures

Four fixes the user asked for, done while the bigger items (crafting guidance, the crystal
workbench, Bronze/Clash) are planned.

## 1. The planet remembers where you stood
Before this, entering first person always put you back at the same spawn point (or the last
landmark you teleported to), so coming back felt like starting over.

- `planet.v2.walk` saves `{x, z, yaw, pitch}`.
- It is written by `view.remember_position()`, called every panel sync while you are walking and
  again when you leave first person. It is not written while you drive, fly or bore, so the machine
  you are sitting in doesn't overwrite it.
- Entering first person restores it, so you come back exactly where you left off, facing the way you
  were facing.
- Validation: the spot must be on the planet, and yaw/pitch must be sane numbers.
- Old saves have no `walk` key and keep spawning at home once more.

## 2. The miniature box is bigger: 16×16×16 and 256 blocks
The 8×8×8 box was too small for anything but a shed (the user's words: "that's not cool either").

- `river_miniatures.survey`: the footprint is now 16×16×16 and a box holds up to 256 blocks.
- `river_construction` save validation, the 我的材料 copy desk and the inventory description all
  follow.
- Old boxes keep working: they are simply under the new limits.

## 3. Drops are random 1-5
Quarrying and mining always gave exactly one unit per block, which made a mining trip feel flat.

| Drop | Before | Now |
|---|---|---|
| Timber (felling a tree) | 3–6 | 3–6 (unchanged) |
| Fibre (felling a tree) | 1–2 | **1–5** |
| 石料 (quarrying rock) | 1 | **1–5** |
| Ore (mining a mineral) | 1 | **1–5** |
| 土方 (topsoil) | 1 | 1–2 |

- Every roll is keyed by the block's coordinates (`dig:x:y:z`), so the same block always yields the
  same amount: no save-scumming by digging twice, and a restored cell digs the same again.
- The 盾构机 uses the same ranges per cut cell (`cut:x:y:z`), and now reports units, with
  `cut_cells` tracking the machine's own cell count.
- The yields live in `data/river_nature.json` (`ore_yield`, `stone_yield`, `drops.fiber.amount`) so
  they can be tuned without touching code.
- A store that is nearly full takes only what it can hold instead of refusing the whole block.

## 4. Blocks have real textures
Every block face was one flat quad, so granite, ore and sand all looked like flat paint.

- **`scripts/river_textures.gd`** builds a small texture atlas in code: one 16×16 greyscale tile per
  material in `data/minerals.json`, inside an 8×8 sheet. **No art files and no import step.**
  - Rock (granite, limestone, basalt, coal): coarse grains with a couple of dark cracks.
  - Minerals (hematite, galena, pollucite…): elongated bright crystals with dark edges, so ore
    sparkles.
  - Mixtures (sand, clay, topsoil): soft blotches.
- The detail is **greyscale and multiplies the per-cell vertex colour**, so a hematite wall stays red
  and 赤砂星's soil still reads as rust — the pattern is added on top of the existing palette,
  depth-darkening and snow/beach/shallow-sea colours.
- **Tile 0 is pure white** and every face that doesn't ask for a texture samples UV (0,0). So trees,
  buildings, animals, machines, the player's own blocks and the god-view meshes are byte-for-byte
  unchanged.
- `river_geometry.face_uv` is the new entry point; the old `face` now just calls it with no atlas
  rect, which keeps every existing caller working and unchanged.
- Generation is deterministic per material (seeded by the material id), so the atlas is identical
  every run and every chunk rebuild.

## Verification
- `test_bedrock`: a mined block now enters the backpack with 1–5 of its mineral, and placing one
  back spends exactly one.
- `test_wild_harvest`: quarrying granite gives 1–5 of the rock and 1–5 石料.
- `test_tbm`: cells and stored units are counted separately; the battery is charged per cell.
- `test_sandbox12`, `test_tbm_ui`, `test_farm_robots`, `test_building_materials` unchanged and green.
- Full suite re-run for the release.

## Still to come (from the same request)
- A branching "what can I make / what do I need" panel with missing buildings named in place.
- Where each element comes from, and a cheaper path to caesium.
- The crystal workbench: lattice parameters, periodic sites, snap-to-boundary.
- Gas/liquid/solid display for custom structures, and the atom-editing feedback gaps.
- Bronze (tech diffusion) and Clash (wars): damage resolved abstractly while you are away, fought
  out only when you are there.
