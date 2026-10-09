# 25 · v0.38 "Chips & Light" (芯片与光): chip fab, packaging, perovskite LEDs, the headlamp

Industry slot from the interleaved plan ([14-industry-island.md](14-industry-island.md), v0.38: "Chip fab +
packaging (P-doped Si, LEDs from the band gap)"). It builds on the v0.37 material model
([20-material-model.md](20-material-model.md)).

I built this while the user was away ("做完之后继续做下一个版本…不需要等我"), so the design calls below are mine:
- Two buildings, as in plan §2.
- LEDs from the perovskite system the game already teaches (the CsPbBr₃ / CsPbCl₃ templates), not GaN, because Ga is not in the game.
- The headlamp is the planet payoff, from plan §6.
- Control boards are a sink for the IC chain.

## Buildings and chain
| Building | Recipe | Inputs → output | Gate | Model |
|---|---|---|---|---|
| 高分子工厂 | 光刻胶 (novolac + DNQ) | C 6, H 6, O 1 → 3 | phenol C₆H₆O (molecule) | — |
| | 环氧树脂 | C 3, H 5, Cl, O → 3 | — | — |
| **晶圆芯片厂** (15 000 c + 60 cr, power 5) | 逻辑芯片 | wafer, photoresist, Cu, 2 F (CF₄ etch), O (gate oxide) → 4 | (the wafer is already gated) | lithography |
| | 功率二极管 | wafer + Al (p⁺ diffusion) → 6 | — | — |
| | 钙钛矿 LED 芯片 | Cs, Pb, Br/Cl (by x), glass → 4 | CsPbBr₃ (crystal) | perovskite_led |
| **封测电路板厂** (12 000 c + 40 cr, power 3) | FR-4 电路板 | glass (fibre), epoxy, Br (flame retardant), 2 Cu (foil) → 2 | — | — |
| | IC 封装 | 2 logic chips, solder, epoxy → 2 | — | packaged_ic (inherits linewidth) |
| | 工厂控制板 | pcb, 2 IC, 2 diodes → 1 | — | — |
| | LED 头灯 | 2 LED chips, pcb, duralumin → 1 | — | headlamp (inherits x) |

## Laws (in `material_model.gd`, data and sources in `material_model.json`)
**Lithography.** The knob is linewidth L, 0.35–5 µm on a log slider.
- **Rayleigh limit:** R = k₁λ/NA, with an i-line 365 nm source, NA 0.6 and k₁ 0.6, gives R ≈ 0.37 µm. Printing yield falls sharply as L approaches R. *(真实数据 / 简化)*
- **Transistors:** 25 mm² ÷ (100 F²) gives 111 thousand at 1.5 µm. The anchor is the 1985 Intel 386: 1.5 µm and 275 k transistors on a larger die. *(简化模型)*
- **Defects:** Stapper's killer-defect size distribution ∝ 1/x³, so defect density ∝ 1/L². Yield follows Poisson, Y = e^(−D·A). *(简化模型)*
- **Clock:** Dennard scaling, ∝ 1/L. *(简化模型)*
- **Value:** good transistors = N × Y. This peaks at an interior linewidth, around 0.5 µm. Too coarse holds too few transistors; too fine and the yield collapses.

**Perovskite LED.** The knob is x, the Cl fraction in CsPb(Br₁₋ₓClₓ)₃. The input mix of Br and Cl follows x.
- **Band gap:** E_g(x) = (1−x)·2.38 + x·3.02 − 0.1·x(1−x) eV. These are experimental gaps (Protesescu 2015); the MP PBE gaps underestimate them, and the card says so.
- **Wavelength:** λ = 1240 / E_g, giving 521 nm green to 410 nm violet.
- **EQE:** 20 % for green down to 5 % for blue/violet. This follows the literature trend. *(简化模型)*
- **Efficacy:** 683 lm/W × V(λ) × EQE, using the CIE photopic curve (Gaussian fit). Green is about 1 000× brighter to the eye than violet. *(真实数据)*

**Headlamp.**
- 3 W, so lumens = efficacy × 3.
- Reach = 3 + 1.2·√lumens metres. The square root is real (inverse-square illuminance); the constants are game values.
- Its colour is the LED's wavelength (Bruton's spectrum-to-RGB approximation).

## Rules added to the industry
- **Inherited properties use the best lots.** When a product inherits a property (the bit's carbon, the IC's linewidth, the lamp's LED colour), the recipe consumes the **best** lots of that input. Sales, contracts and plain inputs still take the worst first.
  - Found from the screenshots: the first headlamp came out cyan from the leftover x = 0.4 LEDs, although green ones were in stock.
- **Control boards.** One per factory, +25 % speed (*游戏数值*). Install it from the 「甲板」 card. It is saved as `buildings[plot].board`.
- **The worn headlamp is reserved** like the bit: it can't be sold or used as an input (`reserved()`).

## Planet
- **Wearing the lamp.** 「戴上（星球第一人称）」 is in the 装备 tab, next to a colour swatch and the lot's numbers.
- **The spotlight.** It hangs on the camera and switches on when (`lamp_needed`) any of these holds:
  - it is night (sun phase < 0.3);
  - the sky is a storm (dark > 0.5);
  - the eye is more than 0.4 m below the natural surface, i.e. in caves and pits.
- **Light.** The light colour and range come from the lot. Energy grows with lumens.
- **Darker nights.** Ambient light in first person now drops from 0.55 to 0.28 at night, so the lamp is worth having. Daytime is unchanged.

## Other
- **New buyer.** 深湾电子城 wants ICs, chips, PCBs, LEDs and control boards. 山地研究所 also takes headlamps and diodes.
- **Blender models.** `chip_fab` (sawtooth clean room, lens tower, violet beam on a wafer) and `packaging_plant` (a PCB-skinned slab with an IC and pins).
- **测试版.** A 「芯片原料包」 button.
- **Footer.** It reads v0.38.

## Save
Industry stays at version 3, with two optional keys:
- `lamp`: must be an item flagged `lamp`.
- `buildings[*].board`: a bool, factories only.

## Verification
- **`tests/test_chips.gd`** (32 checks):
  - every law's shape (386 anchor, Rayleigh/yield, Dennard, interior optimum, 521/410 nm, bowing, V(λ) brightness, colour names);
  - the whole chain;
  - Br/Cl input mixing;
  - IC linewidth inheritance;
  - the lamp from the best LED lot, with the bluer lot kept;
  - the control board, +25 %, once per factory;
  - the lamp can't be sold;
  - the brightest lot is the one worn;
  - save and rejection.
- **`tests/test_headlamp_ui.gd`:**
  - on at night in green with the modelled reach;
  - off without a lamp;
  - off at noon;
  - a storm turns it on.
- **`tests/test_starforge_layout_ui.gd`** now includes both new buildings; every tab still fits.
- **`tests/capture_chips.gd`:** screenshots in `docs/screenshots/v0.38/`, including the night scene without and with the lamp.
