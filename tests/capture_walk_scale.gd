extends SceneTree
## Screenshot helper (not a test): the island first-person view among houses and villagers.
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
	var s=game.state; s.coins=60000; s.materials=[10000,10000,10000]
	for i in [0,1,2,6,7,8]:
		if not s.plots[i].unlocked: s.buy_plot(i)
	s.town_place(3,"engineer_house",0,0); s.town_place(3,"canteen",6,0); s.town_place(3,"doctor_dorm",0,6)
	for x in range(6,11): s.town_place(3,"picket_fence",x,10)
	s.town_place(3,"street_lamp",6,6); s.town_place(3,"young_tree",8,7)
	s.campus_build(5,"institute")
	s.campus.elapsed=90; s.campus.day_time=90
	s.campus_hire("engineer")
	game._sync_world(); game._show_island_walk(); var panel=game.modal
	var p=s.plots[3]
	panel.walker.position=Vector2(p.x*3+0.6,p.z*3+0.9); panel.walker.reset_height()
	var d=Vector3(p.x*3-0.6,0.35,p.z*3-0.6)-panel.walker.eye(); panel.walker.yaw=atan2(-d.x,-d.z); panel.walker.pitch=atan2(d.y,Vector2(d.x,d.z).length()); panel._camera()
	await capture("walk-scale")
	game._close_modal(); s.close_science(); quit()
