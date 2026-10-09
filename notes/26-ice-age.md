# 26 · v0.39 "Ice Age" (冰河期): the time gate, cold survival, mammoths

Planet slot from the interleaved plan ([14-industry-island.md](14-industry-island.md), v0.39: "冰河期 + time gate;
harsher incidents"). It follows the L3 Timelines design in [06-planets.md](06-planets.md):
- same terrain, a different era content pack;
- each timeline keeps its own save;
- only one is live at a time;
- the light bridge becomes a time gate with an era dial.

I built this while the user was away. The design calls below are mine and are open for review.

## Timelines (`planet_program.gd`, `planet_v2.gd`, `data/planet_v2.json` `epochs`)
- **Each world has an epoch.** `PlanetV2.epoch` is `present` or `ice`, saved as `epoch`.
  - The epoch sets `environment.epoch_offset`, which adds to the climate field next to CO₂ warming. The home regions' temperature uses it too.
  - The 冰河期 offset is **−18 °C** *(游戏数值; the real LGM global mean was −6.1 °C, per Tierney 2020)*. Home therefore sits in the tundra band. Snow tint, snow drifts and dead-flora rules come for free.
- **One live world.** `PlanetProgram.timelines` holds the inactive worlds as their own `serialize()` dicts. `travel(to)` swaps the live world.
- **What travels with the player:**
  - raw stock (`field.stock`);
  - workshop provenance records (`field.crafts`, so product validation keeps working);
  - tree seeds, minerals and the mineral codex;
  - the hotbar;
  - the 标本图鉴;
  - health.
- **What stays in its era:** buildings, terrain edits, settlement, regions, animals and weather. Nothing is duplicated: the stored world keeps blank personal fields.
- **The gate.**
  - It opens once the present-day camp reaches 农耕聚落 (`time_gate.requires_era`). After that `gate_open` stays set.
  - The island's rainbow light bridge then shows a dial dialog (「时间之门 · 彩虹光桥」) listing each era with its story and the source note.
  - The 时代 page gets a 「时间之门」 card that says how to open the gate and what changes in the ice age.
- **A fresh 冰河期.** It starts with no sown crops and an LGM story in the 年鉴. Its settlement era ladder is the same as the present's.
- **Miniatures always belong to the present.**
  - The island reads and edits them through `PlanetProgram.home()`, which is the live world, or the stored present restored lazily. `home_saved()` writes edits back.
  - LabState's town validation uses `home_data()`.
  - The 微缩器 refuses in other eras, so island exhibits and courtyard pedestals work and save correctly from either era.

## Cold (`river_combat._cold`, `planet_v2.felt_temperature`, `data/planet_v2.json` `cold`)
- **Felt temperature** = air (climate cell + season + day + any cold-snap chill)
  - +12 °C within 4.5 m of a 篝火
  - +6 °C under a roof
  - +14 °C with the 保温服.
- **Below 0 °C** the player loses 0.12 HP per second per degree below *(游戏数值)*. This applies in both eras, so the present-day far north is dangerous too.
- **HUD.** A ❄ box beside the HP bar shows the felt temperature. While losing heat it adds a hint and a frosty screen edge.
- **篝火.** A natural workshop recipe: 3 timber + 2 stone gives 2 fires.
  - It is a construction kind (machine) and a climate emitter (+1.5 °C on its cell).
  - It is drawn as a stone ring, logs and a stepped flame, with a spark plume and an orange OmniLight.
- **First-person nights** were already darkened in v0.38. The headlamp and the fire now both matter in the ice age.

## 寒潮暴雪 (blizzard incident)
- **When.** Winter in the present (农耕聚落 and 现代生态站). In the 冰河期 it can come in any season (`all_seasons`, chance 0.3).
- **Effects.**
  - −10 °C chill for everyone, also used by the felt temperature.
  - Crop loss of 30 % × (1 − preparation).
  - Resident health loss, like a storm.
- **Preparation.** Half from campfires within the camp radius (2 = full) and half from standable roofed cells (4 = full).
- **Sky.** Dark, hazy and white. The rain particles switch to slow, square snowflakes.

## Mammoths and woolly rhinos
- **Wild sites.** In the 冰河期 the population's `wild_species` is `[mammoth, woolly_rhino]`, and `cold_min` is −30 °C, so tundra sites stay alive. Present-day sites are unchanged.
- **Models.** Procedural cube rigs at real scale:
  - **Mammoth:** about 3 m, a domed head, small ears (real cold adaptation), a long skirt of fur, curved tusks and a trunk.
  - **Woolly rhino:** about 1.8 m, a shoulder hump, a low head with two horns.
  - Gaits are slower.
- **Behaviour.** Both fight back like the boar.
- **Specimens.** Cards with the real prototypes *Mammuthus primigenius* and *Coelodonta antiquitatis*, and only well-established facts.

## 星锻岛 tie-in: 保温服
- **Recipe.** Home goods studio: 3 PE + 1 PTFE gives a 保温服. The real basis is an expanded-PTFE membrane (Gore 1976) over a PE fleece.
- **Wearing it.** 「穿上」 is on the 装备 tab. It gives +14 °C *(游戏数值)*. While worn it is reserved like the bit and the lamp.
- **Buyer.** 山地研究所 also buys suits.

## Save compatibility
| Save | Added | Older saves |
|---|---|---|
| PlanetV2 | optional `epoch` | load as `present` |
| PlanetProgram (still version 12) | optional `timelines` and `gate_open` | load unchanged |
| industry | optional `suit` | load unchanged |

Validation of stored timelines:
- Each era appears at most once, and never the live era.
- Each stored world must restore on its own, and its `epoch` must match.
- Workshop records (crafts) must not be stored there; they travel with the player.
- Every product id is unique across all timelines.
- Organic and sample receipts go through the sandbox check.

## 测试版
「时间之门：切换冰河期/当代」 in the island row opens the gate and swaps eras.

## Verification
- **`tests/test_ice_age.gd`** (36 checks):
  - the offset;
  - no starting crops, and the story;
  - tundra in the north;
  - per-era weather;
  - mammoth and rhino sites;
  - cold-adapted suitability;
  - mammoths fight back;
  - specimen prototypes;
  - winter below freezing;
  - the cold drain;
  - campfire +12, suit +14, roof detection;
  - the blizzard: chill, snow, campfire preparation;
  - the gate: shut until farming, what travels and what stays, nothing duplicated, the 微缩器 refused in the ice age, coming home, the ice world kept between trips;
  - saving and loading in the ice age;
  - rejecting a live-era duplicate and an unknown era;
  - miniatures: exhibit and 复刻 from the ice age, then the save and load.
- **`tests/capture_ice.gd`:** screenshots in `docs/screenshots/v0.39/`.

## Next steps (not in this release)
- Ice-age foraging and hunting yields (meat, hide, ivory).
- Cave bears and a native tribe (L4).
- A frozen river.
- Fewer trees on the steppe-tundra.
- Historical echoes between eras (notes/06, stage 2).
