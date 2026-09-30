extends SceneTree
## Screenshot the v0.25 island looks (sea, shore foam, day/night, glass, foliage) at pinned
## phases (needs a real renderer):
## tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --script res://dev/capture_looks.gd -- --release-ui-test

var game

func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	_run.call_deferred()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/looks"))
	root.get_texture().get_image().save_png("res://artifacts/looks/%s.png" % label)

func _run() -> void:
	game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.8).timeout
	for entry in [["1-day", 0.35], ["2-dusk", 0.68], ["3-night", 0.82], ["4-dawn", 0.04]]:
		game.world.day_phase_override = entry[1]
		game.world._apply_day()
		await create_timer(0.4).timeout
		await shot(entry[0])
	game.world.day_phase_override = 0.35
	game.world._apply_day()
	game.world.zoom_view(0.55)
	await create_timer(0.4).timeout
	await shot("5-close")
	quit()
