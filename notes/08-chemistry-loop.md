# 08 · No element shop, a real chemistry index, and the compound → gear loop (2026-09-30)

User asks (condensed):
1. Remove the element shop? Buying elements kills the wish to explore.
2. Build a chemistry index for the crystal structures of compounds (connect to Materials Project / COD)
   instead of today's hand-picked presets.
3. Can synthesized compounds be made into things that boost exploration/production, closing the loop?

## 1. Remove the element shop — yes, with anti-softlock rules

Today: `lab_state.buy_elements`, shop prices in `economy.json → element_shop`, starter stock H2 O1 S1 Cl2.
Callers: island panel buy buttons, main.gd purchase dialog, `organic_synthesis` auto-buys missing atoms,
tests (`test_island_loop`, `test_state`, `test_material_visitors`). `element_shop.exploration_rate` is also
(mis)used as the income rate of unknown structures and moves to its own key.

Replacement sources:
- **Island trickle (no planet needed):** the v0.25 sea and the sky. A seawater evaporator gives Na, Cl
  (trace Br, Mg); a rain/air collector gives H, O, N, and C from CO₂. Slow, capped, enough to never get stuck.
- **Planet:** mining + refinery (07-world-blocks.md), air/brine collection, organics. Everything rarer
  (Cu, Al, Pb, Li, Cs, F, Fe, Sn, …) only comes from the planet.
- **Rules:** every element used by any goal has at least one renewable source reachable in the first
  session; a test enumerates this. The planet becomes reachable from the start (landing = tutorial).
- Coins stay for island building, expansion, hiring, blind boxes; later, barter with natives
  (specimens/goods), never "buy an element".
- Migration: element stock in old saves is kept; shop UI removed. No coin refund needed.
- Timing: the shop can only go when the refinery exists → **v0.27 "Refinery"**.

## 2. Chemistry index from real databases

Today: 17 hand-built templates in `data/materials.json` (water, methane, NaCl, LiF, CsPbBr₃ perovskite, urea…),
graph-matched in `sandbox_reference.gd` / `specimen.gd`. Everything else is "等待研究的探索样品".

Plan: an **offline, build-time pipeline**, bundled with the game (mobile, offline, no API key in the APK).
- `dev/chem_index/` (Python): fetch → filter → fingerprint → write `data/chem_index/*.bin|json`.
  - **Materials Project** (`mp-api`/pymatgen, needs the user's free API key via `MP_API_KEY` env var, never
    committed). Computed crystals + properties: formation energy, E above hull, band gap, density,
    magnetism, elastic moduli (subset), battery electrodes (voltage/capacity). Licence CC BY 4.0 → attribution.
  - **COD** (Crystallography Open Database): experimental crystal structures (CIF), open data. Marks entries
    as "experimentally observed".
  - **PubChem**: molecules (3D conformers) for the molecular side (water, urea, ethanol…).
  - Licences are re-checked when the pipeline is written; each entry stores its source id (mp-xxxx,
    COD id, CID) and the credits screen lists the databases.
- Filter: only chemical systems made of the game's elements (14 now + Fe, Si, Ca, Sn, K, Mg, P);
  unit cell ≤ ~24 atoms (buildable in the editor); E_hull ≤ 0.1 eV/atom or experimentally observed.
  Expected size: low thousands of entries, a few MB.
- Matching at runtime: reduced formula → candidates → structure fingerprint (sorted species-pair distance
  histogram / coordination numbers, precomputed by pymatgen, recomputed in GDScript for the player's build)
  → match score. Molecules keep the existing graph match.
- What changes for the player:
  - The codex grows from 17 cards to thousands, grouped by chemical system / family.
  - Rarity derives from element abundance + stability. Every card shows real properties with the source id.
  - Unmatched structures stay "未收录 · 假说", with no invented properties (science rule kept).
- Optional later: online lookup of an unmatched structure, desktop only, with the user's own key.
- Timing: **v0.28 "Index"** (after the refinery, before gear, because gear stats come from these properties).

## 3. The closed loop: compounds → gear/machines → further exploration

```
explore planet → mine / collect air & brine / harvest organics
      → island refinery (real processes) → elements
      → atom editor → compound, matched to the index (real properties)
      → fabricator: gear, machines, emitters, building blocks
      → deeper ore tiers, farther regions, harsher biomes, other eras and planets
      → new minerals, elements, specimens …
side loops: emitters reshape the environment → new biomes/species;
            materials given to natives → tech revolution → trade, new buildings to collect
```

Stats come from real properties with a documented mapping. If a property is missing, the compound can't
fill that role (shown as "未测"). Examples (all real uses):

| Compound (source) | Product | What it unlocks | Stat from |
|---|---|---|---|
| Fe (hematite + C), later steel | iron pick / drill | granite/basalt tier, deeper veins | elastic moduli / hardness class |
| Cu + Sn → bronze | bronze tools, trade goods | early tier; gift → natives' bronze age | — (tier) |
| Cu | wire (reuses `electrical_lab`) | power network between machines | resistivity (already sourced) |
| Si, CsPbBr₃ perovskite | solar panel (existing `modern_silicon/perovskite`) | power at base and in the field | band gap vs Shockley–Queisser |
| LiFePO₄ / LiCoO₂ | battery | scanner/drill/lamp/glider energy | MP electrode voltage × capacity |
| Al, Al₂O₃ | light frame | glider, later vehicle → cross the big world | density |
| SiO₂ glass, CaF₂ | lenses, greenhouse | scanner range, greenhouse biome | optical class, band gap |
| LiOH / CaO | CO₂ scrubber | caves, high-CO₂ planet, AI-era ruins | — (reaction stoichiometry) |
| NaCl → NaOH + Cl₂ | water purifier | clean water emitter, native health | — |
| CO(NH₂)₂ urea, NH₃ | fertilizer | fertilizer emitter (L1) | N content |
| CaCO₃ → CaO → cement | concrete blocks | strong buildings; modern-era kit | — |
| H₂ + O₂ (electrolysis) | fuel cells | time gate power, later starship → new eras/planets | reaction enthalpy |

Gating = real needs: hardness tiers (tools), darkness and O₂ underground (lamps, scrubber), cold in the
ice age (heater, insulation), distance (glider, battery), time travel and planets (fuel).
- Timing: **v0.29 "Fabricator"**. The emitters of the environment field are fabricator products, so
  "Earth" (environment field) follows as v0.30.

## Resulting order (proposed)

v0.26 Bedrock (voxels, minerals, scanner) → v0.27 Refinery (+ shop removed, island trickle) →
v0.28 Index (MP/COD/PubChem) → v0.29 Fabricator (gear loop) → v0.30 Earth (environment field) →
v0.31 Specimens → v0.32 Ice Age → v0.33 Settlers → v0.34 Bronze → v0.35 Clash → eras → big world → planets.
