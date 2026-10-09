# 23 · v0.37 "Silicon & Materials" (硅与材料): Si/Ca/P, material property model v1, inorganic works, silicon foundry

Industry slot from the interleaved plan ([14-industry-island.md](14-industry-island.md), v0.37). It also builds the
design agreed in [20-material-model.md](20-material-model.md). The user asked for this on 2026-10-09:
- properties must be continuous, not Minecraft tiers;
- simplified laws, but honest;
- the properties should drive gear.

It also delivers part of the user's backlog: "还有一些元素没有矿石对应的".

## Stage A · elements, ore, refinery, index
- **Elements.** Si 硅, P 磷 and Ca 钙 join the game, making 19 elements.
  - Radii are covalent radii from Cordero 2008, the same source as the others. Colours are CPK.
  - Starter stock is unchanged, so the new elements start at 0.
- **Ore.** 磷灰石 apatite, Ca₅(PO₄)₃F, Mohs 5 (the same reference mineral as the starter pick).
  - It occurs as sedimentary phosphorite blobs in the limestone layer below −6 m.
  - Every material still occurs within ±48 m of home (`test_bedrock`).
- **Refinery routes:**

  | Route | Inputs → output | Chemistry |
  |---|---|---|
  | 石英砂还原硅 (arc furnace) | 2 sand + 2 coal → 2 Si | SiO₂ + 2C → Si + 2CO; gives metallurgical-grade Si |
  | 熔盐电解制钙 (Davy 1808) | 2 limestone + 2 halite → 2 Ca + Cl | via CaCl₂ |
  | 磷灰石电炉制磷 (Wöhler electric furnace) | 2 apatite + 2 sand + 2 coal → 3 P | sand takes the Ca as CaSiO₃ slag |

  The limestone text no longer says the game has no Ca.
- **Index rebuild.**
  - **Materials Project** (key read from `.runtime/secrets` only; no key in any log, file or commit):
    - 2 733 crystals, up from 1 835, of which 1 113 are experimentally observed. The file is 2.0 MB.
    - Two new fields: `poisson` (Poisson's ratio, 623 entries) and `n` (refractive index, 710 entries).
    - Every old id is kept, so saved index finds stay valid.
  - **PubChem:** 10 new Si/P molecules, 116 in total. They include SiH₄, SiCl₄, SiHCl₃ (the Siemens feed), PH₃, PCl₃, PCl₅, POCl₃ and H₃PO₄.
- **Atom palette.** 5 columns inside a scroll box, so 19 elements fit.
- **Refinery cards.** Long route titles now wrap.

## Stage B · material property model v1 (`scripts/material_model.gd`, `data/material_model.json`)
- **Lots.** A modelled item is a set of *lots*: `{n, k: knobs, q: scatter, m: measured}`.
  - The counts in `industry.items` stay authoritative. Every count change goes through `take_item`, so the lots always sum to the count.
  - Stacks merge when knobs and quality agree to 1 %. There are at most 24 lots per item, after which new units join the nearest lot.
  - Consumption takes the worst lots first, so the best bit stays equipped.
  - A save before v0.37 gets default lots.
- **Knobs** are sliders on each recipe in 「生产」, with a live prediction (`预测：硬度 HV 664 ±8% · 韧性 33%`).
  - A 「规律（为什么是这个数）」 button shows each law with its tag — 真实数据, 简化模型, 近似精确 or 游戏数值 — and its source.

  | Recipe → family | Knob | Law (simplified, cited) | The interesting part |
  |---|---|---|---|
  | 碳钢锭 → carbon_steel | C 0.1–1.2 wt% | lever rule ferrite HV 90 ↔ pearlite HV 280; proeutectoid cementite; ρ by volume mix | harder ↔ less tough |
  | 碳钢钻头 → steel_tool | temper 150–650 °C; carbon inherited from the ingots used | Krauss martensite-hardness curve; Hollomon–Jaffe tempering P = T(20 + lg t); tempered-martensite embrittlement near 300 °C; edge = H·√(tough/0.25) below the chip limit | interior sweet spot (≈ C 0.6, 150–200 °C); too much carbon chips |
  | 锡青铜 → tin_bronze | Sn 4–22 wt% (more Sn needs more Sn atoms) | solid solution ΔH ∝ c^½; δ phase above 13.5 % hardens and embrittles | bell metal is hard but brittle |
  | 硬铝 → duralumin | ageing time at 190 °C, 0.25–200 h (log slider) | peak-ageing curve: rises, peaks near 10 h, overages | under- and over-aged are softer but tougher |
  | 铝锂合金 → al_li | Li 0.5–2.8 wt% | −3 % ρ and +6 % E per wt% Li (Rioja & Liu); δ′ planar slip above 1.8 % | specific stiffness ↔ toughness |

- **Scatter.** Each lot has a seeded ±3 % scatter.
  - Unmeasured lots show the prediction with a ±8 % model band.
  - **材料测试台** (a new building: 1 500 coins, 8 credits, power 1, a Blender model) measures a lot for 30 coins. The band becomes the measured value, and the lot gets a report bonus of +15 % on its price.
- **Prices.** A lot's price = market price × clamp(score^0.8, 0.5, 2) × report bonus.
  - Score = weighted property ratios against the default lot.
  - Buyers pay for the property that matters: hardness for steel, specific stiffness for Al-Li, durability for glass, efficiency for wafers.
- **Gear.** The 碳钢钻头 cuts with its best lot's edge hardness, not a fixed 7.4 GPa.
  - The default (C 0.45, 200 °C) gives about 6.3 GPa. A well-chosen bit gives about 7.5 GPa; the starter pick is 5.43.
  - The gear card says whether the value is predicted or measured.

## Stage C · 无机材料厂 and 硅材料厂
New input kind `min:` takes planet minerals (`nature.minerals`) straight into a recipe.

| Building | Recipe | Inputs → outputs | Gate (made in the 原子工坊) | Model |
|---|---|---|---|---|
| 无机材料厂 (4 500 c + 30 cr, power 3) | 钠钙玻璃 | 3 sand + 1 limestone + Na → 2 glass | — | soda_lime_glass |
| | 硅酸盐水泥 | 3 limestone + 1 clay → 3 cement | CaO (NaCl template, Na→Ca, Cl→O) | — |
| | 瓷砖 | 3 clay + 1 sand → 2 tiles | — | — |
| | 过磷酸钙磷肥 | 2 apatite + S, O, H → 3 fertiliser | H₃PO₄ (molecule) | — |
| 硅材料厂 (8 000 c + 50 cr, power 4) | 多晶硅（西门子法） | 4 Si + H + Cl → 2 polysilicon | SiHCl₃ (molecule) | — |
| | N 型硅片 | 2 polysilicon + P → 3 wafers | Si crystal | n_wafer |
| | 太阳能板 | 2 wafers + glass + duralumin → 1 panel | — | solar_panel (inherits the wafer doping) |

**Glass.** The knob is Na₂O, 12–18 mol%.
- **Refractive index:** Appen additive n = Σ xᵢnᵢ, which gives 1.518 at 15 %.
- **Working temperature:** falls with soda. The melt time scales by 1.5 → 0.75 (a new `seconds_by_knob`).
- **Durability:** falls with soda.
- The trade-off is fast and cheap versus durable.

**Wafer.** The knob is P doping, lg N = 14–19.
- **Mobility:** Masetti 1983 fit for electrons.
- **Resistivity:** ρ = 1/(qNμ). 5×10¹⁵ cm⁻³ gives about 1 Ω·cm, as in a real solar wafer.
- **Cell efficiency:** peaks near 1 Ω·cm at 26 %. Too little doping lowers Voc; too much causes Auger loss (simplified).
- **Band gap note.** The laws card says that MP's PBE band gap for Si (0.45 eV) underestimates the measured 1.12 eV. This is a known DFT limitation.

**Panel.** Module efficiency is cell × 0.92. Power is efficiency × 1 600 W (1.6 m² at 1000 W/m²).

**Uses:**
- **太阳能板 → 岛心电网.** In the 装备 tab, 「装一块」 installs the best lot. The grid gains floor(Σ efficiency / 20 %), with at most 12 panels. This is the first way to grow the grid other than rank.
- **磷肥 → Earth.** In the 装备 tab, 「施一份磷肥」 adds +12 % nutrients to every Earth region with crops. If none needs it, nothing is spent.
- **Contracts.**
  - A new buyer, 沙漠光伏电站, wants wafers, panels, glass and polysilicon.
  - 河湾合作社, 城市百货 and 港口船厂 also take cement, tiles, glass and fertiliser.

**Models.** `test_bench`, `inorganic_works` and `silicon_works` are built by `dev/blender/starforge.py`. The script now takes `-- name …` to build only some models.

## UI fixes found in screenshots
- **Deck tab.** The build buttons wrap (HFlowContainer). With 8 building kinds they used to widen the right panel past the screen.
- **Glyph.** The ▾ glyph is not in the UI font; the button says 「规律（为什么是这个数）」 / 「收起规律」 instead.

## Save
- `industry` serialises version 3 with `lots`, `settings` (knob per recipe), `lot_serial` and `solar`.
- **Validation.**
  - Lots must sum to the item count.
  - Lots are allowed only on modelled items.
  - Knobs must belong to the family.
  - q is between 0.8 and 1.2.
  - Panel efficiency is ≤ 0.5.
  - A job may carry knobs, and its time is up to 2× the base (glass).
- **Compatibility.** Versions 1 and 2 still load. The game save version stays 28.

## 测试版
「硅钙磷原料包」 in the island row adds:
- the new elements and ores;
- the four gate compounds in the index.

## Verification
- `tests/test_material_model.gd` (34 checks):
  - every law's shape;
  - the steel sweet spot;
  - the chip edge;
  - TME;
  - knob clamping and scatter;
  - jobs remembering knobs;
  - knob-scaled inputs;
  - default lots for old units;
  - inherited carbon;
  - the planet bit hardness;
  - prices by quality;
  - the test bench;
  - per-lot selling;
  - save round trip and rejection;
  - v0.36 saves.
- `tests/test_silicon.gd` (35 checks):
  - elements and sources;
  - index coverage;
  - glass and wafer laws;
  - module watts;
  - both buildings;
  - mineral inputs;
  - gates;
  - polysilicon → wafer → panel with inherited doping;
  - solar grid power;
  - fertiliser with and without crops;
  - saves.
- Updated tests:
  - `test_bedrock`: 19 materials.
  - `test_industry` and `test_starforge_ui`: the bit hardness is the modelled edge.
- `tests/capture_silicon.gd` (screenshot helper). Screenshots are in `docs/screenshots/v0.37/`.
