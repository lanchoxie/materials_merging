# 40 · v0.51.0 "Guidance" (看得懂): what can I make, and where does it come from

The user's words: *"在一堆元素和工业品里找自己可以做的东西的时候会很无助，我们可能需要类似 LoL 的树杈状可
合成的这种面板，如果缺少建筑需要在这个面板上提示"*, *"对于元素的淬炼也是一样，我们需要告诉玩家从哪些里面
提取这些元素，否则玩家玩起来会很快没劲的"*, and *"包括 Cs 太难获取了"*.

## The problem
The game had 42 industry recipes, 18 refinery processes and 19 elements, and exactly one place to
see any of them: a flat list, per factory, that only showed factories you had already built. So:

- a recipe for a factory you had **not** built was invisible everywhere — the player could not learn
  that 钙钛矿 LED 芯片 exists, let alone that it needs a 晶圆芯片厂;
- "locked" recipes said "先在原子工坊做出 X" but nothing connected the two;
- an element you did not have told you one thing: `星球挖铯榴石 → 精炼厂「铯榴石提铯」` — no layer,
  no rarity, no hint that it might be five metres below where you were digging;
- nothing anywhere said what an element is **for**.

## 1. The guide (`scripts/craft_guide.gd`)
A read-only model that walks the real data — `industry.json`, `refinery.json`, `minerals.json` — and
answers "what is this, what does it need, what is stopping me". No hand-written content: change a
recipe and the answer changes.

**`node(key, need, depth)`** returns a tree. Each node carries `have`/`need` and a status:

| status | meaning |
|---|---|
| `have` | you already hold enough |
| `make` | every input is in hand, the factory exists and the recipe is unlocked |
| `missing` | the factory is there, but inputs are short (the reason lists the first three) |
| `building` | **the factory does not exist** — the reason names it *and its price* |
| `locked` | the experiment that unlocks the recipe has not been run yet |
| `mine` | a base material: how to dig or gather it |
| `none` | the chain is deeper than 6 levels, or it loops |

- Inputs are **scaled**: to make one motor you don't need one iron, you need enough iron for three,
  because a run makes four. The tree asks for the right amount at every level.
- When a material has several recipes (every metal has a small and a bulk process), they are **scored**
  — built factory first, unlocked first, then the most inputs already held — and the best one decides
  the node's own status, with the others listed beside it.

**Element answers:**
- `element_sources(symbol)` — every extractor that makes it outright, every process that yields it
  (with the ores it eats and the per-run output), and every ore that contains it (with its layer,
  its formula and how many atoms per block).
- `element_uses(symbol)` — a reverse index built from every recipe's `el:` inputs: the elements point
  back at the products that need them.
- `element_guide(symbol)` — the one-liner: `铯榴石＋石灰岩 →「铯榴石提铯」 · 用于：钙钛矿 LED 芯片 等`.

## 2. The 工艺路线 tab (随身工具箱)
A new first tab in the toolbox, with three modes:

- **工业成品** — every item the industry can output, with a verdict for each: 已有 / 可生产 / 缺料 /
  **需建厂** / 未解锁. This is the "I don't know what to do" fix: nothing is hidden any more, and the
  answer to "why can't I make this" is on the line itself.
- **元素** — pick an element: its one-line guide, where it comes from (extractor, process, ore with
  its layer), and what uses it.
- **矿石** — pick an ore: layer, hardness, how much is in the bag, which elements it contains, and
  every refinery process that takes it.

The refinery's element readout (`_explain`) now shows the same one-liner instead of only "where from",
so the answer is in the room where you actually refine.

## 3. Caesium is no longer a wall
Cs was the worst chain in the game: 铯榴石 was a 2×2 blob at 1.2 % in a **four-metre** band below
−17 m — the rarest ore by far — and it gates the only Cs recipe (钙钛矿 LED 芯片, behind a 15000-coin
factory), which in turn gates the LED headlamp. Two changes:

- **The ore is findable.** 铯榴石 is now a 3×2×3 blob at 3 % from **−12 m** down, where the player is
  already digging for granite ores. Still the rarest, no longer a lottery.
- **A bulk process.** `pollucite_bulk`: 铯榴石 ×4 ＋ 石灰岩 ×2 → **Cs ×16** in 150 s, following the
  iron and copper bulk pattern — batch hauling pays off, and it uses half the limestone per caesium.

## Verification
- **`tests/test_craft_guide.gd`** (36 checks):
  - `item:glass` is blocked on a building, the reason names 无机材料厂 and its cost, and the tree walks
    down to real ore leaves that say how to dig;
  - with the plant built and the ore in the bag, the same node stops being blocked;
  - a locked recipe names the experiment (原子工坊), not just "locked";
  - Cs lists its process, its ore, its layer, and its only consumer; Fe and H read the same way;
  - **every one of the 19 elements has a source** (no dead ends);
  - 铯榴石 now generates from −12 m, and the bulk caesium run exists.
- `test_refinery` unchanged and green.
- **`tests/capture_guide.gd`:** the three views in `docs/screenshots/v0.51.0/`.

## Next (same request)
- The crystal workbench: lattice parameters (a/b/c/α/β/γ), fractional coordinates, periodic images,
  snap-to-boundary, and an "on the cell boundary" readout.
- Gas/liquid/solid for custom and free-built structures, and the atom-editing feedback gaps.
- Bronze (tech diffusion) and Clash (wars — abstract while you are away, real when you are there).
