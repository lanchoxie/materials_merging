# 02 · Vision: from "accurate simulator" to "delightful toy with real science inside"

**One-line pitch:** *Build molecules with your hands, and watch them build your world.*

The science stays — it is the unique hook. What changes is **how it feels**: every action gets
sound, motion and a reward; every screen shows a goal; the world gives you reasons to explore.

## The five fun pillars

### 1. Juice — every touch answers back
Sound on every interaction, particles, floating numbers, coins that fly into the counter,
squash-and-stretch on reactors, hit-stop and screen shake on chops, a *ding* when geometry locks in.
Rule: **no player action without audiovisual feedback within 100 ms.**

### 2. The atom editor is a satisfying puzzle
- Live match meter whose colour **and pitch** rise as you approach the reference geometry.
- A "PERFECT FIT" moment (flash, chord, stars) at ≥ 98 %.
- 1–3 star rating per molecule, best score remembered → replay value and a skill ceiling.
- Experimenting is free: previews never cost, and edits stop wiping stock.

### 3. Always a next goal
- A milestone track (data-driven) with visible rewards, replacing the 4-step strip.
- Achievements / "firsts" (first perovskite, 10 perfect fits, first miniature…).
- Offline catch-up (capped) and bigger reactor buffers so returning feels good, not punishing.

### 4. Discovery & collection
- **Molecule Codex**: collectible cards with rarity, a reveal animation on first synthesis, the
  science notes (all the honest caveats) living here instead of in the HUD.
- Element collection / periodic-table sticker book.
- Frontier deposits of real elements (Si sand, Ca limestone, Fe ore…) that unlock new reactor
  recipes → the world and the lab finally feed each other.

### 5. A world worth looking at
Sky, water and glass shaders, a slower day/night, tree sway, fullscreen 3D with an overlay HUD,
limb animation for animals/villagers, a walkable light-bridge transition, a shrink-ray effect.

## Design rules for this track

1. **Depth before breadth.** No new era/biome until the island loop feels great.
2. **Science honesty, relocated.** Keep every source/caveat — in the Codex and tooltips, not in the
   main HUD. Never present a fake property as real.
3. **Cozy, not cruel.** Villagers/residents are non-lethal; danger comes from wildlife guarding riches.
4. **Chinese-first UI** (matching the existing game), English in code/notes.
5. **Never break a save.** New state is additive with defaults; version bump + migration + test.
6. **Every release playable and tagged.** Old versions are never overwritten (see 04-versioning.md).

## Tone / look targets
Stylised low-poly "diorama" (think *Townscaper*, *A Short Hike*, *Islanders*) — soft colours, bloom-
free glow via emissive + shaders that work in GL Compatibility (mobile/web).
Audio: soft marimba/glass tones, warm pad ambience; everything synthesized in-repo (no licensing).
