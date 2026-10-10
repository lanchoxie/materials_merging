# 31 · v0.42.0 "Blue Planet" (蓝色星球): one wrap-around world, a globe god view

Step 1 of the planet plan agreed on 2026-10-11 (see [30-wild-harvest.md](30-wild-harvest.md#roadmap-agreed-2026-10-11)).

> 我们需要和minecraft一样是一个非常大的球形的世界，而不是有几个什么固定地点的这种。然后你变成上帝视角应该是一个地球仪，
> 展示的是地球上你的上一次所在位置……地球也需要山脉和海洋洞穴和生物植被群落。

## The planet's shape (`scripts/planet_shape.gd`)
The world is a locally flat block world on a planet. This is not a spherical voxel world:

| Property | Value |
|---|---|
| Circumference | 16 384 m; x wraps from +8192 to −8192 |
| North polar cap | z −7600 |
| South polar cap | z +7600 |
| Equator | z +2600, so home is at about 22.8°N |
| Latitude | piecewise linear in z (90° at each cap) |
| Longitude | x / 8192 × 180° |

- **Polar edge.** The walkable surface stops 60 m short of each cap (`Shape.on_surface`). `inside()` uses it, so the walker stops there like it used to stop at the old disc rim.
- **Continents.** `continent(x,z)` is a sum of sines in whole-number harmonics of the circumference, so it repeats exactly (the test checks this). A bump keeps home on a central continent; the date-line seam is forced to deep ocean, so the wrap is never seen on land. About 41 % of the surface is land.
- **Sea.**
  - Sea level is 0.2 m.
  - The floor drops from a wadeable shelf at the shore (about 0.5 m deep) to 18 m offshore (`ocean_depth`).
  - Water deeper than 1.25 m blocks walking (`deep_water` in `blocked()`); boats and planes come later.
  - Chunks draw the sea as run-length water strips per row. The sea floor darkens with depth, so the water reads as sea and not as more beach.
- **Mountain ranges.**
  - Ridged folds inside continents reach about 60 m (`mountains`). Ranges stay out of the 1.5–3.2 km around home.
  - Rock above 12 m is **granite** (minable, and gives 石料).
  - There are no trees above the tree line (range height 20 m). The ground above 20 m is alpine rock and grass; it is snow from 34 m.
- **Caves.** The v0.33.2 caves now run through the ranges and open on their slopes, but are never carved under the sea.
- **Beaches.** Sand within the coastal band (continent < 0.1).

## Climate and life
- **Temperature follows latitude in both hemispheres.**
  - Formula: `equator − pole_drop·(|lat|/90)^exponent`, with 30 °C, 45 °C and 1.4 (data: `latitude` in `planet_environment.json`), plus the old noise.
  - Home keeps its fixed values.
  - The 冰河期 offset still applies. In the ice age the land north of home, at about 39°N and a desert today, freezes over.
- **New biomes.**
  - 极地冰盖 (`ice`): below −6 °C.
  - 海洋 (`ocean`): over the sea.
- **Trees by climate.** Beyond 300 m from home, cold ground grows pine, cool ground grows pine and birch, and warm ground grows oak and birch. Wood density follows the biome:

  | Biome | Density |
  |---|---|
  | forest | 1.0 |
  | wetland | 0.6 |
  | grassland | 0.35 |
  | tundra | 0.15 |
  | desert | 0.03 |
  | ice, sea | none |

  The home area keeps its old mix.
- **Wildlife and camps** are only placed on dry land.

## No fixed places
- **Region tabs.** The four region tab buttons are gone. The home habitats (meadow, wetland, highland, forest edge) still exist around the river bend and are entered by walking. The 近看 close-up button is gone too.
- **Landmarks.** The seven far landmarks are gone; only 起始河湾 and its gathering slope remain as `LANDMARKS`. The 远行 tab offers 「回到起始河湾」 and the player's own waypoints, and suggests leaving waypoints wherever you go.
- **Location line.** Under the title it shows the biome and coordinates, for example 「当前位置：森林 · 南纬26.0° 西经106.7°」. Near a cap it warns about the polar edge.

## The globe (地球仪, `scripts/planet_globe.gd`)
- **One colour function** (`color_at`) paints sea depth, polar sea ice, biomes (from the blended climate), beaches, ranges and snow.
- **Textures.**
  - `equirect` builds a 256×128 equirectangular image, cubic-upsampled to 512×256.
  - `flat` builds the world map, 256×240 upsampled to 512×480.
  - Both are cached per climate epoch; they take about 0.15 s and 0.27 s on desktop.
- **God view.**
  - It shows only the globe: a sphere mesh with that texture, a faint atmosphere shell and a glowing pin at the last position (home before the first walk).
  - The globe sits on its own render layer (20), and the camera's cull mask switches between it and the ground. Nothing else toggles visibility, so per-frame visibility logic is untouched.
  - Opening the god view turns the globe to face the pin.
  - Drag turns and tilts it (mouse with the left button, or touch; emulated mouse events are skipped). The wheel and ＋/－ zoom; ↶/↷ spin.
  - A tap never jumps between regions.
- **First person** draws the ground layers again. The terrain around the last walk stays loaded, so re-entry is instant.

## World map (世界地图)
- **The whole planet.** It shows the planet strip repeated east and west, with latitude/longitude lines every 30° (the equator stronger) and labels.
- **Zoomed in** (4 km and closer), a sharper 160×100 patch is painted around the view.
- **Wrapping.** Everything is drawn on the near side of the seam, and the walked trail breaks instead of crossing the map.
- **Taps and info.** The info line and taps report coordinates and biome. The old disc outline and landmarks are gone; only home is marked.

## Fixes found on the way
- **Sea strips at negative x.** The strip builder used `-1` as its "no run open" marker, which is a valid x west of home, so the sea never rendered there. It now uses a flag; the test builds chunks on both sides.
- **Wrap periodicity.** `continent()`/`mountains()` used raw x for the home bump and seam terms, so they were not periodic. They wrap x first now.

## Test mode
Biome teleports search the whole surface on solid land, with `biome_at`, and include 冰盖.

## Verification
- **`tests/test_globe.gd`** (37 checks):
  - wrap, latitude and longitude, coordinates;
  - periodic continents; home on land; ocean seam; land share;
  - shelf vs deep sea and walking; polar edge; old disc edge gone;
  - sea chunks drawn west and east;
  - range height, none at home, granite, tree line, pale peaks, caves in ranges but not under the sea;
  - latitude climate in both hemispheres; polar land;
  - pine in the cold, oak and birch in the warm; no trees at sea;
  - only home landmarks;
  - globe texture size and cache; sea colour; sphere layout; mesh; flat map;
  - walker wrap.
- **`tests/test_globe_ui.gd`** (19 checks):
  - globe in the god view and cull mask;
  - no region tabs or close-up;
  - lat/lon line; pin on the globe; drag turns and tilts; a tap keeps the region;
  - journey has home but no far landmarks;
  - first person hides the globe; walking shows biome and coordinates;
  - the pin follows, and the globe faces it;
  - world map texture, coordinates, seam drawing and tap.
- **Updated tests** for the new world:
  - `test_earth`, `test_earth_ui`: land-only cells; northern forest at (1664,−2176); the far north frozen.
  - `test_frontier17`, `test_river_population`, `test_river_exploration`: wrap and polar edge instead of the disc.
  - `test_frontier17_ui`, `test_river_wilderness_ui`, `capture_player_gallery`: teleport to the old coordinates instead of removed landmarks.
  - `test_planet_v2_ui`: globe click, no tabs.
  - `test_ice_age`: the north freezes.
  - `test_test_mode`: ice spot.
- **`tests/capture_globe.gd`:** screenshots in `docs/screenshots/v0.42.0/`.

## Not in this release (by plan)
- **Curved horizon shader.** Deferred to the airplane release: at the 48 m fog distance the drop is about 0.5 m and can't be seen.
- **Crossing oceans.** Needs boats or planes.
