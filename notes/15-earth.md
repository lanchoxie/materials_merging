# 15 · v0.32 "Earth" (地球): a living climate over the 16 km world

## Goal
The river-bend world (河湾) becomes **地球**: a planet with regions that feel different and a
climate the player can change with molecules made on the island.
- Walking far now shows biomes: cold tundra to the north, dry desert to the east, wetlands to
  the west, forests and grassland in between.
- Island molecules become **environment machines** (喷淋塔, 制氧塔, 温室气体塔, 氨肥撒播机).
  Placing them changes the land around them: deserts turn green, wetlands spread, tundra thaws
  as CO₂ warms the planet, and fertiliser adds a little pollution.
- Animals follow the environment: no wildlife in desert or frozen tundra, boars in forests.
- A map overlay (地球环境图) shows biome / water / temperature / nutrients for the whole world,
  the machines, the player and the atmosphere.

## Model (`scripts/planet_environment.gd`, `data/planet_environment.json`)
- **Grid:** 64 × 64 cells of 256 m over the circular world (origin −8192 m).
- **Baseline** per cell (water, temperature, nutrients) is a deterministic formula, never saved:
  - Inside 300 m of the origin the baseline is constant (w 0.55, 19 °C, n 0.44), so the start
    area looks and behaves exactly as before. It ramps to the full pattern by 1 000 m.
  - Temperature falls towards −z ("north", top of the map) and rises to the south.
  - Water falls towards +x (east, desert) and is higher in the west (wetland).
  - Smooth sine noise breaks the bands into patches.
- **Player deltas** (saved, sparse): per cell `[water, temperature, nutrients, pollution]`.
  Each second, a delta relaxes towards the target set by the machines in that cell and its
  4 neighbours (neighbours get 35 %), with τ = 600 s. Cells that return to zero are dropped.
- **Atmosphere** (saved): O₂ % and CO₂ ppm relax towards 20.9 % / 420 ppm plus the machines'
  contribution, with τ = 1 800 s.
  - Warming ΔT = 3 °C × log₂(CO₂ / 420). 3 °C per doubling is the IPCC AR6 best estimate of
    equilibrium climate sensitivity. The *time* is compressed (minutes, not centuries), and
    tower output is a game value.
  - CO₂ also speeds crops a little (CO₂ fertilisation; game factor up to +25 %).
- **Biomes** from the effective values:
  tundra T < 2 °C → desert water < 0.25 → wetland water > 0.78 →
  forest (water ≥ 0.45, nutrients > 0.46, 5 < T < 28) → grassland.
- **Render revision:** a cell's version bumps only when its quantised values change; a global
  version bumps when the warming crosses a 0.5 °C step. Chunks rebuild only on a change.

## Machines
| Machine | Construction kind | Workshop recipe | Sample needed | Effect *(game values)* |
|---|---|---|---|---|
| 喷淋塔 | `sprinkler` | `earth_sprinkler` | water | water +0.30, −1 °C |
| 制氧塔 | `oxygen_tower` | `earth_oxygen_tower` | oxygen | O₂ +0.4 % (cap +2 %) |
| 温室气体塔 | `co2_tower` | `earth_co2_tower` | carbon_dioxide | CO₂ +150 ppm (cap +1 200) |
| 氨肥撒播机 | `fertilizer_spreader` | `earth_fertilizer` | ammonia | nutrients +0.30, pollution +0.04 |

- They are 1-unit construction blocks, built from the backpack like solar panels, so the
  existing place / remove / repack rules apply.
- Workshop qualification now accepts water, oxygen, carbon_dioxide and ammonia samples.
- Each machine has a tall, distinctive model and an animated effect within 70 m.

## Hooks
- Wild sites sample their cell (moisture, water, temperature, pollution, O₂) instead of the
  constant `wild_environment`. Forest sites spawn boars.
- Home regions get the global warming and the cell's local temperature; the oxygen target
  scales with atmospheric O₂.
- Chunk grass is tinted by biome (blended between cells). Render-only decor (cacti, reeds,
  snow mounds, flowers, ferns) is drawn per biome. Trees are dry in deserts and snowy in tundra.
  Tree identity is unchanged.
- Save: an optional `environment` key in planet v2. Older saves load with an untouched planet.

## Tests
- `test_earth`: baseline determinism, start area unchanged, biome variety, emitter effect and
  biome shift, atmosphere and warming, decay after removal, round trip, forged values rejected,
  old saves without the key, wild-site sampling.
- `test_earth_ui`: the overlay map, building a machine through the workshop gate, tinted chunks.

## As built (v0.32.0)
- `scripts/planet_environment.gd` holds the field; `data/planet_environment.json` holds every number.
- The baseline is a deterministic sine-noise formula. Weights were tuned offline for a spread of roughly
  草原 41 % · 森林 14 % · 湿地 15 % · 荒漠 10 % · 冻原 20 % of the disc.
- Machines are counted from construction on each `construction.revision`. Local deltas relax to their
  targets with τ = 600 s (own cell + 35 % to the 4 neighbours, capped); the atmosphere relaxes with τ = 1800 s.
- Chunks rebuild only when their 3×3 cell versions change (quantised), or when global warming crosses a half degree.
- Machine effects (CPUParticles3D) are capped at 16 within 70 m.
- Program save v12 adds the kits; older saves gain them at 0.
- Screenshots: `docs/screenshots/v0.32/`.
