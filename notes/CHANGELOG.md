# Changelog (fun pass)

Old versions are never overwritten. See `04-versioning.md` for where each one lives.

## Baseline: `archive/v0.21.0-interiors-18` (commit `7db2272`)
This is the uncommitted v0.20.0 + 0.21.0 preview work, snapshotted as it was found before any fun-pass change.
Test run: `bash dev/run_tests.sh` in a clean worktree at the tag gives **39 passed, 17 failed**.
These failures already existed and are not caused by the fun pass:

| test | first error |
|---|---|
| test_bridge_scroll_ui | could not create `res://artifacts` (only in a fresh worktree; the dir exists in the main tree) |
| test_factory_ui | available action 投放 标准水箱 |
| test_first_person_editor_ui | touch cancel: same first-person scene returns |
| test_interaction14_ui | left click with default gloves hits exactly once without opening details |
| test_organic14_ui | touch application affects only aimed crop and consumes bottle once |
| test_organic15_ui | native touch submits one real reactor installation at fixed level fee |
| test_organic16_ui | touch starts paid doctor installation of selected organic |
| test_planet_retirement | Parse JSON failed |
| test_planet_v2_ui | map click selects the projected terrain region |
| test_residence_ui | touch anchors observer on chair |
| test_river_exploration | walking stops before expanded world edge |
| test_river_field_ui | mobile action button advances gathering once without an emulated duplicate |
| test_river_inventory_ui | touch selects an owned component |
| test_river_play_ui | toolbar click selects an equipped tool without teleporting |
| test_river_wilderness_ui | E collects once and cannot duplicate forage |
| test_state | seven science templates including substitution discoveries |
| test_touch_scroll | finger starting on purchase button scrolls element list |

Most of these are touch/click UI tests. They probably depend on real input timing or window focus that the
batch runner doesn't provide. They are worth a dedicated fix pass later (see roadmap "Later").

## v0.26.0 "Bedrock" (in progress)
v0.26 in progress: fixed tests. The full suite is now **60 passed, 0 failed** (it was 44 / 16):
- **Headless input (11 tests).** Headless Godot has a 0×0 window. The root viewport is then 64×64 with
  a ~0.044 `canvas_items` stretch transform, so scripted events given in 1440×900 canvas coordinates
  missed every control. The new `scripts/core/test_input.gd` maps events forward through the root
  transform. It is identity in a real window. Tests and main.gd's test helpers use it.
- **Game fix: codex cards.** They used `MOUSE_FILTER_STOP`, so a finger swipe that started on a card could
  not scroll the codex on phones (test_touch_scroll).
- **Game fix: hand foraging.** Since the hotbar rework, E went through the selected slot, so wild foraging
  was only reachable from a side-panel button. E with the hand and nothing aimed now forages nearby ripe
  wild plants (test_river_wilderness_ui).
- **Outdated expectations:**
  - 17 templates instead of 14 (test_state);
  - the world edge follows the 8192 m data radius (test_river_exploration);
  - the residence walk-out waits on real time instead of 90 frames;
  - the bag tab is the grid backpack (test_factory_ui, test_river_wilderness_ui);
  - wild-site fixtures need grid keys (test_interaction14_ui).

## v0.25.0 "Looks": a world worth screenshotting
Save format is unchanged (still v23). Everything here is cosmetic and never touches the economy.

**Day and night** (`scripts/core/day_cycle.gd`)
- A 16-minute cycle driven by the wall clock: dawn, a long day, lilac dusk, a mild blue night.
  About 70 % of it is daylight. It is never saved; `world.day_phase_override` pins it for tests and screenshots.
- Sun pitch, yaw (shadows sweep across the island), colour and energy, ambient light and sky blend
  between keyframes with smoothstep.
- At night lamps, reactors and other glowing materials get up to 3.2× brighter, and the reactor glass rim lights up.
- The LIVE badge shows 清晨 / 白天 / 黄昏 / 夜晚 / 黎明.

**Sea** (`assets/shaders/sea.gdshader`)
- The island now floats on a stylized sea instead of the matte studio floor.
- Shallows, animated foam bands hugging the shore and a foam edge come from a small distance-to-island
  mask baked on the CPU (`_update_shore`). It is only re-baked when the set of parcels changes, so it follows every expansion.
- Soft ripple glints; the sea glows faintly at night.

**Materials**
- Reactor chambers: unshaded fresnel glass with a rising shimmer (`glass.gdshader`).
- Trees and bushes sway in a breeze, weighted by height (`foliage.gdshader`). Leaf materials are marked so
  `StaticGeometry` still merges them into batches.
- The frontier label over the sea gets a dark outline so it stays readable in any light.

**UI**
- The atom editor's rules caveat is folded behind an "ⓘ 规则说明" toggle.

**Tests**
- New `tests/test_looks.gd` (37 checks): keyframes ordered, complete and wrapping, labels, mostly daylight,
  sea shader present, studio floor gone, shore mask bright at the shore and dark in open sea, no re-bake for
  an unchanged island but a re-bake after expansion, night dims the sun and brightens glow and glass,
  leaves batch, the LIVE badge label, and the ⓘ toggle.
- `dev/capture_looks.gd` screenshots day, dusk, night, dawn and a close-up into `artifacts/looks/`.

**Deferred:** river water shader, fullscreen river HUD and river perf (later); limbed animals (v0.26).

## v0.24.0 "Discovery": every structure is a card worth polishing
Save format **v23** (adds `best_fit` and `star_rewards`). v1–v22 saves still load. The codex is seeded from
the island's current samples of discovered structures; star gifts already within reach are marked handed out
**without** paying them (same no-windfall rule as the v0.23 goals).

**Codex** (`data/codex.json` and `scripts/codex.gd`)
- 「结构图鉴」 is now a 4-column card grid. Card border and label show rarity by atom count:
  2–3 常见, 4–5 稀有, 8–9 珍贵, 14–15 传说. Undiscovered cards show "？？？" and how to unlock them.
- Tap a card for its entry: best stars and fit, how to earn the next star, the science text and source,
  and your current samples with their live fit.
- **Stars**: each structure remembers the best geometry fit of a batch you actually *harvested*
  (★ 80 %, ★★ 93 %, ★★★ 98 %, the same thresholds as the editor), so up to 51 stars.
  The atom editor shows "最佳 ★★☆" next to the live match.
- **Star gifts**: at 3/6/10/15/21/28/36/45 stars the codex hands out decorations (flowers, bench, lamps,
  原子风铃, 月亮夜灯, 晶晶小狐狸…). They go straight into the toolbox; exploration props are unlocked.
  The harvest toast says "图鉴奖励 …" and a lilac popup floats under the coin counter.

**First-synthesis reveal**
- The first harvest of a new structure no longer shows a text banner. A card slides in face down,
  flips to show rarity, formula, name and stars, then sparkles, flashes in the rarity colour and floats away (`Fx.card_reveal`).

**Tests**
- New `tests/test_codex.gd` (53 checks): rarity tiers, star thresholds shared with the editor, gift table
  sanity, best-fit only rises, undiscovered structures don't count, gifts are ordered and paid once, the harvest
  path records the fit and announces gifts, the reveal card, v23 round-trip, validation, v22 migration
  without payout, and the codex dialogs.
- `test_state` expects save v23. `test_goals` accepts ≥ v22.

**Test run:** 43 pass / 16 fail. Every failure has the same error lines as the baseline (diffed per test).
- `dev/capture_codex.gd` screenshots the grid, an entry, both faces of the reveal, and the editor.

**Moved:** element sticker book and frontier element deposits → v0.26, where the frontier gets its purpose.

## v0.23.0 "Goals": always know what's next
Save format **v22** (adds `milestones_claimed` and `saved_at`). v1–v21 saves still load; goals the player has
already reached are marked done **without** paying out again, so old islands don't get a windfall.

**Goal track** (`data/milestones.json` and `scripts/milestones.gd`)
- 20 ordered goals: tune, harvest, crate, stars, expand, hire, build, deliver, discover, upgrade, perfect fit, and so on.
  Each pays coins, building materials or catalysts.
- Progress is read live from state; only the ids of claimed goals are saved, so nothing can drift.
- The quest bar shows goal n/20 with a gold progress bar. A finished goal shows a **领取** button (placed
  left of the toast so it's never covered) and gets its own feedback: banner, fanfare, coins flying to the counter.
- A **目标** button opens the full list (✓ done / ★ current / · upcoming).
- After material-journey players (planet joined) claim everything that's ready, the bar goes back to the journey text.

**Idle loop**
- Reactor buffer: 5 → **12** base units (+2 per level, unchanged). A reactor now runs ~5 min unattended, not 2.
- **Offline catch-up**: on load, reactors run for half the time away, capped at 2 hours. They still stop when full.
  Payroll, campus and planet stay paused, keeping the existing promise "离线不计薪".
  A compact **欢迎回来！** dialog summarizes the time away, new units and coins waiting.

**Fixes**
- The toast no longer swallows clicks (it covered part of the world view and the quest bar for 4 s after
  every action).
- `_dialog()` takes an optional height for short dialogs.
- Coin-burst callbacks hold the coin counter weakly. In v0.22.0, coins still in flight when the main scene was
  freed (tests, quitting) raised a script error. There was no gameplay impact, but it showed up in `test_material_visitor_ui`.

**Test run:** 41 pass / 17 fail. The 17 failures are the same tests with the same error lines as the baseline
(diffed per test). `test_planet_retirement` only fails in a fresh worktree.

**Already true, dropped from the plan:** "edits no longer wipe stock". `apply_structure_edit` already collects
the old batch into the toolbox before changing the structure.

**Tests**
- New `tests/test_goals.gd` (92 checks): data sanity, ordered claiming and no double payout, v22 round-trip,
  validation, v21 migration without payout, offline half-speed/cap/no payroll/idempotence, quest bar, claim
  button, dialogs.
- `test_island_loop` now reads the capacity from rules instead of the literal 5; `test_state` expects save v22.
- `dev/capture_goals.gd` screenshots the quest bar, goal list and welcome dialog.

## v0.22.0 "Juice": the island finally feels alive
Save format is unchanged (still v21), so old saves load as-is.

**Sound**
- New `Sfx` autoload: 14 pooled voices, SFX/Music buses, per-sound mix and pitch variance, and a retrigger guard
  (harvest-all sounds like one harvest, not twenty). Settings persist in `user://settings.cfg`.
- 19 synthesized one-shots and 2 seamless ambience loops (island pad, river water + birds). All are generated by
  `python dev/gen_audio.py`, so there are no third-party assets or licences.
- Ambience cross-fades between the island and the river. A ♪ toggle sits in the top bar.
- Every `UI.button` clicks.

**Motion**
- New `Fx` autoload: floating numbers, coins that fly on arcs into the coin counter, sparkles, elastic punch,
  screen flash, banners and an in-place counter. It is capped at 160 live nodes and cleans up after itself.
- The coin counter rolls toward the real value instead of jumping.

**Island feedback** (`scripts/island_feedback.gd`)
- Feedback comes from a per-frame state snapshot diff, so it only celebrates what actually happened.
  A failed action buzzes and shakes the toast; it never shows fake coins.
- Covered actions: tap, harvest (single and all), empty harvest, sale (premium catalyst callout), build, expand,
  upgrade (banner and flash), blind box, hire, spend, and new discovery (banner).
- **Tap combo**: rapid taps raise the pitch, grow the "+2" and show a 连击 ×N meter, with sparkles every 10.
  It is feel only; the economy is untouched.
- **Tap a reactor in the 3D world to harvest it** when it has output. If it's empty, the tap just selects it,
  as before.

**Atom editor**
- The match meter ramps from coral to gold to mint and ticks with rising pitch as you drag.
- Stars (★ ≥ 80 %, ★★ ≥ 93 %, ★★★ ≥ 98 %) appear next to the match percentage.
- Reaching ≥ 98 % plays the "完美契合！" celebration: chord, mint flash, banner and a glowing atom pop.
  It re-arms below 96 % so it can't spam.

**River (first pass)**
- Chop, dig, fill, strike, build, plant, gather, water, feed, pack and unfold each get their own sound.
- Tool impacts give a short first-person camera dip. Footsteps play while walking.
- A failed command buzzes instead of playing the success sound.

**Tooling**
- `dev/run_tests.sh`: batch runner. UI tests that need a renderer run windowed; the rest run headless.
- `dev/capture_juice.gd`: screenshots of the combo, harvest and perfect-fit effects (to `artifacts/juice/`).
- `tests/test_juice.gd`: autoloads, sound imports, node cap, classify table, stars, combo, tap-harvest,
  rolling counter, and river action→sound mapping.
