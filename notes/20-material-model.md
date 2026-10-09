# 20 · Material property model: continuous properties from real anchors (design)

Status: **design, agreed direction** (user, 2026-10-09). **v1 built in v0.37** (see [23-silicon-materials.md](23-silicon-materials.md)):
steel, bronze, duralumin, Al-Li, glass and P-doped Si; gear beyond the drill bit follows in v0.43. It is the design goal for the later phase:
first the v0.37 material-model release, then v0.43 gear, which builds on it.

## The user's requirement
- **Continuous, not discrete.** Materials must not be Minecraft-style discrete tiers. Their properties are continuous
  values that depend on what the player actually made: the compound, the doping and the processing.
- **Simplify, but stay honest.** We do not predict properties from atoms to the mesoscale to the macroscale. We use
  simplified laws ("doping X changes hardness and density like this").
- **Use the properties.** They drive gear and other materials.
- **Balance science against fun.** The user asked how to balance the two; the principle below is my answer.

## Principle: real anchors + simplified laws + clear labels
1. **Anchor.** Every material starts from a real compound in the index. MP crystals give density, formation energy,
   e_hull, band gap, metal/magnetic and, for 386/1835, bulk and shear modulus. PubChem molecules give weight, logP
   and geometry. These numbers are shown as *(真实数据)*.
2. **Modify with one-line laws.** Composition and processing shift the anchor through textbook relations. Each law is
   shown once in plain words, with its source and a *(简化模型)* tag. The laws are smooth, monotone or with one sweet
   spot, so players can reason about them.
3. **Map properties to gameplay with saturating curves.** Saturating curves instead of tiers, and every gain costs
   something (hard ↔ tough, strong ↔ heavy). Gameplay constants are tagged *(游戏数值)*.
4. **Measure.** A predicted property is shown as a value with an uncertainty band. A 材料测试台 (test bench) on the
   island measures a sample and narrows the band. This is both honest (the model is approximate) and a gameplay step.

## The material state (what a made material remembers)
Industry items stop being bare counts. A finished lot carries a small state vector:
- `host`: the index key of the base compound (e.g. Fe₃C/Fe, Cu, Al, Si).
- `dopants`: up to 2 × {element, fraction}, chosen with a slider and capped per system (e.g. C ≤ 2.1 wt% in steel).
- `route`: one processing route per family, chosen on the factory:
  - 退火 (anneal), 淬火 (quench), 回火 (temper), 时效 (age) or 冷加工 (cold work);
  - plus one continuous knob, e.g. ageing time or cooling rate.
- `lot quality`: a seeded ±3 % scatter, so two lots are never identical. It is narrowed by measurement.

Stacks merge only if their properties fall in the same 1 % bucket. This keeps the inventory and the save bounded
(≤ 64 distinct lots per item).

## Property laws (v1 set, each simplified and cited)
| Property | Law | Example in game |
|---|---|---|
| density ρ | rule of mixtures by volume (near exact) | Al–Li gets lighter with Li |
| hardness H | anchor from Chen 2011 (B, G), then: solid-solution strengthening ΔH ∝ c^½ (Fleischer/Labusch); Hall–Petch H = H₀ + k·d^-½, with grain size d from cooling rate; precipitation peak-ageing curve (rises, peaks, overages) | bronze harder with Sn; duralumin peaks at the right ageing time |
| steel hardness | empirical martensite-hardness vs carbon curve (Krauss): quenched HV rises steeply to about 0.6 wt% C, then flattens; tempering lowers it smoothly | carbon slider + quench/temper |
| toughness | Pugh ratio B/G (ductile if > 1.75), lowered by hardening; a hard-but-brittle trade-off | a harder pick chips more (durability) |
| stiffness E | from B and G (isotropic); Voigt–Reuss bounds for composites | glider frame, armour backing |
| band gap E_g | alloy bowing E_g(x) = (1−x)E_A + xE_B − b·x(1−x) | LED colour, solar efficiency |
| conductivity | Nordheim's rule: alloy resistivity rises ∝ x(1−x); semiconductors: carriers from doping (P in Si → n-type) | wires, chips |
| melting / working range | linear between end members, capped by the eutectic where known | solder melts at 183 °C (Sn63Pb37) |

Where MP has no data (no moduli, no conductivity, no melting point), the game shows "缺少数据" and the
law that would apply. It never invents a number without saying so. A short curated handbook table may fill gaps for
key engineering materials, with sources.

## Gameplay mapping (continuous, saturating, with trade-offs)
- **Pick and drill.** Dig speed = base × s(H / H_rock), where s() rises smoothly and saturates near 3×.
  Durability ∝ toughness. Weight (ρ × volume) slows the swing.
- **Axe.** Chop yield and speed from H and toughness.
- **Armour.** Damage reduction 1 − exp(−H·t/k), where t is thickness. Walk speed falls with areal density.
- **Backpack frame.** Capacity from specific stiffness (E/ρ).
- **Wires, chips, LEDs and panels.** Conductivity, band gap and efficiency (the Shockley–Queisser model is already in game).
- **Quality pricing.** Trade-hub price scales smoothly with the measured key property. This replaces fixed prices.

## Where it lives in the roadmap
- **v0.35:** unchanged (promotion pipeline, island Ⅱ housing, home goods, contracts).
- **v0.37 "Si/Ca/P + 材料性质模型 v1".**
  - Fetch: add the new elements and refetch MP with more fields — elasticity, dielectric and magnetic where available.
  - Build: material lots with dopant and route, the law set above for the metallurgy and polymer works plus Si doping, and the 材料测试台.
  - Continuous pick and drill stats (replacing today's single hardness threshold).
- **v0.43 Arsenal and gear.** Armour, drone, glider and the rest use the same lots and laws, and add new materials.

## Today's data, for reference (v0.29 index)
- **MP:** 1 835 crystals, db 2026.04.13. Each has formula, space group, density, volume, e_hull, e_form, band gap
  (direct or not), metal, magnetic, experimental/ICSD flag, lattice and sites. 386 also have bulk and 382 have shear modulus.
- **PubChem:** 106 molecules with name, formula, weight, IUPAC, atoms/bonds/positions, geometry and xlogp.
- **Already used:**
  - fabricator pick hardness (Chen model on B and G) and panel efficiency (Shockley–Queisser on the gap);
  - index identification of what the player made;
  - 星锻岛 evidence gates (v0.34).
