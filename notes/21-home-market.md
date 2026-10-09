# 21 · v0.35 "Home & Market" (家与市): promotions, 星锻公寓, home goods, contracts

Phase-2 slot I2 from [14-industry-island.md](14-industry-island.md), plus the promotion pipeline the user asked for (Q6).
The user confirmed "按照原计划做" on 2026-10-10.

## Promotion pipeline (Q6)
- **Service years.** Island Ⅰ engineers and 博士生 accrue service while the game runs. It counts live campus time only, like campus wages: `industry.serve()` runs inside the 1 s campus loop.
  - 1 学年 = 960 s, which is two campus days.
  - Engineers need 2 学年 and 博士生 need 3.
  - Residents already on the island when v0.35 loads are credited 1 学年.
- **延毕.** When someone first reaches their years, a seeded per-person roll can add one more year. The chance is 12 % for engineers and 25 % for 博士生. The same save always gives the same result.
  - The reason is shown on the card. 博士生 reasons include 审稿人要求补对照实验 and 导师出国访问. Engineer reasons include 工程延期验收.
  - Each person can get at most one 延毕.
- **Approval.** Nothing happens automatically. The player presses 批准晋升 in the 科研小镇 「晋升」 tab or in the 星锻岛 「人员」 tab.
  - A promotion needs island Ⅱ to be open and a free bed in a 星锻公寓.
  - The person leaves island Ⅰ through the existing `campus.dismiss`, which leaves a vacancy there. The campus counters resync.
  - They join island Ⅱ staff as 高级工程师 or 研发博士.
- **Senior staff.**
  - Each is sent to a factory. A factory takes at most 2.
  - 高级工程师: +30 % factory speed.
  - 研发博士: +0.25 batch of extra yield per finished job. It accumulates, so every 4th job gives one more batch. Deterministic.
  - Wages are 20 and 30 coins per day, settled every 480 s from coins. While wages are owed, the staff bonus pauses. 「补发欠薪」 pays the arrears.
- **星锻公寓.**
  - Holds 4 beds, +2 per level, up to Lv 3. It needs no licence.
  - Furniture placed in it raises comfort: staff bonuses rise up to +20 % when it is fully furnished.

## 未来家居工坊 and new materials
- **New in the 高分子工厂:** 硫化橡胶 (vulcanised rubber), from C/H/S. It is gated by having made C₄H₆ (butadiene), the real monomer (Goodyear 1844).
- **Studio recipes.** Furniture pieces are flagged 家具. The others are materials or kitchenware.

  | Item | Inputs | Notes |
  |---|---|---|
  | 刨花板 (particleboard) | planet timber + UF resin | hot-pressed (Dunky 1998) |
  | 星环椅 (furniture) | steel + PE | |
  | 刨花板书桌 (furniture) | particleboard + steel | |
  | 浮光沙发 (furniture) | particleboard + rubber + PE | |
  | 不粘锅 | duralumin + PTFE | PTFE safe below about 260 °C |
- **Uses for furniture:**
  - sell it;
  - fill contracts;
  - furnish a 星锻公寓;
  - 「送回浮岛 Ⅰ 摆放」 puts it in the island Ⅰ toolbox (`storage.decorations`).

  On island Ⅰ there are four new town furniture items: sf_chair, sf_desk, sf_sofa and sf_kitchen. They have their own meshes in `town_decor.gd`.
  - They can't be bought with coins (`town_locked`).
  - Selling one returns it to the toolbox instead of minting coins.

## Contracts and the cargo airship
- **The board.** The trade hub posts 3 contracts and refreshes them every 15 min. 「换一批」 costs 2 credits.
- **What gets asked for.**
  - Each buyer has a story and a `wants` list, for example 城市百货 wants furniture and 港口船厂 wants steel, solder and rubber.
  - Contract lines come from what the player can make today, meaning the factory is built and the evidence is met.
- **Reward.** 1.5× the items' sale value, plus 4–12 credits and XP. There is no penalty for ignoring a contract.
- **Delivery.** It loads the airship, which carries one contract per trip. After a 90 s trip it pays out.
  - Delivering a contract does not saturate market prices.
  - The Blender-made airship docks at the trade hub and flies a loop over the island while in transit.

## Other
- **Power.** The island grid now grows by 1 per rank above the unlock rank, capped at 40. It is still a placeholder until the Energy Park.
- **测试版.** The test panel gets 「员工满年限」: every engineer and 博士生 reaches their years, and the 延毕 rolls still apply.
- **Models.** `dev/blender/starforge.py` adds home_studio, staff_housing and the airship, for 8 glb files in total.
- **Save.** The industry section moves to version 2, with staff, service, delays, wages, furniture, contracts and the airship, all strictly validated. A v0.34 island (version 1) loads and starts the pipeline fresh. The save-file version stays 28.

## Deferred
- PVC irrigation pipe on the planet (an environment emitter) moves to the v0.36 planet release, which deals with water and incidents.
- The light bridge between the islands and the maglev ring stay visual extras.

## Verification
- `tests/test_industry_staff.gd` (29 checks): legacy service, the year gate, the stable 延毕 roll, housing requirement, approval and vacancy, speed and yield bonuses, wages and arrears, studio furniture, apartment comfort, island Ⅰ toolbox, timber input, contracts and airship, reroll, v2 round trip, v1 upgrade, rejection cases.
- `tests/test_starforge_ui.gd` (17 checks): adds the 晋升 tab approval, the staff tab's factory assignment, and the contract board.
- `tests/capture_starforge.gd` adds campus-promotion, staff, contracts and airship shots (in `docs/screenshots/v0.35/`).
