# 16 · v0.33 "Polish" (精美化): models, creatures, light and water

## Goal
The user asked, after Earth, for a polish pass: nicer first-person models, nicer island residents,
nicer Earth models, creatures and materials. There are no new mechanics and no save changes. Every
change is display-only, and the population, ranch and hitbox logic read the same data as before.

## Constraints that shaped it
- **Renderer.** The game uses `gl_compatibility` on desktop and Android:
  - no SSAO, no SDFGI and no screen-space reflections;
  - only one directional shadow, which is enabled on desktop and disabled on Android/web.
  - So depth comes from baked vertex shading, a real sky, and a cheap shaded viewmodel.
- **Draw calls.** Each figure merges into a few meshes:
  - island figures: body, two arms and two legs;
  - planet animals: body, four legs and a tail.
  - Merged meshes are cached per look and shared by every instance.
- **Hitboxes.** These read `node.mesh` (or a `bounds` meta) on the same nodes as before, so attack
  and inspect targeting is unchanged.

## What changed
### Light, sky and baked shading (`planet_v2_view.gd`, `river_geometry.gd`)
- **Sky.**
  - A ProceduralSky with its own day cycle:
    - the zenith goes from deep blue to day blue;
    - the horizon goes from dusk orange to pale blue;
    - fog and ambient colour follow the horizon.
  - The sun and the sky change during the in-game day: the sun rises in the east, its elevation follows the day, and it is warmer at dawn.
  - Sky reflections are off, because they washed out the vertex colours.
- **Sun shadows.**
  - Desktop: two-split PSSM out to 40 m.
  - The compatibility renderer roughly doubles the lit brightness when a shadowed light is
    present, so the sun energy is scaled by 0.6 when shadows are on.
- **Fill light.** A cool fill light from the opposite side, with `SKY_MODE_LIGHT_ONLY` so it draws no
  second sun disc.
- **Baked shading.** `G.face` darkens undersides and the bottom edge of every wall, a cheap form of
  contact occlusion that applies to every voxel and cube mesh.

### First-person hands (`first_person_hands.gd`, `assets/shaders/viewmodel.gdshader`)
- **Hand and arm.**
  - The arm is a shaded, gloved hand with curled fingers, knuckle highlights and a thumb.
  - The suit sleeve has a glowing cuff stripe and a wrist analyser.
- **Tools.**
  - The axe, pick, hammer and scanner have real heads, grip wraps and glowing screens.
  - The sapling, bottle (with glowing liquid), sample box and crate are modelled too.
- **Sway.** The rig lags a little behind camera turns, then settles. It also breathes and bobs to the side while walking.
- **Viewmodel shader.**
  - It squashes depth toward the near plane (reversed-Z: `mix(z, w, 0.9)`), so the held tool never clips into walls.
  - It has a glow parameter for emissive parts.

### Island residents (`campus_view.gd`, `figure_geometry.gd`)
- **Figures.**
  - Chibi figures with a ball head, set-back hair and a fringe.
  - Eyes with highlights, blush and a mouth.
  - Shoulders, cuffs, hands, shoes.
- **Role looks.**
  - 工程师: hard hat and a hi-vis vest.
  - 博士: lab coat, teal shirt, badge, stethoscope.
  - 教授: glasses.
  - 院士: robe with a medal.
  - 采购商: hat and bag.
- **Motion.** Legs swing, arms swing against them while walking, and the working arm chops while the tool rotates.

### Planet creatures (`creature_rig.gd`)
- **Animals.**
  - 草甸小鹿: spotted coat, white belly and chest, ears with pink insides, eyes, nose, a white tail.
  - 林地野猪: mane ridge, tusks, snout disc with nostrils, ears.
  - Fish: back stripe, dorsal fin, eyes, side fins.
- **Rig.**
  - The legs and tail are child pivots.
  - The gait advances by the distance actually travelled, so animals trot when they move and stand still when they don't.
  - Diagonal pairs move together.
  - Tails flick faster when idle; fish tails sway.
- **People.** Villagers and camp visitors are rigged ~1.6 m people with faces and swinging arms and legs.
  - The farmer has a straw hat.
  - The craftsman has a leather apron.
  - From era 2, both wear a teal cap and carry a field analyser.
  - Visitors carry backpacks.
  - A working villager swings their right arm.
- **Birds.** Six ambient birds wheel over the walker by day, flapping and gliding. They are render-only and can't be targeted.

### Water (`assets/shaders/planet_water.gdshader`)
- **River, ponds and the camp spring.**
  - Flowing ripples and sun glints.
  - A sky-tinted fresnel rim.
  - Slight transparency, so fish show underneath.
  - Pollution tints still come through the vertex colour.
- **Continued river.** The scenery river outside the start area moves to a second chunk surface with the same material.
- **Sea.** The far sea plane uses the island's stylised sea shader without the shore mask.

## Verification
- `tests/capture_polish.gd` is a screenshot helper, not a test. It takes these shots:
  - island overview, walk and resident close-up;
  - meadow villagers and animals;
  - the river;
  - the hammer and scanner hands;
  - the forest, a wild boar close-up and the birds.
  - Run it windowed with `-- --release-ui-test --tag=X`.
  - The `--exp=noshadow|nosky|nofill|nofog` switches were used to isolate the brightness problem.
- The full suite was run after the change. Final screenshots are in `docs/screenshots/v0.33/`.

## Not done (candidates for later)
- **Tree sway.** Trees live in the shared chunk mesh with a standard material. Sway would need a
  foliage shader on a separate surface, like the water.
- Skinned or Blender-authored models. These are deferred to the Starforge Isle art decision (Q8 in [14-industry-island.md](14-industry-island.md)).
- Night-time lights on the planet (camp lanterns, villager torches).
