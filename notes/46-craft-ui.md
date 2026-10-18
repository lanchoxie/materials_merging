# 46 · v0.57.0 "Craft UI" (工艺格): the 工艺路线 tab becomes an icon-card grid

The user found the old list-style craft panel unsatisfying ("太阴间了") and asked for something
between a Minecraft flat tile view and a LoL item tree. This release replaces the list with an
icon-card grid and an inline tree drill-down.

## What changed

The 工艺路线 tab in the island panel (`scripts/island_panel.gd`) used to render every craftable
item as a single-row list entry with a status word and a "看链条" button. It now opens to a
**4-column grid of tiles**:

| Status | Border color | Meaning |
|---|---|---|
| 可生产 (make) | MINT (green) | everything is ready, you can make it now |
| 缺料 (missing) | GOLD (amber) | a material is missing somewhere in the chain |
| 需建厂 (building) | LILAC (violet) | the required factory isn't built |
| 未解锁 (locked) | LILAC (violet, dim) | a prerequisite recipe hasn't been made |
| 已有 (have) | MUTED (dim) | already in stock |

Each tile shows the item name (word-wrapped) and the current stock count. Tapping a tile opens
the inline tree view for that item — a back button returns to the grid.

## The tree drill-down

`_guide_tree()` renders the guide node's children as indented rows with a colored left-indicator
strip matching the status color. Each row shows `name  have / need` and the detail string (what
is missing, which building, how long it takes). The depth is capped at 5 to keep deep chains
readable.

The tree data itself comes from `craft_guide.gd` (v0.51) — its logic is unchanged. Only the
rendering layer moved from list rows to cards.

## Default state

`guide_target` now defaults to `"item:__grid"` (the grid sentinel) instead of `"item:glass"`, so
the tab opens showing the full grid rather than drilling into one item. `_guide_pick("item")`
also navigates to the grid instead of jumping to the first recipe output.

## What did not change

`craft_guide.gd` is untouched — the tree-building logic, status classification, and source hints
all stay. The element and mineral detail views (`_element_detail`, `_mineral_detail`) are also
unchanged; only `_guide_list()` was replaced and `_guide_tree()` / `_guide_status_color()` added.

## Files changed

- `scripts/island_panel.gd` — `_guide_list()` rewritten as a card-grid + tree drill-down;
  `_guide_tree()` and `_guide_status_color()` added; `guide_target` default → `"item:__grid"`;
  `_guide_pick("item")` → grid.
