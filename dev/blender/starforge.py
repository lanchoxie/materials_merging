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

CORAL = "ff8a7a"; ICE = "9fe7ff"

# --- 未来家居工坊 Home Goods Studio (v0.35): stacked offset glass showroom pods, a robot arm.
def home_studio():
    clear(); plinth(accent=CORAL)
    glass = mat("glass", "bfe9f2", metal=0.1, rough=0.08); gm = mat("gun", GUN, metal=0.6, rough=0.45)
    neon = mat("neon", CORAL, emit=4.0)
    for i, (x, y, z, w) in enumerate(((-0.35, 0.1, 0.65, 1.7), (0.3, -0.15, 1.45, 1.4), (-0.15, 0.25, 2.15, 1.1))):
        box((w, w * 0.8, 0.7), (x, y, z), glass)
        box((w + 0.04, w * 0.8 + 0.04, 0.06), (x, y, z + 0.37), gm)
        box((w * 0.9, 0.03, 0.03), (x, y - w * 0.4 - 0.02, z - 0.3), neon)
    # A chair on display in the lowest pod and the arm placing it.
    box((0.3, 0.3, 0.06), (-0.4, 0.1, 0.42), mat("seat", ICE, emit=0.6))
    box((0.3, 0.05, 0.3), (-0.4, 0.24, 0.6), mat("seat", ICE, emit=0.6))
    cyl(0.12, 0.5, (0.85, 0.75, 0.45), gm)
    box((0.08, 0.08, 0.8), (0.65, 0.6, 0.85), mat("arm", STEEL, metal=0.8), rot=(0.5, 0.4, 0))
    sphere(0.07, (0.45, 0.45, 1.15), neon)
    holo_logo(3.0, CORAL); export("home_studio")

# --- 星锻公寓 Staff Apartments (v0.35): capsule pods stacked in a staggered tower, warm windows.
def staff_housing():
    clear(); plinth(accent=ICE)
    shell = mat("shell", "e8edf2", metal=0.2, rough=0.35); window = mat("window", "ffd9a0", emit=2.4)
    cyl(0.18, 2.8, (0, 0, 1.55), mat("core", GUN, metal=0.6), verts=8)
    for k in range(5):
        a = k * 1.3; r = 0.55; z = 0.55 + k * 0.5
        x, y = math.cos(a) * r, math.sin(a) * r
        cyl(0.32, 0.9, (x, y, z), shell, verts=12, rot=(math.pi / 2, 0, a))
        sphere(0.12, (x + math.cos(a) * 0.46, y + math.sin(a) * 0.46, z), window)
    torus(0.75, 0.03, (0, 0, 3.0), mat("ring", ICE, emit=4.0), seg=32)
    holo_logo(3.4, ICE); export("staff_housing")

# --- 货运飞艇 Cargo airship (v0.35): envelope, gondola, fins, glowing engines.
def airship():
    clear()
    env = mat("envelope", "eef1f4", metal=0.1, rough=0.4)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.0, location=(0, 0, 0))
    o = bpy.context.active_object; o.scale = (2.2, 0.75, 0.75); finish(o, env, True)
    torus(0.76, 0.04, (0.6, 0, 0), mat("band", GOLD, emit=3.0), rot=(0, math.pi / 2, 0))
    torus(0.76, 0.04, (-0.6, 0, 0), mat("band", GOLD, emit=3.0), rot=(0, math.pi / 2, 0))
    box((1.0, 0.35, 0.3), (0, 0, -0.9), mat("gondola", GUN, metal=0.6))
    box((0.9, 0.36, 0.08), (0, 0, -0.73), mat("strip", CYAN, emit=3.0))
    for s in (-1, 1):
        box((0.5, 0.04, 0.5), (-1.9, s * 0.3, 0.2 * s), mat("fin", "c9ced6", metal=0.4), rot=(0.6 * s, 0, 0))
        cyl(0.14, 0.3, (-0.2, s * 0.45, -0.8), mat("engine", GUN, metal=0.6), rot=(0, math.pi / 2, 0))
        cyl(0.1, 0.05, (-0.37, s * 0.45, -0.8), mat("jet", CYAN, emit=4.0), rot=(0, math.pi / 2, 0))
    export("airship")

# --- v0.37 材料测试台 Test Bench: lab block with a Vickers indenter column and a glowing readout.
def test_bench():
    clear(); plinth(w=2.4, d=2.4, accent="9fe7ff")
    white = mat("white", "e6ebf0", metal=0.2, rough=0.35); gm = mat("gun", GUN, metal=0.6, rough=0.45)
    box((1.8, 1.0, 0.9), (0, 0.35, 0.63), white)
    box((1.82, 1.02, 0.06), (0, 0.35, 1.1), gm)
    cyl(0.09, 1.3, (-0.45, 0.35, 1.75), mat("steel", STEEL, metal=0.85, rough=0.3), verts=10)
    box((0.5, 0.36, 0.32), (-0.45, 0.35, 2.3), gm)
    cyl(0.05, 0.3, (-0.45, 0.35, 1.3), mat("tip", "9fe7ff", emit=4.0), r2=0.0)
    box((0.7, 0.05, 0.45), (0.45, -0.15, 1.45), mat("screen", "9fe7ff", emit=3.0), rot=(0.25, 0, 0))
    box((0.3, 0.3, 0.3), (0.55, 0.45, 1.28), mat("sample", "c98b4a", metal=0.7, rough=0.3))
    holo_logo(2.9, "9fe7ff"); export("test_bench")

# --- v0.37 无机材料厂 Inorganic Works: rotary cement kiln on piers, glass furnace with a molten glow.
def inorganic_works():
    clear(); plinth(accent="ff9a5c")
    gm = mat("gun", GUN, metal=0.6, rough=0.45); clay = mat("clay", "c98a5a", rough=0.8)
    cyl(0.32, 2.3, (0, 0.6, 0.95), mat("kiln", "9aa1aa", metal=0.5, rough=0.45), verts=14, rot=(0, math.pi / 2 - 0.12, 0))
    for x in (-0.7, 0.0, 0.7): box((0.18, 0.35, 0.6 + x * 0.1), (x, 0.6, 0.45), gm)
    for x in (-0.4, 0.4): torus(0.36, 0.04, (x, 0.6, 0.95 - x * 0.12), mat("ring", "ff9a5c", emit=3.0), rot=(0, math.pi / 2, 0), seg=16)
    box((1.1, 0.8, 0.8), (-0.45, -0.55, 0.58), clay)
    box((1.12, 0.82, 0.12), (-0.45, -0.55, 1.03), gm)
    box((0.5, 0.06, 0.28), (-0.45, -0.97, 0.5), mat("melt", HOT, emit=6.0))
    cyl(0.14, 1.4, (-0.85, -0.3, 1.7), gm, verts=8)
    cyl(0.3, 0.9, (0.7, -0.55, 0.65), mat("silo", "d9dee5", metal=0.3, rough=0.4), verts=12)
    box((0.5, 0.5, 0.04), (0.7, -0.55, 1.12), mat("pane", "bfe6ef", metal=0.1, rough=0.05))
    holo_logo(2.8, "ff9a5c"); export("inorganic_works")

# --- v0.37 硅材料厂 Silicon Foundry: clean-room box, Czochralski puller tower, a tilted solar array.
def silicon_works():
    clear(); plinth(accent="8fd3ff")
    white = mat("white", "eef1f4", metal=0.2, rough=0.3); gm = mat("gun", GUN, metal=0.6, rough=0.45)
    box((1.4, 1.2, 0.9), (-0.45, 0.4, 0.63), white)
    box((1.42, 0.05, 0.3), (-0.45, -0.21, 0.8), mat("window", "8fd3ff", emit=2.5))
    cyl(0.32, 0.7, (0.75, 0.55, 0.55), mat("crucible", "c9ced6", metal=0.7, rough=0.3), verts=14)
    cyl(0.12, 1.5, (0.75, 0.55, 1.6), gm, verts=10)
    cyl(0.16, 0.5, (0.75, 0.55, 1.05), mat("ingot", "7d8590", metal=0.9, rough=0.2), verts=12)
    torus(0.34, 0.03, (0.75, 0.55, 0.92), mat("glow", "8fd3ff", emit=4.0), seg=16)
    for i in range(3):
        box((0.62, 0.4, 0.03), (-0.75 + i * 0.66, -0.75, 0.55), mat("cell", "2d3f73", metal=0.3, rough=0.15), rot=(0.55, 0, 0))
        box((0.64, 0.02, 0.02), (-0.75 + i * 0.66, -0.75, 0.66), mat("busbar", "c9ced6", metal=0.9))
    holo_logo(3.0, "8fd3ff"); export("silicon_works")

# --- v0.38 晶圆芯片厂 Chip Fab: sawtooth clean-room hall, a lithography lens tower firing a violet beam
# onto a wafer disc, gas cabinets.
def chip_fab():
    clear(); plinth(accent="b18cff")
    white = mat("white", "eef1f4", metal=0.2, rough=0.3); gm = mat("gun", GUN, metal=0.6, rough=0.45)
    violet = mat("beam", "b18cff", emit=5.0)
    box((1.9, 1.2, 0.7), (-0.25, 0.45, 0.53), white)
    for i in range(4):
        box((0.46, 1.22, 0.06), (-1.0 + i * 0.5, 0.45, 0.98), mat("tooth", "c9d3de", metal=0.3, rough=0.3), rot=(0, 0.45, 0))
        box((0.04, 1.2, 0.22), (-0.8 + i * 0.5, 0.45, 1.0), mat("skylight", "b18cff", emit=2.0))
    cyl(0.22, 1.6, (0.85, -0.55, 1.0), gm, verts=12)
    cyl(0.34, 0.25, (0.85, -0.55, 1.9), mat("lens", "dfe7ff", metal=0.1, rough=0.05), verts=16)
    cyl(0.05, 0.75, (0.85, -0.55, 0.55), violet, verts=8)
    cyl(0.3, 0.03, (0.85, -0.55, 0.2), mat("wafer", "3d4a6b", metal=0.8, rough=0.15), verts=24)
    for k in range(3): box((0.06, 0.6, 0.02), (0.75 + k * 0.1, -0.55, 0.22), mat("die", "b18cff", emit=1.5))
    for x in (-0.9, -0.6): cyl(0.1, 0.6, (x, -0.75, 0.48), mat("gas", "ffd36b", metal=0.5), verts=10)
    holo_logo(3.0, "b18cff"); export("chip_fab")

# --- v0.38 封测电路板厂 Packaging & Board Plant: a slab building skinned as a green PCB with copper
# traces, roof fins as chip pins, and a black IC block with glowing pads.
def packaging_plant():
    clear(); plinth(accent="5fe0c8")
    pcb = mat("pcb", "1f7a55", rough=0.6); copper = mat("trace", "e0a050", emit=1.5, metal=0.8)
    box((2.0, 1.6, 0.8), (0, 0.1, 0.58), pcb)
    for i in range(5):
        box((1.6, 0.04, 0.02), (0, -0.55 + i * 0.32, 0.99), copper)
        box((0.04, 0.04, 0.6), (-0.95, -0.55 + i * 0.32, 0.58), copper)
    box((0.9, 0.9, 0.22), (0.2, 0.1, 1.1), mat("ic", "23262e", metal=0.3, rough=0.4))
    for i in range(6):
        for s in (-1, 1):
            box((0.06, 0.16, 0.04), (-0.18 + i * 0.15, 0.1 + s * 0.52, 1.02), mat("pin", "c9ced6", metal=0.9))
    sphere(0.06, (0.55, 0.45, 1.24), mat("led", "7cff9a", emit=5.0), seg=8)
    box((0.5, 0.3, 0.5), (-0.6, -0.75, 0.43), mat("reel", GUN, metal=0.6))
    cyl(0.2, 0.08, (-0.6, -0.92, 0.6), mat("tape", "5fe0c8", emit=1.0), rot=(math.pi / 2, 0, 0))
    holo_logo(2.7, "5fe0c8"); export("packaging_plant")

# --- v0.40 电池工厂 Battery Works: three cylindrical-cell "skyscrapers" with lime charge bars.
def battery_works():
    clear(); plinth(accent="b6ff5c")
    gm = mat("gun", GUN, metal=0.6, rough=0.45); shell = mat("shell", "d9dee5", metal=0.5, rough=0.3)
    lime = mat("charge", "b6ff5c", emit=4.0)
    for i, (x, y, h) in enumerate(((-0.7, 0.35, 2.4), (0.05, -0.3, 3.0), (0.8, 0.4, 2.0))):
        cyl(0.36, h, (x, y, 0.18 + h / 2), shell, verts=16)
        cyl(0.38, 0.12, (x, y, 0.18 + h), gm, verts=16)
        cyl(0.12, 0.14, (x, y, 0.3 + h), mat("cap", "b87333", metal=0.8), verts=10)
        for k in range(int(h / 0.45)):
            box((0.08, 0.06, 0.22), (x + 0.36, y, 0.45 + k * 0.45), lime if k < int(h / 0.45) - 1 else mat("empty", "3a4250"))
    box((1.0, 0.5, 0.35), (0.1, 0.85, 0.36), gm)
    box((0.9, 0.04, 0.2), (0.1, 0.6, 0.4), mat("strip", "b6ff5c", emit=2.0))
    holo_logo(3.6, "b6ff5c"); export("battery_works")

import sys
only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for build in (metal_works, polymer_works, trade_hub, deck_tile, thruster, home_studio, staff_housing, airship, test_bench, inorganic_works, silicon_works, chip_fab, packaging_plant, battery_works):
    if not only or build.__name__ in only: build()
