extends SceneTree
## v0.26 "Bedrock": voxel ground, real-mineral geology, mining, placing, scanning, saves and meshing.
const State=preload("res://scripts/lab_state.gd")
const V2=preload("res://scripts/planet_v2.gd")
const Geology=preload("res://scripts/planet_geology.gd")
const Walker=preload("res://scripts/river_walker.gd")
const Stream=preload("res://scripts/river_chunk_stream.gd")
const SUBSCRIPT={"₀":"0","₁":"1","₂":"2","₃":"3","₄":"4","₅":"5","₆":"6","₇":"7","₈":"8","₉":"9"}
var failures=[]
var checks=0

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func above(v,p: Vector2) -> void:
	var ground=v.construction.terrain.ground(p)
	v.actor={"eye":Vector3(p.x,ground+3,p.y),"feet":Vector3(p.x,ground+1.38,p.y),"direction":Vector3.DOWN}

## A clear, flat 3x3 patch with the given natural top, away from paths, rivers, trees and animals.
func flat_spot(v,top: float,from: Vector2i) -> Vector2i:
	var t=v.construction.terrain
	for z in range(from.y,from.y+60):
		for x in range(from.x,from.x+60):
			var ok=true
			for dz in range(-2,3):
				for dx in range(-2,3):
					var p=Vector2(x+dx,z+dz)
					if t.natural_height(p)!=top or t.blocked(p,v.construction.obstacles) or t.on_path(p) or t.river_cell(p) or not v.nature._structure_near(Vector3i(x+dx,0,z+dz),v).is_empty(): ok=false
			for e in v.combat.entities(v):
				if e.position.distance_to(Vector2(x,z))<4: ok=false
			if ok: return Vector2i(x,z)
	return Vector2i(99999,99999)

func _initialize() -> void:
	_geology()
	var s=State.new(); var v=s.planet.v2; v.active=true
	_mining(s,v)
	_saves(v)
	_walker(v)
	_mesher(v)
	s.close_science()
	print("BEDROCK: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _geology() -> void:
	var all: Dictionary=Geology.rules().materials
	check(all.size()==19,"nineteen real ground materials are defined")
	for id in all:
		var m: Dictionary=all[id]
		var plain=str(m.formula)
		for k in SUBSCRIPT: plain=plain.replace(k,SUBSCRIPT[k])
		for symbol in m.elements: check(plain.contains(symbol) or m.kind!="mineral","%s formula %s lists its element %s" % [id,m.formula,symbol])
		if m.kind=="mineral": check(not str(m.formula).is_empty() and not m.elements.is_empty(),"%s is a mineral with a real formula" % id)
		check(int(m.hits)>0 or id=="bedrock","%s can be mined" % id)
	check(Geology.info("halite").formula=="NaCl" and Geology.info("hematite").formula=="Fe₂O₃" and Geology.info("fluorite").mohs=="4","reference minerals keep textbook formulas and Mohs hardness")
	var T=preload("res://scripts/river_terrain.gd").new()
	var seen={}; var same=true
	for x in range(-48,48,2):
		for z in range(-48,48,2):
			var top=T.natural_height(Vector2(x,z)); var river=T.river_cell(Vector2(x,z))
			for y in range(Geology.bedrock_y(),ceili(top)):
				var id=Geology.natural(Vector3i(x,y,z),top,river); seen[id]=true
				if (x+z+y)%17==0: same=same and id==T.natural_material(Vector3i(x,y,z))
	check(same,"geology is a pure deterministic function of the cell")
	var missing=[]
	for id in all:
		if not seen.has(id): missing.append(id)
	check(missing.is_empty(),"every material occurs somewhere near home: missing "+str(missing))
	check(Geology.natural(Vector3i(3,Geology.bedrock_y(),3),1.0,false)=="bedrock" and Geology.natural(Vector3i(3,0,3),1.0,false)=="topsoil","topsoil on top, bedrock at the floor")
	check(Geology.natural(Vector3i(3,-15,3),1.0,false) in ["granite","pollucite","spodumene","cassiterite","hematite"],"granite layer holds its own ores")
	check(T.natural_height(Vector2(15,14))==floor((T.legacy_height(Vector2(15,14))+0.055)*2)/2 or T.natural_height(Vector2(15,14))==0.5,"natural top is the old ground floored to half metres")
	check(Geology.describe("malachite").contains("Cu₂CO₃(OH)₂") and Geology.describe("malachite").contains("莫氏硬度"),"analyser text carries formula and hardness")

func _mining(s,v) -> void:
	var c=v.construction; var t=c.terrain; var n=v.nature; var f=v.field
	var spot=flat_spot(v,1.0,Vector2i(20,20))
	if spot.x==99999: spot=flat_spot(v,0.5,Vector2i(20,20))
	check(spot.x!=99999,"a clear flat patch exists for mining")
	var p=Vector2(spot); var top=t.natural_height(p); var cell=Vector3i(spot.x,ceili(top)-1,spot.y)
	above(v,p); var aim=v.Target.query(v)
	check(aim.get("type")=="terrain" and aim.get("voxel")==cell and aim.get("material")=="topsoil" and aim.get("name")=="表土","aim reports the exact voxel and its material")
	check(v.Target.prompt(v,aim).contains("采掘镐"),"terrain prompt names the new tools")
	var soil=int(f.stock.soil); s.planet.command(s,"v2_dig")
	check(f.stock.soil==soil+1 and not t.solid(cell) and n.discovered.has("topsoil"),"one pick hit removes a topsoil voxel into the soil stock and the codex")
	# Dig down through the clay or sand band: harder materials need several hits.
	var below=cell+Vector3i.DOWN; var id=t.material(below); var hits=int(Geology.info(id).hits)
	above(v,p)
	for i in range(hits-1):
		s.planet.command(s,"v2_dig")
		check(t.solid(below),"%s survives hit %d of %d" % [id,i+1,hits])
	var message=s.planet.command(s,"v2_dig")
	# v0.50: a block yields a random 1-5 of its mineral, keyed by the cell.
	check(not t.solid(below) and (int(n.minerals.get(id,0)) in [1,2,3,4,5] or id=="topsoil"),"%s breaks on hit %d and enters the backpack: %s" % [id,hits,message])
	check(n.discovered.has(id) and message.contains("新发现"),"first find is announced and recorded")
	var items=v.inventory.entries(s)
	if id!="topsoil":
		check(items.has("rock:"+id) and items["rock:"+id].action.type=="place_rock" and items["rock:"+id].category=="minerals","mined rock appears in the backpack as a placeable mineral")
		var slots=v.inventory.serialize(); slots.slots[8]="rock:"+id
		check(v.inventory.restore(slots),"hotbar save can hold a mineral slot")
	var old_bar={"version":1,"slots":["tool:collect","tool:remove","seed:grain","","","","","",""],"selected":0}
	check(v.inventory.restore(old_bar) and "tool:dig" in v.inventory.slots and "tool:scan" in v.inventory.slots,"pre-Bedrock hotbars receive the pick and analyser once")
	var cleared=v.inventory.serialize(); cleared.slots=["tool:collect","","","","","","","",""]
	check(v.inventory.restore(cleared) and v.inventory.slots.count("")==8,"a current hotbar keeps the player's own empty slots")
	# Scan a wall voxel below and a tree-free patch.
	above(v,p); var scan=s.planet.command(s,"v2_scan")
	var wall=t.material(below+Vector3i.DOWN)
	check(scan.contains("分析仪") and scan.contains(str(Geology.info(wall).name)),"analyser reads the aimed voxel: "+scan)
	check(n.discovered.has(wall),"scanning also fills the codex")
	# Put the mined block back where it came from: the save goes back to pristine.
	if id!="topsoil":
		var held=int(n.minerals.get(id,0))   # v0.50: one dig yields 1-5, so track what is held.
		above(v,p); message=s.planet.command(s,"v2_place_rock",{"mineral":id})
		check(t.material(below)==id and int(n.minerals.get(id,0))==held-1,"placing a rock spends one and restores the cell: "+message)
		check(not n.voxels.has(below),"a restored natural cell leaves no stored edit")
	above(v,p); s.planet.command(s,"v2_fill")
	check(t.natural_height(p)==t.height_at(p) and n.voxels.is_empty(),"refilling the top returns the exact natural ground (slab-aware)")
	# No free matter, no bedrock breaking, no burying buildings.
	above(v,p); var voxels=n.voxels.duplicate(); message=s.planet.command(s,"v2_place_rock",{"mineral":"pollucite"})
	check(n.voxels==voxels and message.contains("没有"),"cannot place minerals you have not mined")
	message=n.dig({"voxel":Vector3i(spot.x,Geology.bedrock_y(),spot.y)},v)
	check(message.contains("基岩") and t.solid(Vector3i(spot.x,Geology.bedrock_y(),spot.y)),"bedrock refuses the pick")
	var b={"x":spot.x+1,"y":c.base(Vector3i(spot.x+1,0,spot.y)),"z":spot.y,"kind":"block","source":"9"}
	c.blocks[c.key(c.cell(b))]=b
	message=n.dig({"voxel":Vector3i(spot.x+1,b.y-1,spot.y)},v)
	check(t.solid(Vector3i(spot.x+1,b.y-1,spot.y)) and message.contains("构件"),"ground under a built block cannot be dug out")
	message=n.place({"voxel":Vector3i(spot.x+1,b.y-1,spot.y),"target":Vector3i(spot.x+1,b.y+3,spot.y)},"topsoil",v)
	check(message.contains("构件"),"no terrain is stacked on a building column")
	c.blocks.clear()
	# Player-safe placement: never inside your own body.
	f.stock.soil=3; above(v,p); v.actor.feet=Vector3(p.x,t.ground(p),p.y); voxels=n.voxels.duplicate()
	s.planet.command(s,"v2_fill"); check(n.voxels==voxels,"cannot entomb yourself")
	# Voxel cap is a hard bound on save size.
	var cap=int(n.rules.max_voxels); n.rules.max_voxels=n.voxels.size()
	message=n.dig({"voxel":Vector3i(spot.x-1,ceili(top)-1,spot.y)},v)
	check(message.contains("已满"),"edit cap blocks new edits: "+message)
	n.rules.max_voxels=cap

func _saves(v) -> void:
	var t=v.construction.terrain; var n=v.nature
	n.set_voxel(Vector3i(30,-5,30),"",t); n.set_voxel(Vector3i(30,3,30),"granite",t); n.minerals["galena"]=4; n.discovered["galena"]=true
	var data=JSON.parse_string(JSON.stringify(v.serialize())); var copy=V2.new()
	check(copy.restore(data),"voxel save reloads through JSON")
	var cn=copy.nature; var ct=copy.construction.terrain
	check(cn.voxels==n.voxels and int(cn.minerals.galena)==4 and cn.discovered.has("galena"),"voxels, minerals and codex round-trip")
	check(not ct.solid(Vector3i(30,-5,30)) and ct.material(Vector3i(30,3,30))=="granite","restored world answers the same geometry")
	var bad=data.duplicate(true); bad.nature.voxels["30:-40:30"]=""
	check(not V2.new().restore(bad),"cells below bedrock are rejected")
	bad=data.duplicate(true); bad.nature.voxels["30:1:30"]="bedrock"
	check(not V2.new().restore(bad),"bedrock cannot be placed through a save")
	bad=data.duplicate(true); bad.nature.minerals["gold"]=1
	check(not V2.new().restore(bad),"unknown minerals are rejected")
	bad=data.duplicate(true); bad.nature.minerals["galena"]=-1
	check(not V2.new().restore(bad),"negative stock is rejected")
	# v0.25 saves stored whole-column offsets; every old building base must stay put.
	var legacy=data.duplicate(true)
	legacy.nature={"version":1,"edits":{},"trees":{},"seeds":data.nature.seeds}
	var probes=[]
	for x in range(-40,40,3):
		for z in range(-40,40,5):
			var p=Vector2(x,z)
			if t.river_cell(p) or t.bridge(p) or probes.size()>=40: continue
			var delta=[-2,-1,1,2,3][probes.size()%5]
			legacy.nature.edits[n.cell_key(p)]=delta; probes.append([p,delta])
	var old=V2.new(); check(old.restore(legacy),"v0.25 nature save migrates")
	var ot=old.construction.terrain; var kept=true
	for row in probes:
		var p: Vector2=row[0]; var old_ground=ot.legacy_height(p)+0.055+row[1]
		if floori(ot.ground(p))!=floori(old_ground): kept=false; print("base moved at ",p," old=",old_ground," new=",ot.ground(p))
	check(kept,"migrated columns keep every old construction base cell")
	check(old.nature.serialize().version==2 and old.nature.minerals.is_empty(),"migrated nature saves as version 2")

func _walker(v) -> void:
	var c=v.construction; var t=c.terrain; var n=v.nature
	n.voxels.clear(); n.columns.clear()
	var spot=flat_spot(v,1.0,Vector2i(-60,20))
	check(spot.x!=99999,"a flat full-block patch exists for the pit test")
	if spot.x==99999: return
	var top=ceili(t.natural_height(Vector2(spot)))
	for y in [top-1,top-2]: n.set_voxel(Vector3i(spot.x,y,spot.y),"",t)
	var w=Walker.new(t); w.construction=c; w.position=Vector2(spot); w.reset_height()
	check(is_equal_approx(w.feet_y,top-2),"walker stands on the pit floor")
	w.yaw=0; w.movement=Vector2(1,0)
	for i in range(90): w.step(1.0/60)
	check(absf(w.position.x-spot.x)<0.5 and is_equal_approx(w.feet_y,top-2),"a two-block wall holds the walker in the pit")
	check(not t.overlaps(w.position,w.feet_y,float(t.rules.body_height)),"walker never ends inside rock")
	n.set_voxel(Vector3i(spot.x,top-2,spot.y),"topsoil",t)
	w.position=Vector2(spot); w.reset_height(); w.movement=Vector2(1,0)
	for i in range(50): w.step(1.0/60)
	check(absf(w.position.x-spot.x)>0.7 and is_equal_approx(w.feet_y,top),"auto-jump climbs a single block step")
	# A tunnel roof stops a jump.
	n.voxels.clear(); n.columns.clear()
	w.position=Vector2(spot); w.movement=Vector2.ZERO; w.reset_height()
	n.set_voxel(Vector3i(spot.x,top+2,spot.y),"granite",t); w.jump()
	var peak=w.feet_y
	for i in range(60): w.step(1.0/60); peak=maxf(peak,w.feet_y)
	check(peak+float(t.rules.body_height)<=top+2.01,"a block overhead caps the jump")
	n.voxels.clear(); n.columns.clear()

func _mesher(v) -> void:
	var t=v.construction.terrain; var n=v.nature
	var stream=Stream.new(); stream.terrain=t; stream.season=0
	var key=t.chunk_at(Vector2(20,20)); var start=Time.get_ticks_usec(); var mesh=stream._build(key); var plain=Time.get_ticks_usec()-start
	check(mesh!=null and mesh.get_surface_count()==1,"a natural chunk meshes")
	var faces=mesh.surface_get_array_len(0)/6
	var span=int(t.rules.chunk_cells)
	for x in range(key.x*span+2,key.x*span+14,3):
		for z in range(key.y*span+2,key.y*span+14,3):
			for y in range(-6,1): n.set_voxel(Vector3i(x,y,z),"",t)
	start=Time.get_ticks_usec(); var dug=stream._build(key); var edited=Time.get_ticks_usec()-start
	check(dug.surface_get_array_len(0)/6>faces+100,"dug shafts add wall faces")
	print("BEDROCK mesher: natural %.1f ms (%d faces), 16 shafts %.1f ms (%d faces)" % [plain/1000.0,faces,edited/1000.0,dug.surface_get_array_len(0)/6])
	check(plain<25000 and edited<80000,"chunk remesh stays within the headless budget")
	stream.free()
