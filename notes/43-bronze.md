# 43 · v0.54.0 "Bronze" (青铜时代): tech diffusion and the first raid

Two things the user explicitly asked for in the same conversation: **Bronze** (materials the player
brings to the tribe push them into a new tech era) and **Clash** (tribal conflict, resolved
abstractly while you are away and visibly when you are there).

## Bronze: tech diffusion

The tribe 溪石部落 now progresses through eras:

| Era | Trigger | Effect |
|---|---|---|
| 新石器时代 (default) | — | base gather rates |
| **青铜时代** | player gifts 6× 孔雀石 or other Cu-bearing items | +1 timber/fiber/food per day; the chief menu shows 🥉 青铜时代 |

How to trigger it:
1. Mine 孔雀石 from the shallow copper seam (−8 m layer, mohs 3.5–4).
2. Open the chief menu (E near a tribe member), press **送孔雀石（青铜扩散）**.
3. After 6 gifts the tribe enters the Bronze era. The news log says exactly what happened.

The era survives saves (`era` / `copper_gifts` / `next_raid_day` / `raiders` are now in the save).
Old saves (version 1) restore as `neolithic` with no copper gifts, so no surprise era jump.

## Clash: the first raid

When the tribe's huts are finished, a raid is scheduled every 25 days from the rules data.

**While you are away (off-planet or in god-view):** the raid resolves abstractly — the tribe
defends alone, loses a little food and timber, and the news log records it. Friendship drops by 0.2.

**While you are present (in first-person on the planet):** a squad of 3 外族战士 spawns ~20 m from
the village as full entities. They appear in the combat targeting system alongside animals and
settlers. You can fight them:
- The crosshair and E prompt target them like any other hostile.
- Each hit reduces their HP by 1 (they have 2 HP each).
- When the last raider falls the news fires a victory message and friendship goes up by 0.25.

The raiders are visible through the normal miniature/proximity rendering pipeline, not new code.

## Implementation details

**`data/river_natives.json`**: added `bronze` block (trigger threshold, copper item list, gather
bonus, news event text) and `clash` block (interval, abstract losses, raider count/HP/names, victory
messages). All values are data-driven and tuneable without code changes.

**`scripts/river_natives.gd`**: added `era`, `copper_gifts`, `raiders`, `next_raid_day` fields;
`_tick_bronze()` fires the era transition once when `copper_gifts` reaches the threshold;
`_tick_clash()` resolves the raid either abstractly (player absent) or by spawning raiders (present);
`strike_raider()` handles individual hits; `gift()` handles the `kind=="copper"` branch; `_new_day()`
applies the Bronze era gather bonus; `serialize()`/`restore()` handle version 2 (old saves load
cleanly as version 1 → neolithic with no-op Bronze/Clash state).

**`scripts/river_combat.gd`**: raiders added to `entities()` as type `"raider"`;
`strike()` dispatches to `v.natives.strike_raider(id)`.

**`scripts/planet_v2_panel.gd`**: **送孔雀石** button added to the chief menu; era badge appears in
the panel title.

## Also fixed (in v0.53)

The v0.53.0 APK was built with `--export-release` directly from bash, which skips the JDK/SDK setup
that Godot needs for signing and the `apksigner` verification step. The result was a valid zip that
Android refused to parse. All future APK builds must go through `build_android.ps1`. The correct
`builds/AtomAtelier-0.53.0-android.apk` was rebuilt with the PowerShell script and verified with
`apksigner.bat` (v3 scheme, SHA-1 `d769548...`, same key as v0.48 and all prior releases).
