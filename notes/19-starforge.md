# 19 · v0.34 "Starforge Isle" (星锻岛 · 浮岛 Ⅱ)

First release of phase 2. Plan and decisions: [14-industry-island.md](14-industry-island.md) (slot I1).
The user confirmed "按计划来" on 2026-10-09.

## What shipped
- **岛主等级 with a visible XP bar.**
  - The top bar shows `岛主 Lv.n · into/need XP` and a lilac progress bar.
  - "+N XP" pops rise from the bar, and a banner marks each new rank.
  - Curve: rank n → n+1 needs `60·n^1.3` XP *(game)*.
- **One-time conversion of old progress.**
  - On the first tick, the legacy score is turned into XP once, with no pop. The score counts milestones ×20, codex stars ×10, index finds ×15, Σ reactor levels ×5, plots ×8, refinery level ×50 and fabricator crafts ×25.
  - After that, any growth of that score keeps paying XP (`industry.sync_legacy`).
  - Nothing else had to be hooked: XP is the diff of state the game already tracks.
  - Industry adds its own XP: building, upgrading, every crafted item, and sales (1 XP per 10 coins).
- **Unlock card.** Island Ⅱ unlocks at:
  - rank 6
  - 12 000 coins
  - 30 合金片
  - 24 home plots
  - refinery Lv 2
  - one fabricator craft

  Each condition shows ✓/✗ with a how-to line. These were softened from the plan's draft values, and they all live in `data/industry.json`.
- **工业信用.** Fuse 星砂 + 晶露 + 合金片 (1 each) into 5 credits, one-way, at ×1 or ×10.
- **Deck.**
  - The island starts with 4 plots and can grow to 16 in this release.
  - Each new plot costs coins and credits, growing ×1.18 per plot.
  - A starter grid gives 10 power. One licence per factory kind, plus one more per 6 ranks.
- **Factories.**
  - Each factory has levels 1–3: +25 % speed and +1 queue slot per level.
  - Like the refinery, inputs are reserved when a job is queued. Jobs also run during offline catch-up.

  **冶金工厂 (Metallurgy Works)**
  | Product | Inputs | Unlocked by making |
  |---|---|---|
  | 碳钢 (carbon steel) | Fe + C | Fe₃C |
  | 锡青铜 (tin bronze) | Cu + Sn | Cu₃Sn |
  | 焊料 Sn63Pb37 (solder) | Sn + Pb | — |
  | 硬铝 (duralumin) | Al + Cu | Al₂Cu |
  | 铝锂 (Al–Li) | Al + Li + Cu | LiAl |
  | 碳钢钻头 (carbon-steel drill bit) | carbon steel ingots | Fe₃C |

  **高分子工厂 (Polymer Works)**
  | Product | Inputs | Unlocked by making |
  |---|---|---|
  | PE | ethanol batches | C₂H₄ |
  | PVC | ethanol + Cl | C₂H₃Cl |
  | PTFE | C + F | C₂F₄ |
  | 脲醛树脂 (UF resin) | urea batches + C/H/O | CH₂O |

  - Every recipe shows its real method and equation, with the source in `industry.json`.
  - **Evidence gate:** the compound must be in `index_found`. It is looked up by formula across the MP crystals and PubChem molecules (`Industry.has_made`).
- **星港交易所 (Trade Hub).**
  - It sells industry items only, never elements or raw batches.
  - Price = base × demand. Demand = 1 − saturation (floor 25 %). Each unit sold adds 0.04, and saturation halves every 20 min *(game)*.
- **Planet payoff: 碳钢钻头.**
  - Hardness is 7.4 GPa, the real order of magnitude for hardened tool steel (about HV 750).
  - Once equipped, `sync_gear` uses it whenever it is harder than the fabricator pick. The starter pick is 5.43 GPa.
- **Blender pipeline.**
  - Portable Blender 4.2.3 LTS lives in `tools/blender/` (git-ignored, checksum-verified download).
  - `dev/blender/starforge.py` builds the metallurgy works, polymer works, trade hub, deck tile and thruster, and exports them to `assets/models/starforge/*.glb`. It is committed, so the models are reproducible:
    ```
    tools/blender/blender.exe -b --factory-startup --python dev/blender/starforge.py
    ```
  - **Lesson:** glTF emissive strength above 1 reads as white on the Compatibility renderer. Accents keep strength ≤ 1, so their hue survives.
- **星锻岛 screen.** `starforge_panel.gd` plus `starforge_view.gd`.
  - It shows a floating deck diorama on four glowing thrusters over a hex hull, with ghost outlines for future plots.
  - Tabs: 甲板 (deck), 生产 (production), 交易所 (trade hub), 装备 (gear).
  - It opens from the new 「星锻岛」 toolbar button.
- **测试版.** The test panel gets 「开放星锻岛 +300信用」.
- **Save.**
  - Save version 28 adds an `industry` section with a strict validator: buildings only on owned plots, recipes matching their factory, bounded jobs, items and saturation.
  - Older saves load with island Ⅱ locked, and their old progress converts to XP.

## Not in this slice (moved to later slots)
- The cyan light bridge, the airship loop and the maglev ring are visuals. A toolbar button and screen replace the switcher for now.
- PVC irrigation pipe (planet emitter), contracts, airship export and the furniture studio go to v0.35 with the promotion pipeline.

## Verification
- `tests/test_industry.gd` (30 checks) covers:
  - the rank curve and the legacy conversion;
  - the unlock gates and their cost;
  - fusing;
  - licences, power and plots;
  - the evidence gate, reserved inputs, production and XP;
  - batch inputs;
  - market saturation and recovery;
  - the bit setting the planet dig hardness;
  - JSON round trip and rejection, and the whole-game save.
- `tests/test_starforge_ui.gd` (12 checks) covers the toolbar, the locked card, and build, feed, sell and equip through the panel buttons, plus the XP pop.
- `tests/test_state.gd` and `tests/test_builder.gd` now expect save version 28.
- `tests/capture_starforge.gd` is a screenshot helper. Its screenshots are in `docs/screenshots/v0.34/`.
