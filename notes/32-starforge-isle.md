# 32 · v0.43.0 "Starforge Isle" (星锻岛 · 第二浮岛): island Ⅱ like island Ⅰ

Step 2 of the 2026-10-11 plan.

> 第二个浮岛我们需要和第一个浮岛一样，而不是就是一个展示的模型，他也需要可以扩张和造建筑包括工人休息的建筑，以及可以摆放
> 我们的装饰和可以第一人称进入。

Design choice: everything stays inside `industry.gd` (island Ⅱ's own state). Buildings keep their keys (plot index), so staff homes, factories, furnishing, queues and the old tests stay valid. Island Ⅰ's code is reused where it is pure:
- `island_town.gd` tile rules;
- `town_decor.gd` mesh builders;
- `river_walker` and the exploration input;
- the residence interior.

## Expansion (扩建甲板)
- **`industry.deck`** is a list of `[x, z]` cells, one per plot index. Plots 0–15 default to the old 4-wide grid, so `plot_center(i)` is unchanged for every existing plot. `_sync_deck()` fills in cells for old saves and for code that sets `plots` directly.
- **Placement.**
  - `frontier()` lists free cells beside the deck, within the island bounds `plots.span` = [−3, 6].
  - `buy_plot_at(state, cell)` builds there.
  - `buy_plot` (the old button) takes the next old-grid cell, or else the first frontier cell.
- **Limits.** The cap went from 16 to 36 plots. The cost curve is unchanged.
- **Panel.** The 甲板 tab has a deck map: numbered plots tinted by their building, and ＋ on every cell you can build out.
- **Diorama.** Tiles sit at their cells and frontier cells show as holograms. The hull is a slab under each plot with a keel cone under the middle, and thrusters hang under the outermost plots. The orbit camera backs off for big decks.

## Buildings: 员工休息室 and staff stamina
- **员工休息室 (`staff_lounge`).**
  - A glass pavilion with sofas, a coffee bar and plants. The new Blender model is in `dev/blender/starforge.py` (`-- staff_lounge`).
  - 1800 coins + 12 credits, power 1, no licence.
  - Seats: 3, plus 2 per level, up to level 3.
- **Stamina** (`staff[].energy`, 0–100, and `resting`; rules in `industry.json` → `staff.energy`):

  | Rule | Value |
  |---|---|
  | Drain | only while the staff member's factory has a job running: 100 per `work_seconds` (480 game s) |
  | Tired at | 20, then resting is set and there's a note (「累了」) |
  | Recovery | 100 per `rest_seconds` (300 s) × apartment comfort (furnished up to +20 %), +100 % with a lounge seat |
  | Back at | 90, with a note (「休息好了，回到工厂」) |

  - Lounge seats go to resting staff in id order (`in_lounge`). Unassigned staff rest too.
  - No speed or yield bonus while resting.
  - Status words (`status_of`): 工作中, 待命 (line idle), 休息室, 公寓休息, 休息中.
- **人员 tab.** Shows a stamina bar and status per person, and explains the rule.

## Decorations on the deck
- **Storage.** `industry.deck_items` holds `{"plot": [{uid, kind, x, z, rot}]}` with island Ⅰ's 12×12 tile grid per plot.
- **Fitting.** `deck_plot(i)` presents a plot to `Town.fits`. A building plot counts as fully occupied, so decorations go on empty plots, and building on a decorated plot asks you to clear it first.
- **Sourcing.**
  - Pieces come from the shared toolbox (`storage.decorations`, the same as island Ⅰ's build menu).
  - Otherwise they are bought at the island-Ⅰ price, with island Ⅰ's locks: studio furniture is made, not bought.
  - `store_decor` puts a piece back in the toolbox.
- **Panel.** Each empty plot card lists what stands there (收回) and 摆<装饰> buttons, which use the first free spot.
- **Drawing.** The diorama draws decorations with island Ⅰ's builders (fences join, windmills turn).

## First person (第一人称登岛)
- **Screen.** `starforge_walk_panel.gd` reuses the diorama in `walk_mode` (no orbit, no bobbing) with the shared walker, the exploration input and first-person hands.
- **Surface** (`starforge_walk_surface.gd`): deck cells are walkable; factory plinths and decorations block (paths and flower beds don't). Same toy scale as island Ⅰ's walk.
- **Staff** stand by their factory, in the lounge or by their apartment, walking between them as their status changes.
- **E does:**

  | Aimed at | What happens |
  |---|---|
  | factory | opens its management (`focus_plot`); the walk waits on the return stack and resumes in place |
  | 星锻公寓 | walks inside |
  | decoration | puts it back in the toolbox |
  | staff member | shows name, role, stamina and status |

- **Placing decorations.** Pick a piece in the toolbox bar, aim at the deck and press E. A tile ghost shows where it goes, green if it fits and red if not; 旋转 turns it.
- **星锻公寓 interior.** A new `staff_housing` type in `residence_interiors.json` / `residence_layout.gd`:
  - one bed per resident place (4/6/8);
  - a coffee corner;
  - a sofa from level 2 and a display case at level 3;
  - up to 4 extra pieces for the furniture placed there.

  You can lie on the beds and sit on the sofa.
- **Exits.** Leaving the walk returns to the management screen.

## Save
`industry` section version 4: `deck`, `deck_items`, `decor_serial`, and staff `energy`/`resting`. The top-level save stays at 28. Restore checks:
- the deck has one cell per plot; cells are unique, in bounds and each beside an earlier one;
- decorations sit on empty plots, are real decor kinds, have unique uids below the serial and fit without overlap;
- stamina is 0–100.

v1–v3 saves load with the old grid and rested staff.

## Verification
- **`tests/test_starforge_isle.gd`** (50 checks):
  - old grid positions, frontier, building west or anywhere beside, refusals, the old button, plot_at, cap;
  - lounge seats and levels;
  - decorations: toolbox, overlap, factory plots, houses refused, rotation, edges, buying, studio lock, clearing before building, storing;
  - stamina: idle, working, drain, tired note, no bonus, lounge seat, lounge rate, unassigned rest, comfort, back to work, home-only rest is slower;
  - save round-trip; five corrupt-save rejections; v3 save upgrade; full game save and load.
- **`tests/test_starforge_walk_ui.gd`** (24 checks):
  - walk button; deck-map ＋;
  - the walk opens on free deck with staff figures; lounge spot; factories block;
  - E on a factory opens management, labelled 返回星锻岛漫步, and closing resumes in place;
  - hold, ghost, place, draw, aim, store; placement clamps inside the plot;
  - enter the apartment (4 beds) and leave; leaving the walk returns to management.
- **Existing tests** pass: `test_industry`, `test_industry_staff`, `test_starforge_ui`, `test_starforge_layout_ui`, `test_residence_*`.
- **`tests/capture_starforge_isle.gd`:** screenshots in `docs/screenshots/v0.43.0/`.
