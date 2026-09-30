extends SceneTree
## Screenshot helper (not a test): first-time tour overlays on the island and in the refinery.
const Main=preload("res://scripts/main.gd")
var game
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred()
func capture(file: String) -> void:
	await create_timer(0.8).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+file+".png")
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.coach_autostart=true; game._coach("island")
	await create_timer(0.5).timeout
	await capture("coach-island-1")
	for i in range(4): game.coach.next_button.pressed.emit()
	await capture("coach-island-5")
	game.coach.next_button.pressed.emit()
	game.state.planet.v2.nature.minerals.merge({"halite":2,"coal":3},true)
	game._show_refinery(); await create_timer(0.5).timeout
	for i in range(3): game.coach.next_button.pressed.emit()
	await capture("coach-refinery-4")
	quit()
