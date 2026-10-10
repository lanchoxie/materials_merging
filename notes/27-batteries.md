# 27 · v0.40 "Batteries & Power" (电池与能源): battery works, LFP cells, the cordless drill, grid storage

Industry slot from the interleaved plan ([14-industry-island.md](14-industry-island.md), v0.40: "Energy: batteries
(lead-acid → LiFePO₄), energy park"). P arrived in v0.37, so LiFePO₄ is no longer deferred.

I built this while the user was away. The design calls below are mine:
- The planet payoff is a **cordless drill**: plan §6 lists drills and battery packs.
- The energy park is folded into **grid storage**, since solar panels already feed the grid (v0.37).

## Chain
| Building | Recipe | Inputs → output | Gate | Model |
|---|---|---|---|---|
| **电池工厂** (14 000 c + 50 cr, power 3) | 铅酸蓄电池 | 4 Pb, S, 4 O, 2 H, PE (case) → 1 | PbSO₄ (made in the sandbox) | — |
| | 磷酸铁锂电芯 | Li, Fe, P, 4 O, 2 C, Al (foil), Cu (foil) → 4 | LiFePO₄ | lfp_cell |
| | 电池包 | 8 cells, IC (BMS), duralumin → 1 | — | battery_pack (inherits t) |
| 冶金工厂 | 电机 | 3 Cu, 3 Fe, Si (silicon steel) → 1 | — | — |
| 封测电路板厂 | 充电电钻 | motor, steel bit, battery pack → 1 | — | power_drill (inherits t) |

## Laws (`material_model.gd`; sources Padhi 1997, Zheng 2012, May 2018, Moses 1990)
The knob is the cathode coating thickness t, 40–200 µm.

- **Capacity (Faraday):** 96485 / (3.6 × 157.76) = **170 mAh/g**, exact. Plateau ≈ 3.3 V, so the cathode gives ≈ 560 Wh/kg. *(真实数据)*
- **Cell specific energy:** 560 × 0.4 × t/(t+60). Current collectors, separator and case store nothing, so thicker is better. This lands at 90–175 Wh/kg, the real LFP cell range. *(简化模型)*
- **Rate capability:** C_max = 10·(50/t)², because the diffusion time grows with t². *(简化模型)*
- **Tool energy:** Wh/kg × min(1, C_max/3C). This gives an interior optimum near 90 µm. A thin coating stores too little; a thick one can't drive a drill. *(游戏数值)*
- **Pack:** 8 × 26650-class cells (85 g each) ≈ 13 V and 80–100 Wh, which matches a real 18 V / 4 Ah tool battery (72 Wh).
- **Drill:**
  - 3 Wh per dug block *(game)*.
  - At ≥ 3C the drill halves the hits per block; a weaker pack gives up to ×0.8.
  - The motor uses silicon steel (Fe-3%Si), whose resistivity is about 4× that of plain steel, which cuts eddy-current losses. *(真实)*

## Planet
- **Equipping.** Equip the drill in the 装备 tab. Its state (`charge, cap, factor, wh`) is one dictionary shared by `industry.drill_state` and `nature.drill`, so digging drains the same charge the UI shows.
- **Digging.** `nature.dig` multiplies the needed hits by the factor while the charge holds at least one block's worth. The prompt shows 「电钻 n%」.
- **Recharging.** Charge refills whenever the player is not on the planet (full in about 120 s, *game*). Planet ↔ island ↔ planet is the loop.

## Island grid
- **储能电池.** Lead-acid gives +1 power and an LFP pack +2 (*game*), up to 8 batteries, permanently installed.
- **Buyer.** A new 海岛微电网 buyer wants batteries, cells, motors and panels. 山地研究所 also takes drills and packs.

## Save
Industry stays at version 3, with optional `drill`, `drill_charge` and `storage` (each unit 1–2, at most 8).

## 测试版
「电池原料包」 adds the elements, PE/IC/duralumin/bits and the PbSO₄ and LiFePO₄ gates.

## Verification
- **`tests/test_batteries.gd`** (29 checks):
  - Faraday's 170 mAh/g;
  - the energy/rate trade-off and the real Wh/kg range;
  - the interior optimum;
  - pack Wh and blocks per charge;
  - a weak pack drills weaker;
  - the whole chain, with thickness inheritance;
  - the drill shares state with the planet, digs out a cell, uses charge and recharges on the island;
  - lead-acid storage +1;
  - the drill can't be sold;
  - save and rejection.
- **`tests/test_starforge_layout_ui`** includes the battery works.
- **`tests/capture_batteries.gd`:** screenshots in `docs/screenshots/v0.40/`.

## Later
- Sodium-ion (Prussian white) and Li–S from the plan's table.
- A real energy park (fuel cell + H₂).
- Batteries for rovers (v0.41).
