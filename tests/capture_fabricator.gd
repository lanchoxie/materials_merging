extends SceneTree
## Screenshot helper (not a test): the fabricator with AlN / Al2O3 / PbS batches, a crafted pick and panel, and the sources overlay.
const Main=preload("res://scripts/main.gd")
var game
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred()
func capture(file: String) -> void:
	await create_timer(0.8).timeout; game.toast_panel.hide(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+file+".png")
func harvest(s, atoms: Array, units: int) -> String:
	var r: Dictionary=s.reactors[0]
	r.build_left=0.0; r.template="sodium_chloride"; r.atoms=atoms; r.positions=[[-1.3,0,0],[1.3,0,0]]; r.pending=units; r.stored_coins=0.0
	s.harvest(0)
	return s.signature(r)
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	s.coach_seen["fabricator"]=true; s.coins=800.0
	var aln=harvest(s,["Al","N"],7); var pbs=harvest(s,["Pb","S"],6); harvest(s,["Li","F"],4); harvest(s,["Cu","O"],5)
	s.fabricator.craft(s,aln,"pick"); s.fabricator.craft(s,pbs,"panel")
	s.index_notice.clear()
	game._show_fabricator()
	await capture("fabricator-panel")
	game.modal._show_sources()
	await capture("fabricator-sources")
	game.modal.handle_back(); game.modal.handle_back(); s.close_science(); quit()
