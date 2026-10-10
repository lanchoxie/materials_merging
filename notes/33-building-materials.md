# 33 · v0.44.0 "Building Materials" (百工建材): doors, windows, boards, bricks, roofs × 4 materials

Step 3 of the 2026-10-11 plan.

> 我们还需要更多的建筑材料，比如门窗板砖屋顶，除了木制的还需要石制品和其他塑料或者金属制品。

## The catalogue (data-driven)
`data/river_construction.json` gains two tables:
- `materials`: wood, stone, plastic and metal, each with a body colour and a trim colour;
- `shapes`: the five shapes below.

Each shape × material pair is a kind `<shape>_<material>`, built from the workshop recipe `field_<shape>_<material>` (20 recipes, listed as 「建材 · …」). Existing kinds, recipes, units and costs are unchanged.

| Shape | Per pack | Solid | Notes |
|---|---|---|---|
| 板 slab | 8 | lower half of the cell | floors, shelves; a slab is a 0.5 m step (walker step 0.62 m), so slabs make stairs; roofing |
| 砖墙 brick | 8 | full | mortar courses (wood/stone), trim bands (plastic), ribbed panels (metal); counts as a wall; roofing |
| 门 door | 2 | 2 cells; none when open | E opens/shuts; faces the builder (`rot`); won't shut on you |
| 窗 window | 4 | full | frame + see-through glass pane; counts as a wall; faces the builder |
| 坡屋顶 slope | 8 | a ramp 0.05→1 rising away from the builder | walk up it; roofing; tile lines |

**Costs.**
- Wood and stone use planet raw materials (`natural_inputs`). For example: wood brick 4 timber, stone slab 2 stone, stone door 3 stone + 1 timber, wood slope 2 timber + 2 fibre.
- Plastic uses 聚乙烯粒料 (`pe`) and metal uses 碳钢锭 (`steel_ingot`), both from the 星锻岛 store (`industry_inputs`). A brick costs 2; every other shape costs 1 for a whole pack. One steel ingot (Fe 6 + C 1 makes 2) roofs 8 cells, which keeps metal cheap; the coming 盾构机 makes Fe cheaper still.
- Every window also takes one 钠钙玻璃板 (`glass`) from 星锻岛.

## How it works
- **Construction** (`river_construction.gd`):
  - `shape_of(kind)` reads the shape.
  - `occupant(cell)` returns the block filling a cell, including a door's upper cell.
  - `solid_height(block, cell, point)` gives 0 for an open door, 0.5 for a slab, the ramp height for a slope, and 1 otherwise.
  - `overlaps`, `floor_at`, `trace`, `place_error` and `connected` all go through them. The walker, the rover, ranch animals and the settlement get partial cells for free.
  - `facing_rot(direction)` snaps the builder's look direction to 0–3. It is stored as `rot` on doors, windows and slopes; doors also store `open`.
  - `toggle_door(key, actor)` opens and shuts doors; it is the `v2_door` command.
  - `count_walls()` counts the old wooden block plus every kind with `wall`. The settlement's "blocks" goal uses it, so stone, plastic and metal walls count.
- **Planet E.** Aiming at a door shows 「E 开门 / 关门」. E toggles it unless the 拆卸锤 is held. A door's ghost is two cells tall and a slab's is half a cell.
- **Drawing.**
  - `Components.piece()` draws each shape in the piece's local frame and turns it by `rot`. The slope is a real wedge with outward-wound faces.
  - Window panes go on a second, alpha-blended surface per chunk (`glass_material`), so you can see through them.
- **Workshop.**
  - `river_field.crafting_error/reserve/cancel` take `state.industry`. Packing takes the 星锻岛 items and records them on the craft (`industry`); cancelling returns them as fresh standard lots.
  - The workshop page lists 星锻岛 inputs with stock, and says why a recipe can't start.
  - The copy desk prices and takes 星锻岛 inputs too.
- **搭建 tab.** A compact 建材 card: a 5×4 grid of the parts (each opens its workshop page) and a one-paragraph guide. The 20 recipes stay out of the 「加工 ·」 button list.

## Save
- Construction stays at version 1. New optional block fields:
  - `rot` (0–3) is only allowed on rotating shapes;
  - `open` (bool) is only allowed on doors;
  - a door needs its upper cell free and within the height limit.
- Field craft records may carry `industry`, which must equal the recipe's `industry_inputs`; a record missing its inputs is rejected.
- Older saves have neither field and load unchanged.

## Verification
- **`tests/test_building_materials.gd`** (40 checks):
  - the 20-part catalogue: units, planet vs 星锻岛 inputs, glass in every window, 建材 names;
  - plastic crafting: refused without PE, takes and records PE, saves in flight, tampered record rejected, cancel refunds, six packs debit the store;
  - door: placement and facing, upper cell, blocks when shut, 开门 prompt, E opens, walk through, won't shut on you, shuts, upper cell refused, a walker is stopped then passes;
  - slab: half-height top, stand on it, walk up onto it;
  - slope: faces +x when built facing +x, the ramp climbs, roofing flags;
  - window blocks; wall count and settlement metric;
  - all 20 parts draw in 4 rotations with panes on glass, and a chunk gets a glass surface;
  - save keeps doors open; bad `rot`/`open` rejected;
  - the copy desk charges steel for a metal roof.
- **Existing tests** pass unchanged: `test_river_field(_ui)`, `test_wild_harvest`, `test_sandbox12(_ui)`, `test_frontier17(_ui)`, `test_ranch13(_ui)`, `test_river_inventory(_ui)`, `test_river_play(_ui)`, `test_incidents`.
- **`tests/capture_materials.gd`:** screenshots in `docs/screenshots/v0.44.0/` (a stone house with glass windows, a wooden door, metal slopes and plastic slabs; the open door; inside; the metal-window workshop page).
