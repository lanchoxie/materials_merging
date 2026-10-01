# 13 · v0.31 "Builder": easier building, real gates on doctors and elements

The user asked for this tidy pass after v0.30, before starting Earth (now v0.32). Request on 2026-10-01:
- Some buildings still take a whole plot.
- Paths are hard to undo.
- They want a one-click recycle and an undo button while placing.
- Buildings should span plots, with no visible gap between plots.
- Without a doctor, or without the elements, you must not be able to build the matching reactor or substitute elements.
- Without a doctor you must not be able to change molecules, and the game should say what to do.

Decisions the user picked:
1. With no doctor, **coordinate tuning stays allowed**. Composition, connectivity, template and new-reactor changes are blocked.
2. Building a reactor **costs the template's elements**. Changing the template costs only the net new atoms.
3. One-click recycle works **per plot and island-wide** (paths and decor go to the toolbox; buildings and reactors are not recycled).

## Findings (before the change)
- **Plot connectivity** is plot adjacency (`campus_layout.road_links`). The thin edge roads are only drawn.
  - Tile row/column 11 was reserved for them (`usable: 11`).
  - The grass top is 2.82 m on a 3 m pitch, which leaves a 0.18 m soil seam between plots.
- Items live in their plot with local tiles 0..10. Occupancy, `fits` and the load validator are per plot, and build mode clamps the ghost inside one plot.
- A reactor is a fixed centre 8×8 with no anchor. Nothing else may go on a reactor plot.
- No doctor check exists anywhere.
  - A queued install with no doctor waits forever, silently.
  - The only "is a doctor free" logic is `organic_synthesis.logistics` (hint only).
- Building a reactor costs 100 coins and no elements. Changing the template costs 25 coins and no elements.
- The atom-editor palette lets you pick elements you have 0 of; only the final quote refuses.
- Build mode has no undo or eraser. Decor is removed one tap at a time (收起 / 出售).

## Design
### Town grid
- `usable` is 12: every tile of a plot can be built on.
  - The edge-road drawing goes, and connectivity is unchanged (adjacency).
  - Unlocked neighbours' grass meets edge to edge: one continuous lawn.
- **Global tiles**: tile (x, z) of plot p is (p.x·12 + x, p.z·12 + z).
  - An item still belongs to the plot that holds its **anchor** tile (local 0..11), but its footprint may spill into neighbours.
  - Occupancy is built island-wide.
  - Every covered tile must be on an unlocked plot that isn't the plaza, a legacy whole-plot kind, or under a reactor.
- Buildings (main and extra) keep their anchor in their own plot, because residents, capacity and cupboards key on the plot.
  - They can spill across the edge. Decor can move anywhere.
  - Long-press relocation of a whole plot stays as it is.
- **Reactors become footprint items**: anchor `at` (default [2,2]), 8×8, movable within their plot in build mode.
  - Buildings and decor may use the rim around them.
  - A reactor plot can't take a *main* building, but it can take extra buildings, which are pooled as before.
- Save **v27**: items may spill, and reactor plots may have `at`. A v26 save is a valid v27 save, but v0.30 can't read v27.

### Build mode
- **Undo** (撤销 button and Ctrl+Z): a journal of this build session.
  - Place → take back (coins refunded if paid, toolbox stock returned if used).
  - Move → move back. Erase → put back.
- **Eraser** (擦除 tool): drag over paths/decor and each touched item goes to the toolbox. Each step is undoable.
- **One-click recycle**:
  - The plot sidebar has 回收本地块装饰与小路 (N) with a second-tap confirm.
  - The build HUD has 回收全岛小路 (undoable within the session).

### Doctor and element gates
- `LabState.install_status() -> {ok, message}`: ok when at least one doctor is on post auto or logistics (the posts that install).
  - Messages: "需要装炉博士：先建博士公寓与科研院所，再招募博士" / "博士都在其他岗位：安排一位博士负责装炉".
- Gated (after the existing plot/space checks, so their messages keep priority):
  - `place_reactor`, `change_template`;
  - `edit_quote` / `sandbox_reactor_quote` when atoms, bonds or composition change.
  - Coordinate-only edits stay free.
- Elements:
  - `place_reactor` takes the template's atoms.
  - `change_template` takes the net new atoms (refunded on cancel, like edits).
  - New quotes `reactor_quote(plot, template)` and `template_quote(index, template)` drive the template list: disabled buttons with cost, stock and reason.
- Palettes (atom editor, structure workshop):
  - Elements with 0 stock are disabled, with "where to get it" text (the refinery's source hint).
  - With no installing doctor, composition tools are disabled and a banner explains what to do. Dragging atoms still works.
- Help, tour and milestone hints mention the doctor.

## Tests
- New `test_builder` (logic) and `test_builder_ui`.
- Update the tests the scouting listed: test_state, test_hometown(+ui), test_organic15, test_reactor_looks, test_structure_start, test_release(+ui), and the fixtures `install` helper (hire a doctor first).

## As built (differences from the design above)
- **Reactors stay centred** (8×8 at [2,2], no `at`, not movable).
  - Too much depends on the fixed centre: reactor views, install orbs, walk surfaces, residents' paths and the legacy layout.
  - The rim (tiles 0–1 and 10–11) is now usable for decor and *extra* buildings. A reactor plot still can't take a main building.
- **The undo journal is state-level** (`LabState.town_journal`), not per build session.
  - So the sidebar's ↶ 撤销 and Ctrl+Z also work after build mode closes.
  - It holds up to 40 groups and isn't saved; it is cleared on load.
  - One drag stroke or one recycle is one group (`town_group_begin/end`).
  - Undo refuses a building that is already in use (residents moved in) or upgraded.
- **Spill rule:** an item's anchor must be on the selected plot (local 0..11). Since the largest footprint is 8, it reaches at most one plot over.
  - `island_cells` reads plots within Chebyshev distance 2 rather than caching a whole-island map.
  - A moved building keeps its anchor inside its source plot.
- **Gate order:**
  - In `reactor_quote` / `template_quote` the order is: validity, then space, then coins, then doctor, then elements. So the first missing thing is named.
  - `sandbox_reactor_quote` computes the required elements before the doctor check. This keeps `organic_synthesis.status` listing the missing elements even with no doctor.
- **A queued install still finishes if the doctor leaves later.** The gate only applies when you queue.
  - The pending job keeps saying a logistics doctor is needed.
- The visual-test path in `main.gd` and the benchmarks stock a legacy doctor and elements before building reactors.

### Known limitations
- Residents still walk along the old plot-edge lines. Items placed on row/column 11 can stand in their way (cosmetic).
- Island-wide path recycle collects every path, including ones painted in v0.27–v0.30 saves.

### Tests
- `test_builder` (~50 checks):
  - spill, locked land, reactor rim, undo (place/move/store/toolbox/stroke/building), recycle, save v27 round trip and validator, and the gates.
- `test_builder_ui`:
  - seam-spanning path via taps, HUD undo/eraser/island recycle, sidebar two-tap recycle and undo, Ctrl+Z, template dialog banner and disabled buttons, editor lock, building with elements.
- Updated:
  - test_state (save 27), test_hometown, test_campus_view (no ConnectedRoads), test_campus_integration, test_organic15, test_reactor_looks (net-new orbs), test_structure_start and test_release_ui.
  - capture_player_gallery and both benchmarks.
