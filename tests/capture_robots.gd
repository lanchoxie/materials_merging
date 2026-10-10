extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.46: a farm robot working a little field of planters.

func shot(file: String) -> void:
	await create_timer(0.8).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v046"))
	root.get_texture().get_image().save_png("res://artifacts/v046/%s-%s.png" % [file,tag])

var serial=900
func put(v,kind: String,recipe: String,x: int,z: int) -> String:
	var c=v.construction; var id=str(serial); serial+=1
	v.field.crafts[id]={"recipe":recipe,"complete":true,"inputs":v.field.rules.recipes[recipe].natural_inputs.duplicate()}
	if v.field.rules.recipes[recipe].has("industry_inputs"): v.field.crafts[id]["industry"]=v.field.rules.recipes[recipe].industry_inputs.duplicate()
	c.sources[id]={"product":{"id":int(id),"recipe":recipe,"recipe_version":1,"source_batch":"river:"+id},"remaining":int(c.rules.recipes[recipe].units)-1}
	var y=c.base(Vector3i(x,0,z)); var k=c.key(Vector3i(x,y,z))
	c.blocks[k]={"x":x,"y":y,"z":z,"kind":kind,"source":id}; c.revision+=1
	return k

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2
	for i in range(20): await process_frame
	var robot=put(v,"farm_robot","field_farm_robot",20,21)
	var keys=[]
	for x in [18,19,21,22]:
		for z in [19,23]: keys.append(put(v,"planter","field_planter",x,z))
	for i in range(keys.size()):
		v.field.gardens[keys[i]]={"growth":[1.0,0.8,0.5,0.2,1.0,0.6,0.35,0.9][i],"moisture":0.6 if i%3!=0 else 0.15,"waterings":1}
	v.field.hopper(robot).grain=7; v.field.hopper(robot).seeds=4
	game._show_planet_v2(); await process_frame; var panel=game.modal
	panel._enter(); for i in range(20): await process_frame
	v.world.paused=false
	var w=panel.view.walker; w.position=Vector2(20.5,27.5); w.reset_height(); w.yaw=0.05; w.pitch=-0.36
	for i in range(12): v.world.elapsed=int(v.world.elapsed)+1; v._step()
	panel._sync(); for i in range(90): await process_frame
	await shot("robot-field")
	w.position=Vector2(20.2,23.4); w.reset_height(); w.yaw=0.0; w.pitch=-0.55; panel._sync(); for i in range(20): await process_frame
	panel._aim(); for i in range(5): await process_frame
	await shot("robot-prompt")
	print("V046 CAPTURE done (%s)" % tag); quit(0)
