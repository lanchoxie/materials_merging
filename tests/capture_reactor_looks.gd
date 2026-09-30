extends SceneTree
## Screenshot helper (not a test): the four reactor tiers with liquid, gas, solid contents and install orbs.
const Main=preload("res://scripts/main.gd")
var game
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred()
func capture(file: String) -> void:
	await create_timer(1.2).timeout; game.toast_panel.hide(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+file+".png")
func setup(s, level: int, template: String) -> void:
	var r=s.reactors[0]; r.level=level; r.build_left=0.0; r.erase("installation")
	r.template=template; r.sandbox=false; r.atoms=s.templates[template].atoms.duplicate(); r.positions=s.initial_positions(template,r.id); s._reset_product(r); s._structure_cache.clear()
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; s.coins=100000
	var cases=[[1,"water","reactor-tier1-liquid"],[6,"methane","reactor-tier2-gas"],[11,"sodium_chloride","reactor-tier3-solid"],[16,"ethanol","reactor-tier4-install"]]
	for c in cases:
		setup(s,c[0],c[1])
		if c[2].ends_with("install"):
			s.reactors[0]["installation"]={"payload":{"kind":"template","template":"glycerol"},"remaining":9.0,"fee":0,"elements":{"C":3,"H":8,"O":3}}
		game._select_plot(int(s.reactors[0].plot)) if game.has_method("_select_plot") else null; game._sync_world(); game.world.rebuild(); game.world.focus_plot(int(s.reactors[0].plot)); game.world.camera.size=5.0
		game._rebuild_sidebar()
		await capture(c[2])
	quit()
