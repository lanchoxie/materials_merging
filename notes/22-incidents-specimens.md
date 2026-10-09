# 22 · v0.36 "Weather & Specimens" (天气与标本): era framework, incidents, 标本图鉴

Planet slot from the interleaved plan ([14-industry-island.md](14-industry-island.md), v0.36). This answers the user's
earlier question about different eras and different incidents.

## Era framework (`river_settlement.gd`, `data/river_settlement.json`)
- **Requirements in data.** Each era lists its requirements under `eras[i].requires`. Each entry gives a metric id, a threshold path into the rules, a label and a hint.
  - `checklist()` reads the list. Metrics are one `match` in `metric()`.
  - Row ids stay the same as before, so the era buttons, tests and saves are unchanged.
- **Per-era weather.** Each era also lists its incidents and a daily chance:
  - 原野营地: storm and flood, 10 %.
  - 农耕聚落: storm, flood and drought, 16 %.
  - 现代生态站: storm, flood and drought, 22 %.
- **Era count.** Save validation and the panel read the era count from data (`last_era()`). The v0.39 冰河期 is then one more data entry, plus any new metrics it needs.

## Incidents (`planet_incidents.gd`, `data/planet_incidents.json`)
- **The director is deterministic.** It rolls once per planet day with a fixed hash, so the same save always gets the same weather.
  - No incident before day 3, and at least 3 days between incidents.
  - It picks only kinds that fit both the era and the season:
    - storm: spring to autumn;
    - flood: spring and summer;
    - drought: summer and autumn.
- **A warning a day ahead.** It goes into the 年鉴 and the first-person goal line, e.g. 「预警：暴风雨 · 42秒后到来 · 现在准备度 50%」. During the warning hour the sky slowly clouds over.
- **Preparation is measured from what the player built**, never from a stored flag:

  | Incident | What protects | Full protection |
  |---|---|---|
  | 暴风雨 storm | standable shelter cells under a roof within 14 m of the camp | 4 cells |
  | 河水上涨 flood | built blocks 3–9 m from the river, along the home stretch (\|z\| ≤ 40 m) | 16 blocks (a levee) |
  | 干旱 drought | sprinkler emitters (v0.32) plus PVC 灌溉管 | 4 combined |

- **Effects.** Damage scales with (1 − preparation).
  - **Storm:** extra rain fills the regions. Unprotected crops stop growing and lose growth. Unsheltered residents lose health.
  - **Flood:** wetland and riverbank flood. Their crops stop growing and lose growth.
    - When the water recedes it leaves **silt**: +15 % nutrients in those regions, which is how real floodplains stay fertile.
  - **Drought:** no rain, and evaporation rises up to 2.5×. Preparation reduces this, and each pipe cuts a further 15 %.
- **Outcome.**
  - The 年鉴 records the incident's preparation, crop and health losses, and a 「稳住了」 mark when preparation was at least 50 %.
  - Each weathered incident pays 30 岛主 XP through the legacy score.
  - A 「灾害记录」 card lists the last 16 incidents.
- **PVC 灌溉管.** This is the phase-2 planet payoff carried over from v0.34. Laying one line costs 2 PVC from 星锻岛 (`LabState.lay_pipe`). At most 4 lines can be laid.
- **Sky.**
  - Storm: a darker sky and sun, fog pulled closer, and rain streaks around the camera (CPUParticles3D, so it works on mobile).
  - Drought: a warm yellow haze.
  - Floods show through the region water meshes, which rise.
- **时代 page.** A 「天气与灾害」 card shows:
  - the coming or current incident and how to prepare for it;
  - the current preparation percentage for all three kinds;
  - buttons to lay pipe and to go to the workshop.

## 标本图鉴 (`planet_specimens.gd`, `data/specimens.json`)
- **Scanning.** The analyser on an animal or tree records a specimen. The same species found again in a new biome records a new habitat.
  - People are never specimens.
- **Cards.** Each card names the real-world prototype and gives only well-established biology:

  | Game species | Prototype |
  |---|---|
  | 湿地鱼 | 鲫鱼 *Carassius auratus* |
  | 小鹿 | 狍 *Capreolus pygargus* |
  | 林地野猪 | 野猪 *Sus scrofa* |
  | 橡树 | 栎属 *Quercus* |
  | 白桦 | *Betula platyphylla* |
  | 松树 | 松属 *Pinus* |

- **XP.** A new species pays 25 岛主 XP and a new habitat pays 10.
- **年鉴.** The 「标本图鉴」 card now sits at the top of the 年鉴, above the mineral codex.

## Performance pass (user: "越来越卡")
The user said the game felt more and more laggy. New probes measure the cost: `tests/benchmark_frames.gd` (frame time per scene), `tests/benchmark_planet_parts.gd` (cost per system) and `tests/benchmark_chunks.gd` (chunk build). All are run windowed.

**Problems found (desktop):**
- **Crosshair aiming cost 64 ms and ran about 8 times a second.** `construction.trace` steps 4 cm along the ray, and at every step `terrain.blocked()` rebuilt the tree list of 9 chunks.
- **Walking cost 2 ms per substep**, from the same tree rebuild.
- **A cold hill chunk took 23 ms to build.** Most of it was `column_has_cave` testing 14 cells of trig per column.

**Fixes:**
- `chunk_trees` is cached per chunk against `nature.revision`. Every chop, planting and growth stage bumps the revision, so the cache is never stale.
- Each voxel's cave test is cached (`_cave_cells`).
- `column_has_cave` rejects most columns with one mid-depth sample. The tunnel field changes by at most 0.04 per metre, so the result is exact; the same 13 of 1536 columns still have caves.

**Results:**

| | Before | After |
|---|---|---|
| aiming | 64 ms | 4.5 ms |
| walking (per substep) | 2 ms | 0.25 ms |
| cold hill chunk | 23 ms | 13 ms |

Frame time, average / 95th percentile:

| Scene | Before | After |
|---|---|---|
| walking at home | 22 / 54 ms | 16.7 / 16.7 ms (vsync) |
| walking in the hills | 40 / 128 ms | 18.6 / 28.7 ms |
| storm | 35 / 81 ms | 16.7 / 16.8 ms |

**Still open:** building a new chunk costs about 6–9 ms (warm cache), and a phone is several times slower than a desktop. A time-sliced mesher is the next step if phones still hitch in the hills.

**The machine:** 16 GB with about 3.5 GB free. League of Legends used about 3.2 GB, and the background full-suite run was killed twice for low memory.

## Save
Planet v2 gains two optional sections, `incidents` and `specimens`, both strictly validated. Saves made before v0.36 load with neither, and the save version stays 28.

## 测试版
The Earth section of the test panel gets 「10秒后暴风雨 / 洪水 / 干旱」.

## Verification
- `tests/test_incidents.gd` (27 checks) covers:
  - era rows from data with their old ids;
  - the last era;
  - per-era weather;
  - deterministic and first-day-gated rolls;
  - a storm's warning, start, damage and record;
  - flood levee preparation, silt and protected crops;
  - PVC pipes and drought modifiers;
  - specimens, biomes and XP;
  - the analyser's prototype text and the "people are not specimens" rule;
  - the save round trip, old saves, and rejection.
- `tests/capture_incidents.gd` (screenshot helper): clear, storm, drought, the era weather card and the specimen journal. Screenshots are in `docs/screenshots/v0.36/`.
