extends SceneTree

const World = preload("res://scripts/world_view.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func advance(world: Node3D, seconds: float) -> void:
	for i in range(ceili(seconds * 30.0)):
		world._process(1.0 / 30.0)

func _run() -> void:
	var plots: Array = []
	var kinds := ["fence", "sculpture", "house", "garden", "reactor", "road", "road", "empty", "fence"]
	for i in range(9):
		plots.append({"x": i % 3 - 1, "z": int(i / 3) - 1, "unlocked": true, "kind": kinds[i], "rid": 0 if i == 4 else -1})
	var custom := {"plot": 4, "template": "custom_unknown", "level": 1, "atoms": ["S", "Cl", "H"], "positions": [[-1, 0, 0], [1, 0, 0], [0, 1.5, 0]], "bonds": [[0, 1, 1]], "build_left": 0}
	var model := {"plots": plots, "reactors": [custom], "templates": {}, "elements": {}, "engineers": 2}
	var world = World.new()
	root.add_child(world)
	world.setup(model)
	world.set_process(false)
	await process_frame
	check(world._content.get_node_or_null("Plot_0/GardenFence") != null, "fence plot has dedicated geometry")
	check(world._content.get_node_or_null("Plot_1/AtomicSculpture/CrystalAtoms") != null, "sculpture contains a crystal atom display")
	check(world._content.get_node_or_null("Plot_5/StoneRoad") != null, "road plot has stone path geometry")
	var molecule: Node3D = world._content.get_node("Plot_4/Molecule")
	check(molecule.get_node_or_null("Atom_0_S") != null and molecule.get_node_or_null("Atom_1_Cl") != null, "unknown custom species render from actual atoms")
	check(molecule.get_child_count() == 4, "unknown custom topology renders only supplied bond")
	custom.bonds = []
	world.sync(plots, [custom], {}, {}, 2)
	check(world._content.get_node("Plot_4/Molecule").get_child_count() == 3, "explicit empty custom bonds do not invent connections")
	for kind in ["road", "fence", "sculpture"]:
		var sample := Node3D.new()
		world.add_child(sample)
		world._build_simple_plot(sample, kind, false)
		check(sample.get_child_count() > 0, "distant decoration keeps silhouette: " + kind)
		sample.queue_free()
	world.set_visitor(false, "晶体收藏家", 1)
	check(world._visitor_phase == "absent" and not world._visitor_node.visible, "cooldown starts with no visible buyer")
	world.set_visitor(true, "晶体收藏家", 1)
	var visitor_id: int = world._visitor_node.get_instance_id()
	check(world._visitor_phase == "arriving" and world._visitor_node.visible, "availability starts entrance animation")
	advance(world, 1.0)
	var position: Vector3 = world._visitor_node.position
	var elapsed: float = world._visitor_phase_time
	for i in range(10): world.set_visitor(true, "晶体收藏家", 1)
	check(world._visitor_node.position == position and world._visitor_phase_time == elapsed, "repeated polls never restart entrance")
	check(world._visitor_node.get_instance_id() == visitor_id, "visitor mesh created once")
	world.rebuild()
	check(world._visitor_node.get_instance_id() == visitor_id and world._visitor_node.position == position, "land rebuild preserves visitor node and world position")
	check(world._visitor_phase_time == elapsed and world._visitor_phase == "arriving", "land rebuild preserves animation progress")
	advance(world, 2.6)
	check(world._visitor_phase == "greeting", "buyer reaches welcome point and greets")
	advance(world, 0.4)
	check(world._visitor_arms[1].rotation.z > 1.5, "greeting actually raises and waves an arm")
	check(world._visitor_badge.visible, "arrival exposes a floating trade coin")
	check(world._visitor_node.get_node_or_null("Body/HatBrim") != null, "buyer has distinct brimmed hat")
	check(world._visitor_arms[0].get_node_or_null("Briefcase") != null, "buyer carries a real 3D briefcase")
	await process_frame
	if DisplayServer.get_name() != "headless":
		world.camera.size = 12.5
		world.camera.position = Vector3(11.0, 12.0, 15.0)
		world.camera.look_at(Vector3(0.0, 0.5, 0.5))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/world-life-070.png")
		world.camera.size = 5.5
		world.camera.position = Vector3(5.0, 3.0, 8.0)
		world.camera.look_at(Vector3(1.0, 0.8, 3.3))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/buyer-wave-070.png")
	advance(world, 3.0)
	check(world._visitor_phase == "browsing", "buyer stays present after greeting")
	world.set_visitor(true, "材料收藏家", 1)
	check(world._visitor_phase == "browsing" and world._visitor_node.get_meta("buyer_name") == "材料收藏家", "name update does not cause reentry")
	world.set_visitor(false, "材料收藏家", 1)
	check(world._visitor_phase == "leaving" and world._visitor_node.visible, "visit expiration starts visible departure")
	advance(world, 1.0)
	position = world._visitor_node.position
	world.set_visitor(false, "材料收藏家", 1)
	check(world._visitor_node.position == position, "cooldown polling never teleports exiting buyer")
	advance(world, 2.0)
	check(world._visitor_phase == "absent" and not world._visitor_node.visible, "departed buyer remains hidden throughout cooldown")
	world.set_visitor(true, "表面研究员", 2)
	check(world._visitor_active_visit == 2 and world._visitor_phase == "arriving", "next visit starts exactly one new entrance")
	advance(world, 4.0)
	world.set_visitor(true, "分子收藏家", 3)
	check(world._visitor_phase == "leaving", "changed visit identity retires previous buyer")
	advance(world, 3.0)
	check(world._visitor_phase == "arriving" and world._visitor_active_visit == 3, "queued new visit arrives after previous departure")
	check(world._visitor_node.get_instance_id() == visitor_id, "all visits reuse a single character")
	world.set_visitor(false, "分子收藏家", 3)
	advance(world, 3.0)
	check(world._visitor_phase == "absent", "availability cancellation during entry departs cleanly")
	world.queue_free()
	await process_frame
	print("WORLD LIFE: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
