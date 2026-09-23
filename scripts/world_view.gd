extends Node3D
const StaticGeometry=preload("res://scripts/static_geometry.gd")
## The entire little laboratory is made from meshes, so it needs no imported art.

signal plot_clicked(index: int)

const PITCH: float = 3.0
const TEAL: Color = Color("398d83")
const MINT: Color = Color("9dddd0")
const CREAM: Color = Color("fff3d8")
const INK: Color = Color("244f59")
const SOIL: Color = Color("bb7d63")
const GOLD: Color = Color("f9c868")
const INITIAL_CAMERA_POSITION: Vector3 = Vector3(13.0, 15.0, 18.0)
const INITIAL_CAMERA_TARGET: Vector3 = Vector3(0.0, 0.35, 0.0)
const DETAIL_BUDGET: int = 36
const SIMPLE_DETAIL_RADIUS: float = 37.0

var camera: Camera3D
var _model
var _plots: Array = []
var _reactors: Array = []
var _templates: Dictionary = {}
var _elements: Dictionary = {}
var _worker_count: int = 2
var _selected: int = 4
var _time: float = 0.0
var _signature: String = ""
var _content: Node3D
var _selection: Node3D
var _molecules: Array = []
var _workers: Array = []
var _motes: Array = []
var _materials: Dictionary = {}
var _selection_markers: Array = []
var _camera_target: Vector3 = INITIAL_CAMERA_TARGET
var _coord_lookup: Dictionary = {}
var _map_min: Vector2 = Vector2(-3.0, -3.0)
var _map_max: Vector2 = Vector2(3.0, 3.0)
var _detailed_plots: Dictionary = {}
var _visible_plots: Dictionary = {}
var _detail_signature: String = ""
var campus_life_enabled: bool = false
var detail_budget: int = DETAIL_BUDGET
var detail_refresh_left: float = -1.0
var geometry_rebuilds: int = 0
var interaction_lock: bool = false
# The visiting buyer lives outside ProceduralIsland so land and LOD rebuilds
# never restart an arrival, reset a wave, or duplicate a character.
var _visitor_node: Node3D
var _visitor_body: Node3D
var _visitor_legs: Array = []
var _visitor_arms: Array = []
var _visitor_badge: Node3D
var _visitor_available := false
var _visitor_name := "收购商"
var _visitor_visit_count := -1
var _visitor_active_visit := -1
var _visitor_phase := "absent"
var _visitor_phase_time := 0.0
var _visitor_walk_time := 0.0
var _visitor_route_start := Vector3.ZERO
var _visitor_route: Array[Vector3] = []
var _visitor_route_length := 0.0
const VISITOR_GATE := Vector3(0.0, 0.10, 5.30)
const VISITOR_LANDING := Vector3(0.0, 0.10, 4.30)
const VISITOR_STOP := Vector3(1.20, 0.10, 3.55)


func _ready() -> void:
	_ensure_stage()
	if _content == null:
		rebuild()


func setup(model) -> void:
	_model = model
	var template_data = _property(model, "templates", {})
	var element_data = _property(model, "elements", {})
	sync(_property(model, "plots", []), _property(model, "reactors", []), template_data, element_data, int(_property(model, "engineers", 2)))


func _property(object, name: String, fallback):
	if object is Dictionary:
		return object.get(name, fallback)
	if object != null:
		for property in object.get_property_list():
			if str(property.name) == name:
				var value = object.get(name)
				return value if value != null else fallback
	return fallback


func sync(plots_data: Array, reactors_data: Array, templates: Dictionary, element_data: Dictionary, worker_count: int) -> void:
	_plots = plots_data
	_reactors = reactors_data
	_templates = templates
	_elements = element_data
	_worker_count = worker_count
	_ensure_stage()
	var next_signature: String = _make_signature()
	if _content == null or next_signature != _signature:
		rebuild()


func _make_signature() -> String:
	# Render only structural changes: stock, income and construction countdown ticks
	# must not rebuild hundreds of meshes during ordinary production.
	var items: Array = [mini(_worker_count, 10)]
	for index in range(_plots.size()):
		var plot: Dictionary = _plot_data(index)
		items.append([_plot_coord(index), plot.get("unlocked", false), plot.get("kind", "empty"), plot.get("reactor_index", plot.get("rid", -1))])
	for reactor in _reactors:
		items.append([reactor.get("plot", -1), reactor.get("level", 1), reactor.get("template", "water"), reactor.get("positions", []), reactor.get("atoms", []), reactor.get("bonds", []), float(reactor.get("build_left", 0.0)) > 0.0])
	return JSON.stringify(items)


func _ensure_stage() -> void:
	if is_instance_valid(camera):
		return
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("152e37")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b4ded3")
	environment.ambient_light_energy = 0.38
	# Compatibility rendering clips bright filmic lighting; keep the light budget low.
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment_node.environment = environment
	add_child(environment_node)
	var sunlight: DirectionalLight3D = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-53.0, -34.0, 0.0)
	sunlight.light_color = Color("fff1d9")
	sunlight.light_energy = 0.78
	sunlight.shadow_enabled = not (OS.has_feature("android") or OS.has_feature("web"))
	sunlight.directional_shadow_max_distance = 45.0
	sunlight.shadow_bias = 0.035
	sunlight.shadow_normal_bias = 1.0
	add_child(sunlight)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24.0, 140.0, 0.0)
	fill.light_color = Color("bfe7e7")
	fill.light_energy = 0.20
	add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.5
	camera.position = INITIAL_CAMERA_POSITION
	camera.near = 0.1
	camera.far = 150.0
	add_child(camera)
	camera.look_at(_camera_target)
	camera.current = true
	# A matte studio floor grounds the island and catches its soft shadows.
	_box(self, Vector3(1640.0, 0.12, 1640.0), Vector3(0.0, -1.36, 0.0), _mat(Color("19343d")))


func rebuild() -> void:
	geometry_rebuilds += 1
	detail_refresh_left = -1.0
	_ensure_stage()
	if is_instance_valid(_content):
		_content.free()
	_content = Node3D.new()
	_content.name = "ProceduralIsland"
	add_child(_content)
	_molecules.clear()
	_workers.clear()
	_motes.clear()
	_selection_markers.clear()
	_update_map_lookup()
	_choose_visible_details()
	_build_foundation()
	for index in range(_plots.size()):
		_build_plot(index)
	_build_paths_and_details()
	_build_workers()
	_build_motes()
	_selection = Node3D.new()
	_content.add_child(_selection)
	_build_selection()
	select_plot(_selected)
	_signature = _make_signature()
	_detail_signature = _visible_detail_signature()


func _build_foundation() -> void:
	# Each parcel contributes its own strata. MultiMesh keeps a sprawling island
	# to a handful of draw calls instead of allocating a large slab or 600 nodes.
	var positions: Array[Vector3] = []
	var grass_colors: Array[Color] = []
	var shades: Array[Color] = [Color("80bba0"), Color("91c7a6"), Color("78b697")]
	for index in range(_plots.size()):
		positions.append(_plot_position(index))
		grass_colors.append(shades[index % shades.size()] if bool(_plot_data(index).get("unlocked", false)) else Color("628c7b"))
	_batch_boxes(Vector3(2.98, 0.33, 2.98), Vector3(0, -0.95, 0), positions, _mat(Color("4f9185")))
	_batch_boxes(Vector3(3.02, 0.27, 3.02), Vector3(0, -0.69, 0), positions, _mat(Color("d6a47e")))
	_batch_boxes(Vector3(3.0, 0.44, 3.0), Vector3(0, -0.36, 0), positions, _mat(SOIL))
	_batch_boxes(Vector3(3.04, 0.12, 3.04), Vector3(0, -0.10, 0), positions, _mat(Color("aeb995")))
	var grass_material: StandardMaterial3D = _mat(Color.WHITE).duplicate()
	grass_material.vertex_color_use_as_albedo = true
	_batch_boxes(Vector3(2.82, 0.12, 2.82), Vector3.ZERO, positions, grass_material, grass_colors)
	var along_x: Array[Vector3] = []
	var along_z: Array[Vector3] = []
	for index in range(_plots.size()):
		var coord: Vector2i = _plot_coord(index)
		var pos: Vector3 = _plot_position(index)
		for side in [-1, 1]:
			if not _coord_lookup.has(coord + Vector2i(0, side)):
				for offset in [-0.91, 0.06, 0.99]:
					along_x.append(pos + Vector3(offset, -0.46 + 0.025 * sin(index + offset), side * 1.508))
			if not _coord_lookup.has(coord + Vector2i(side, 0)):
				for offset in [-0.91, 0.06, 0.99]:
					along_z.append(pos + Vector3(side * 1.508, -0.46 + 0.025 * cos(index + offset), offset))
	_batch_boxes(Vector3(0.58, 0.095, 0.024), Vector3.ZERO, along_x, _mat(Color("d9ab84")))
	_batch_boxes(Vector3(0.024, 0.095, 0.58), Vector3.ZERO, along_z, _mat(Color("d9ab84")))


func _batch_boxes(size_value: Vector3, offset: Vector3, positions: Array[Vector3], material: Material, colors: Array[Color] = []) -> void:
	if positions.is_empty():
		return
	var box: BoxMesh = BoxMesh.new()
	box.size = size_value
	var batch: MultiMesh = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = not colors.is_empty()
	batch.mesh = box
	batch.instance_count = positions.size()
	for index in range(positions.size()):
		batch.set_instance_transform(index, Transform3D(Basis.IDENTITY, positions[index] + offset))
		if not colors.is_empty():
			batch.set_instance_color(index, colors[index])
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.material_override = material
	_content.add_child(instance)


func _plot_coord(index: int) -> Vector2i:
	var data: Dictionary = _plot_data(index)
	return Vector2i(int(data.get("x", index % 3 - 1)), int(data.get("z", floori(float(index) / 3.0) - 1)))


func _plot_position(index: int) -> Vector3:
	var coord: Vector2i = _plot_coord(index)
	return Vector3(float(coord.x) * PITCH, 0.0, float(coord.y) * PITCH)


func _plot_data(index: int) -> Dictionary:
	if index >= 0 and index < _plots.size() and _plots[index] is Dictionary:
		return _plots[index]
	return {"unlocked": index in [3, 4, 5], "kind": "reactor" if index == 4 else "empty"}


func _build_plot(index: int) -> void:
	_build_plot_raw(index)
	var plot_node = _content.get_node_or_null("Plot_%d" % index)
	if plot_node != null: StaticGeometry.bake(plot_node)

func _build_plot_raw(index: int) -> void:
	if not _visible_plots.has(index):
		return
	var data: Dictionary = _plot_data(index)
	var unlocked: bool = bool(data.get("unlocked", false))
	var pos: Vector3 = _plot_position(index)
	var plot_root: Node3D = Node3D.new()
	plot_root.name = "Plot_%d" % index
	plot_root.position = pos
	_content.add_child(plot_root)
	if not unlocked:
		if index < 9 and _detailed_plots.has(index):
			_build_wild_plot(plot_root, index)
		else:
			_build_frontier_plot(plot_root, index)
		return
	var kind: String = str(data.get("kind", "empty"))
	if campus_life_enabled and kind in ["plaza","institute","engineer_house","doctor_dorm","professor_apartment","academician_villa","canteen","park","garden","house"]: return
	var reactor: Dictionary = _reactor_on_plot(index, data)
	if not _detailed_plots.has(index):
		_build_simple_plot(plot_root, kind, not reactor.is_empty())
		return
	if kind == "reactor" or not reactor.is_empty():
		_build_reactor(plot_root, reactor)
	elif kind == "garden" or kind == "crystal" or kind == "crystal_garden":
		_build_garden(plot_root)
	elif kind == "house" or kind == "cottage":
		_build_house(plot_root)
	elif kind == "road":
		_build_road(plot_root)
	elif kind == "fence":
		_build_fence(plot_root)
	elif kind == "sculpture":
		_build_sculpture(plot_root)
	else:
		_build_empty_plot(plot_root, index)


func _build_frontier_plot(parent: Node3D, index: int) -> void:
	# Appended land is a quiet survey site; it remains selectable and affordable
	# to render even when a long chain of unlocked parcels has a large frontier.
	_box(parent, Vector3(0.07, 0.48, 0.07), Vector3(0.0, 0.28, 0), _mat(CREAM))
	_box(parent, Vector3(0.40, 0.23, 0.045), Vector3(0.17, 0.44, 0), _mat(Color("dfce9d")))
	if _detailed_plots.has(index):
		_bush(parent, Vector3(-0.8, 0.07, -0.74), 0.35)
		_grass(parent, Vector3(0.85, 0.06, 0.77), index)


func _build_simple_plot(parent: Node3D, kind: String, has_reactor: bool) -> void:
	# Zoomed-out buildings retain their distinct silhouettes without glass,
	# animated atoms or numerous trim pieces. Up to 36 nearby plots use full art.
	if kind == "reactor" or has_reactor:
		_cylinder(parent, 1.02, 1.02, 0.30, Vector3(0, 0.26, 0), _mat(CREAM), 12)
		_cylinder(parent, 0.84, 0.84, 1.42, Vector3(0, 1.09, 0), _mat(Color("96c9ba")), 12)
		_cylinder(parent, 0.94, 0.61, 0.24, Vector3(0, 1.90, 0), _mat(TEAL), 12)
	elif kind in ["house", "cottage"]:
		_box(parent, Vector3(1.5, 1.1, 1.4), Vector3(0, 0.62, 0), _mat(CREAM))
		_cylinder(parent, 1.1, 0.0, 0.75, Vector3(0, 1.52, 0), _mat(Color("db947b")), 4)
	elif kind in ["garden", "crystal", "crystal_garden"]:
		_box(parent, Vector3(1.8, 0.20, 1.8), Vector3(0, 0.18, 0), _mat(Color("f2ddb7")))
		_cylinder(parent, 0.38, 0.0, 1.3, Vector3(0, 0.90, 0), _mat(Color("91d9d3")), 6)
	elif kind == "road":
		_build_road(parent, true)
	elif kind == "fence":
		_build_fence(parent, true)
	elif kind == "sculpture":
		_build_sculpture(parent, true)
	else:
		_cylinder(parent, 0.40, 0.40, 0.025, Vector3(0, 0.076, 0), _mat(Color("dce6c1")), 6)


func _reactor_on_plot(index: int, data: Dictionary) -> Dictionary:
	for reactor in _reactors:
		if int(reactor.get("plot", -1)) == index:
			return reactor
	var reactor_index: int = int(data.get("reactor_index", data.get("rid", -1)))
	if reactor_index >= 0 and reactor_index < _reactors.size():
		return _reactors[reactor_index]
	return {}


func _build_empty_plot(parent: Node3D, index: int) -> void:
	# The parcel is visibly ready to build, with a little inset foundation marker.
	_cylinder(parent, 0.52, 0.52, 0.025, Vector3(0, 0.076, 0), _mat(Color("dce6c1")), 6)
	_box(parent, Vector3(0.40, 0.025, 0.075), Vector3(0, 0.100, 0), _mat(Color("96b89a")))
	_box(parent, Vector3(0.075, 0.026, 0.40), Vector3(0, 0.100, 0), _mat(Color("96b89a")))
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(0.08, 0.13, 0.08), Vector3(side * 1.12, 0.13, -1.1), _mat(CREAM))
	_grass(parent, Vector3(-1.05, 0.06, 0.89), index)
	_grass(parent, Vector3(0.94, 0.06, 1.06), index + 4)


func _build_wild_plot(parent: Node3D, index: int) -> void:
	for offset in [Vector3(-0.96, 0.05, -0.80), Vector3(0.91, 0.05, 0.72)]:
		_grass(parent, offset, index)
	if index in [0, 2, 6]:
		_tree(parent, Vector3(-0.62, 0.06, -0.46), 0.88 if index == 0 else 0.72)
		_bush(parent, Vector3(0.80, 0.08, -0.80), 0.45)
	elif index in [7, 8]:
		_bush(parent, Vector3(-0.72, 0.08, -0.73), 0.48)
		_sphere(parent, 0.22, Vector3(0.93, 0.15, -0.63), _mat(Color("c1ccbc")), Vector3(1.1, 0.60, 0.8))
	else:
		_bush(parent, Vector3(-0.8, 0.06, -0.7), 0.38)
	# Brass survey pins and a quiet little padlock communicate expansion.
	for x in [-1.15, 1.15]:
		for z in [-1.15, 1.15]:
			_cylinder(parent, 0.035, 0.035, 0.20, Vector3(x, 0.14, z), _mat(Color("ead6a0")), 8)
	var lock_root: Node3D = Node3D.new()
	lock_root.position = Vector3(0.20, 0.34, 0.24)
	lock_root.rotation_degrees.y = 35.0
	parent.add_child(lock_root)
	_box(lock_root, Vector3(0.34, 0.28, 0.11), Vector3.ZERO, _mat(Color("e4d5a8")))
	var loop: MeshInstance3D = _torus(lock_root, 0.092, 0.128, Vector3(0, 0.18, 0), _mat(Color("f6ebc5")))
	loop.rotation_degrees.x = 90.0
	_sphere(lock_root, 0.025, Vector3(0, 0.015, 0.064), _mat(Color("929d7c")))
	_box(lock_root, Vector3(0.028, 0.048, 0.016), Vector3(0, -0.025, 0.061), _mat(Color("929d7c")))


func _build_reactor(parent: Node3D, reactor: Dictionary) -> void:
	var level: int = int(reactor.get("level", 1))
	var building: bool = float(reactor.get("build_left", 0.0)) > 0.0
	var metal: StandardMaterial3D = _mat(CREAM)
	var dark: StandardMaterial3D = _mat(TEAL)
	var mint: StandardMaterial3D = _mat(MINT)
	_cylinder(parent, 1.07, 1.12, 0.12, Vector3(0, 0.15, 0), _mat(Color("9bb4a0")), 48)
	_cylinder(parent, 1.03, 1.03, 0.24, Vector3(0, 0.31, 0), metal, 48)
	_cylinder(parent, 0.98, 0.98, 0.095, Vector3(0, 0.43, 0), dark, 48)
	_cylinder(parent, 0.87, 0.87, 0.075, Vector3(0, 0.50, 0), mint, 48)
	_cylinder(parent, 0.72, 0.72, 0.016, Vector3(0, 0.55, 0), _mat(Color("d6f5dd"), 0.23), 48)
	# A translucent open chamber makes the atoms the star of the laboratory.
	var glass: StandardMaterial3D = _mat(Color(0.66, 0.92, 0.90, 0.14))
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var chamber: MeshInstance3D = _cylinder(parent, 0.88, 0.88, 1.34, Vector3(0, 1.20, 0), glass, 48)
	chamber.mesh.cap_top = false
	chamber.mesh.cap_bottom = false
	chamber.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for angle in [40.0, 140.0, 225.0]:
		var radians: float = deg_to_rad(angle)
		var point: Vector3 = Vector3(cos(radians) * 0.90, 1.19, sin(radians) * 0.90)
		_cylinder(parent, 0.044, 0.044, 1.39, point, metal, 12)
	_torus(parent, 0.80, 0.965, Vector3(0, 1.90, 0), dark)
	_torus(parent, 0.83, 0.946, Vector3(0, 1.966, 0), mint)
	# The angled crown reads like an observatory, with an open viewing aperture.
	var crown := _cylinder(parent, 0.94, 0.66, 0.14, Vector3(0, 2.045, 0), metal, 48)
	crown.mesh.cap_top = false
	crown.mesh.cap_bottom = false
	_torus(parent, 0.55, 0.64, Vector3(0, 2.13, 0), dark)
	_torus(parent, 0.56, 0.60, Vector3(0, 2.151, 0), _mat(Color("c2eee6"), 0.15))
	for x in [-0.73, 0.73]:
		_box(parent, Vector3(0.22, 0.13, 0.39), Vector3(x, 0.17, 0.67), dark)
	# Screen and power canister sit toward the front edge of the parcel.
	var console_root: Node3D = Node3D.new()
	parent.add_child(console_root)
	console_root.position = Vector3(0.72, 0.58, 0.81)
	console_root.rotation_degrees.y = -18.0
	_box(console_root, Vector3(0.48, 0.37, 0.16), Vector3.ZERO, metal)
	_box(console_root, Vector3(0.34, 0.21, 0.024), Vector3(0, 0.034, 0.093), _mat(Color("315b62")))
	_box(console_root, Vector3(0.22, 0.025, 0.009), Vector3(-0.025, 0.076, 0.11), _mat(Color("9ae8be"), 0.35))
	_box(console_root, Vector3(0.15, 0.018, 0.009), Vector3(-0.06, 0.022, 0.11), _mat(Color("84cdbb"), 0.25))
	_sphere(console_root, 0.025, Vector3(0.13, -0.092, 0.10), _mat(GOLD, 0.3))
	_cylinder(parent, 0.19, 0.19, 0.53, Vector3(-0.96, 0.40, 0.43), dark, 20)
	_cylinder(parent, 0.20, 0.20, 0.065, Vector3(-0.96, 0.68, 0.43), metal, 20)
	_cylinder(parent, 0.08, 0.08, 0.12, Vector3(-0.96, 0.76, 0.43), _mat(GOLD), 16)
	for step in range(mini(level, 5)):
		_sphere(parent, 0.032, Vector3(-0.20 + step * 0.105, 0.33, 1.038), _mat(GOLD, 0.32))
	_build_molecule(parent, reactor)
	if building:
		for x in [-1.09, 1.09]:
			_cylinder(parent, 0.055, 0.055, 1.00, Vector3(x, 0.58, 1.02), _mat(GOLD), 8)
			_box(parent, Vector3(0.13, 0.13, 0.13), Vector3(x, 1.10, 1.02), _mat(Color("fff2b8"), 0.3))
		_box(parent, Vector3(2.23, 0.16, 0.08), Vector3(0, 0.75, 1.05), _mat(GOLD))


func _build_molecule(parent: Node3D, reactor: Dictionary) -> void:
	var key: String = str(reactor.get("template", "water"))
	var template: Dictionary = _templates.get(key, {})
	var positions: Array = reactor.get("positions", template.get("positions", []))
	var atoms: Array = reactor.get("atoms", template.get("atoms", template.get("elements", template.get("symbols", []))))
	if positions.is_empty():
		# A deliberately empty custom specimen must not become a water molecule.
		if reactor.has("positions"):
			return
		positions = [[0.0, 0.0, 0.0], [-0.76, -0.56, 0.0], [0.76, -0.56, 0.0]]
		atoms = ["O", "H", "H"]
	var points: Array[Vector3] = []
	var center: Vector3 = Vector3.ZERO
	for position in positions:
		var point: Vector3 = _vector(position)
		points.append(point)
		center += point
	center /= maxf(1.0, float(points.size()))
	var bound: float = 0.01
	for point in points:
		bound = maxf(bound, point.distance_to(center))
	var scale_factor: float = minf(0.53, 0.60 / bound)
	var molecule: Node3D = Node3D.new()
	molecule.name = "Molecule"
	parent.add_child(molecule)
	molecule.position = Vector3(0, 1.20, 0)
	molecule.rotation_degrees = Vector3(12, 24, -7)
	_molecules.append({"node": molecule, "phase": float(_molecules.size()) * 2.1})
	var symbols: Array[String] = []
	for index in range(points.size()):
		var symbol: String = "C"
		if index < atoms.size():
			if atoms[index] is Dictionary:
				symbol = str(atoms[index].get("element", atoms[index].get("symbol", "C")))
			else:
				symbol = str(atoms[index])
		symbols.append(symbol)
		var info: Dictionary = _elements.get(symbol, {})
		var color: Color = _atom_color(symbol)
		if info.get("color", null) is String:
			color = Color(str(info.color))
		var contexts: Array = reactor.get("atom_contexts",template.get("atom_contexts",[]))
		var display_radius: float = float(contexts[index].radius) if index < contexts.size() else float(info.get("covalent_radius", info.get("radius",0.7)))
		var radius: float = clampf(0.08 + display_radius * 0.075,0.105,0.23)
		if points.size() > 12:
			radius *= 0.76
		var atom_mesh := _sphere(molecule, radius, (points[index] - center) * scale_factor, _mat(color))
		atom_mesh.name = "Atom_%d_%s" % [index, symbol]
	var bonds: Array = reactor.get("bonds", template.get("bonds", []))
	if not bonds.is_empty():
		for bond in bonds:
			var start: int = -1
			var finish: int = -1
			if bond is Array and bond.size() >= 2:
				start = int(bond[0])
				finish = int(bond[1])
			elif bond is Dictionary:
				start = int(bond.get("a", bond.get("i", -1)))
				finish = int(bond.get("b", bond.get("j", -1)))
			if start >= 0 and finish >= 0 and start < points.size() and finish < points.size():
				_bond(molecule, (points[start] - center) * scale_factor, (points[finish] - center) * scale_factor, 0.042, _mat(Color("e7dfc5")))
	elif not reactor.has("bonds") and not template.has("bonds"):
		# Only a visual nearest-neighbour hint. Scientific scoring lives in the model.
		for start in range(points.size()):
			var nearest: float = INF
			for finish in range(points.size()):
				if start != finish:
					nearest = minf(nearest, points[start].distance_to(points[finish]))
			for finish in range(start + 1, points.size()):
				var distance: float = points[start].distance_to(points[finish])
				if distance <= nearest * 1.25 and distance > 0.001:
					_bond(molecule, (points[start] - center) * scale_factor, (points[finish] - center) * scale_factor, 0.034, _mat(Color("e7dfc5")))


func _vector(value) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.get("x", 0)), float(value.get("y", 0)), float(value.get("z", 0)))
	return Vector3.ZERO


func _atom_color(symbol: String) -> Color:
	var colors: Dictionary = {"H": Color("fff5df"), "C": Color("52647c"), "O": Color("f2837d"), "N": Color("6bace2"), "S": Color("f6ce62"), "Cl": Color("92c86d"), "Br": Color("c98765"), "I": Color("b796d3"), "Cs": Color("92c9d8"), "Pb": Color("877eb8"), "Ti": Color("81bfc5"), "Ca": Color("a5d984"), "Si": Color("dfb284"), "Na": Color("a5a2dd")}
	return colors.get(symbol, Color("a6d4be"))


func _build_garden(parent: Node3D) -> void:
	_box(parent, Vector3(1.95, 0.16, 1.95), Vector3(0, 0.16, 0), _mat(Color("f2ddb7")))
	_box(parent, Vector3(1.75, 0.10, 1.75), Vector3(0, 0.25, 0), _mat(Color("859c9a")))
	for index in range(7):
		var angle: float = float(index) * 2.40
		var radius: float = 0.0 if index == 0 else 0.54
		var height: float = 1.30 if index == 0 else 0.45 + float(index % 3) * 0.19
		var pos: Vector3 = Vector3(cos(angle) * radius, 0.32, sin(angle) * radius)
		var crystal_root: Node3D = Node3D.new()
		parent.add_child(crystal_root)
		crystal_root.position = pos
		crystal_root.rotation_degrees.z = 0.0 if index == 0 else cos(angle) * 13.0
		var crystal_color: Color = Color("91d9d3") if index % 2 == 0 else Color("c7b5e4")
		_cylinder(crystal_root, 0.20, 0.20, height * 0.7, Vector3(0, height * 0.35, 0), _mat(crystal_color), 6)
		_cylinder(crystal_root, 0.20, 0.0, height * 0.30, Vector3(0, height * 0.85, 0), _mat(crystal_color.lightened(0.12)), 6)
	for x in [-0.94, 0.94]:
		_box(parent, Vector3(0.15, 0.30, 0.15), Vector3(x, 0.32, 0.95), _mat(CREAM))
		_sphere(parent, 0.10, Vector3(x, 0.52, 0.95), _mat(GOLD, 0.4))
	_bush(parent, Vector3(-0.99, 0.09, -0.92), 0.24)


func _build_road(parent: Node3D, simple: bool = false) -> void:
	var road := Node3D.new()
	road.name = "StoneRoad"
	parent.add_child(road)
	_box(road, Vector3(2.78, 0.07, 1.16), Vector3(0, 0.10, 0), _mat(Color("c7b98f")))
	_box(road, Vector3(1.16, 0.072, 2.78), Vector3(0, 0.101, 0), _mat(Color("c7b98f")))
	if simple: return
	for row in range(-2, 3):
		for column in range(-2, 3):
			if absi(row) > 0 and absi(column) > 0: continue
			var shade := Color("eee0ba") if (row + column) % 2 == 0 else Color("dfcfac")
			_box(road, Vector3(0.49, 0.032, 0.49), Vector3(column * 0.54, 0.151, row * 0.54), _mat(shade))
	for point in [Vector3(-1.10, 0.075, 1.09), Vector3(1.11, 0.075, -1.10)]:
		_grass(road, point, 7)


func _build_fence(parent: Node3D, simple: bool = false) -> void:
	var fence := Node3D.new()
	fence.name = "GardenFence"
	parent.add_child(fence)
	for x in [-1.12, 1.12]:
		for z in [-1.12, 1.12]: _fence_post(fence, Vector3(x, 0.07, z))
	for height_value in ([0.42] if simple else [0.27, 0.46]):
		_box(fence, Vector3(2.22, 0.08, 0.07), Vector3(0, height_value, -1.12), _mat(CREAM))
		for side in [-1.0, 1.0]:
			_box(fence, Vector3(0.07, 0.08, 2.22), Vector3(side * 1.12, height_value, 0), _mat(CREAM))
			_box(fence, Vector3(0.63, 0.08, 0.07), Vector3(side * 0.80, height_value, 1.12), _mat(CREAM))
	if simple: return
	for x in [-0.49, 0.49]: _fence_post(fence, Vector3(x, 0.07, 1.12))
	_box(fence, Vector3(0.58, 0.23, 0.46), Vector3(-0.67, 0.23, -0.65), _mat(TEAL))
	_bush(fence, Vector3(-0.67, 0.34, -0.65), 0.32)
	_sphere(fence, 0.08, Vector3(-0.53, 0.67, -0.59), _mat(GOLD))
	_box(fence, Vector3(0.69, 0.035, 0.91), Vector3(0, 0.09, 1.0), _mat(Color("e3d2aa")))


func _build_sculpture(parent: Node3D, simple: bool = false) -> void:
	var sculpture := Node3D.new()
	sculpture.name = "AtomicSculpture"
	parent.add_child(sculpture)
	_cylinder(sculpture, 0.91, 0.91, 0.16, Vector3(0, 0.16, 0), _mat(Color("e9dcbb")), 24)
	_cylinder(sculpture, 0.69, 0.75, 0.22, Vector3(0, 0.35, 0), _mat(TEAL), 24)
	_torus(sculpture, 0.62, 0.69, Vector3(0, 0.48, 0), _mat(GOLD))
	var atoms := Node3D.new()
	atoms.name = "CrystalAtoms"
	atoms.position = Vector3(0, 1.23, 0)
	atoms.rotation_degrees.y = 18.0
	sculpture.add_child(atoms)
	_sphere(atoms, 0.27, Vector3.ZERO, _mat(Color("b6a5de"), 0.08), Vector3.ONE, 16)
	var corners: Array[Vector3] = []
	for index in range(8):
		var pos := Vector3(0.46 if index & 1 else -0.46, 0.46 if index & 2 else -0.46, 0.46 if index & 4 else -0.46)
		corners.append(pos)
		_sphere(atoms, 0.13, pos, _mat(MINT), Vector3.ONE, 12)
	if simple: return
	for index in range(8):
		for bit in [1, 2, 4]:
			var other: int = index ^ bit
			if other > index: _bond(atoms, corners[index], corners[other], 0.025, _mat(Color("799f9b")))
	for direction in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var pos: Vector3 = direction * 0.46
		_sphere(atoms, 0.125, pos, _mat(GOLD), Vector3.ONE, 12)
		_bond(atoms, Vector3.ZERO, pos, 0.028, _mat(Color("ddc69a")))
	_box(sculpture, Vector3(0.38, 0.17, 0.035), Vector3(0, 0.32, 0.72), _mat(GOLD))
	# This display is a decorative geometric atom sculpture, not a material claim.


func _build_house(parent: Node3D) -> void:
	_box(parent, Vector3(1.89, 0.14, 1.74), Vector3(0, 0.16, 0), _mat(Color("dfcfb1")))
	_box(parent, Vector3(1.52, 1.03, 1.27), Vector3(0, 0.73, -0.12), _mat(CREAM))
	_box(parent, Vector3(1.55, 0.15, 1.30), Vector3(0, 0.27, -0.12), _mat(MINT))
	# Two thick roof panels form a soft, toy-like gable.
	for side in [-1.0, 1.0]:
		var roof: MeshInstance3D = _box(parent, Vector3(0.99, 0.15, 1.61), Vector3(side * 0.40, 1.42, -0.12), _mat(Color("db947b")))
		roof.rotation_degrees.z = side * -31.0
	_box(parent, Vector3(0.38, 0.40, 0.38), Vector3(0.42, 1.58, -0.48), _mat(Color("d9c4a4")))
	_box(parent, Vector3(0.45, 0.09, 0.45), Vector3(0.42, 1.81, -0.48), _mat(TEAL))
	_box(parent, Vector3(0.34, 0.69, 0.045), Vector3(-0.23, 0.60, 0.537), _mat(TEAL))
	_sphere(parent, 0.030, Vector3(-0.12, 0.60, 0.571), _mat(GOLD))
	_box(parent, Vector3(0.38, 0.37, 0.05), Vector3(0.40, 0.85, 0.55), _mat(TEAL))
	_box(parent, Vector3(0.29, 0.27, 0.028), Vector3(0.40, 0.85, 0.59), _mat(Color("cae9dc"), 0.1))
	_box(parent, Vector3(0.035, 0.28, 0.03), Vector3(0.40, 0.85, 0.61), _mat(CREAM))
	_box(parent, Vector3(0.30, 0.035, 0.03), Vector3(0.40, 0.85, 0.61), _mat(CREAM))
	_box(parent, Vector3(0.58, 0.1, 0.35), Vector3(-0.23, 0.26, 0.70), _mat(Color("d4d8ba")))
	_bush(parent, Vector3(0.73, 0.10, 0.80), 0.29)
	_bush(parent, Vector3(-0.91, 0.10, -0.78), 0.34)


func _build_paths_and_details() -> void:
	if campus_life_enabled: return
	var path: StandardMaterial3D = _mat(Color("d8c29a"))
	var north_south: Array[Vector3] = []
	var east_west: Array[Vector3] = []
	for index in range(_plots.size()):
		var coord: Vector2i = _plot_coord(index)
		var pos: Vector3 = _plot_position(index)
		if _coord_lookup.has(coord + Vector2i(1, 0)):
			north_south.append(pos + Vector3(PITCH * 0.5, 0.063, 0))
		if _coord_lookup.has(coord + Vector2i(0, 1)):
			east_west.append(pos + Vector3(0, 0.064, PITCH * 0.5))
	_batch_boxes(Vector3(0.18, 0.035, PITCH), Vector3.ZERO, north_south, path)
	_batch_boxes(Vector3(PITCH, 0.035, 0.18), Vector3.ZERO, east_west, path)
	# The original welcome corner remains a landmark, with no fixed outer fence
	# preventing the land from growing. Its boardwalk disappears when land joins.
	if not _visible_plots.has(7):
		return
	if not _coord_lookup.has(Vector2i(0, 2)):
		for step in range(4):
			_box(_content, Vector3(1.1 + step * 0.04, 0.13, 0.29), Vector3(0, -0.07 - step * 0.16, 4.58 + step * 0.24), _mat(Color("dcb58d")))
	for x in [-0.87, 0.87]:
		_cylinder(_content, 0.065, 0.07, 0.63, Vector3(x, 0.40, 4.30), _mat(TEAL), 12)
		_sphere(_content, 0.15, Vector3(x, 0.78, 4.30), _mat(Color("ffecaf"), 0.3))
		_cylinder(_content, 0.21, 0.10, 0.13, Vector3(x, 0.96, 4.30), _mat(TEAL), 12)
	_box(_content, Vector3(0.11, 0.48, 0.11), Vector3(1.61, 0.32, 4.22), _mat(Color("d5ac88")))
	_box(_content, Vector3(0.44, 0.30, 0.32), Vector3(1.61, 0.66, 4.22), _mat(Color("e99883")))
	_box(_content, Vector3(0.29, 0.032, 0.01), Vector3(1.61, 0.71, 4.39), _mat(INK))


func _fence_post(parent: Node3D, pos: Vector3) -> void:
	_box(parent, Vector3(0.10, 0.44, 0.10), pos + Vector3(0, 0.22, 0), _mat(CREAM))
	_cylinder(parent, 0.085, 0.0, 0.10, pos + Vector3(0, 0.49, 0), _mat(CREAM), 4)


func _tree(parent: Node3D, pos: Vector3, scale_value: float) -> void:
	var tree: Node3D = Node3D.new()
	parent.add_child(tree)
	tree.position = pos
	tree.scale = Vector3.ONE * scale_value
	_cylinder(tree, 0.12, 0.08, 0.81, Vector3(0, 0.41, 0), _mat(Color("bc9873")), 9)
	_sphere(tree, 0.51, Vector3(0, 1.04, 0), _mat(Color("70aa8b")), Vector3(1.0, 1.22, 1.0), 16)
	_sphere(tree, 0.35, Vector3(-0.25, 0.90, 0.12), _mat(Color("85bd96")), Vector3(1.0, 1.12, 1.0), 16)
	_sphere(tree, 0.33, Vector3(0.27, 1.13, 0.04), _mat(Color("a2cfa2")), Vector3(1.0, 1.1, 1.0), 16)
	_sphere(tree, 0.055, Vector3(0.21, 1.16, 0.37), _mat(Color("f1b79a")))
	_sphere(tree, 0.05, Vector3(-0.15, 0.95, 0.48), _mat(Color("f1b79a")))


func _bush(parent: Node3D, pos: Vector3, radius: float) -> void:
	_sphere(parent, radius, pos + Vector3(0, radius * 0.45, 0), _mat(Color("7eb68e")), Vector3(1.1, 0.78, 1.0), 12)
	_sphere(parent, radius * 0.63, pos + Vector3(radius * 0.62, radius * 0.30, 0.08), _mat(Color("a5cc93")), Vector3(1.0, 0.9, 1.0), 12)
	_sphere(parent, 0.035, pos + Vector3(-radius * 0.2, radius * 1.10, radius * 0.6), _mat(Color("fce0b2")))


func _grass(parent: Node3D, pos: Vector3, seed_value: int) -> void:
	for index in range(3):
		var blade: MeshInstance3D = _cylinder(parent, 0.04, 0.0, 0.18 + float(index % 2) * 0.08, pos + Vector3((index - 1) * 0.07, 0.08, sin(float(index + seed_value)) * 0.05), _mat(Color("79a77d")), 5)
		blade.rotation_degrees.z = (index - 1) * 17.0


func _build_workers() -> void:
	if campus_life_enabled: return
	for index in range(clampi(_worker_count, 1, 10)):
		var worker: Node3D = Node3D.new()
		_content.add_child(worker)
		worker.scale = Vector3.ONE * 0.73
		var torso: Node3D = Node3D.new()
		worker.add_child(torso)
		_box(torso, Vector3(0.29, 0.28, 0.21), Vector3(0, 0.38, 0), _mat(TEAL if index % 2 == 0 else Color("cc8c75")))
		_box(torso, Vector3(0.23, 0.14, 0.024), Vector3(0, 0.40, -0.12), _mat(MINT))
		for x in [-0.105, 0.105]:
			_box(torso, Vector3(0.045, 0.24, 0.025), Vector3(x, 0.40, -0.125), _mat(CREAM))
		_sphere(torso, 0.167, Vector3(0, 0.65, -0.01), _mat(CREAM), Vector3(1.0, 0.9, 0.9))
		_sphere(torso, 0.164, Vector3(0, 0.78, -0.01), _mat(GOLD), Vector3(1.0, 0.62, 1.0))
		_cylinder(torso, 0.196, 0.196, 0.032, Vector3(0, 0.747, -0.029), _mat(GOLD), 20)
		_box(torso, Vector3(0.033, 0.045, 0.19), Vector3(0, 0.871, -0.012), _mat(Color("ffe0a0")))
		for x in [-0.058, 0.058]:
			_sphere(torso, 0.021, Vector3(x, 0.66, -0.150), _mat(INK))
		_box(torso, Vector3(0.046, 0.014, 0.009), Vector3(0, 0.60, -0.153), _mat(Color("a77966")))
		var legs: Array = []
		var arms: Array = []
		for side in [-1.0, 1.0]:
			var leg: Node3D = Node3D.new()
			worker.add_child(leg)
			leg.position = Vector3(side * 0.085, 0.27, 0)
			_box(leg, Vector3(0.10, 0.17, 0.11), Vector3(0, -0.08, 0), _mat(Color("426975")))
			_box(leg, Vector3(0.125, 0.07, 0.18), Vector3(0, -0.18, -0.03), _mat(INK))
			legs.append(leg)
			var arm: Node3D = Node3D.new()
			torso.add_child(arm)
			arm.position = Vector3(side * 0.20, 0.49, 0)
			_cylinder(arm, 0.060, 0.060, 0.20, Vector3(0, -0.10, 0), _mat(CREAM), 10)
			_sphere(arm, 0.066, Vector3(0, -0.21, 0), _mat(Color("e9c99d")))
			arms.append(arm)
		_workers.append({"node": worker, "body": torso, "legs": legs, "arms": arms, "offset": float(index) * 12.0 / maxf(1.0, float(_worker_count)), "speed": 0.34 + 0.035 * (index % 3)})


func _build_motes() -> void:
	for index in range(10):
		var angle: float = float(index) * 2.399
		var pos: Vector3 = Vector3(cos(angle) * (2.2 + float(index % 3)), 0.65 + float(index % 4) * 0.52, sin(angle) * 3.4)
		var mote: MeshInstance3D = _sphere(_content, 0.022 + float(index % 2) * 0.01, pos, _mat(Color("fff7ce"), 0.5), Vector3.ONE, 8)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_motes.append({"node": mote, "base": pos, "phase": float(index) * 1.2})


## Idempotent visitor presentation. The model owns arrival frequency and orders;
## this method only animates changes in the supplied visit identity/state.
func set_visitor(available: bool, buyer_name: String, visit_count: int) -> void:
	_ensure_visitor()
	var next_name := buyer_name.strip_edges().left(32)
	if next_name.is_empty(): next_name = "收购商"
	var state_changed := available != _visitor_available or visit_count != _visitor_visit_count
	_visitor_name = next_name
	_visitor_available = available
	_visitor_visit_count = visit_count
	if not state_changed:
		if _visitor_active_visit == visit_count: _visitor_node.set_meta("buyer_name", next_name)
		return
	if available:
		if _visitor_phase == "absent":
			_start_visitor_arrival()
		elif _visitor_active_visit != visit_count and _visitor_phase != "leaving":
			_start_visitor_departure()
		elif _visitor_phase == "leaving":
			# Finish the current exit; the requested visit enters afterward.
			pass
	else:
		if _visitor_phase != "absent" and _visitor_phase != "leaving": _start_visitor_departure()


func _ensure_visitor() -> void:
	if is_instance_valid(_visitor_node): return
	_visitor_node = Node3D.new()
	_visitor_node.name = "BuyerVisitor"
	_visitor_node.visible = false
	_visitor_node.scale = Vector3.ONE * 1.10
	add_child(_visitor_node)
	_visitor_body = Node3D.new()
	_visitor_body.name = "Body"
	_visitor_node.add_child(_visitor_body)
	# A plum coat, straw hat, little bow tie and brass case distinguish buyers
	# from the smaller engineers in yellow hard hats.
	var coat := _mat(Color("8f769f"))
	var skin := _mat(Color("efd0ae"))
	_box(_visitor_body, Vector3(0.40, 0.44, 0.28), Vector3(0, 0.64, 0), coat)
	_box(_visitor_body, Vector3(0.16, 0.36, 0.035), Vector3(0, 0.65, -0.155), _mat(CREAM))
	for side in [-1.0, 1.0]:
		var bow := _box(_visitor_body, Vector3(0.10, 0.075, 0.042), Vector3(side * 0.04, 0.79, -0.186), _mat(TEAL))
		bow.rotation_degrees.z = side * 22.0
	_sphere(_visitor_body, 0.028, Vector3(0, 0.79, -0.209), _mat(GOLD))
	_sphere(_visitor_body, 0.225, Vector3(0, 1.02, -0.016), skin, Vector3(1.0, 0.93, 0.91))
	for x in [-0.083, 0.083]:
		_sphere(_visitor_body, 0.027, Vector3(x, 1.045, -0.209), _mat(INK))
		var rim := _torus(_visitor_body, 0.053, 0.063, Vector3(x, 1.045, -0.227), _mat(Color("b99b69")))
		rim.rotation_degrees.x = 90.0
	_box(_visitor_body, Vector3(0.045, 0.020, 0.018), Vector3(0, 1.045, -0.232), _mat(Color("b99b69")))
	_box(_visitor_body, Vector3(0.055, 0.016, 0.010), Vector3(0, 0.948, -0.212), _mat(Color("ad776d")))
	_cylinder(_visitor_body, 0.31, 0.31, 0.043, Vector3(0, 1.196, -0.015), _mat(Color("efd9a4")), 24).name = "HatBrim"
	_cylinder(_visitor_body, 0.205, 0.19, 0.21, Vector3(0, 1.30, -0.005), _mat(Color("e3cb99")), 20)
	_cylinder(_visitor_body, 0.208, 0.207, 0.055, Vector3(0, 1.237, -0.005), coat, 20)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.105, 0.44, 0)
		_visitor_node.add_child(leg)
		_box(leg, Vector3(0.13, 0.26, 0.14), Vector3(0, -0.13, 0), _mat(INK))
		_box(leg, Vector3(0.165, 0.10, 0.24), Vector3(0, -0.305, -0.040), _mat(Color("3d454e")))
		_visitor_legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.255, 0.81, 0)
		_visitor_body.add_child(arm)
		_cylinder(arm, 0.080, 0.080, 0.27, Vector3(0, -0.12, 0), coat, 12)
		_sphere(arm, 0.088, Vector3(0, -0.29, 0), skin, Vector3.ONE, 12)
		_visitor_arms.append(arm)
	var suitcase := Node3D.new()
	suitcase.name = "Briefcase"
	suitcase.position = Vector3(-0.045, -0.51, 0)
	_visitor_arms[0].add_child(suitcase)
	_box(suitcase, Vector3(0.17, 0.30, 0.37), Vector3.ZERO, _mat(Color("b48a62")))
	_box(suitcase, Vector3(0.19, 0.055, 0.38), Vector3(0, 0.02, 0), _mat(Color("dbc098")))
	_box(suitcase, Vector3(0.032, 0.073, 0.10), Vector3(-0.102, 0.05, 0), _mat(GOLD))
	var handle := _torus(suitcase, 0.05, 0.075, Vector3(0, 0.195, 0), _mat(Color("735b49")))
	handle.rotation_degrees.z = 90.0
	_visitor_badge = Node3D.new()
	_visitor_badge.name = "TradeReady"
	_visitor_badge.position = Vector3(0, 1.73, 0)
	_visitor_node.add_child(_visitor_badge)
	# A real coin marker has no imported texture or font dependency.
	var coin := _cylinder(_visitor_badge, 0.13, 0.13, 0.04, Vector3.ZERO, _mat(GOLD, 0.10), 20)
	coin.rotation_degrees.x = 90.0
	_box(_visitor_badge, Vector3(0.034, 0.14, 0.044), Vector3(0, 0, -0.027), _mat(Color("fff0bf")))
	for side in [-1.0, 1.0]:
		_sphere(_visitor_badge, 0.030, Vector3(side * 0.24, 0, 0), _mat(CREAM), Vector3.ONE, 8)


func _start_visitor_arrival() -> void:
	_visitor_active_visit = _visitor_visit_count
	_visitor_node.set_meta("buyer_name", _visitor_name)
	_visitor_node.set_meta("visit_count", _visitor_active_visit)
	_visitor_phase = "arriving"
	_visitor_phase_time = 0.0
	var gate := _visitor_gate_position()
	_visitor_route_start = gate
	_set_visitor_route([gate, VISITOR_LANDING, VISITOR_STOP])
	_visitor_node.position = gate
	_visitor_node.visible = true
	_visitor_badge.visible = false


func _start_visitor_departure() -> void:
	_visitor_phase = "leaving"
	_visitor_phase_time = 0.0
	_visitor_route_start = _visitor_node.position
	var gate := _visitor_gate_position()
	if _visitor_node.position.z >= VISITOR_LANDING.z:
		_set_visitor_route([_visitor_node.position, gate])
	else:
		_set_visitor_route([_visitor_node.position, VISITOR_LANDING, gate])
	_visitor_badge.visible = false


func _visitor_gate_position() -> Vector3:
	# Without the next parcel, use the existing welcome steps instead of
	# walking through empty space beside the floating island.
	return VISITOR_GATE if _coord_lookup.has(Vector2i(0, 2)) else Vector3(0.0, -0.56, 5.30)


func _set_visitor_route(points: Array) -> void:
	_visitor_route.assign(points)
	_visitor_route_length = 0.0
	for i in range(1, _visitor_route.size()): _visitor_route_length += _visitor_route[i - 1].distance_to(_visitor_route[i])


func _visitor_route_point(progress: float) -> Vector3:
	var remaining := clampf(progress, 0.0, 1.0) * _visitor_route_length
	for i in range(1, _visitor_route.size()):
		var length_value := _visitor_route[i - 1].distance_to(_visitor_route[i])
		if remaining <= length_value and length_value > 0.00001:
			return _visitor_route[i - 1].lerp(_visitor_route[i], remaining / length_value)
		remaining -= length_value
	return _visitor_route.back() if not _visitor_route.is_empty() else VISITOR_STOP


func _animate_visitor(delta: float) -> void:
	if not is_instance_valid(_visitor_node) or _visitor_phase == "absent": return
	_visitor_phase_time += delta
	_visitor_walk_time += delta
	var walking := _visitor_phase in ["arriving", "leaving"]
	if walking:
		var duration := 3.4 if _visitor_phase == "arriving" else 2.8
		var progress := clampf(_visitor_phase_time / duration, 0.0, 1.0)
		_visitor_node.position = _visitor_route_point(progress)
		var direction := _visitor_route_point(progress + 0.01) - _visitor_route_point(progress - 0.01)
		direction.y = 0.0
		if direction.length_squared() > 0.001: _visitor_node.look_at(_visitor_node.position + direction.normalized(), Vector3.UP)
		if progress >= 1.0:
			if _visitor_phase == "arriving":
				_visitor_phase = "greeting"
				_visitor_phase_time = 0.0
				_visitor_badge.visible = true
			else:
				_visitor_phase = "absent"
				_visitor_node.visible = false
				_visitor_phase_time = 0.0
				if _visitor_available: _start_visitor_arrival()
				return
	elif _visitor_phase == "greeting":
		_visitor_node.look_at(_visitor_node.position + Vector3(0.5, 0.0, 1.0), Vector3.UP)
		if _visitor_phase_time >= 2.4:
			_visitor_phase = "browsing"
			_visitor_phase_time = 0.0
	else:
		_visitor_node.rotation.y += sin(_visitor_walk_time * 0.55) * delta * 0.06
	var step := _visitor_walk_time * 7.5
	_visitor_body.position.y = absf(sin(step)) * 0.025 if walking else sin(_visitor_walk_time * 2.0) * 0.009
	for index in range(2):
		var swing := sin(step + index * PI)
		_visitor_legs[index].rotation.x = swing * 0.40 if walking else 0.0
		_visitor_arms[index].rotation.x = -swing * (0.12 if index == 0 else 0.31) if walking else 0.0
		_visitor_arms[index].rotation.z = 0.0
	if _visitor_phase == "greeting":
		_visitor_arms[1].rotation.z = 2.1 + sin(_visitor_phase_time * 9.0) * 0.27
		_visitor_arms[1].rotation.x = -0.10
	elif _visitor_phase == "browsing":
		# A small recurring hello keeps the shopkeeper visibly alive during a visit.
		if fposmod(_visitor_phase_time, 11.0) < 1.4:
			_visitor_arms[1].rotation.z = 1.95 + sin(_visitor_phase_time * 8.0) * 0.18
	_visitor_badge.position.y = 1.73 + sin(_visitor_walk_time * 2.4) * 0.045
	_visitor_badge.rotation.y = -_visitor_node.rotation.y + 0.40


func _build_selection() -> void:
	var mat: StandardMaterial3D = _mat(Color("fcebb2"), 0.18)
	for x in [-1.36, 1.36]:
		for z in [-1.36, 1.36]:
			var marker: Node3D = Node3D.new()
			_selection.add_child(marker)
			marker.position = Vector3(x, 0.11, z)
			_box(marker, Vector3(0.40, 0.038, 0.065), Vector3(-signf(x) * 0.17, 0, 0), mat)
			_box(marker, Vector3(0.065, 0.039, 0.40), Vector3(0, 0, -signf(z) * 0.17), mat)
			_selection_markers.append(marker)


func select_plot(index: int) -> void:
	var next_selected: int = clampi(index, 0, maxi(0, _plots.size() - 1))
	var changed: bool = next_selected != _selected
	_selected = next_selected
	if is_instance_valid(_selection):
		_selection.position = _plot_position(_selected)
	if changed and is_instance_valid(_content):
		_refresh_camera_details()


func orbit(delta_radians: float) -> void:
	if not is_instance_valid(camera):
		return
	camera.position = _camera_target + (camera.position - _camera_target).rotated(Vector3.UP, delta_radians)
	camera.look_at(_camera_target)


## Positive x/y moves the view right/down on screen. One unit is one parcel.
func pan_view(direction: Vector2) -> void:
	_ensure_stage()
	var screen_right: Vector3 = camera.basis.x
	var screen_down: Vector3 = camera.basis.z
	screen_right.y = 0.0
	screen_down.y = 0.0
	var shift: Vector3 = (screen_right.normalized() * direction.x + screen_down.normalized() * direction.y) * PITCH
	_move_camera_target(_camera_target + shift)
	_refresh_camera_details()


## Multiplicative zoom: a factor below one zooms in; above one zooms out.
func zoom_view(factor: float) -> void:
	_ensure_stage()
	if not is_finite(factor) or factor <= 0.0:
		return
	camera.size = clampf(camera.size * factor, 8.0, 45.0)
	_refresh_camera_details()


func reset_view() -> void:
	_ensure_stage()
	_camera_target = INITIAL_CAMERA_TARGET
	camera.position = INITIAL_CAMERA_POSITION
	camera.size = 14.5
	camera.look_at(_camera_target)
	_refresh_camera_details()


func focus_plot(index: int) -> void:
	if index < 0 or index >= _plots.size():
		return
	select_plot(index)
	_move_camera_target(_plot_position(index) + Vector3(0, INITIAL_CAMERA_TARGET.y, 0))
	_refresh_camera_details()


func _move_camera_target(target: Vector3) -> void:
	var clamped: Vector3 = Vector3(clampf(target.x, _map_min.x, _map_max.x), INITIAL_CAMERA_TARGET.y, clampf(target.z, _map_min.y, _map_max.y))
	camera.position += clamped - _camera_target
	_camera_target = clamped
	camera.look_at(_camera_target)


func _update_map_lookup() -> void:
	_coord_lookup.clear()
	_map_min = Vector2.ZERO
	_map_max = Vector2.ZERO
	for index in range(_plots.size()):
		var coord: Vector2i = _plot_coord(index)
		_coord_lookup[coord] = index
		var position_xz: Vector2 = Vector2(coord) * PITCH
		_map_min = _map_min.min(position_xz)
		_map_max = _map_max.max(position_xz)
	_move_camera_target(_camera_target)


func _choose_visible_details() -> void:
	_detailed_plots.clear()
	_visible_plots.clear()
	var candidates: Array = []
	var radius: float = clampf(camera.size * 1.35, 11.0, SIMPLE_DETAIL_RADIUS)
	for index in range(_plots.size()):
		var distance: float = Vector2(_plot_position(index).x - _camera_target.x, _plot_position(index).z - _camera_target.z).length_squared()
		if distance <= radius * radius or index == _selected:
			_visible_plots[index] = true
			candidates.append({"index": index, "distance": -1.0 if index == _selected else distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.distance) < float(b.distance))
	for index in range(mini(detail_budget, candidates.size())):
		_detailed_plots[int(candidates[index].index)] = true


func _visible_detail_signature() -> String:
	var detailed: Array = _detailed_plots.keys()
	var visible: Array = _visible_plots.keys()
	detailed.sort()
	visible.sort()
	return JSON.stringify([detailed, visible])


func _refresh_camera_details() -> void:
	# Camera movement is immediate; expensive LOD geometry waits until the gesture settles.
	detail_refresh_left = 0.22

func _commit_camera_details() -> void:
	_choose_visible_details()
	var next_signature: String = _visible_detail_signature()
	if next_signature != _detail_signature:
		rebuild()


func screen_pick(screen_pos: Vector2) -> int:
	if not is_instance_valid(camera):
		return -1
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var direction: Vector3 = camera.project_ray_normal(screen_pos)
	if absf(direction.y) < 0.00001:
		return -1
	var distance: float = (0.08 - origin.y) / direction.y
	if distance < 0:
		return -1
	var point: Vector3 = origin + direction * distance
	# Lookup is based on actual coordinates; append-only plot IDs stay stable
	# across saves even for sparse, irregular islands and negative coordinates.
	var coord: Vector2i = Vector2i(floori((point.x + PITCH * 0.5) / PITCH), floori((point.z + PITCH * 0.5) / PITCH))
	return int(_coord_lookup.get(coord, -1))


func handle_click(screen_pos: Vector2) -> int:
	var index: int = screen_pick(screen_pos)
	if index >= 0:
		select_plot(index)
		plot_clicked.emit(index)
	return index


func _process(delta: float) -> void:
	if detail_refresh_left >= 0.0 and not interaction_lock:
		detail_refresh_left -= delta
		if detail_refresh_left < 0.0: _commit_camera_details()
	_time += delta
	_animate_visitor(delta)
	for item in _molecules:
		var node: Node3D = item.node
		node.rotation.y += delta * 0.24
		node.position.y = 1.20 + sin(_time * 1.1 + float(item.phase)) * 0.055
	for item in _motes:
		var node: Node3D = item.node
		var base: Vector3 = item.base
		var phase: float = item.phase
		node.position = base + Vector3(sin(_time * 0.3 + phase) * 0.15, sin(_time * 0.8 + phase) * 0.12, cos(_time * 0.25 + phase) * 0.10)
	for item in _workers:
		var worker: Node3D = item.node
		var travel: float = fposmod(_time * float(item.speed) + float(item.offset), 12.0)
		var direction: Vector3 = Vector3.FORWARD
		var position_on_path: Vector3
		if travel < 3.0:
			position_on_path = Vector3(-1.5 + travel, 0.10, -1.5)
			direction = Vector3.RIGHT
		elif travel < 6.0:
			position_on_path = Vector3(1.5, 0.10, -1.5 + travel - 3.0)
			direction = Vector3.BACK
		elif travel < 9.0:
			position_on_path = Vector3(1.5 - (travel - 6.0), 0.10, 1.5)
			direction = Vector3.LEFT
		else:
			position_on_path = Vector3(-1.5, 0.10, 1.5 - (travel - 9.0))
			direction = Vector3.FORWARD
		worker.position = position_on_path
		worker.look_at(position_on_path + direction, Vector3.UP)
		var walk_phase: float = _time * 7.0 + float(item.offset)
		item.body.position.y = absf(sin(walk_phase)) * 0.025
		for index in range(2):
			var phase: float = walk_phase + index * PI
			item.legs[index].rotation.x = sin(phase) * 0.42
			item.arms[index].rotation.x = -sin(phase) * 0.30
	for marker in _selection_markers:
		marker.position.y = 0.115 + sin(_time * 2.2) * 0.012


func _mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key: String = color.to_html(true) + ":" + str(glow)
	if _materials.has(key):
		return _materials[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.68
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.25
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	_materials[key] = material
	return material


func _box(parent: Node3D, size_value: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size_value
	return _mesh(parent, mesh, pos, material)


func _sphere(parent: Node3D, radius: float, pos: Vector3, material: Material, stretch: Vector3 = Vector3.ONE, segments: int = 24) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(6, segments / 2)
	var instance: MeshInstance3D = _mesh(parent, mesh, pos, material)
	instance.scale = stretch
	return instance


func _cylinder(parent: Node3D, bottom: float, top: float, height_value: float, pos: Vector3, material: Material, segments: int = 32) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height_value
	mesh.radial_segments = segments
	return _mesh(parent, mesh, pos, material)


func _torus(parent: Node3D, inner: float, outer: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 40
	mesh.ring_segments = 10
	return _mesh(parent, mesh, pos, material)


func _bond(parent: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
	var delta: Vector3 = finish - start
	if delta.length() < 0.001:
		return
	var instance: MeshInstance3D = _cylinder(parent, radius, radius, delta.length(), (start + finish) / 2.0, material, 10)
	instance.quaternion = Quaternion(Vector3.UP, delta.normalized())


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance
