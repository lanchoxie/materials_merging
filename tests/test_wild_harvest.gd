extends SceneTree
## v0.41.2 野外生存 (user request): no piles and no stumps; felled trees drop timber/seeds/fibre/fruit
## by deterministic chance; quarrying rock gives 石料; crops roll grain and seeds; hunting gives meat;
## cooking at a campfire; eating heals and warms; copying a boxed build in the workshop costs real
## materials; unfolding previews every cell.
const State=preload("res://scripts/lab_state.gd")
const PlanetV2=preload("res://scripts/planet_v2.gd")
const Construction=preload("res://scripts/river_construction.gd")
const Mini=preload("res://scripts/river_miniatures.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func fell(v,tree) -> void:
	for i in range(int(v.nature.rules.chop_hits)): v.nature.chop(tree.id,v.field,v.construction.terrain)

func _initialize() -> void:
	# --- Trees: rolled, deterministic drops; no stump left to target.
	var v=PlanetV2.new(); var t=v.construction.terrain
	var trees=[]
	for z in range(-4,4):
		for x in range(-4,4):
			for tree in t.tree_records(Vector2i(x,z)):
				if tree.growth>=0.99: trees.append(tree)
	check(trees.size()>=40,"enough grown trees to sample (%d)" % trees.size())
	var seeds_before=0
	for k in v.nature.seeds: seeds_before+=int(v.nature.seeds[k])
	var timber_min=99; var timber_max=0; var seed_drops=0; var oak_fruit=0; var oaks=0; var pine_fruit=0; var pines=0
	for tree in trees.slice(0,40):
		var timber_before=int(v.field.stock.timber); var seeds=int(v.nature.seeds[tree.species]); var fruit=int(v.field.stock.fruit)
		fell(v,tree)
		var got=int(v.field.stock.timber)-timber_before
		timber_min=mini(timber_min,got); timber_max=maxi(timber_max,got)
		if int(v.nature.seeds[tree.species])>seeds: seed_drops+=1
		if tree.species=="oak": oaks+=1; oak_fruit+=int(v.field.stock.fruit)-fruit
		if tree.species=="pine": pines+=1; pine_fruit+=int(v.field.stock.fruit)-fruit
	check(timber_min>=3 and timber_max<=6 and timber_max>timber_min,"timber varies within 3–6 (%d–%d)" % [timber_min,timber_max])
	check(seed_drops>=12 and seed_drops<=36,"seeds drop by chance, not every time (%d/40)" % seed_drops)
	check(v.field.stock.fiber>0,"felling also yields plant fibre")
	var again=PlanetV2.new(); fell(again,trees[0])
	var replay=PlanetV2.new(); fell(replay,trees[0])
	check(again.field.stock==replay.field.stock and again.nature.seeds==replay.nature.seeds,"the same tree always drops the same (no reroll by reloading)")
	check(trees[0].x not in [] and Vector2(trees[0].x,trees[0].z) not in t.chunk_trees(t.chunk_at(Vector2(trees[0].x,trees[0].z))),"a felled tree no longer stands or blocks")
	check(v.field.nodes(Vector2(18,16),60).is_empty(),"no gathering piles anywhere")
	# --- Rock gives building stone too.
	var g=PlanetV2.new(); var gt=g.construction.terrain
	var cell=Vector3i.ZERO; var found=false
	for y in range(-14,-30,-1):
		var c=Vector3i(20,y,20)
		if gt.natural_material(c)=="granite": cell=c; found=true; break
	check(found,"a granite cell exists under home")
	g.actor={"eye":Vector3(20,y_of(gt,20,20)+1.6,20),"feet":Vector3(20,y_of(gt,20,20),20),"direction":Vector3.DOWN}
	var stone=int(g.field.stock.stone); var msg=""
	for i in range(20):
		msg=g.nature.dig({"voxel":cell,"target":cell},g)
		if not msg.contains("采掘"): break
	check(int(g.field.stock.stone)==stone+1 and int(g.nature.minerals.get("granite",0))==1,"quarrying granite gives the rock and 石料: "+msg)
	# --- Crops roll grain and seeds.
	var f=g.field; var w={"elapsed":1234,"seeds":0}
	var grains=[]; var seed_counts=[]
	for i in range(30):
		var key="0:%d:0" % i; f.gardens[key]={"growth":1.0,"moisture":0.5,"waterings":0}
		var before=int(f.stock.grain); w.seeds=0; w.elapsed=1234+i
		f.harvest(key,w); grains.append(int(f.stock.grain)-before); seed_counts.append(int(w.seeds))
	check(grains.min()>=2 and grains.max()<=4 and grains.max()>grains.min(),"a crop gives 2–4 grain (%d–%d)" % [grains.min(),grains.max()])
	check(seed_counts.min()>=0 and seed_counts.max()<=3 and seed_counts.max()>seed_counts.min(),"seeds per harvest vary 0–3")
	# --- Meat, cooking, eating.
	var s=State.new(); var p=s.planet; var pv=p.v2; pv.active=true
	var boar={"key":"wild:t:1","type":"wild","row":{"species":"woodland_boar","health":0.01},"name":"林地野猪","position":Vector2(30,30),"site":"t","entity":null}
	pv.population.sites["t"]={"animals":[boar.row],"visitors":[]}
	pv.combat._remove(boar,pv); pv.population.sites.erase("t")
	var meat_range: Array=pv.combat.rules.meat.woodland_boar
	var meat=pv.field.span(meat_range,pv.field.roll(boar.key,9))
	check(meat>=2 and meat<=3,"a boar yields 2–3 meat")
	pv.field.stock.meat=3; pv.field.stock.grain=4; pv.field.stock.fruit=2; pv.field.stock.fiber=2
	var at=Vector2(30,30); var ground=pv.construction.terrain.ground(at)
	pv.actor={"eye":Vector3(at.x,ground+1.6,at.y),"feet":Vector3(at.x,ground,at.y),"direction":Vector3.FORWARD}
	check(p.command(s,"v2_cook",{"recipe":"cooked_meat"}).contains("篝火旁"),"cooking needs a campfire")
	var product={"id":int(p.serial),"recipe":"field_campfire","recipe_version":1,"source_batch":"river:"+str(int(p.serial))}
	pv.field.crafts[str(int(p.serial))]={"recipe":"field_campfire","complete":true,"inputs":pv.field.rules.recipes.field_campfire.natural_inputs.duplicate()}; p.serial+=1
	pv.construction.sources[str(int(product.id))]={"product":product,"remaining":1}
	var fc=Vector3i(31,pv.construction.base(Vector3i(31,0,31)),31)
	pv.construction.blocks[pv.construction.key(fc)]={"x":fc.x,"y":fc.y,"z":fc.z,"kind":"campfire","source":str(int(product.id))}; pv.construction.revision+=1
	check(p.command(s,"v2_cook",{"recipe":"cooked_meat"}).contains("做好") and int(pv.field.stock.cooked_meat)==1 and int(pv.field.stock.meat)==2,"meat is roasted at the campfire")
	check(p.command(s,"v2_cook",{"recipe":"stew"}).contains("做好") and int(pv.field.stock.stew)==1,"stew from meat, grain and fibre")
	check(p.command(s,"v2_eat",{"resource":"fruit"}).contains("不饿"),"no point eating at full health with nothing to warm")
	pv.combat.player_health=50.0
	var felt=pv.felt_temperature(pv.actor.feet)
	check(p.command(s,"v2_eat",{"resource":"stew"}).contains("暖身") and is_equal_approx(pv.combat.player_health,95.0) and int(pv.field.stock.stew)==0,"hot stew heals 45")
	check(absf(pv.felt_temperature(pv.actor.feet)-felt-14.0)<0.01,"and warms by 14 °C")
	pv.combat.tick(250.0,pv,false)
	check(absf(pv.felt_temperature(pv.actor.feet)-felt)<0.01,"the warmth wears off")
	var inv=pv.inventory.entries(s)
	check(inv.has("raw:cooked_meat") and inv["raw:cooked_meat"].action.type=="eat","cooked food can be eaten from the hotbar")
	var path="res://saves/wild-harvest.json"
	check(s.save_game(path).begins_with("已保存") and State.new().load_game(path),"a save with meat and food loads")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path)); DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	var old=pv.field.serialize(); old.stock.erase("meat"); old.stock.erase("stew"); old.changed={"home:0":{"hits":1,"ready_at":0}}
	var fresh=preload("res://scripts/river_field.gd").new()
	check(fresh.restore(old,pv.construction,int(pv.world.elapsed)) and fresh.changed.is_empty() and int(fresh.stock.meat)==0,"old saves with pile progress and no food still load")
	# --- Building copy in the workshop.
	s=State.new(); p=s.planet; pv=p.v2
	p.command(s,"join"); s.campus_build(3,"workshop"); s.campus_road(3); s.campus_assign_post(s.campus.people[0].id,"workshop")
	var c=pv.construction
	var wall={"id":int(p.serial),"recipe":"field_wall","recipe_version":1,"source_batch":"river:"+str(int(p.serial))}
	pv.field.crafts[str(int(p.serial))]={"recipe":"field_wall","complete":true,"inputs":pv.field.rules.recipes.field_wall.natural_inputs.duplicate()}; p.serial+=1
	c.sources[str(int(wall.id))]={"product":wall,"remaining":5}
	var base=c.base(Vector3i(19,0,14))
	for dy in range(3): var b={"x":19,"y":base+dy,"z":14,"kind":"block","source":str(int(wall.id))}; c.blocks[c.key(c.cell(b))]=b
	Mini.pack(c,{"type":"block","key":c.blocks.keys()[0]})
	var id=c.miniatures.keys()[0]
	var q=p.copy_quote(s,id)
	check(not q.ready and q.message.contains("木料"),"copying needs the raw materials: "+q.message)
	pv.field.stock.timber=4
	q=p.copy_quote(s,id)
	check(q.ready and int(q.packages.field_wall)==1 and int(q.inputs.timber)==4,"three wall blocks cost one wall package (4 timber)")
	check(p.command(s,"copy_building",{"id":id}).contains("复制完成") and c.miniatures.size()==2 and int(pv.field.stock.timber)==0,"the workshop builds a real copy")
	var copy_id=""
	for k in c.miniatures:
		if k!=id: copy_id=k
	check(not c.miniatures[copy_id].get("replica",false),"the copy is a real build, not a display replica")
	check(Construction.new().restore(c.serialize()),"material conservation holds with the copy's own packages")
	var restored=State.new()
	check(restored.planet.restore(JSON.parse_string(JSON.stringify(p.serialize())),restored),"the whole workshop save with the copy validates")
	# Unfold preview lists every cell.
	pv.active=true; var lane=Vector2(40,14); var lg=c.terrain.ground(lane)
	pv.actor={"eye":Vector3(lane.x+4,lg+1.6,lane.y),"feet":Vector3(lane.x+4,lg,lane.y),"direction":(Vector3(lane.x,lg,lane.y)-Vector3(lane.x+4,lg+1.6,lane.y)).normalized()}
	var plan=Mini.plan(c,copy_id,pv.actor)
	check(plan.get("cells",[]).size()==3,"the unfold preview has a ghost for every block (%d)" % plan.get("cells",[]).size())
	# --- Digging is not refused for odd reasons (user: 幼树在扎根 / 道路下面不能挖).
	var d=PlanetV2.new(); var dt=d.construction.terrain
	var standing=null
	for k in [Vector2i(1,1),Vector2i(2,1),Vector2i(1,2),Vector2i(3,3)]:
		for tr in dt.tree_records(k):
			if not tr.cut and tr.growth>=0.99: standing=tr; break
		if standing!=null: break
	var tp=Vector2(roundi(standing.x),roundi(standing.z)); var top=ceili(dt.height_at(tp))-1
	d.actor={"eye":Vector3(tp.x+2,dt.ground(tp)+1.6,tp.y),"feet":Vector3(tp.x+2,dt.ground(tp),tp.y),"direction":Vector3.DOWN}
	var under=d.nature.dig({"voxel":Vector3i(int(tp.x),top-3,int(tp.y))},d)
	check(under.contains("采掘") or under.contains("采到") or under.contains("挖出"),"deep under a tree can be dug: "+under)
	var surface=d.nature.dig({"voxel":Vector3i(int(tp.x),top,int(tp.y))},d)
	check(surface.contains("砍倒") and not surface.contains("幼树"),"the surface cell under a standing tree says to fell it first: "+surface)
	var road=Vector2.INF
	for x in range(-40,41):
		for z in range(-40,41):
			if dt.on_path(Vector2(x,z)) and not dt.blocked(Vector2(x,z),[]): road=Vector2(x,z); break
		if road!=Vector2.INF: break
	if road!=Vector2.INF:
		var rc=Vector3i(int(road.x),ceili(dt.height_at(road))-1,int(road.y))
		var on_road=d.nature.dig({"voxel":rc},d)
		check(not on_road.contains("主路") and not on_road.contains("通行"),"roads can be dug: "+on_road)
	# --- Machines do something to planters (user: the sprinkler did not water them).
	var m=PlanetV2.new(); var mc=m.construction; var mf=m.field
	var near_key=""; var far_key=""; var fed_key=""
	for spot in [[Vector2i(40,40),"planter"],[Vector2i(43,40),"sprinkler"],[Vector2i(60,40),"planter"],[Vector2i(80,40),"planter"],[Vector2i(82,40),"fertilizer_spreader"]]:
		var cc=Vector3i(spot[0].x,mc.base(Vector3i(spot[0].x,0,spot[0].y)),spot[0].y)
		mc.blocks[mc.key(cc)]={"x":cc.x,"y":cc.y,"z":cc.z,"kind":spot[1],"source":"x"}
		if spot[1]=="planter":
			mf.gardens[mc.key(cc)]={"growth":0.0,"moisture":0.1,"waterings":0}
			if spot[0].x==40: near_key=mc.key(cc)
			elif spot[0].x==60: far_key=mc.key(cc)
			else: fed_key=mc.key(cc)
	mf.gardens[fed_key].moisture=0.9; mf.gardens[far_key].moisture=0.9
	var wrld={"elapsed":5000}
	for i in range(30): mf.tick(wrld,mc); wrld.elapsed+=1
	check(float(mf.gardens[near_key].moisture)>0.5,"a sprinkler keeps planters within 6 m wet (%.2f)" % float(mf.gardens[near_key].moisture))
	check(float(mf.gardens[fed_key].growth)>float(mf.gardens[far_key].growth)*1.25,"a fertilizer spreader speeds up nearby planters")
	var tip=m.Target.prompt(m,{"type":"block","kind":"sprinkler","name":"喷淋塔","distance":2.0})
	check(tip.contains("种植箱自动保持湿润"),"aiming at a machine explains what it does")
	if failures.is_empty(): print("WILD HARVEST OK (%d checks)" % checks); quit(0)
	else: print("WILD HARVEST FAILED: ",failures); quit(1)

func y_of(t,x: float,z: float) -> float:
	return t.ground(Vector2(x,z))
