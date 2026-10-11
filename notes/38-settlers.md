# 38 · v0.49.0 "Settlers" (溪石部落): the first native tribe

The first step of the natives track: notes/06-planets.md L4, "Living natives".

**Not in this release:**
- Tech diffusion (L5, "Bronze").
- Wars (L6, "Clash"). Whether the player may supply weapons is still open question Q4 in notes/14.

## The tribe (`scripts/river_natives.gd`, `data/river_natives.json`)
- **Where they live.**
  - 溪石部落 settles on present-day Earth only: not in the ice age, not on 赤砂星.
  - The village is a deterministic spot found by spiralling out from (260, −180): a 15×10 m footprint with one floor level, dry land, off the river and the sea, and no tree trunks.
  - On today's Earth that is (180, 12), about 170 m from home.
  - The search runs once (about 0.1 s) and is cached.
- **Four people**, all rigged like the settlement's villagers but in hide and ochre:
  - 岩川 (族长, the chief): keeps to the campfire;
  - 苇生 (工匠, the builder): builds;
  - 阿栗 and 小溪 (采集者, gatherers): walk out to gather and come back.
- **Stock.** Timber, stone and food, with caps. Each game day (60 s) the gatherers add 8 timber, 3 stone and 6 food, and everyone eats one food. Friendship drifts slowly back toward 0. A woodpile and a stone heap by the village grow with the stock, under a sign with the tribe's name.
- **Building with the player's block kit.**
  - Each of two huts gets a ring of wood walls (`block`) with a two-high doorway at the front, a 3×3 fibre roof (`roof`) and a stone campfire in front.
  - **Headroom.** Natural ground comes in half-metre steps. If any cell of the village footprint is a half step, the walls get a third course (a lintel over the doorway), so the inside always has headroom. That gives 48 or 64 cells.
  - The builder walks to the next missing cell (bottom-up), works 4 s, pays the cost from stock (1 timber per wall or roof cell, 2 stone per campfire) and sets the block, checked by the same `place_error` as the player's. A cell that can't be built is noted in the tribe's news and retried later.
  - The finished huts give real shelter, and the campfires warm you like your own.
- **Their blocks are theirs.**
  - They sit in the construction store with source `native:tribe`, so collision, rendering, shelter and warmth all work.
  - They have their own cap (64) and don't count toward the player's 512, `count_kind` or `count_walls` (camp goals).
  - Save validation: every native block must be a cell of the tribe's blueprint with the right kind, the village must be at its deterministic spot, and native blocks without a tribe are rejected.
  - The miniaturiser refuses them.
  - Taking one with the 拆卸锤 gives you nothing. The tribe notices (−0.1 friendship, a news line) and rebuilds it.

## Talking to them
- **Aiming.** Aiming at a tribe member shows their title, task and 「E 交谈（友好度 N%，观望/友好/亲近/戒备）」.
- **E opens the chief's menu:** friendship, stock, what is left to build and who is building it, the latest news.
  - **送食物 ×2** (grain, fruit or roast meat) or **送木料 ×4**: +0.1 friendship, up to 3 gifts a day. Gifts go into their stock (timber speeds up building).
  - **Pottery.** At 60 % friendship the chief gives one 部落陶罐 back each day (a new backpack resource).
  - **Trade:** 3 timber + 2 fibre → 2 raw meat, up to 3 a day, refused while friendship is below −20 %.
- **A raised hand.** Striking one of them doesn't hurt anyone: they dodge, and friendship drops by 0.3.

## Save
- `planet.v2.natives`: home, members (positions and tasks), stock, friendship, the cells built, the day counters and news.
- Saves from before v0.49 get a fresh tribe, which settles when the world first ticks.

## Verification
- **`tests/test_natives.gd`** (28 checks):
  - a fixed dry spot away from home and the river;
  - four people led by 岩川;
  - the builder adds blocks; every native block is a blueprint cell; the builder works at the village;
  - both huts are finished in time, with news and real shelter;
  - player counts and caps exclude them; boxing is refused;
  - a taken block costs friendship and is rebuilt;
  - save and load; forged, moved and orphaned native blocks rejected; old saves get a tribe;
  - no tribe in the ice age or on 赤砂星;
  - gifts, the daily gift limit, pottery for good friends, trade, refusal while wary;
  - the tribe's people as encounters: a raised hand only costs friendship; the talk prompt.
- **`test_sandbox12`** now counts the player's own blocks: the tribe may already be building during its minute of game time.
- **`tests/capture_natives.gd`:** screenshots in `docs/screenshots/v0.49.0/`.

## Next
- "Bronze" (L5 tech diffusion): exposure to the player's materials → use → maintain → make locally, with tech revolution events.
- "Clash" (L6) waits on Q4: how far weapons and wars may go.
