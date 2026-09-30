# 09 — Island town: free placement, decorations, pedestals, visible tiers

User request (2026-09-30), summarised:
- Buildings of different levels and reactors of different upgrades should look different.
- When a doctor loads elements and a compound's state changes, this needs its own look and UI animation.
- Is the island finite? Could it be infinite?
- Several buildings per plot instead of one.
- Hay Day–style coin decorations (fences, paths, others) and pedestals for models brought back from planets.

## Current state (verified in code)
- **Island size:** the island is a plot grid that grows from the start. Opening a plot costs materials (`lab_state.gd` `buy_plot`, `plot_cost`). It is hard-capped at 128 unlocked plots (`MAX_UNLOCKED_PLOTS`), with 3 m pitch.
- **One building per plot:** each plot has one `kind` string. `place_reactor`, `campus_build`, `move_building` and `building_drag.valid_target` all require `kind=="empty"`. A plot also takes up to 8 props in fixed edge slots, plus a road flag. There is no demolish or sell.
- **Building levels:**
  - `campus_architecture.gd` already varies height and floors with level for the institute, dorm, canteen, workshop and professor apartment, and adds an annex to the villa.
  - The park and engineer house do not change.
  - Colour and material never change with level.
- **Reactors:**
  - Lv 1–20. The model is fixed; only up to 5 gold dots show the level (`world_view.gd` `_build_reactor`).
  - The doctor's install trip is a walk plus a tool swing; there is no visual of what goes in.
  - Phase (solid/liquid/gas) exists only as data in `organic_materials.json` and the river tank. The island has no phase visuals.
- **Decorations:**
  - Props: flower, bench, lamp, fence, trophy, plus 3 relics.
  - Old decorations take a whole plot.
  - `economy.json.decorations` is unused.
- **Pedestals:** river miniatures can be exhibited on a plot (`river_miniatures.exhibit`). There is one static cream pedestal per plot and no labels.

## Proposal
### v0.27 家园 Hometown — layout freedom
1. **Tile grid inside plots.** Each 3 m plot becomes a 6×6 grid of 0.5 m tiles.
   - Every building, reactor and decoration gets a footprint from data, for example a hut 2×2, a reactor 3×3, the institute 5×5 and a lamp 1×1.
   - A plot holds anything whose footprints fit.
   - Save migration: existing buildings are centred in their old plot, and old prop slots map to edge tiles.
2. **Build mode.** Pick an item, then see a ghost with green or red tiles; tap to place; rotate by 90°. Moving works with a long press, as today. "收起" returns an item to storage and "出售" refunds 50%.
3. **Coin decoration shop.** Every item is data-driven (price, footprint, unlock level):
   - fence segments that auto-join, with gates
   - path tiles: stone, wood and crystal, auto-connecting
   - hedges, flower beds, trees, lamps, benches, fountain, pond, signposts, flags
4. **Pedestals (展台).** Small stone, large, rotating turntable and glass case.
   - They hold v0.26 mineral specimens, river miniatures and, later, creature specimens.
   - Each pedestal has a label card showing name, formula, where it was found and when.
   - Filled pedestals add a small visitor-appeal bonus, so collecting feeds back into the island.
5. **Building tier looks.** Every building gets 3 visual tiers across its levels:
   - Tier 1: wood and plain walls
   - Tier 2: brick and trim
   - Tier 3: glass, solar panels and flags
   Upgrading plays an animation: scaffold, a dust puff, a squash-and-stretch pop, and a stars badge in the UI.
6. **Island size.** Raise the cap from 128 to about 400 plots. This needs a render budget and culling of far plots.
   - A truly infinite island is not planned. The planet (v0.26+, wrap-around 8 km) is the infinite frontier; the island stays the curated home base.
   - A later option is extra floating islets linked by bridges.

### v0.28 精炼 Refinery + furnace tiers (merged with the planned Refinery)
- Reactor looks at levels 1, 5, 10 and 15: glass flask → steel kettle → high-pressure autoclave → plasma furnace. Each tier gets its own shell, pipes, gauges and glow.
- Tiers also gate process conditions (temperature and pressure). This fits the Refinery, which turns v0.26 minerals into elements and replaces the element shop.
- **Visible install:** the doctor walks up and opens the hatch, and CPK-coloured element orbs arc into the chamber.
- **Phase visuals inside the chamber:**
  - solid: a growing crystal lattice
  - liquid: a fill level with a wave shader
  - gas: swirling particles, with the gauge needle rising
- **UI:** a phase badge (固/液/气) that morphs with a short tween when the state changes, a progress ring, and a "state changed" toast.

Order after this: v0.29 Index (MP/COD), v0.30 Fabricator, v0.31 Earth.
