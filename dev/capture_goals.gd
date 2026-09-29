extends SceneTree
## Screenshot the v0.23 goal track, goal list and welcome-back summary (needs a real renderer):
## tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --script res://dev/capture_goals.gd -- --release-ui-test

var game

func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	_run.call_deferred()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/goals"))
	root.get_texture().get_image().save_png("res://artifacts/goals/%s.png" % label)

func _run() -> void:
	game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.8).timeout
	game._update_goal()
	await shot("1-in-progress")
	game.state.apply_edit(0, game.state.templates.water.positions.duplicate(true))
	game._update_goal()
	await create_timer(0.5).timeout
	await shot("2-ready")
	game._claim_goal()
	await create_timer(0.35).timeout
	await shot("3-claimed")
	await create_timer(1.5).timeout
	game._show_goals()
	await create_timer(0.3).timeout
	await shot("4-list")
	game._close_modal()
	game._show_welcome({"away": 5400, "simulated": 2700.0, "capped": false, "units": 12, "coins": 164.0})
	await create_timer(0.3).timeout
	await shot("5-welcome")
	quit()
