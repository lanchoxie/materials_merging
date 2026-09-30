# 06 · Planets, timelines and collecting — the big direction (2026-09-30)

User request (condensed from the Chinese message of 2026-09-30):
- Elements/materials synthesized on the island can **change the environment of a whole planet or of part
  of it**. This is the main link between island and planet.
- Worlds should be **as large as possible**. **Earth comes first**; other planets (No Man's Sky style) follow.
- Each planet has a **timeline**; the player can travel between eras. Each era has its own events and
  creatures, e.g. mammoths in the primitive era. They can be hunted, or turned into specimens with the model
  extractor (the existing 微缩器). The same applies to people of different eras.
- Conflicts per era: tribal conflict, ancient war, modern war, tech/AI war. Our materials influence them.
  Example: a people touching our metal for the first time can trigger a tech revolution.
- Natives build their own settlements and repair buildings we damaged.
- **Collecting specimens and building models is a core pillar.**

It is big, but it breaks down into ~8 layers that stack. Every layer reuses code that already exists.

## 0. What we already have (reuse, don't rewrite)

| Need | Existing piece |
|---|---|
| First-person, hotbar, block building, dig/fill ±6, chop/plant | `planet_v2*`, `river_construction`, `river_nature`, `river_inventory` |
| 16.4 km bounded world, 49 streamed chunks | `river_chunk_stream`, `data/planet_exploration.json` (FRONTIER-17) |
| Animals with health/hunger/breeding/heritable O₂ need, wild sites | `planet_v2`, `river_population` |
| Hunting / fighting back (health, anger, chase) | `river_combat` |
| Residents that fetch, farm, maintain facilities | `river_ranch`, `river_settlement` |
| 3 eras on one map (camp → farming → modern) | era page (FRONTIER-17) |
| Model extractor for own builds (≤64 blocks) → island display | `river_miniatures`, `island_miniature_view` |
| Island → workshop → planet products (water, O₂, filters, solar, wood…) | `planet_program`, `workshop_access`, `factory_recipes.json` |
| Collection UI with rarity/stars/reveal | v0.24 codex (`codex.gd`, `Fx.card_reveal`) |
| Day/night, water/glass/foliage shaders | v0.25 |

## 1. The layers

### L1 · Environment field — the island↔planet link (foundation, do first)
- Three scales: **planet** (atmosphere O₂/CO₂, mean temperature, sea level), **region cells** (coarse grid,
  ~256 m → 64×64 = 4096 cells on the current map; channels: water, temperature, nutrients, salinity,
  pollution, metal/material exposure), **local** (the existing planter/trough/fence level).
- **Emitters** made in the workshop from island products: sprinkler/irrigation tower, O₂ releaser, CO₂/heat
  tower, fertilizer spreader (urea, which the reactors already make), desalination unit, metal cache
  (metal ingots left for natives to find). Each has capacity, supply use and a radius. Planet-scale change needs
  many emitters or sustained output ("terraforming"), so it is never one click.
- Cells diffuse to neighbours at 1 Hz. The biome of each cell is derived from its channels
  (desert ↔ grassland ↔ forest ↔ wetland ↔ tundra). Vegetation colour, tree density and animal spawns follow.
- Science rule kept: effects come from **real channels** (water, O₂, CO₂, nutrients, salt, heat). A player's
  unknown structure never gets invented properties. It can still be a display piece, or be used in a clearly
  labelled "hypothesis" world.
- Visible payoff: an environment overlay map, plus before/after of the same region.

### L2 · Specimens & the museum — the collection pillar
- Extend the 微缩器 from "own builds" to **creatures** and **native buildings**:
  - Creature: hunt it (existing combat) → carcass → extract a specimen. Or non-lethal: tranquilize/scan (slower,
    rarer "live" specimen). Both give a posed miniature for the island.
  - Native building: scan an intact building → blueprint miniature. The original stays; natives can rebuild it.
- **Island museum**: display plinths plus a specimen codex (reuse the v0.24 card grid: rarity, era, where
  found, first-found date). Sets per era give bonuses (decor, research clues). Specimens are unique items: no copying.
- Collection is the long-tail goal. Every new era or planet adds pages.

### L3 · Timelines — travel between eras
- A planet has a fixed ordered set of timelines, e.g. Earth: 冰河/原始 → 古代 → 近代 → 现代 → AI 未来.
- **Same terrain seed, different era content pack**: species, biomes (ice age = colder baseline), native
  factions, building kits and event deck. The existing 3-stage era page becomes the first content.
- Each timeline has **its own saved diff** (built blocks, dug terrain, settlements, creatures, environment).
  Only the active one simulates. Others are frozen; no background time.
- Stage 1: timelines are independent. Stage 2 (later): **historical echoes**. Selected outcomes in an earlier
  era (a tribe you armed survives, a species you saved) change the starting state of later eras, from a small
  explicit list so it stays deterministic and testable.
- Travel UI: a time gate (reuse the light-bridge look) with an era dial.

### L4 · Living natives — settlements that build and repair
- Factions (tribe/city/state/corporation depending on era) have members, stockpile, known techs, needs and a
  settlement plan.
- Build loop (already sketched in EARTH-MASTERPLAN §6): need → pick project → reserve materials → carry → build.
  **Repair**: damaged/destroyed native buildings (including ones the player broke) enter the project queue.
- Buildings use the **same block kit** as the player (NMS Frontiers idea), so miniaturizing and repairing work
  on both.

### L5 · Tech diffusion — "they touched our metal"
- Each faction has tech levels per domain (tools, agriculture, metallurgy, energy, medicine, computing).
- Exposure to a player material (found cache, trade, gift, battlefield loot) → **use** → **maintain** →
  **make locally** (the three-tier model from MATERIAL-TIMELINES-RESEARCH §6). Only the last tier spreads.
- Crossing a threshold fires a visible **tech revolution event**: new building kit, new tools in hand, a
  banner in the log. Driven by real material categories (metal → tools/weapons, glass → greenhouses,
  solar → power), not by fake numbers on unknown structures.

### L6 · Conflicts & events per era
- An **event director** picks events that fit the era and the current state: migrations, famine, a mammoth
  herd arrives, a plague, tribal raid, ancient siege, industrial/world war, AI uprising.
- War is **faction-level abstract simulation** (strength, supply, tech, morale, territory), with **visible
  representative skirmishes** near the player (a few units reusing combat and residents), not an RTS.
- Materials matter through supply and tech: iron tools/weapons, medicine, food, fortifications. The player can
  arm a side, supply both sides, broker peace with supplies, or stay an observer.

### L7 · Bigger worlds
- Now: 16.4 km bounded plane. Next: **wrap-around planet map** (walk far enough east and you come back from the
  west; world map drawn as a globe), with **floating origin** for precision. No true sphere mesh, which is much
  cheaper on mobile.
- True voxels/caves are a separate, later project (storage/meshing rewrite). Keep the ±6 heightmap until then.

### L8 · More planets
- After Earth works end to end: a star map and a second planet built as a content pack. Example: a cold
  CO₂ planet where warming + O₂ + water is the long terraform goal, with its own species and timeline.
- Planets differ by baseline environment and species tolerances. The same product can help on one planet
  and hurt on another, which is the fun of choosing what to synthesize.

## 2. Content/tone decision to confirm with the user
- **Humans as specimens.** Recommended: animals can be hunted or scanned. People of any era are collected
  **non-lethally**: 3D scan / portrait miniature / keepsake traded or given when they trust you. They can
  still be hurt in fights and wars. Reasons: tone (cozy-but-deep, the vision in 02-vision.md), the Android
  store age rating, and it gives a reason to befriend natives. **Confirmed by the user (2026-09-30).**
- Timelines independent first, historical echoes later: **confirmed**.
- Wrap-around map + floating origin, no true sphere: **confirmed**.
- Ground becomes a voxel grid with our own real-mineral geology: see [07-world-blocks.md](07-world-blocks.md)
  (it moves the release table below back by two: v0.26 Bedrock, v0.27 Refinery, v0.28 Earth).

## 3. Release slicing (each one playable, tagged, save-migrated)

| Release | Theme | Must-have | Reuses |
|---|---|---|---|
| **v0.26 "Earth"** | the link | Fix/stabilise the river touch tests first; name the planet 地球; region environment grid + planet atmosphere; 3–4 emitter products from island elements (water tower, O₂, fertilizer from urea, CO₂/heat); biome shift visible; overlay map | planet_v2, factory recipes, v0.25 shaders |
| v0.27 "Specimens" | collect | 微缩器 on creatures (hunt → specimen, scan → live specimen) and native buildings; island museum + specimen codex | combat, miniatures, codex UI |
| v0.28 "Ice Age" | timelines | timeline framework + per-timeline saves; 冰河/原始 era: mammoth, woolly rhino, cave bear, a tribe; time gate | chunk stream, population, light bridge |
| v0.29 "Settlers" | natives | faction model; tribes build/expand/repair with the shared block kit | river_settlement, construction |
| v0.30 "Bronze" | tech diffusion | material exposure → use/maintain/make; first tech revolution event | workshop products |
| v0.31 "Clash" | conflict I | event director; tribal conflict + ancient war (abstract + visible skirmishes); supplies matter | combat |
| v0.32–0.34 | more eras | 古代 → 近代(工业/世界大战) → 现代 → AI 未来, each with species/faction/event pack | all of the above |
| v0.35 | big world | wrap-around map, floating origin, globe world map | chunk stream |
| v0.36+ | planets | star map + second planet content pack | everything |

Rules that keep it shippable:
- **Every system first gets one small, complete example**: one emitter, one specimen, one era, one war.
  Only then comes a content pack.
- Mobile budgets from EARTH-MASTERPLAN §10 still apply: 1 detailed world, ≤36 nearby detailed entities,
  1 Hz ecology, 5 s faction planning.
- Models stay procedural low-poly, limbs from primitives (this picks up the deferred "limbed animals" item).
  No Blender dependency until silhouettes need it.
- Save compatibility: each layer adds its own versioned section with defaults. The saves of all old tags keep loading.
