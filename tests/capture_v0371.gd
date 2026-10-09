extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.37.1: refinery ×5/排满/循环, 星锻岛 factory loops and the
## staff tab that used to overflow, the 工艺车间 batch, and 复刻 in the 河湾作品 dialog.
const Mini=preload("res://scripts/river_miniatures.gd")

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v0371"))
	root.get_texture().get_image().save_png("res://artifacts/v0371/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var ind=s.industry
	for i in range(20): await process_frame
	var m: Dictionary=s.planet.v2.nature.minerals
	for id in ["hematite","coal","halite","limestone","malachite"]: m[id]=20
	s.refinery.start_many(s,"hematite_iron",2); s.refinery.set_repeat("hematite_iron")
	game._show_refinery(); for i in range(10): await process_frame
	await shot("refinery")
	game._close_all(); await process_frame
	preload("res://scripts/test_mode.gd").open_starforge(s,900); ind.gain(Industry.step(14)); s.coins=900000; ind.plots=12
	for k in ["metal_works","trade_hub","staff_housing","polymer_works","home_studio","inorganic_works"]: ind.build(s,ind.buildings.size(),k)
	s.index_found[Industry._keys_for("Cu3Sn")[0]]=true; s.element_inventory["Cu"]=60; s.element_inventory["Sn"]=10
	ind.start_many(s,0,"bronze",2); ind.set_repeat(0,"bronze")
	preload("res://scripts/test_mode.gd").finish_service(s)
	for i in range(3): s.campus_hire("engineer")
	preload("res://scripts/test_mode.gd").finish_service(s)
	for row in ind.candidates(s):
		if row.ready: s.campus_promote(int(row.id))
	game._show_starforge(); var panel=game.modal
	panel._tab("factory"); for i in range(20): await process_frame
	await shot("starforge-factory")
	panel._tab("staff"); await process_frame
	await shot("starforge-staff")
	panel._close(); await process_frame
	await shot("back-on-island")
	var sample=s.product_snapshot(s._new_reactor(3,"water",0.0)); s.storage.add_product(sample,5)
	s.planet.command(s,"join"); s.planet.command(s,"qualify",{"batch_id":sample.id})
	s.planet.command(s,"buy_feed",{"input":"feed","count":10})
	s.planet.command(s,"batch",{"recipe":"standard_water_crate","count":5,"production_mode":"partner"})
	game._show_factory("standard_water_crate"); for i in range(10): await process_frame
	await shot("workshop-batch")
	game._close_all(); await process_frame
	var c=s.planet.v2.construction
	c.sources={"1":{"product":{"id":1,"recipe":"field_wall","recipe_version":1,"source_batch":"field:1"},"remaining":6}}
	var b1={"x":19,"y":c.base(Vector3i(19,0,14)),"z":14,"kind":"block","source":"1"}; var b2=b1.duplicate(); b2.y+=1
	c.blocks={c.key(c.cell(b1)):b1,c.key(c.cell(b2)):b2}
	Mini.pack(c,{"type":"block","key":c.key(c.cell(b1))}); s.replicate_miniature("1")
	game._show_miniatures(); for i in range(5): await process_frame
	await shot("miniatures")
	# The replica on a courtyard turntable (used to fail: the pedestal view typed the ledger as a Dictionary).
	game._close_all(); await process_frame
	s.materials=[10000,10000,10000]; s.coins=900000
	s.town_place(3,"turntable",8,8)
	var uid=-1
	for item in s.plots[3].items:
		if str(item.kind)=="turntable": uid=int(item.uid)
	var copy=""
	for k in c.miniatures:
		if c.miniatures[k].get("replica",false): copy=k
	print("EXHIBIT ",s.town_exhibit(3,uid,{"type":"mini","id":copy}))
	game._sync_world(); game._select_plot(3)
	game.world.camera.size=5.0; var p=s.plots[3]; var at=Vector3(p.x*3,0,p.z*3)
	game.world.camera.position=at+Vector3(4,5,6); game.world.camera.look_at(at)
	for i in range(20): await process_frame
	await shot("pedestal")
	print("V0371 CAPTURE done (%s)" % tag); quit(0)
