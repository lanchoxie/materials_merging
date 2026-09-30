extends SceneTree
## Screenshot the v0.24 codex grid, a codex entry, the first-synthesis card flip and the editor's
## codex stars (needs a real renderer):
## tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --script res://dev/capture_codex.gd -- --release-ui-test

const Feedback = preload("res://scripts/island_feedback.gd")

var game

func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	_run.call_deferred()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/codex"))
	root.get_texture().get_image().save_png("res://artifacts/codex/%s.png" % label)

func _run() -> void:
	game = load("res://scripts/main.gd").new()
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await create_timer(0.8).timeout
	var s = game.state
	for id in ["hydrogen", "methane", "carbon_dioxide", "ethanol"]: s.discovered.append(id)
	s.best_fit = {"water": 0.985, "hydrogen": 0.94, "methane": 0.83, "carbon_dioxide": 0.6, "ethanol": 0.95}
	s.star_rewards = 2
	game._show_collection()
	await create_timer(0.3).timeout
	await shot("1-grid")
	game._show_codex_entry("methane")
	await create_timer(0.3).timeout
	await shot("2-entry")
	game._close_modal()
	s.discovered.append("glycerol")
	game.get_node("/root/Fx").card_reveal(Feedback.reveal_card(s, "glycerol"))
	await create_timer(0.35).timeout
	await shot("3-reveal-back")
	await create_timer(0.8).timeout
	await shot("4-reveal-front")
	await create_timer(2.5).timeout
	game.selected_reactor = 0
	game._open_editor()
	await create_timer(0.6).timeout
	await shot("5-editor")
	quit()
