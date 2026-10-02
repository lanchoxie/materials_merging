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
| [17-testbuild-earth-ux.md](17-testbuild-earth-ux.md) | v0.33.1: 测试版 build and panel, depot by E, era action rows, 微缩器 preview, god view follows you, beacons, trail, 世界地图, sky-blue fixes |
| [CHANGELOG.md](CHANGELOG.md) | Running log of what has actually been shipped on this track |

Quick commands:

```bash
bash dev/run_tests.sh                 # full headless suite -> artifacts/test-run/summary.txt
bash dev/run_tests.sh island          # only tests whose name contains "island"
python dev/gen_audio.py               # regenerate synthesized SFX/music into assets/audio/
```
