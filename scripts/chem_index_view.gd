extends RefCounted
## v0.29 chemistry index widgets: browser cards and a slowly turning 3D preview of the real
## structure (PubChem conformer with bonds, or the MP unit cell with its edges).
const UI = preload("res://scripts/ui.gd")
const Index = preload("res://scripts/chem_index.gd")
const MAX_PREVIEW_ATOMS = 160

static func card(entry: Dictionary, found: bool, action: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(206, 128)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	var tint := Color(str(Index.stability(entry).color)) if not entry.has("cid") else UI.MINT
	var face := UI.style(Color("1b2f3a") if found else Color("132129"), 14, UI.GOLD if found else Color(tint, 0.35))
	face.set_border_width_all(2 if found else 1)
	var hover := face.duplicate(); hover.bg_color = face.bg_color.lightened(0.08)
	b.add_theme_stylebox_override("normal", face)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(action)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12; v.offset_right = -12; v.offset_top = 8; v.offset_bottom = -8
	v.add_theme_constant_override("separation", 1)
	b.add_child(v)
	var lines: Array
	if entry.has("cid"):
		lines = [[str(entry.group), 12, UI.MUTED], [Index.formula(entry), 24, UI.MINT if found else UI.TEXT], [str(entry.name), 14, UI.TEXT], ["✓ 已收录" if found else "CID %d" % int(entry.cid), 12, UI.GOLD if found else UI.MUTED]]
	else:
		lines = [["%s · %s" % [Index.CRYSTAL_SYSTEMS.get(str(entry.crystal_system), ""), Index.stability(entry).name], 12, tint], [Index.formula(entry), 24, UI.MINT if found else UI.TEXT], ["%s · %s" % [str(entry.spacegroup), str(entry.id)], 13, UI.TEXT], ["✓ 已收录" if found else ("实验观测" if bool(entry.experimental) else "计算预测"), 12, UI.GOLD if found else UI.MUTED]]
	for line in lines:
		var l := UI.label(str(line[0]), int(line[1]), line[2])
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.clip_text = true
		v.add_child(l)
	return b

## Atoms (symbol, position) and bonds (index pairs + order) to draw, centred on the origin.
static func geometry(entry: Dictionary) -> Dictionary:
	var atoms: Array = []
	var bonds: Array = []
	var edges: Array = []
	if entry.has("cid"):
		for i in range(entry.atoms.size()):
			var p: Array = entry.positions[i]
			atoms.append([str(entry.atoms[i]), Vector3(float(p[0]), float(p[1]), float(p[2]))])
		for b in entry.bonds: bonds.append([int(b[0]), int(b[1]), int(b[2])])
	else:
		var a := Vector3(entry.lattice[0][0], entry.lattice[0][1], entry.lattice[0][2])
		var b := Vector3(entry.lattice[1][0], entry.lattice[1][1], entry.lattice[1][2])
		var c := Vector3(entry.lattice[2][0], entry.lattice[2][1], entry.lattice[2][2])
		for site in entry.sites:
			var f := Vector3(float(site[1]), float(site[2]), float(site[3]))
			# Atoms on a face, edge or corner also appear on the opposite side, like a textbook cell.
			for dx in ([0, 1] if f.x < 0.02 else [0]):
				for dy in ([0, 1] if f.y < 0.02 else [0]):
					for dz in ([0, 1] if f.z < 0.02 else [0]):
						if atoms.size() < MAX_PREVIEW_ATOMS:
							atoms.append([str(site[0]), a * (f.x + dx) + b * (f.y + dy) + c * (f.z + dz)])
		for corner in range(8):
			for axis in range(3):
				if corner & (1 << axis): continue
				var start := a * float(corner & 1) + b * float((corner >> 1) & 1) + c * float((corner >> 2) & 1)
				edges.append([start, start + [a, b, c][axis]])
	var centre := Vector3.ZERO
	if entry.has("cid"):
		for atom in atoms: centre += atom[1]
		centre /= maxf(1.0, atoms.size())
	else:
		centre = (Vector3(entry.lattice[0][0], entry.lattice[0][1], entry.lattice[0][2]) + Vector3(entry.lattice[1][0], entry.lattice[1][1], entry.lattice[1][2]) + Vector3(entry.lattice[2][0], entry.lattice[2][1], entry.lattice[2][2])) * 0.5
	var radius := 1.0
	for atom in atoms:
		atom[1] -= centre
		radius = maxf(radius, atom[1].length())
	for e in edges:
		e[0] -= centre; e[1] -= centre
		radius = maxf(radius, maxf(e[0].length(), e[1].length()))
	return {"atoms": atoms, "bonds": bonds, "edges": edges, "radius": radius}

static func preview(entry: Dictionary, elements: Dictionary, size: Vector2 = Vector2(360, 300)) -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.name = "IndexPreview"
	box.custom_minimum_size = size
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	box.add_child(view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b9d7e0")
	env.environment.ambient_light_energy = 0.55
	view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 1.2
	view.add_child(sun)
	var g := geometry(entry)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	pivot.rotation_degrees = Vector3(18, 0, 0)
	view.add_child(pivot)
	var spin := Node3D.new()
	spin.name = "Spin"
	pivot.add_child(spin)
	var crystal := not entry.has("cid")
	for atom in g.atoms:
		var info: Dictionary = elements.get(atom[0], {})
		var mesh := SphereMesh.new()
		mesh.radius = clampf(float(info.get("radius", 0.8)) * (0.30 if crystal else 0.36), 0.14, 0.62)
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 20; mesh.rings = 10
		var ball := MeshInstance3D.new()
		ball.mesh = mesh
		ball.position = atom[1]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(str(info.get("color", "a5efd1")))
		mat.roughness = 0.3
		ball.material_override = mat
		spin.add_child(ball)
	for bond in g.bonds:
		var p: Vector3 = g.atoms[bond[0]][1]
		var q: Vector3 = g.atoms[bond[1]][1]
		var axis := (q - p)
		if axis.length() < 0.01: continue
		var side := axis.cross(Vector3.UP if absf(axis.normalized().y) < 0.9 else Vector3.RIGHT).normalized()
		for k in range(int(bond[2])):
			var shift := side * (float(k) - float(int(bond[2]) - 1) / 2.0) * 0.14
			spin.add_child(_stick(p + shift, q + shift, 0.055, Color("dfe8ea")))
	for e in g.edges:
		spin.add_child(_stick(e[0], e[1], 0.025, Color("f2c46d")))
	var cam := Camera3D.new()
	cam.fov = 38
	cam.position = Vector3(0, 0, float(g.radius) / tan(deg_to_rad(19.0)) + 1.2)
	view.add_child(cam)
	var turn := spin.create_tween().set_loops()
	turn.tween_property(spin, "rotation:y", TAU, 14.0).from(0.0)
	return box

static func _stick(p: Vector3, q: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius
	mesh.height = p.distance_to(q)
	mesh.radial_segments = 8
	var stick := MeshInstance3D.new()
	stick.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	stick.material_override = mat
	stick.position = (p + q) * 0.5
	var dir := (q - p).normalized()
	var up := Vector3.UP
	var rot_axis := up.cross(dir)
	if rot_axis.length() > 0.0001: stick.basis = Basis(rot_axis.normalized(), up.angle_to(dir))
	elif dir.y < 0: stick.basis = Basis(Vector3.RIGHT, PI)
	return stick
