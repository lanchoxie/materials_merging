# v0.34 星锻岛 signature models, built from code so they are reproducible.
# Run:  tools/blender/blender.exe -b --factory-startup --python dev/blender/starforge.py
# Writes assets/models/starforge/*.glb. Low poly for mobile (GL Compatibility): flat colours,
# emissive accents for the cyan/amber/gold glow, no textures. Front faces -Z (Godot forward).
import bpy, bmesh, math, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "starforge")
os.makedirs(OUT, exist_ok=True)

def hexcolor(h):
    h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) / 255.0 for i in (0, 2, 4)) + (1.0,)

_mats = {}
def mat(name, color, emit=0.0, metal=0.0, rough=0.7):
    key = (name, color, emit, metal, rough)
    if key in _mats: return _mats[key]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hexcolor(color)
    b.inputs["Metallic"].default_value = metal; b.inputs["Roughness"].default_value = rough
    if emit > 0:
        # Godot reads glTF emissive strength > 1 as overbright white on the Compatibility renderer, so
        # the accent keeps its hue at strength 1 and `emit` only scales how much of it glows.
        b.inputs["Emission Color"].default_value = hexcolor(color); b.inputs["Emission Strength"].default_value = min(1.0, emit / 4.0)
    _mats[key] = m; return m

def clear():
    bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials):
        for item in list(block):
            if item.users == 0: block.remove(item)
    _mats.clear()

def finish(o, material, smooth=False):
    o.data.materials.append(material)
    if smooth: bpy.ops.object.shade_smooth()
    return o

def box(size, at, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at, rotation=rot)
    o = bpy.context.active_object; o.scale = size; return finish(o, material)

def cyl(r, h, at, material, verts=12, r2=None, rot=(0, 0, 0)):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=at, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=at, rotation=rot)
    return finish(bpy.context.active_object, material)

def torus(R, r, at, material, rot=(0, 0, 0), seg=24):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=6, location=at, rotation=rot)
    return finish(bpy.context.active_object, material)

def sphere(r, at, material, seg=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=at)
    return finish(bpy.context.active_object, material, True)

def export(name):
    # Blender is Z-up; the glTF exporter converts to Godot's Y-up.
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
                              export_yup=True, export_materials="EXPORT")
    print("wrote", path)

GUN = "3a4250"; DECK = "4b5563"; STEEL = "8b95a3"; DARK = "232a33"
CYAN = "35e0ff"; AMBER = "ffb547"; GOLD = "ffd36b"; HOT = "ff7a2e"

def plinth(w=2.6, d=2.6, accent=CYAN):
    # Hex-panel footing with a light strip; every building stands on one (1 plot = 3 m).
    box((w, d, 0.18), (0, 0, 0.09), mat("deck", DECK, metal=0.4, rough=0.55))
    for s in (-1, 1):
        box((w * 0.96, 0.06, 0.04), (0, s * d * 0.47, 0.2), mat("strip", accent, emit=3.0))
        box((0.06, d * 0.96, 0.04), (s * w * 0.47, 0, 0.2), mat("strip", accent, emit=3.0))

def holo_logo(z, accent):
    # Floating tier ring above the roof: the building's 标识.
    torus(0.42, 0.035, (0, 0, z), mat("logo", accent, emit=4.0), seg=32)
    torus(0.28, 0.025, (0, 0, z), mat("logo", accent, emit=4.0), rot=(math.pi / 2, 0, 0), seg=24)

# --- 冶金工厂 Metallurgy Works: squat tapered furnace stack, hammer press, glowing pour arc.
def metal_works():
    clear(); plinth(accent=AMBER)
    gm = mat("gun", GUN, metal=0.6, rough=0.45); st = mat("steel", STEEL, metal=0.8, rough=0.35)
    cyl(0.75, 1.6, (-0.45, 0.2, 1.0), gm, verts=10, r2=0.5)
    cyl(0.55, 0.12, (-0.45, 0.2, 1.84), mat("rim", DARK))
    cyl(0.18, 0.9, (-0.45, 0.2, 2.3), st, verts=8)
    torus(0.78, 0.06, (-0.45, 0.2, 0.55), mat("hot", HOT, emit=5.0))
    torus(0.66, 0.05, (-0.45, 0.2, 1.25), mat("hot", HOT, emit=5.0))
    box((0.7, 0.9, 0.9), (0.75, -0.3, 0.65), gm)
    box((0.5, 0.7, 0.18), (0.75, -0.3, 1.2), st)
    box((0.18, 0.18, 0.9), (0.75, -0.3, 1.7), st)
    for i in range(3): box((0.34, 0.2, 0.08), (0.2 + i * 0.36, -0.95, 0.26), mat("mould", DARK))
    cyl(0.07, 0.8, (-0.05, -0.55, 0.75), mat("pour", HOT, emit=6.0), rot=(0.9, 0, 0.5))
    holo_logo(3.0, AMBER); export("metal_works")

# --- 高分子工厂 Polymer Works: three distillation columns with spiral catwalks, pellet silo.
def polymer_works():
    clear(); plinth(w=2.6, d=2.6, accent=AMBER)
    white = mat("white", "d9dee5", metal=0.3, rough=0.4); gm = mat("gun", GUN, metal=0.6, rough=0.45)
    for i, (x, h) in enumerate(((-0.75, 2.6), (0.0, 3.1), (0.75, 2.2))):
        cyl(0.28, h, (x, 0.45, 0.18 + h / 2), white, verts=12)
        cyl(0.3, 0.1, (x, 0.45, 0.18 + h), gm)
        for k in range(int(h / 0.7)):
            torus(0.34, 0.025, (x, 0.45, 0.5 + k * 0.7), mat("joint", AMBER, emit=3.0), seg=16)
    cyl(0.5, 1.3, (0.2, -0.6, 0.85), mat("glass", "9fe7ff", metal=0.1, rough=0.1), verts=16)
    for k, c in enumerate(("ff5f6d", "5fd0ff", "ffe26b", "7cff9a")):
        sphere(0.13, (0.05 + 0.1 * k, -0.6 + 0.08 * (k % 2), 0.45 + 0.18 * k), mat("pellet" + c, c, emit=0.6))
    cyl(0.52, 0.12, (0.2, -0.6, 1.55), gm)
    box((1.6, 0.08, 0.08), (0, 0.45, 2.0), mat("pipe", STEEL, metal=0.8))
    holo_logo(3.6, AMBER); export("polymer_works")

# --- 星港交易所 Trade Hub: tall spire, airship docking arm, rotating gold ticker ring.
def trade_hub():
    clear(); plinth(accent=GOLD)
    gm = mat("gun", GUN, metal=0.6, rough=0.45); gold = mat("goldtrim", GOLD, emit=2.5)
    cyl(0.7, 0.6, (0, 0, 0.48), gm, verts=8)
    cyl(0.35, 2.6, (0, 0, 2.0), mat("spire", "c9ced6", metal=0.7, rough=0.3), verts=8, r2=0.12)
    torus(0.75, 0.05, (0, 0, 1.6), gold, seg=32)
    torus(0.55, 0.04, (0, 0, 2.3), gold, seg=32)
    box((1.2, 0.12, 0.12), (0.6, 0, 2.6), gm)
    cyl(0.28, 0.9, (1.25, 0, 2.35), mat("ship", "e8edf2", metal=0.2), rot=(0, math.pi / 2, 0))
    sphere(0.06, (0, 0, 3.4), mat("beacon", "ff4d4d", emit=6.0), seg=8)
    holo_logo(3.0, GOLD); export("trade_hub")

# --- 星锻岛 deck tile: one 3 m plot of gunmetal hex panels with cyan seams.
def deck_tile():
    clear()
    box((3.0, 3.0, 0.3), (0, 0, -0.15), mat("deck", DECK, metal=0.4, rough=0.55))
    for k in range(-1, 2):
        box((2.9, 0.04, 0.02), (0, k * 1.0, 0.01), mat("seam", CYAN, emit=2.0))
        box((0.04, 2.9, 0.02), (k * 1.0, 0, 0.01), mat("seam", CYAN, emit=2.0))
    export("deck_tile")

# --- Anti-gravity thruster ring hung under the island.
def thruster():
    clear()
    cyl(0.9, 0.8, (0, 0, 0), mat("gun", GUN, metal=0.6, rough=0.45), verts=16, r2=0.6)
    torus(1.0, 0.12, (0, 0, -0.5), mat("glow", CYAN, emit=6.0), seg=32)
    cyl(0.5, 0.2, (0, 0, -0.55), mat("core", "b8f6ff", emit=8.0), verts=16)
    export("thruster")

for build in (metal_works, polymer_works, trade_hub, deck_tile, thruster): build()
