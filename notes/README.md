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
| [CHANGELOG.md](CHANGELOG.md) | Running log of what has actually been shipped on this track |

Quick commands:

```bash
bash dev/run_tests.sh                 # full headless suite -> artifacts/test-run/summary.txt
bash dev/run_tests.sh island          # only tests whose name contains "island"
python dev/gen_audio.py               # regenerate synthesized SFX/music into assets/audio/
```
