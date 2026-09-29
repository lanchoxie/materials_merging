extends SceneTree
## Screenshot the v0.22 feedback mid-animation (needs a real renderer, not --headless):
## tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --script res://dev/capture_juice.gd -- --release-ui-test

var game

func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	_run.call_deferred()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/juice"))
	root.get_texture().get_image().save_png("res://artifacts/juice/%s.png" % label)

func _run() -> void:
	game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(1.0).timeout
	# Combo taps from the toolbar button position.
	game.pointer_position = Vector2(146, 836)
	for i in range(10):
		game._action(game.state.click_energy())
		await create_timer(0.07).timeout
	await shot("1-combo")
	# Harvest with coins flying to the counter.
	var r: Dictionary = game.state.reactors[0]
	r.pending = 5; r.stock = 5; r.stored_coins = 180.0
	game.pointer_position = Vector2(640, 470)
	game._tap_harvest(4)
	await create_timer(0.3).timeout
	await shot("2-harvest")
	await create_timer(1.5).timeout
	# Perfect fit in the atom editor.
	game._open_editor()
	await create_timer(0.5).timeout
	var editor = game.modal
	var reference: Dictionary = game.state.templates[game.state.reference_id(r)]
	editor.dragging = true
	editor.points = reference.positions.duplicate(true)
	editor._position_changed()
	await create_timer(0.35).timeout
	await shot("3-perfect")
	quit()
