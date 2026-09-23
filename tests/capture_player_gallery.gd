extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred()
func capture(file: String) -> void:
	await create_timer(0.6).timeout; game.toast_panel.hide(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+file+".png")
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; s.coins=3200; s.materials=[80,80,80]
	s.place_reactor(5,"hydrogen"); s.reactors.back().build_left=0
	s.place_decoration(3,"garden"); s.place_decoration(7,"house")
	game._sync_world(); game._select_plot(4)
	await capture("gallery-island")
	game.world.camera.size=8.8; game.world.camera.position=Vector3(6,7,9); game.world.camera.look_at(Vector3(0,0.8,0))
	await capture("gallery-reactors")
	game._open_editor(); await capture("gallery-atoms")
	game._close_modal(); game._show_island_walk(); await capture("gallery-island-walk")
	game._show_planet_v2(); game.modal._enter(); game.modal._travel("woods"); await create_timer(3).timeout; await capture("gallery-wilderness")
	game._close_modal(); _cabin(s)
	game._sync_world(); game._show_island_walk(); var panel=game.modal
	panel.walker.position=Vector2(-1.7,-2.0); panel.walker.reset_height()
	var d=Vector3(-2.05,0.62,-0.98)-panel.walker.eye(); panel.walker.yaw=atan2(-d.x,-d.z); panel.walker.pitch=atan2(d.y,Vector2(d.x,d.z).length()); panel._camera()
	await capture("gallery-miniature")
	game._close_modal(); s.close_science(); quit()

func _place(s,x: int,z: int,y: int,kind: String,recipe: String) -> void:
	var v=s.planet.v2; v.actor={"eye":Vector3(x,y+4,z),"feet":Vector3(x,y+2.38,z),"direction":Vector3.DOWN}
	s.planet.command(s,"v2_build",{"kind":kind,"recipe":recipe})

func _cabin(s) -> void:
	var v=s.planet.v2; v.active=true
	for i in range(3): s.planet.products.append({"id":900+i,"recipe":["field_floor","field_wall","field_roof"][i],"recipe_version":1,"source_batch":"gallery"})
	for x in range(6,9):
		for z in range(12,14): _place(s,x,z,0,"floor","field_floor")
	for x in [6,8]:
		for z in [12,13]:
			for y in [1,2]: _place(s,x,z,y,"block","field_wall")
	for z in [12,13]:
		for x in [6,8]: _place(s,x,z,3,"roof","field_roof")
	for z in [12,13]:
		v.actor={"eye":Vector3(7,3.5,z),"feet":Vector3(7,1.88,z+2),"direction":Vector3.LEFT}; s.planet.command(s,"v2_build",{"kind":"roof","recipe":"field_roof"})
	preload("res://scripts/river_miniatures.gd").pack(v.construction,{"type":"block","key":v.construction.blocks.keys()[0]})
	s.planet.command(s,"v2_mini_exhibit",{"id":"1","plot":3}); v.active=false

