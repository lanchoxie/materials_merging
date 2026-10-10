# 36 · v0.47.0 "Floatplane" (水陆两栖小飞机): flight, far terrain, the curved horizon

Step 6 of the 2026-10-11 plan: an airplane with the curved-horizon shader, before the spaceship.

## The plane
- **Making it.** 水陆两栖小飞机 (`plane`) is built at 载具总装厂 (150 s) from 8 duralumin, 2 steel ingots, 2 motors, 3 battery packs, a control board and 2 glass.
- **Deploying.** The 装备 tab sends it to the planet or brings it home. It has its own slot (`industry.plane`, `plane_state`) and a deployed plane can't be sold.
- **Battery.** 3000 Wh at 40 Wh/km (more at full throttle), about 75 km per charge. It recharges on the island in about 5 minutes. Rules are in `industry.json` → `plane`.
- **On the planet.** It is parked beside you the first time; walk within 4.5 m and press E.
- **Flight model** (`planet_plane.gd`, arcade, no physics bodies):

  | Input | Action |
  |---|---|
  | W / S | throttle up / down (target airspeed up to 62 m/s) |
  | A / D | bank and turn (slower when rolling) |
  | drag up / down | sets the nose (±0.45 rad) |
  | Space | levels it |

  - **Takeoff.** At 24 m/s with the nose up, it lifts off.
  - **Off the throttle** it glides down gently (3 m/s at idle). Below 17 m/s it stalls and sinks.
  - **Hard landings.** Touching down faster than 9 m/s vertical, or nose-down, is a hard landing: it stops short, with no damage.
  - **It floats.** The sea is a runway, so it takes off from and lands on water, and oceans can be crossed.
  - **On the ground** it stops at steps over 0.7 m or at trees.
  - **Edges.** The polar caps turn it back, and the date line wraps.
  - **Ceiling.** 420 m.
  - **Getting out.** Only when stopped on ground or water, beside the plane. Leaving first person mid-flight sets it down where it is.
- **Flight panel.** It replaces the aim line and the hotbar: state (flying / water taxi / ground roll), km/h, height above ground, throttle, battery, coordinates, heading, and the last message.

## Seeing far: the far terrain and the curved horizon
- **Far terrain** (`planet_far_terrain.gd`).
  - **Grid.** A 121×121 grid (40 m cells, 2.4 km radius). That is past the horizon even at the 420 m ceiling, where the horizon is √(2Rh) ≈ 1.5 km.
  - **Heights and colours.** Heights come from the real terrain function (`legacy_height`), sunk 1.4 m so the near chunks always win. The sea is flat at sea level, and colours come from the globe painter (`Globe.color_at`).
  - **Building it.** It is built 4 rows per frame and swapped in when done (no stall), and rebuilt after 600 m.
- **Curved horizon** (`assets/shaders/far_terrain.gdshader`).
  - Every far vertex drops by d²/2R around the plane, with R ≈ 2607.6 m (16 384 m circumference): about 0.4 m at 48 m, 6 m at 180 m and 190 m at 1 km.
  - On the walk the fog ends at 48 m, where the drop is under half a metre and can't be seen, so the shader is only used in flight (as agreed in the plan).
- **While flying:**
  - The fog opens with height: end = 60 m + 7×height, up to 2.6 km; begin = 45 % of the end.
  - The camera sees 3.2 km.
  - The sky's "ground" turns to sea haze, because the curved horizon shows below it.
  - The flat −33 m sea plane hides; it would poke through the curved far sea.
  - Above 25 m, the near chunks hide, chunk streaming pauses (60 m/s would stall it), and no wildlife sites or camps are observed or spawned on the way.
  - On landing, everything comes back and streaming resumes.

## Save
- `industry`: `plane`, `plane_charge`.
- `planet.v2.plane`: `{x, z, heading}`, anywhere on the surface.
- A save during flight keeps the plane's last ground position.

## Test mode
「小飞机（派往地球）」.

## Verification
- **`tests/test_plane.gd`** (24 checks):
  - data; deploy and reserve; recharge and save;
  - a takeoff from the sea: floats, skims, lifts off at takeoff speed, climbs out;
  - Wh per km; banked turn; levelling;
  - a throttle-off glide down to a water landing;
  - a steep dive ends in a hard landing;
  - the polar turn-back; the date-line wrap; a flat battery;
  - the far grid: size, terrain heights, flat blue sea, curvature origin and shader formula;
  - planet save, and a parking spot past the pole rejected.
- **`tests/test_plane_ui.gd`** (16 checks):
  - kit; parked on arrival; reach from the beach; boarding; flight panel;
  - a takeoff from the water and climb;
  - far terrain shown and sea plane hidden; camera far;
  - no sites spawned aloft; streaming paused;
  - no exit in the air;
  - position tracked; exit at the shore; near world restored;
  - game save and load.
- **Vehicle tests** pass: rover, TBM, planet v2.
- **`tests/capture_plane.gd`:** screenshots in `docs/screenshots/v0.47.0/`, including the curved horizon at 380 m.

## Next (agreed plan)
The spaceship and a second planet (reuse the timeline save swap, `PlanetProgram.timelines`, for planets), then native factions.
