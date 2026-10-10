# Fun Overhaul Notes (Claude track)

This directory is separate from `docs/` on purpose. `docs/` is the historical design/release record
written during v0.1–v0.21 (Chinese). These notes cover the new **"make it fun and cool"** track that
starts from the `archive/v0.21.0-interiors-18` baseline.

| File | What's in it |
|---|---|
| [01-audit.md](01-audit.md) | What the game is today, what is great, what is hurting it (with code references) |
| [02-vision.md](02-vision.md) | Creative direction: the five fun pillars and the rules we follow |
| [03-roadmap.md](03-roadmap.md) | Release-by-release rollout plan (v0.22 → v0.26) with concrete tasks |
| [04-versioning.md](04-versioning.md) | Branches, tags, save compatibility, and how old versions are kept |
| [05-tech.md](05-tech.md) | Engine/language choices, new architecture pieces, asset pipeline |
| [06-planets.md](06-planets.md) | The big direction: environment field, specimens, timelines, natives, wars, more planets |
| [07-world-blocks.md](07-world-blocks.md) | Voxel ground vs Minecraft, real-mineral geology, refinery loop |
| [08-chemistry-loop.md](08-chemistry-loop.md) | Element shop removal, MP/COD/PubChem chemistry index, compound → gear loop |
| [09-island-town.md](09-island-town.md) | v0.27 island town: tile placement, decorations, pedestals, tier looks |
| [10-refinery.md](10-refinery.md) | v0.28: navigation stack, refinery, reactor tiers and phases, first-time tours |
| [11-index.md](11-index.md) | v0.29: offline MP/PubChem chemistry index, honest matching, index browser, credits |
| [12-fabricator.md](12-fabricator.md) | v0.30: crystals → pick heads (Chen hardness) and solar panels (Shockley–Queisser); Fe/Sn smelting |
| [13-builder.md](13-builder.md) | v0.31: seamless plots, items across plot edges, undo/eraser/recycle, doctor and element gates |
| [14-industry-island.md](14-industry-island.md) | Phase 2 plan: Starforge Isle industry chain (materials → chips → energy → vehicles → gear → space) |
| [15-earth.md](15-earth.md) | v0.32: climate field, biomes, environment machines, warming, 环境图 |
| [16-polish.md](16-polish.md) | v0.33: sky and shadows, shaded hands and tools, chibi residents, rigged planet creatures, water shader |
| [22-incidents-specimens.md](22-incidents-specimens.md) | v0.36: data-driven era framework, storms/floods/droughts with warnings and preparation, PVC pipes, 标本图鉴 |
| [32-starforge-isle.md](32-starforge-isle.md) | v0.43: island Ⅱ deck expansion, staff stamina and the lounge, decorations on the deck, first-person walk, 星锻公寓 interior |
| [31-globe.md](31-globe.md) | v0.42: wrap-around planet, continents/oceans/ranges/caves, latitude climate, globe god view, whole-planet map |
| [30-wild-harvest.md](30-wild-harvest.md) | v0.41.2: probabilistic drops, no piles/stumps, food and cooking, building copies, per-cell preview, machines; the agreed roadmap |
| [29-custom-reactors.md](29-custom-reactors.md) | v0.41.1: 我的炉型, 空白反应炉, PubChem reference geometry for custom molecules; phone hang notes |
| [28-rover.md](28-rover.md) | v0.41: vehicle assembly, the rover's kinematic driving, chase camera, energy and charging |
| [27-batteries.md](27-batteries.md) | v0.40: battery works (lead-acid, LiFePO₄ thickness trade-off), packs, motor, cordless drill on Earth, grid storage |
| [26-ice-age.md](26-ice-age.md) | v0.39: time gate between timelines, cold survival (campfire, roof, 保温服), 寒潮暴雪, mammoths and woolly rhinos |
| [25-chips-light.md](25-chips-light.md) | v0.38: chip fab (lithography yield), perovskite LEDs (bowing, V(λ)), packaging, control boards, the headlamp |
| [24-playtest-fixes.md](24-playtest-fixes.md) | v0.37.1: leaving 星锻岛 and its layout, miniature unfolding/pedestals/复刻, batch and loop production |
| [23-silicon-materials.md](23-silicon-materials.md) | v0.37: Si/Ca/P and apatite, MP rebuild, material property model v1 (knobs, lots, laws, test bench), inorganic works, silicon foundry |
| [21-home-market.md](21-home-market.md) | v0.35: promotion pipeline (service years, 延毕, approval), 星锻公寓, senior staff, 未来家居工坊, rubber, contracts + airship |
| [20-material-model.md](20-material-model.md) | design: continuous material properties from real anchors + simplified laws (doping, processing), test bench, gear mapping; v0.37 → v0.43 |
| [19-starforge.md](19-starforge.md) | v0.34: 星锻岛 — 岛主 XP bar, 工业信用, deck plots, metallurgy and polymer works, trade hub, steel drill bit, Blender pipeline |
| [18-terrain-caves.md](18-terrain-caves.md) | v0.33.2: hills, ridged mountains, river valley, karst caves with mouths, legacy pads for old far builds, hill-shaded 世界地图 |
| [17-testbuild-earth-ux.md](17-testbuild-earth-ux.md) | v0.33.1: 测试版 build and panel, depot by E, era action rows, 微缩器 preview, god view follows you, beacons, trail, 世界地图, sky-blue fixes |
| [CHANGELOG.md](CHANGELOG.md) | Running log of what has actually been shipped on this track |

Quick commands:

```bash
bash dev/run_tests.sh                 # full headless suite -> artifacts/test-run/summary.txt
bash dev/run_tests.sh island          # only tests whose name contains "island"
python dev/gen_audio.py               # regenerate synthesized SFX/music into assets/audio/
```
