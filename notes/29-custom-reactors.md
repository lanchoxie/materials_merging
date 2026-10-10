# 29 · v0.41.1 custom reactors: 我的炉型, 空白反应炉, reference geometry for custom molecules

User request (2026-10-11, phone play):

> 自定义的不能和预设的一样调整键长获得百分比和金币提示，还有自定义的搭出来了不在常用直接可以建立的炉子里面，和预设的几种不统一。以及我们需要空白/自定义炉子给玩家自行搭建。

## What was missing
- **No feedback in the studio.** The 结构工坊 never showed a match % or a coin rate. It showed only the raw distance between two picked atoms, and atoms moved only in ±0.10 Å axis steps.
- **No reference geometry for most custom molecules.** A custom structure got a reference only if its bond graph equalled one of the 17 presets. Anything else, including real molecules from the chemistry index, earned the flat 0.15–0.30 coins/s exploration stipend with no match %.
- **The build menu offered only presets.** A custom design could only be applied onto an existing reactor.
- **No blank reactor.**

## Changes
- **Real reference geometry for custom molecules (`LabState._pubchem_geometry`).**
  - A custom science-mode molecule whose bond graph matches a PubChem entry with **3D** coordinates gets those coordinates as its reference, mapped into the player's atom order.
  - The reference provides bond lengths and every bonded angle, tagged `geometry_ref: "pubchem:<cid>"`.
  - `quality()` then scores it like a preset, and `income_breakdown` pays the preset formula × `index_geometry_factor` 0.8 *(game value)*.
  - Excluded: 2D PubChem layouts, crystals and atom art.
- **The studio shows the numbers.**
  - Over the 3D view: 「几何匹配 n% · 预计 x 金币/秒（Lv.n）」 and the reference's name, or why there is none.
  - The bond line shows 「目标 x Å」.
  - New 「键长 −0.05 / −0.02 / +0.02 / +0.05」 buttons move the second picked atom along the bond.
- **我的炉型 (`player_templates` in the save, at most 24).**
  - 「存为我的炉型」 is in the studio footer and on each work in 我的作品库.
  - Applying a design to a reactor or building one also saves it.
  - The 「＋ 反应炉」 menu lists 我的炉型 above the presets, each with its match %, coins/s, required elements, and 「建造此反应炉」 / 「先调一调再建」 / 「删除」.
  - For an existing reactor, 「装载到这座炉」 opens the studio on it.
- **空白反应炉.** The first card in the 「＋ 反应炉」 menu opens the studio in **build mode** for that empty plot. 「建造到此空地」 calls `place_custom_reactor`, which costs the same as a preset: 100 coins, every atom, a doctor, and a free 8×8 centre.
  - The new reactor is a normal sandbox reactor. It carries the matched preset id, or `water`, as its placeholder template, so saves and stored batches stay valid.
- **收益说明.** The 「每一枚金币」 dialog explains PubChem-referenced reactors and no longer hard-codes 0.15.

## Save
Adds an optional `player_templates` key; the version stays 28 and older saves load. Each entry must have:
- an id `my:N`, unique;
- a name ≤ 48 chars;
- a work that passes `sandbox_validate` and is not empty.

## Also in v0.41.1
- **Island walk.** It got `pilot()`. The exploration input is shared with the planet, and v0.41 had broken five island-walk tests; the full suite caught it before release.

## Phone hang on entering the island (open)
- **What was measured.** On a desktop with a late-game state (every factory looping, refinery looping, 8 h away):
  - offline catch-up 59 ms;
  - Main start 285 ms;
  - island walk open 56 ms;
  - island and walk frames about 7 ms.

  No hang reproduces. `tests/benchmark_startup.gd` is the probe.
- **Next step.** Find out exactly where it hangs (start-up, back from Earth, 走进浮岛, or 星锻岛). If the phone can be plugged in, read `adb logcat` (adb is in `tools/android/sdk/platform-tools`).

## Verification
- **`tests/test_custom_reactors.gd`** (23 checks):
  - a methanol reference from PubChem, with a real C–O bond and angles;
  - partial vs ~100 % match;
  - stretching lowers the match;
  - income above the stipend;
  - art never claims a reference;
  - save, update, ids and remove for 我的炉型;
  - quote gates (doctor, elements);
  - a direct build on an empty plot, which is a real reactor, keeps the match and is paid;
  - it earns like a preset;
  - save round trip, rejection of a malformed design, and old saves.
- **`tests/capture_custom.gd`:** screenshots in `docs/screenshots/v0.41.1/`.
