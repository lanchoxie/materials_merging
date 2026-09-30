extends SceneTree
## Screenshot helper (not a test): the refinery with some mined minerals and a running batch.
const Main=preload("res://scripts/main.gd")
var game
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred()
func capture(file: String) -> void:
	await create_timer(0.8).timeout; game.toast_panel.hide(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+file+".png")
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	s.planet.v2.nature.minerals.merge({"halite":3,"coal":4,"malachite":2,"gibbsite":1,"limestone":2},true)
	s.refinery.start(s,"malachite_smelting"); s.refinery.tick(s,70.0)
	s.refinery.start(s,"halite_electrolysis"); s.refinery.tick(s,8.0)
	game._show_refinery("Cu")
	await capture("refinery-panel")
	game._close_modal(); s.close_science(); quit()
