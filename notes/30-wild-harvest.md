# 30 · v0.41.2 "Wild Harvest" (野外生存): drops, food, building copies, placement preview, machines

Intermediate release from the user's 2026-10-11 feedback. The larger planet plan is in
[the planet plan below](#roadmap-agreed-2026-10-11).

> 树桩这个东西莫名其妙的不要出现了。包括散石堆和灌木堆什么的可以去掉了，改成就是可以挖到的石头和我们可以砍到的树。然后砍树和收获种子的时候需要设置概率掉落……我们需要可以制作一些食物，吃了可以回血保暖……这个模型建筑不仅仅可以复制模型，还可以复制这个建筑……复制建筑需要我们在一个特定工厂里面完成……摆放建筑的时候我们需要和摆放方块一样给出范围提示……灌溉机好像不会自动把周围的种植箱灌湿，还有其他设备好像不知道有什么用

## Gathering
- **No more piles.** The 枯枝堆, 散石堆, 纤维草 and 野果丛 piles are gone; `field.nodes()` returns []. Old saves with progress on a pile load, and that progress is dropped.
- **No stumps.** A felled tree is not drawn at all; it already did not block or target.
- **Felled trees drop by chance.** Each roll is deterministic per tree id via `Field.roll(key,salt)`, so reloading cannot reroll it:

  | Drop | Rule |
  |---|---|
  | timber | 3–6 |
  | seed | 60 % |
  | fibre | 55 % chance of 1–2 |
  | fruit | oak 40 %, birch 15 %, pine 10 % |

- **Quarrying rock** (granite, basalt, limestone) also gives 1 **石料** (stone, formerly 散石) on top of the rock block.
- **Crops.**
  - A planter gives 2–4 grain, plus seeds from three chances (80/45/20 %), so 0–3 seeds.
  - A region crop gives 1 seed plus a 50 % chance of a second.

## Food
- **Hunting.** Killing game drops raw meat, rolled per animal: deer 1–2, boar 2–3, woolly rhino 3–5, mammoth 5–8, fish 1.
- **Cooking at a campfire.** E on a campfire opens the menu:

  | Dish | Inputs | Heal | Warmth |
  |---|---|---|---|
  | 烤肉 | meat | 30 | +6 °C for 90 s |
  | 谷物粥 | 2 grain + fruit | 25 | +10 °C for 150 s |
  | 热汤 | meat + grain + fibre | 45 | +14 °C for 240 s |

  Fruit can be eaten raw and heals 5.
- **Eating.** Foods sit in the backpack (`field.stock`) and are eaten from the hotbar (E) or the backpack's 「吃一份」. You can't eat at full health unless the food warms you. The warmth adds to felt temperature (v0.39 cold) and wears off. *All numbers are game values.*

## Building copies (工艺车间 → 「建筑复制」)
- **What it does.** Pick a boxed build, including a display replica. The copy desk charges each block's recipe in raw materials, in whole packages; leftover pieces stay in the new copy. It needs workshop staff on duty. The copy appears in 河湾作品, ready to unfold.
- **Which builds can be copied.** Only builds made from raw-material (field) recipes. Others say which part can't be copied.
- **Every package is a real product.** Each one gets an issued workshop id and a craft record, so material conservation and save validation hold. Tested with the full program restore.

## Placement preview
Unfolding a boxed build shows a ghost for **every block cell**, green if it fits and red if not, like placing a single block. Before, there was one bounding box.

## Machines (user: the sprinkler did not water the planters)
- **喷淋塔** keeps every planter within 6 m wet (+0.02 moisture per second).
- **氨肥撒播机** makes planters within 6 m grow 30 % faster.
- **Aiming at any machine says what it does**, with live numbers. The oxygen tower shows atmospheric O₂ %; the CO₂ tower shows ppm and the warming it causes.

## Digging (user: 「幼树在扎根」「道路下面不能挖」 made no sense)
- **Roads and bridges.** Digging no longer refuses them.
- **Trees and facilities** only guard the surface cell they stand on. The message there is now 「<树>长在这里：先用斧头把它砍倒」; it used to call every tree a 幼树. Deeper cells are always diggable.
- Building blocks above a cell still protect it, so nothing is left hanging.
- Placing blocks keeps its old checks.

## Save
- New stock ids: `meat`, `cooked_meat`, `porridge`, `stew`.
- Missing stock ids default to 0, and old `changed` pile progress is dropped.
- The food buff is not saved.

## Verification
- **`tests/test_wild_harvest.gd`** (35 checks):
  - timber range, the seed rate and fibre;
  - deterministic replays;
  - felled trees gone;
  - no piles;
  - granite gives stone;
  - grain and seed rolls;
  - meat;
  - cooking needs a campfire; roasting and stew;
  - eating rules, heal and warmth, and the warmth wearing off;
  - food on the hotbar;
  - saves, old saves;
  - building copy cost, copy, conservation and full save;
  - per-cell preview;
  - the sprinkler waters, the spreader speeds growth, machine prompts;
  - digging under trees and roads.
- **Updated tests:** `test_river_field`, `test_river_field_ui`, `test_sandbox12`, `test_frontier17` (piles removed, rolled yields).
- **`tests/capture_wild.gd`:** screenshots in `docs/screenshots/v0.41.2/`.

## Roadmap (agreed 2026-10-11)
See memory and notes/03:
1. **Globe world.** A wrap-around planet with polar caps, a curved-horizon shader and a globe god view showing the last position. Remove the 4 fixed regions and the 7 landmarks. Add oceans, mountain ranges, caves and biome vegetation communities.
2. **星锻岛 as a real island** like island Ⅰ: expand, buildings including staff rest, decorations, first-person.
3. **New requests (2026-10-11, recorded here):**
   - **More building materials:** doors, windows, boards, bricks and roofs, in wood, **stone**, **plastic** and **metal**.
   - **A 盾构机 (tunnel boring machine).** Metal parts cost many refined elements today. A TBM bores tunnels and collects the ore along the way in bulk, so metals are cheaper to supply.
   - **Farm robots** that plant, water and harvest planters automatically.
4. **Later:** airplane → spaceship → second planet.
