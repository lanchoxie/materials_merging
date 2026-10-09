# 24 · v0.37.1 playtest fixes: leaving 星锻岛, miniatures, batch and loop production

This patch answers what the user reported from phone play on 2026-10-10:

> 第二个浮岛显示有问题，手机上被截断了，而且回不去主浮岛。微缩模型不能正确摆放在展示台上，也不能复制，也不能被重新摆放出来，一直提示距离不够。很多队列需要一个个点太蠢了，也没有排队机制。

## 1 · 星锻岛: cut off, and no way back
**Cause, no way back.** 「返回浮岛 Ⅰ」 only emitted `dismissed`. Main cleared its `modal`, but the full-screen panel stayed on top as an orphan. After that, neither Android back nor Escape could reach it. Every other panel calls `dismissed.emit(); queue_free()`.

**Fix, no way back.** `starforge_panel.gd` now has `_close()`, `handle_back()` (the Android back button) and `set_return_label()`, like the refinery panel.

**Cause, cut off.** In the right-hand scroll, horizontal mode is disabled, so the scroll takes its content's minimum width. Rows that never wrap pushed the panel past the screen edge:
- the staff tab's 「派到N号…」 row, which reached 1601 px of 1412 with five factories;
- the sell rows;
- long labels.

**Fix, cut off.**
- Button rows are `HFlowContainer`s (`_flow`).
- Every label stacked in a column wraps (`_wrap_labels` after each redraw).
- The header is clipped before the return button.

## 2 · Miniatures (微缩模型)
- **The "距离不够" message.** On the planet, `unfold` ran the per-block reach check (5.9 m from the eye) on every cell. Two things made it fail:
  - The model grew in +x/+z from the aimed corner.
  - A 3-wide or 4-high build always had a cell out of reach, whichever way the player stood.

  New `Miniatures.plan()`:
  - centres the footprint on the aim point;
  - rests the base on the highest ground under it;
  - checks reach only for the aimed cell.

  The other checks are unchanged: support, overlap, the player's body, trees and rock. `unfold` and the aim preview both use `plan()`.
- **Preview.** A green or red ghost box shows where the build will land. The prompt shows why it can't.
- **Pedestals.** A miniature on a courtyard stone pedestal, turntable or glass case never rendered. `campus_view._exhibit` typed the construction ledger (an object) as `Dictionary`, which is a runtime error. Fixed, with a regression check in `test_hometown_ui`.
- **复刻 (copy).** In the 「河湾作品」 dialog, 「复刻 · N金币」 (100 + 10 per block) makes a display-only replica.
  - It stands on any island stand or pedestal.
  - It refuses to unfold on the planet, so building material is still never duplicated (the source ledger conservation rule).
  - Replicas carry `replica: true`. Save validation leaves their pieces out of the source counts and rejects a malformed flag.
- **Backpack text.** A miniature on a courtyard pedestal no longer says it can be unfolded.

## 3 · Batch and loop production
| Where | New |
|---|---|
| 精炼厂 | 「×5」 and 「排满 ×N」 (bounded by queue space and ore); a 「循环精炼」 switch per process; a ⟳ line with 「停止循环」 above the queue |
| 星锻岛 factories | 「排满 ×N」; a 「循环生产」 switch per recipe (one loop per building); ⟳ on the factory card |
| 工艺车间 | 「连续制作 5 / 10 件」: the next item starts by itself when the bench frees up; 「补充10份供料」 |

- **Loops refill inside `tick`.** They work with the panel closed and during offline catch-up for the refinery and 星锻岛. The workshop stays live-only, as before: it depends on engineers being at work.
- **Loops never bypass a gate.** They call the same `start()`, which still checks inputs, evidence, the queue and stock caps. With no inputs they simply idle.
- **Save compatibility.**
  - Refinery: an optional `repeat` (a process id).
  - Industry: an optional `buildings[plot].repeat`, which must be a recipe of that building.
  - Workshop: an optional `batch {recipe, left ≤ product_limit}`.
  - Older saves load unchanged.

## Also
- The footer still said 「v0.36 天气与标本」; it now reads 0.37.1.
- Full queues hide the 排满 button instead of showing 「排满 ×0」.

## Verification
- **`tests/test_queues.gd`** (36 checks):
  - refinery fill, ore-bounded batch, the loop until the ore runs out, ore pickup, save and rejection;
  - factory fill, the loop, the wrong-factory loop, the idle loop with no negative stock, save;
  - workshop buy ×10, a batch of 4, save, cancel;
  - a 3×4×3 cabin unfolds from all four sides 4 m away, conservation after unfolding;
  - replicas: paid, never unfold, can be exhibited, valid in the save, a malformed flag is rejected.
- **`tests/test_starforge_ui.gd`:** 返回浮岛 Ⅰ and Android back both really close 星锻岛. This was confirmed to fail on v0.37.0.
- **`tests/test_starforge_layout_ui.gd`** (new, windowed for real fonts): every tab stays inside its panel with all eight building kinds and staff. Confirmed to fail on v0.37.0 (staff tab 1601 px).
- **`tests/test_hometown_ui.gd`:** a miniature on a turntable renders with its name card.
- **`tests/capture_v0371.gd`:** screenshots in `docs/screenshots/v0.37.1/`.
