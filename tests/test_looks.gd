extends SceneTree
## v0.25 "Looks": day/night keyframes, the stylized sea and its baked shore mask, night glow,
## swaying foliage that still batches, and the time-of-day badge.

const World = preload("res://scripts/world_view.gd")
const DayCycle = preload("res://scripts/core/day_cycle.gd")
const StaticGeometry = preload("res://scripts/static_geometry.gd")

var failures: Array = []
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	_run.call_deferred()

func _run() -> void:
	_test_cycle()
	await _test_world()
	await _test_main()
	if failures.is_empty(): print("PASS: %d looks checks" % checks)
	else: print("FAILED: %d of %d looks checks" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _same_look(a: Dictionary, b: Dictionary) -> bool:
	for key in a:
		if a[key] is Color and Vector4(a[key].r - b[key].r, a[key].g - b[key].g, a[key].b - b[key].b, 0).length() > 0.01: return false
		if a[key] is float and absf(a[key] - b[key]) > 0.1: return false
	return true

func _test_cycle() -> void:
	var last := -1.0
	for key in DayCycle.KEYS:
		check(float(key[0]) > last and key.size() == 10, "keyframes ascend and are complete: %s" % str(key[0]))
		last = float(key[0])
	check(is_equal_approx(float(DayCycle.KEYS[0][0]), 0.0) and is_equal_approx(last, 1.0), "keyframes cover the whole cycle")
	check(_same_look(DayCycle.sample(0.0), DayCycle.sample(0.9999)), "the cycle wraps without a jump")
	check(float(DayCycle.sample(0.35).night) == 0.0 and float(DayCycle.sample(0.82).night) == 1.0, "day is day, night is night")
	check(float(DayCycle.sample(0.35).sun_energy) > float(DayCycle.sample(0.82).sun_energy), "the moon is dimmer than the sun")
	check(is_equal_approx(DayCycle.sun_yaw(0.0), DayCycle.sun_yaw(1.0)), "the sun's path wraps too")
	var labels := []
	for t in [0.04, 0.35, 0.68, 0.82, 0.97]: labels.append(DayCycle.label(t))
	check(labels == ["清晨", "白天", "黄昏", "夜晚", "黎明"], "time-of-day labels: %s" % str(labels))
	check(DayCycle.phase_at(0.0) == 0.0 and is_equal_approx(DayCycle.phase_at(DayCycle.LENGTH_SECONDS * 2.5), 0.5), "phase follows the wall clock")
	var day_share := 0
	for i in range(100): if DayCycle.sample(i / 100.0).night < 0.5: day_share += 1
	check(day_share >= 60, "mostly daylight: %d%%" % day_share)

func _test_world() -> void:
	var plots: Array = []
	var kinds := ["garden", "house", "garden", "road", "reactor", "road", "empty", "fence", "garden"]
	for i in range(9):
		plots.append({"x": i % 3 - 1, "z": int(i / 3) - 1, "unlocked": true, "kind": kinds[i], "rid": 0 if i == 4 else -1})
	var reactor := {"plot": 4, "template": "custom_unknown", "level": 1, "atoms": ["O", "H", "H"], "positions": [[0, 0, 0], [0.8, 0.6, 0], [-0.8, 0.6, 0]], "bonds": [[0, 1, 1], [0, 2, 1]], "build_left": 0}
	var world = World.new()
	world.day_phase_override = 0.35
	root.add_child(world)
	world.setup({"plots": plots, "reactors": [reactor], "templates": {}, "elements": {}, "engineers": 2})
	await process_frame
	check(world.sea != null and world.sea.material_override is ShaderMaterial, "the island floats on a shader sea")
	check(world.find_child("*Floor*", true, false) == null, "the old studio floor is gone")
	var sea: ShaderMaterial = world.sea.material_override
	var mask = sea.get_shader_parameter("shore_mask")
	check(mask is ImageTexture, "a shore mask is baked")
	if mask is ImageTexture:
		var image: Image = mask.get_image()
		var rect: Vector4 = sea.get_shader_parameter("mask_rect")
		var pixel := func(x: float, z: float) -> float:
			var px := Vector2((x - rect.x) / rect.z * image.get_width(), (z - rect.y) / rect.w * image.get_height())
			return image.get_pixelv(Vector2i(px).clamp(Vector2i.ZERO, Vector2i(image.get_width() - 1, image.get_height() - 1))).r
		var edge: float = World.PITCH * 1.5 + 0.4
		check(pixel.call(edge, 0.0) > 0.8, "the mask is bright right at the shore")
		check(pixel.call(edge, 0.0) > pixel.call(edge + World.PITCH, 0.0), "the mask fades away from the shore")
		check(pixel.call(rect.x + 0.5, rect.y + 0.5) < 0.05, "open sea is outside the mask")
		var key: String = world._shore_key
		world.rebuild()
		check(world._shore_key == key and sea.get_shader_parameter("shore_mask") == mask, "an unchanged island does not re-bake the mask")
		var wider := plots.duplicate(true)
		wider.append({"x": 2, "z": 0, "unlocked": true, "kind": "empty", "rid": -1})
		world.sync(wider, [reactor], {}, {}, 2)
		await process_frame
		check(world._shore_key != key and sea.get_shader_parameter("shore_mask") != mask, "expanding the island re-bakes the shore")
	# Day and night.
	var day_energy: float = world._sun.light_energy
	var day_sky: Color = world._environment.background_color
	check(world.night == 0.0 and world.day_phase == 0.35, "pinned daytime")
	world.day_phase_override = 0.82
	world._apply_day()
	check(world.night == 1.0 and world._sun.light_energy < day_energy and world._environment.background_color != day_sky, "night dims the sun and darkens the sky")
	check(float(sea.get_shader_parameter("night")) == 1.0, "the sea knows it is night")
	check(not world._glow_materials.is_empty(), "the island has glowing materials")
	var glowing := true
	for entry in world._glow_materials:
		glowing = glowing and entry[0].emission_energy_multiplier > float(entry[1]) * 2.0
	check(glowing, "lamps and reactors glow brighter at night")
	check(world._glass_material != null and float(world._glass_material.get_shader_parameter("glow")) == 1.0, "reactor glass rims light up at night")
	world.day_phase_override = 0.35
	world._apply_day()
	check(is_equal_approx(world._sun.light_energy, day_energy), "morning comes back")
	# Foliage sways but still batches.
	check(not world._leaf_materials.is_empty(), "trees and bushes use the foliage shader")
	var grove := Node3D.new()
	for i in range(3):
		var leaf := MeshInstance3D.new()
		leaf.mesh = SphereMesh.new()
		leaf.material_override = world._leaf(Color("70aa8b"))
		leaf.position.x = i
		grove.add_child(leaf)
	StaticGeometry.bake(grove)
	check(grove.get_child_count() == 1 and grove.get_child(0).name == "StaticBatch" and grove.get_child(0).mesh.surface_get_material(0) == world._leaf(Color("70aa8b")), "swaying leaves are still merged into static batches")
	grove.free()
	world.queue_free()
	await process_frame

func _test_main() -> void:
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	await process_frame
	await process_frame
	game.world.day_phase_override = 0.82
	game.world._apply_day()
	game._update_labels()
	check(game.live_badge.text.ends_with("夜晚"), "the LIVE badge tells the time of day: " + game.live_badge.text)
	game._open_editor()
	await process_frame
	var toggle: Button = game.find_child("CaveatToggle", true, false)
	check(toggle != null, "the editor has an ⓘ rules toggle")
	if toggle != null:
		var caveat: Control = toggle.get_parent().get_child(toggle.get_index() + 1)
		check(not caveat.visible, "the rules caveat starts folded")
		toggle.pressed.emit()
		check(caveat.visible and caveat.text.contains("几何评分不等同真实能量"), "ⓘ unfolds the caveat")
	game.queue_free()
	await process_frame
