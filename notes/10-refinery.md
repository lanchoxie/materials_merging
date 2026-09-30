# 10 · v0.28 "Refinery": elements from the ground, reactors that look their level, a game that explains itself

The user's asks for this release (2026-10-01):
- Different reactor tiers need different looks, and a doctor installing new elements should show visibly how the compound's state changes, with UI animation.
- Game logic needs tidying. Example: leaving a screen opened on the planet could drop you onto the island.
- Synthesis needs enough onboarding and a sensible layout.

## 1 · Screens return where they were opened (step 1)
- `main.gd` keeps a return stack. Walk/planet screens (`set_editor_open`) are suspended, not destroyed, when a screen opens over them.
- `_screen_closed` / `_resume_suspended` bring them back with camera and position intact.
- `_close_all` is the only way to jump straight home (the "island" route).
- Close buttons say where they go: "返回河湾", "返回漫步", "返回反应釜", "返回浮岛".
- The organic reactor panel is now suspendable too, so the reactor → refinery → back round trip works.
- Test: `tests/test_navigation_ui.gd`.

## 2 · Refinery replaces the coin element shop (step 2)
The loop is: planet minerals (v0.26 geology) → refinery processes → element stock → substitution / doctor install / organic reactor.
- **Extractors** (`data/refinery.json`) trickle elements from seawater, air and water:
  - salt pan → Na, Cl
  - bromine tower → Br
  - air separation → N, O
  - electrolyser → H, O
  - carbon capture → C

  They pause at a cap (12, +6 per level).
- **Processes** turn one mined block into 2 formula units, following the real route. For example:
  - halite electrolysis (Downs cell)
  - malachite + coal → Cu
  - gibbsite + coal → Al
  - fluorite + sulfuric acid → HF → F
  - spodumene → Li
  - pollucite → Cs

  Sources are listed in the data file.
- Minerals are reserved up front. Only the first queued batch runs. Offline catch-up also refines.
- Upgrades cost coins and add speed, cap and queue length.
- Every "missing element" message names where to get it (`Refinery.how_to_get`), in the organic panel, the island element tab and the refinery itself.
- Save v24 adds `refinery`. v1–v23 saves load with a fresh refinery.

## 3 · Reactor looks and phases (step 3)
- `scripts/reactor_look.gd` has four tiers: Lv.1 玻璃反应瓶, Lv.5 夹套反应釜, Lv.10 高压反应釜, Lv.15 等离子反应腔.
  - Each tier adds its own hardware around the same glass chamber, so the molecule stays visible:
    - kettle: copper bands and a feed pipe
    - autoclave: steel ribs, a bolted flange and a live pressure gauge
    - plasma chamber: two orbiting glowing rings and antennae
  - Gold pips count levels inside the tier.
  - Reaching a new tier shows a banner, and the sidebar says which level unlocks the next look.
- `data/phases.json` gives the room-temperature phase of every template from its melting and boiling points (sourced). The chamber holds:
  - solid: crystals
  - liquid: a fill with a bobbing surface and rising bubbles
  - gas: a drifting translucent cloud
  - Unidentified structures stay unlabelled ("未鉴定").
- The sidebar shows a phase badge (pops in with a tween) and the mp/bp line.
- **Doctor install:** the elements being installed hover over the crown as CPK-coloured orbs.
  - They spiral down into the chamber as `installation.remaining` falls.
  - For a plain recipe change, the orbs use the new structure's own elements.
  - When the install changes the phase, `phase_notice` shows a "物态变化 液态 → 气态" banner in the new phase's colour.
- The animated nodes carry `dynamic_geometry` so static batching skips them. Progress updates never rebuild the island.
- Test: `tests/test_reactor_looks.gd`. Screenshot helper: `tests/capture_reactor_looks.gd`.

## 4 · First-time tours (step 4)
- `scripts/coach.gd` is a CanvasLayer overlay:
  - Four dim rects leave a hole around one control. Clicks outside the hole are blocked; the control itself stays usable, and pressing it also advances.
  - A pulsing gold frame surrounds the hole, and a caption card has 下一步 / 跳过指引.
  - The hole is clipped to its scroll box.
  - A tour ends quietly when its screen closes or gets covered.
- `scripts/coach_tours.gd` has five tours:
  - island (reactor, workbench, harvest, goals, refinery)
  - atom workbench
  - refinery (the three steps, stock, extractors, processes, dig for ore)
  - organic reactor (recipe, requirements, refinery shortcut, doctor install)
  - structure workshop
- Seen tours are saved (`coach` list in the v24 save, validated). Help has "重新播放新手指引".
- Tours only start by themselves in the real game. Script-driven runs (tests, captures) opt in.
  - Those runs also never load or write the player's default save slot (`default_slot_enabled`).
- Test: `tests/test_coach_ui.gd`. Screenshot helper: `tests/capture_coach.gd`.

## Deferred
- Tiers gating process conditions (temperature/pressure) in the refinery.
- A wave shader for liquids and a growing-lattice animation for solids.
