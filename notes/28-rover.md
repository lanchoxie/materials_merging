# 28 · v0.41 "Rover" (越野车): real driving on Earth

Industry slot from the interleaved plan ([14-industry-island.md](14-industry-island.md), v0.41: "Rover with real
driving"). The user's earlier answer Q7 asked for **real driving**, not teleporting. Built while the user was away;
the design calls below are mine.

## Assembly
- **载具总装厂.** 25 000 c + 80 cr, power 4, a Blender model. Recipe: 4 steel ingots + 4 rubber + glass + 2 motors + 2 battery packs + a control board gives **星球越野车** (90 s).
- **Energy model.** The model family `rover` inherits the packs' coating thickness.
  - 16 cells ≈ 190 Wh at 90 µm.
  - 80 Wh/km, which is in the range of small EVs and quadricycles (60–110 Wh/km). That gives about 2.3 km of range.
  - Car steel share is 45–70 % (Argonne GREET).
- **Deploying.** 「派往地球」 on the 装备 tab sends it to Earth. The tab also shows charge, range and a charge bar.
- **Charging.** The rover charges on the island (full in about 180 s). Parked within 10 m of a 太阳能方块 on Earth, it charges slowly (300 s for full). All *game values*.

## Driving (`scripts/river_rover.gd`)
The game has no physics bodies. The rover is a custom kinematic on the voxel heightfield:
- **Speed:** accel 4.5 m/s², brake 9, drag 2.5. Top speed 10 m/s (36 km/h), 14 with Shift. Reverse is capped at 40 % of top speed, and water slows it to 45 %.
- **Steering:** bicycle model, heading rate = v/L·tan(δ), with L 2.2 m and δ up to 0.55 rad.
- **Collision.**
  - Moves in 0.25 m substeps.
  - Ground under the centre comes from `construction.floor_at`. It climbs a rise up to **1.05 m** (one block) and falls at up to 12 m/s.
  - Five footprint probes (centre, both axles, both sides) stop on trees, barriers and the world edge, and on anything built **above** climbing height. A one-block step is driven over; a two-block wall stops it.
  - A collision reverses about 20 % of the speed and flashes 「撞到了」.
- **Suspension.** Pitch and roll come from the ground under the axles and wheels, low-passed.
- **Energy.** Wh/km × distance. With a flat battery it only crawls at 1.5 m/s.
- **Duck-typing.** It duck-types the walker (`movement`, `running`, `look`, `jump`, `stop`, `yaw`, `eye`).
  - The exploration input now drives `view.pilot()`, the rover while seated.
  - Drag or touch look orbits the chase camera; Space is the handbrake.

## In the planet view and panel
- **Parking.** The deployed rover parks about 3 m in front of the player the first time they are on Earth in first person. Where it stops is saved per era (`PlanetV2.rover_at`).
- **E (and the action button).** Shows 「上车」 within 3.5 m. While driving it shows 「下车」, and exiting looks for a free spot beside, behind or in front of the rover.
- **Android back.** Leaves the seat first.
- **Chase camera.** 7 m behind and 2.4 m up, lerped, never below the ground. It orbits with the look drag.
- **Seat sync.** The seat carries the walker along, so population observation, the trail, the minimap, targeting, rain and the headlamp all keep working.
- **HUD.** Speed in km/h, charge %, remaining range, and warnings.
- **Disabled while driving.** Attacking and tool use.
- **The model.** Yellow chassis, roll cage, a solar roof, four spinning wheels and headlights that switch on in the dark.

## Save
Planet: optional `rover` `{x, z, heading}`, inside the world radius. Industry: optional `vehicle` and `rover_charge`.

## 测试版
「越野车」 gives a charged rover and deploys it.

## Verification
- **`tests/test_rover.gd`** (23 checks):
  - acceleration and top speed;
  - forward motion;
  - 80 Wh/km;
  - braking and reversing;
  - steering sign;
  - one-block climb, two-block wall, tree;
  - crawling on empty;
  - range model;
  - chain and inheritance;
  - island charging;
  - not sellable while deployed;
  - saves and rejection.
- **`tests/test_rover_ui.gd`** (16 checks, through the real panel and input):
  - parks in reach;
  - 上车;
  - holding W drives it and uses battery;
  - the seat carries the walker;
  - chase camera;
  - HUD;
  - 下车 beside it;
  - the spot is remembered;
  - Android back;
  - save and load;
  - recalling removes it.
- Screenshots are in `docs/screenshots/v0.41/`.

## Later
- Cargo slots (40 in the plan).
- Headlight and battery upgrades.
- Driving speed in chunk streaming: a forward-biased stream radius, if phones pop in.
- Rovers for natives and trade (v0.42+).
