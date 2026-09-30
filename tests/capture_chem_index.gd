extends SceneTree
## Screenshot helper (not a test): chemistry index browser, entries, credits, sidebar and tour.
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
	for key in ["cid:962","cid:280","cid:313","cid:1176","cid:702"]: s.index_found[key]=true
	var licl: Dictionary=s.structure_data({"template":"sodium_chloride","atoms":["Li","Cl"]}).index
	s.index_found[str(licl.key)]=true
	game._show_index()
	await capture("index-molecules")
	game.index_kind="crystal"; game.index_filter=["Cs","Pb"]; game._refresh_index()
	await capture("index-crystals-cs-pb")
	var pv: Dictionary=s.templates.perovskite
	game._show_index_entry(str(s.structure_data({"template":"perovskite","atoms":pv.atoms}).index.key))
	await capture("index-entry-perovskite")
	game._show_index_entry(str(licl.key))
	await capture("index-entry-licl")
	game._show_index_entry("cid:241")
	await capture("index-entry-benzene")
	game._show_index_credits()
	await capture("index-credits")
	game._close_all()
	var r=s.reactors[0]; r.build_left=0.0; r.template="sodium_chloride"; r.atoms=["Li","Cl"]; r.positions=[[-1.3,0,0],[1.3,0,0]]
	game._select_plot(int(r.plot))
	await capture("index-sidebar")
	s.coach_seen.erase("index"); game.coach_autostart=true; game.index_kind="molecule"; game.index_filter=[]
	game._show_index(); await create_timer(0.5).timeout
	game.coach.next_button.pressed.emit()
	await capture("index-coach-2")
	game._close_all(); s.close_science(); quit()
