extends SceneTree
## v0.44 百工建材 (user request): doors, windows, boards, bricks and roofs in wood, stone, plastic and
## metal. Five shapes × four materials: slabs are half a cell (stairs), doors are two cells tall and
## open with E (walk through when open), windows are glass, slopes are walkable roofs; plastic and
## metal (and window glass) come from 星锻岛's store, wood and stone from the planet.
const State=preload("res://scripts/lab_state.gd")
const Components=preload("res://scripts/river_component_geometry.gd")
const Walker=preload("res://scripts/river_walker.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func craft(s,recipe: String) -> void:
	s.planet.command(s,"pack",{"recipe":recipe,"production_mode":"island"}); s.planet.tick(60,1)

## Stand `back` metres from the cell along `side` and aim at its ground (or the face of what's there).
func aim(v,x: int,z: int,side: Vector2,back: float=2.2,height: float=0.05) -> void:
	var g=v.construction.terrain.ground(Vector2(x,z))
	var eye=Vector3(x+side.x*back,g+1.62,z+side.y*back); var at=Vector3(x,g+height,z)
	v.actor={"eye":eye,"feet":eye-Vector3(0,1.62,0),"direction":(at-eye).normalized()}

func build(s,kind: String,x: int,z: int,side: Vector2=Vector2(0,1)) -> String:
	aim(s.planet.v2,x,z,side)
	return s.planet.command(s,"v2_build",{"kind":kind,"recipe":"field_"+kind})

func _initialize() -> void:
	var s=State.new(); s.coins=100000; var p=s.planet; var v=p.v2; var f=v.field; var c=v.construction; var ind=s.industry
	v.active=true; v.world.paused=true
	# --- The catalogue: 5 shapes × 4 materials, each a construction kind and a workshop recipe.
	var kinds=0; var ok=true
	for shape in c.rules.shapes:
		for m in c.rules.materials:
			var kind="%s_%s" % [shape,m]; var rid="field_"+kind
			kinds+=1
			if not c.rules.kinds.has(kind) or c.rules.recipes.get(rid,{}).get("kind")!=kind or not f.rules.recipes.has(rid): ok=false
			elif int(c.rules.recipes[rid].units)!=int(c.rules.shapes[shape].units): ok=false
	check(ok and kinds==20,"20 building parts: every shape in wood, stone, plastic and metal")
	check(f.rules.recipes.field_brick_wood.natural_inputs.has("timber") and f.rules.recipes.field_brick_stone.natural_inputs.has("stone"),"wood and stone come from the planet")
	check(f.rules.recipes.field_brick_plastic.industry_inputs.has("pe") and f.rules.recipes.field_brick_metal.industry_inputs.has("steel_ingot"),"plastic needs PE pellets and metal needs steel ingots from 星锻岛")
	check(f.rules.recipes.field_window_wood.industry_inputs.get("glass",0)==1 and f.rules.recipes.field_window_metal.industry_inputs.get("glass",0)==1,"every window needs a glass pane")
	check(p.recipe("field_door_metal").name.begins_with("建材"),"the workshop lists them as 建材")
	# --- Crafting with 星锻岛 items: checked, taken, refunded, saved.
	p.command(s,"join"); s.campus_build(3,"workshop"); s.campus_road(3); s.campus_assign_post(s.campus.people[0].id,"workshop")
	f.stock.timber=60; f.stock.stone=40; f.stock.fiber=10
	check(f.crafting_error("field_slab_plastic",ind).contains("星锻岛"),"no PE on 星锻岛: plastic parts can't be made")
	ind.items["pe"]=3; ind._reconcile("pe"); ind.items["steel_ingot"]=4; ind._reconcile("steel_ingot"); ind.items["glass"]=2; ind._reconcile("glass")
	check(f.crafting_error("field_slab_plastic",ind).is_empty(),"with PE in store they can")
	p.command(s,"pack",{"recipe":"field_slab_plastic"})
	check(int(ind.items.pe)==2 and f.crafts[str(int(p.job.id))].get("industry",{}).get("pe",0)==1,"packing takes one PE and records it")
	var saved=JSON.parse_string(JSON.stringify(p.serialize()))
	var restored=State.new(); check(restored.planet.restore(saved,restored),"an in-flight plastic craft saves")
	var tampered=saved.duplicate(true); tampered.v2.field.crafts[str(int(p.job.id))].erase("industry")
	check(not State.new().planet.restore(tampered,State.new()),"a craft record missing its 星锻岛 inputs is rejected")
	p.command(s,"cancel_pack")
	check(int(ind.items.pe)==3 and p.job.is_empty(),"cancelling refunds the PE")
	for rid in ["field_slab_plastic","field_door_wood","field_slab_wood","field_slope_metal","field_window_stone","field_brick_stone"]: craft(s,rid)
	check(p.products.size()==6,"six building packs crafted (%d)" % p.products.size())
	check(int(ind.items.pe)==2 and int(ind.items.steel_ingot)==3 and int(ind.items.glass)==1,"store debited: 1 PE, 1 steel, 1 glass")
	# --- Door: two cells tall, faces the builder, E opens it, walk through when open.
	var dx=22; var dz=18; var base=c.base(Vector3i(dx,0,dz))
	var said=build(s,"door_wood",dx,dz)
	var door: Dictionary=c.blocks.get(c.key(Vector3i(dx,base,dz)),{})
	check(not door.is_empty() and int(door.rot)==0 and door.open==false,"a wooden door stands where aimed, facing the builder, shut (%s)" % said)
	check(c.occupant(Vector3i(dx,base+1,dz))==door,"the door fills the cell above too")
	check(c.overlaps(Vector2(dx,dz),float(base),1.75),"a shut door blocks the way")
	aim(v,dx,dz,Vector2(0,1),2.0,1.0)
	check(v.Target.prompt(v,v.Target.query(v)).contains("开门"),"aiming at it offers 开门")
	check(p.command(s,"v2_door",{"key":c.key(Vector3i(dx,base,dz))}).contains("开了") and door.open,"E opens it")
	check(not c.overlaps(Vector2(dx,dz),float(base),1.75),"an open door lets you through")
	check(c.toggle_door(c.key(Vector3i(dx,base,dz)),{"feet":Vector3(dx,base,dz)}).contains("门洞"),"it won't shut on you")
	check(p.command(s,"v2_door",{"key":c.key(Vector3i(dx,base,dz))}).contains("关上") and not door.open,"and shuts again")
	check(c.place_error(Vector3i(dx,base+1,dz),{"feet":Vector3(0,-50,0),"eye":Vector3(dx,base+1,dz+2)},true,"brick_stone").contains("已经有"),"nothing can go in the door's upper cell")
	var walker=Walker.new(c.terrain); walker.construction=c
	walker.position=Vector2(dx,dz+1.2); walker.reset_height(); walker.yaw=0; walker.movement=Vector2(0,-1)
	for i in range(40): walker.step(0.05)
	check(walker.position.y>dz+0.4,"walking into a shut door stops you (%.2f)" % walker.position.y)
	door.open=true; c.revision+=1
	for i in range(40): walker.step(0.05)
	check(walker.position.y<dz-0.5,"through an open door you walk on (%.2f)" % walker.position.y)
	# --- Slab: half a cell, a step you can walk up.
	var sx=26; var sz=18; var sb=c.base(Vector3i(sx,0,sz))
	build(s,"slab_wood",sx,sz)
	check(c.blocks.has(c.key(Vector3i(sx,sb,sz))) and absf(c.floor_at(Vector2(sx,sz),sb+1.6)-(sb+0.5))<0.001,"a slab's top is half a cell up")
	check(not c.overlaps(Vector2(sx,sz),sb+0.5,1.75) and c.overlaps(Vector2(sx,sz),sb+0.2,1.75),"you stand on a slab, not in it")
	walker.position=Vector2(sx,sz+1.3); walker.reset_height(); walker.movement=Vector2(0,-1); walker.yaw=0
	for i in range(30): walker.step(0.05)
	check(absf(walker.feet_y-(sb+0.5))<0.05 and walker.position.y<sz+0.3,"walking onto a slab steps up (feet %.2f)" % walker.feet_y)
	# --- Slope: rises away from the builder; a ramp underfoot; a roof overhead.
	var rx=30; var rz=18; var rb=c.base(Vector3i(rx,0,rz))
	build(s,"slope_metal",rx,rz,Vector2(-1,0))
	var slope: Dictionary=c.blocks.get(c.key(Vector3i(rx,rb,rz)),{})
	check(not slope.is_empty() and int(slope.rot)==1,"a slope built facing +x rises toward +x (rot %s)" % str(slope.get("rot")))
	var low=c.floor_at(Vector2(rx-0.4,rz),rb+1.9); var high=c.floor_at(Vector2(rx+0.4,rz),rb+1.9)
	var ground=c.terrain.ground(Vector2(rx,rz))
	check(high>rb+0.85 and high-maxf(low,ground)>0.3,"the ramp climbs to the top of its cell (%.2f → %.2f, ground %.2f)" % [low-rb,high-rb,ground-rb])
	check(c.rules.kinds.slope_metal.get("roof",false) and c.rules.kinds.slab_plastic.get("roof",false),"slopes and slabs count as roofing")
	# --- Window: solid, glass, counts as wall; brick counts as wall too.
	var wx=34; var wz=18; var wb=c.base(Vector3i(wx,0,wz))
	build(s,"window_stone",wx,wz); build(s,"brick_stone",wx+1,wz)
	check(c.blocks.has(c.key(Vector3i(wx,wb,wz))) and c.overlaps(Vector2(wx,wz),float(wb),1.75),"a window blocks the way")
	check(c.count_walls()==2 and c.count_kind("block")==0,"bricks and windows count as walls (%d)" % c.count_walls())
	check(v.settlement.metric("blocks",v.world,c)>=0,"the settlement counts walls through count_walls")
	# --- Drawing: every kind draws; window panes get a see-through surface.
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); var glass=SurfaceTool.new(); glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var drawn=true
	for kind in c.rules.kinds:
		if not c.rules.kinds[kind].has("shape"): continue
		for r in range(4):
			Components.piece(st,glass,{"x":0,"y":0,"z":0,"kind":kind,"rot":r,"open":r%2==1},c.rules)
	check(st.commit().get_surface_count()==1 and glass.commit().get_surface_count()==1,"all 20 parts draw in all four rotations, panes on glass")
	var view=preload("res://scripts/river_construction_view.gd").new(); view.material=StandardMaterial3D.new(); root.add_child(view)
	view.sync(c,Vector2(wx,wz))
	var with_glass=false
	for k in view.chunks:
		if view.chunks[k].mesh.get_surface_count()==2: with_glass=true
	check(with_glass,"a chunk with a window gets a glass surface")
	# --- Save checks: rot only on turning shapes, open only on doors, nothing in a door's upper cell.
	var data=JSON.parse_string(JSON.stringify(c.serialize()))
	var copy=preload("res://scripts/river_construction.gd").new()
	check(copy.restore(data) and copy.blocks[c.key(Vector3i(dx,base,dz))].open==true,"doors keep their open state in a save")
	var bad=data.duplicate(true); bad.blocks[c.key(Vector3i(sx,sb,sz))]["rot"]=1
	check(not preload("res://scripts/river_construction.gd").new().restore(bad),"a slab with a rotation is rejected")
	bad=data.duplicate(true); bad.blocks[c.key(Vector3i(wx,wb,wz))]["open"]=true
	check(not preload("res://scripts/river_construction.gd").new().restore(bad),"an open window is rejected")
	bad=data.duplicate(true); bad.blocks[c.key(Vector3i(dx,base,dz))]["rot"]=7
	check(not preload("res://scripts/river_construction.gd").new().restore(bad),"a rotation out of range is rejected")
	# --- The copy desk prices 星锻岛 parts too.
	var mini=preload("res://scripts/river_miniatures.gd")
	mini.pack(c,{"type":"block","key":c.key(Vector3i(rx,rb,rz))})
	var id=str(c.miniatures.keys().back())
	var q=p.copy_quote(s,id)
	check(q.get("industry",{}).get("steel_ingot",0)==1 and q.message.contains("碳钢"),"copying a metal roof costs a steel ingot (%s)" % q.message)
	view.queue_free()
	if failures.is_empty(): print("BUILDING MATERIALS OK (%d checks)" % checks); quit(0)
	else: print("BUILDING MATERIALS FAILED: ",failures); quit(1)
