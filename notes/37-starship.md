# 37 · v0.48.0 "Starship" (星际飞船 · 赤砂星): a second planet

Step 7, the last of the 2026-10-11 plan: multiple planets reached by spaceship (No Man's Sky style), each a locally flat wrap-around block world.

## Planet profiles (`data/planets.json`)
Every planet uses the same generator and the same size (16 384 m around). A profile changes:

| Field | What it does |
|---|---|
| `phase` | the continents' harmonic phases (a different map) |
| `sea_bias` | how much is sea |
| `mountain` | range height |
| `temperature`, `water` | climate offsets, added everywhere |
| `hematite` | ore richness multiplier |
| `soil_tint`, `sky_tint`, `globe_tint` | colours |

**地球** is today's values exactly; the tests check that its profile reproduces the same continents and ranges. Earth worlds also use the empty profile, so nothing about Earth changed.

**赤砂星 · 红色荒漠行星:**
- 9 °C hotter and much drier;
- mostly land (sea_bias −0.18) with a few inland seas;
- ranges up to 85 m;
- 4× the hematite, a place to mine iron with the 盾构机;
- rust-red soil, a dusty orange horizon, and a tan globe.

**How it is passed around:**
- The shape functions (`continent`, `mountains`, `is_ocean`) take an optional profile.
- `Geology.natural` takes it for ore richness.
- The world's terrain and climate hold their own profile (`terrain.set_profile`, `environment.set_profile`), and every caller passes it on: chunks, the far terrain, the globe, the world map, and test-mode teleports.
- There is no global "current planet", so the island can still read Earth's home world (miniatures, exhibits) while you stand on 赤砂星.
- The globe texture cache is keyed by planet as well as climate.

## Worlds
- **`PlanetV2.planet`.** It is saved. A missing value loads as Earth, and an unknown id is rejected. The profile is applied before anything is restored, because block placement is checked against ground height.
- **Timeline keys.**
  - Earth's eras keep their keys (`present`, `ice`), so v0.39–v0.47 saves load unchanged.
  - Other planets are `<planet>:present`.
  - `world_key()` names the live world.
- **Shared rules.**
  - `at_home()` and `home()` mean Earth's present day.
  - The time gate only works on Earth. On another planet the light bridge goes to the landing site, and the dialog explains why.
- **One swap routine** (`PlanetProgram._swap`) serves the time gate and the ship.
  - What the player carries goes along: raw stock, workshop records, seeds, minerals, the codex, the backpack, specimens and health.
  - Each world keeps its own buildings, terrain edits, settlement, regions, animals and weather.
- **Save checks.**
  - World keys must be known.
  - At most one world may hold the ship.
  - `gate_open` is only required for Earth's other eras.

## The starship
- **Making it.** 星际飞船 (`starship`) is built at 载具总装厂 (240 s) from 16 duralumin, 10 steel ingots, 6 motors, 6 battery packs, 3 control boards, 4 logic chips and 4 glass.
- **Battery.** 6000 Wh; a jump costs 2500 Wh. It recharges on the island in about 6 minutes.
- **Commissioning.** It is commissioned on the 装备 tab (`industry.ship`). It appears beside you on the planet and stands there (`v2.ship_at`, saved with the world).
- **The star map.** E within 6 m opens 星图 (`main._show_voyage`): each planet's globe map, name, story and a 跃迁 button. The current planet is marked; the button is disabled there and when the battery is too low.
- **Launching** (`PlanetProgram.voyage`):
  - it costs the jump Wh;
  - the world swaps, and the ship moves with you to the landing site (14, 21);
  - the planet view reopens in orbit (the globe of the new planet);
  - 第一人称进入 lands you there.
- **Heading.** The planet view's heading names the planet: 「赤砂星 · 红色荒漠行星」 in amber.

## Also fixed
- 星锻岛's factory tab: when a recipe can't start, its button showed the whole "missing inputs" message on one line. The starship's seven inputs pushed the panel to 1524 px. The button now says 原料不足 and the reason wraps beneath it (caught by `test_starforge_layout_ui`).

## Verification
- **`tests/test_planets.gd`** (27 checks):
  - two planets; Earth's profile is identical to today's generator;
  - 赤砂星 has more land, taller ranges, more hematite, and is hotter and drier, with different ground;
  - separate globe textures;
  - world save and load as 赤砂星; unknown planet rejected; old saves load as Earth;
  - no ship, no voyage;
  - a jump: Wh cost; backpack and ship carried; Earth's buildings stay; the island reaches Earth's home world;
  - the time gate is Earth-only;
  - terrain edits persist per planet across round trips; a flat battery can't jump;
  - full game save and load on 赤砂星; two ships and unknown world keys rejected.
- **`tests/test_starship_ui.gd`** (12 checks):
  - kit; the ship beside you; boarding range;
  - the star map shows both planets and marks where you are;
  - launch swaps the world into a fresh view in orbit, with heading and ground;
  - landing beside the ship;
  - gear card; the light bridge on another planet.
- **Unchanged tests** pass: ice age, globe, earth, planet v2, plane, starforge isle.
- **`tests/capture_starship.gd`:** screenshots in `docs/screenshots/v0.48.0/`.

## What's next
The 2026-10-11 plan is complete. Still open from earlier lists:
- native factions (原住民派系), war events and the incident director;
- more planets (new profiles are data-only);
- a ship that flies in the world, reusing the plane's flight model and far terrain;
- more element ores.
