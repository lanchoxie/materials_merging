# 07 · Blocks, digging and geology: borrow Minecraft's grammar, keep our own chemistry (2026-09-30)

User question: the planet terrain today is not block-shaped, which will make building, digging, native
building/repair and model extraction awkward. Should we copy Minecraft, or design our own
build/dig/mineral/element-collection system?

## Today (why it feels off)

| Piece | Current representation | Problem |
|---|---|---|
| Ground | 2D heightmap, 1 m columns, natural heights in 0.14/0.16/0.28 m terrace steps (`river_terrain.natural_height`) | Ground height does not line up with the 1 m block grid; no overhangs, caves or underground |
| Dig/fill | integer offset per column, ±6 m (`river_nature.terraform`, 4096 edits) | Can only raise/lower a whole column; nothing to find underground |
| Building | sparse 1 m cubes, 512 cap, 8 high (`river_construction`) | Separate from the ground; floats or sinks into terraced ground |
| Extractor | own blocks only, ≤64 in 8×8×8 | Can't capture terrain or native buildings |
| Elements | bought with coins in the element shop (14 elements) | The planet does not feed the island at all |

## Recommendation: hybrid

**Borrow Minecraft's grammar** (the part that is a solved problem):
- The world is a **1 m voxel grid**; ground, player builds and native builds are all the same cells.
- Dig a cell → get that material. Place anywhere adjacent. Chunks 16×16, vertical sections of 16,
  height −64 … +64 m. Only diffs against the procedural generator are saved (same as now, just 3D).
- Reasons: building feels right immediately; natives can build and **repair** by diffing against a stored
  blueprint; the extractor becomes "select a box of voxels"; digging creates caves and ore hunting.

**Design our own on top** (what makes it this game and not a Minecraft clone):
1. **Every block is a real material.** Minerals have real formulas: 石英砂 SiO₂, 方解石/石灰岩 CaCO₃,
   岩盐 NaCl, 赤铁矿 Fe₂O₃, 孔雀石 Cu₂CO₃(OH)₂, 锡石 SnO₂, 方铅矿 PbS, 萤石 CaF₂, 铝土矿 (gibbsite Al(OH)₃),
   煤 (mostly C), 硫磺 S, 锂辉石 LiAlSi₂O₆, 铯榴石 (rare Cs), 冰 H₂O. Rocks that are mixtures (granite,
   basalt, soil) are labelled as mixtures with typical composition, never a fake single formula.
2. **Scanner (分析仪)** — NMS-style visor: look at any block, creature or building to read its composition.
   The same tool later drives specimen scanning (L2). This is the educational hook.
3. **Planet → island → planet loop.** Mined minerals go to a new island **refinery** that uses real
   processes: smelt hematite with carbon → Fe (+CO₂), electrolyse brine/halite → Na + Cl₂, calcine limestone
   → CaO + CO₂, roast galena → Pb + SO₂. Outputs fill the existing `element_inventory`, so the atom editor gets
   supply from the planet. The shop stays as the fallback. By-products (CO₂, SO₂) count as emissions in the
   environment field (L1): industry has a cost, which is exactly what the later industrial era is about.
4. **Not just digging.** Air collector (N₂/O₂/CO₂/Ar by planet atmosphere), seawater/brine evaporation
   (Na, Cl, Br, Li, Mg), organics from plants/animals (C, N, P, Ca). Elements come from the whole planet.
5. **Softer shapes.** Cube + slab (½) + slope + post, so natural ground and buildings look like the low-poly
   island instead of pure cubes. Stylized vertex colours per biome; the v0.25 shaders carry over.
6. **Environment acts on blocks.** Water + nutrients spread grass onto soil; drought turns topsoil to sand;
   ice-age cold freezes water blocks; salinity whitens soil. The field (L1) becomes visible in the voxels.
7. **Geology per timeline/era.** Ice age surface has flint and obsidian; natives in the bronze era mine
   malachite and cassiterite themselves (L5). Ore depletion is per timeline save.
8. **Depth tiers.** Topsoil → clay/sand → limestone/sandstone → granite/basalt with veins → deep rare ores.
   Ore veins use deterministic noise from the planet seed.

New elements this adds to `elements.json` (science-honest, real data): Fe, Si, Ca, Sn, K, Mg, P
(Fe and Sn are needed for the bronze/iron eras and the metal cache emitter).

## Technical plan

- Storage: per chunk section a `PackedByteArray` of 16³ material ids (palette per planet). Save = RLE diff
  vs generator per touched section. Old saves migrate: heightmap edits → column fill/removal, old blocks →
  voxel cells, natural heights rounded to 1 m / ½ m slabs.
- Meshing: face-culling + greedy meshing per section on `WorkerThreadPool`, one ArrayMesh per section with
  vertex colours, collision from the same faces. GDScript first, behind a perf gate:
  **Android: 7×7 chunks visible (≈112 m, same as today) at 30 FPS; a section remesh < 8 ms on desktop.**
  If the gate fails, move only the mesher into a GDExtension (C++ or Rust via godot-rust). We avoid the
  godot_voxel *module* because it needs a custom engine build for every export target.
- Kept: chunk streaming, trees as objects on top of voxels, walker/controller (collision changes source),
  hotbar/backpack, combat, population, settlement AI (their "floor height" queries go through one
  `world.surface_at()` function, so switching the backend touches one place).
- World size stays 16.4 km for now; wrap-around + floating origin (L7) come later and don't depend on this.

## Effect on the release slicing (proposed, pending user OK)

Everything after this (native build/repair, building specimens, ore-driven tech revolutions) sits on voxels,
so the ground rewrite goes first:

| Release | Theme |
|---|---|
| **v0.26 "Bedrock"** | voxel ground + shapes, dig/place any cell, geology layers + 8–10 real minerals, scanner, save migration, perf gate. (Also fix the river touch tests first.) |
| v0.27 "Refinery" | island refinery (real processes → element inventory), air/brine collection, new elements, emissions |
| v0.28 "Earth" | environment field + emitters + biome shift on voxels (was v0.26) |
| v0.29 "Specimens" → … | as in 06-planets.md, each shifted by two |
