# 42 · v0.53.0 "Editor Feel" (手感一致): the same feedback when adjusting atoms

The user's words: *"和我们原有的默认的几种在调整原子时候的UI反馈还是很不一样"*.

## The gap
The game has two atom editors, and they felt like different programs:

| | 结构工作台 (`atom_editor.gd`) | 自由造物 (`sandbox_editor.gd`) |
|---|---|---|
| what you are adjusting | 正在调整 Cs #09 | `Cs #09  0.00, 0.00, 0.00 Å` |
| the atom's own data | 半径 1.88 Å · Cs⁺ 离子半径，配位数12 · 价态 1 · 配位数 12 | *nothing* |
| fit | `几何匹配 87% ★★☆ · 精品级` + a tinted bar that goes cold→warm→mint | one floating line: `几何匹配 87% · 预计 0.42 金币/秒` |
| income | a big `0.42 金币 / 秒` number | buried in the same floating line |
| aiming at a ball | n/a (the site is picked from a list) | no feedback until you click |

## What changed (`sandbox_editor.gd`)
The sandbox — the editor the player actually uses to build things — now shows the same feedback the
preset editor always had:

- **The selected atom's own context**, straight from the reference data: its radius and radius type,
  and its oxidation state and coordination when the data has them —
  `半径 0.76 Å · 共价半径（sp3参考）`.
- **实验室反馈**, the preset editor's heading, with:
  - the **fit sentence**: `几何匹配 74% ☆☆☆ · 继续探索`, using the same thresholds
    (完美契合 ≥98 %, 精品级 ≥93 %, 平稳运转 >80 %) and the same stars;
  - a **tinted bar** under it, cold red → warm gold → mint with the fit, so "am I getting closer?" is
    readable at a glance without reading a number;
  - the **big rate number**: `1.73 金币 / 秒`.
- **Hovering a ball names it** — `指向 H 2（点击选中）` — and lights it dimmer than the selected atom,
  so you can tell what is under the cursor before committing to a click. (The preset editor never
  needed this because its sites are picked from a list; the sandbox is a 3D viewport.)

The floating line over the viewport is kept: it is still the one-glance summary while dragging.

## Verification
- `test_sandbox`, `test_sandbox12`, `test_sandbox12_ui`, `test_sandbox_editor` all green.
- A type-inference error (`var q := state.quality(...)`, whose helper is deliberately untyped) was
  caught by `test_sandbox_editor` during the change.
- **`tests/capture_editorfeel.gd`:** the feedback panel before and after a nudge, in
  `docs/screenshots/v0.53.0/` (fit 74 % → 63 % when a C–H bond is stretched by 0.40 Å).
- Full suite re-run for the release.

## Next
Bronze (tech diffusion) and Clash (wars). At the user's request, wars resolve abstractly while the
player is away — people and buildings take damage, but no units are simulated — and are fought out
for real only when the player is present.
