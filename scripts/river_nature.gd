extends RefCounted
## Sparse, persistent changes over deterministic terrain. Inventory commits are atomic.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/river_nature.json"))
const Geology=preload("res://scripts/planet_geology.gd")
const Fabricator=preload("res://scripts/fabricator.gd")
const SOIL_ONLY="树苗需要种在表土或黏土上"
var voxels={}      # Vector3i -> material id; "" means dug out
var columns={}     # Vector2i -> {y: true}: index of edited cells per column
var minerals={}    # mined stock by material id (表土 goes to the field's soil stock)
var discovered={}  # material id -> true (矿物图鉴)
var mining={}      # transient hit progress on one cell
var pick_hv=-1.0   # v0.30: equipped pick hardness (GPa), set by LabState.sync_gear; <0 = starter pick
var pick_name=""
## v0.40: the equipped cordless drill's state, shared with LabState.industry ({} when none).
var drill: Dictionary={}
var trees={}
var seeds={"oak":0,"birch":0,"pine":0}
var revision=0
var chunk_versions={}
var planted_by_chunk={}

func cell_key(p: Vector2) -> String:
	return "%d:%d" % [roundi(p.x),roundi(p.y)]

func natural_id(p: Vector2) -> String:
	return "n:%d:%d" % [roundi(p.x/3.3),roundi(p.y/3.3)]

func touch(p: Vector2,t) -> void:
	revision+=1
	var chunk=t.chunk_at(p)
	for z in range(-1,2):
		for x in range(-1,2):
			var k=chunk+Vector2i(x,z); chunk_versions[k]=int(chunk_versions.get(k,0))+1

## Which tree grows here. Home keeps its old mix; elsewhere the climate decides (v0.42): conifers
## in the cold, birch in cool woods, oak and birch in warm ones.
var climate=null
func species_at(p: Vector2) -> String:
	var keys=rules.species.keys(); var pick=posmod(roundi(p.x/3.3)*7+roundi(p.y/3.3)*13,3)
	if climate==null or p.length()<300.0: return keys[pick]
	var t=float(climate.values(climate.cell_of(p)).y)
	if t<6.0: return "pine"
	if t<13.0: return ["pine","birch","birch"][pick]
	return ["oak","birch","oak"][pick]

func descriptor(id: String,p: Vector2) -> Dictionary:
	var kind=species_at(p)
	var row=trees.get(id,{"species":kind,"growth":1.0,"cut":false,"hits":0,"water":0.0})
	return {"id":id,"x":p.x,"z":p.y,"species":row.species,"growth":row.growth,"cut":row.cut,"hits":row.hits,"water":row.water}

func records(chunk: Vector2i,t) -> Array:
	var result=[]
	for p in t.chunk_tree_origins(chunk): result.append(descriptor(natural_id(p),p))
	for id in planted_by_chunk.get(chunk,[]):
		var row=trees[id]; result.append(descriptor(id,Vector2(row.x,row.z)))
	return result

func lookup(id: String,t) -> Dictionary:
	var parts=id.split(":")
	if parts.size()!=3 or not parts[1].is_valid_int() or not parts[2].is_valid_int(): return {}
	if parts[0]=="p":
		if not trees.has(id): return {}
		return descriptor(id,Vector2(trees[id].x,trees[id].z))
	if parts[0]!="n": return {}
	var ix=int(parts[1]); var iz=int(parts[2])
	var p=Vector2(ix*3.3+sin(iz*12.7+ix)*0.8,iz*3.3+cos(ix*4.3)*0.8)
	if not t.inside(p,2) or p not in t.chunk_tree_origins(t.chunk_at(p)): return {}
	return descriptor(id,p)

func chop(id: String,field,t) -> String:
	var tree=lookup(id,t)
	if tree.is_empty() or tree.cut: return "这棵树已经砍倒了"
	if tree.growth<0.99: return "这棵幼树还没长成，先照顾它"
	var D: Dictionary=rules.drops
	if not field.can_add("timber",int(D.timber[1])) or seeds[tree.species]>=int(rules.max_seed_stock): return "木料或树种已满，先整理背包"
	if not trees.has(id) and trees.size()>=int(rules.max_trees): return "林木记录已满"
	tree.hits+=1; trees[id]=tree
	if tree.hits<int(rules.chop_hits): touch(Vector2(tree.x,tree.z),t); return "%s · 砍伐 %d/%d" % [rules.species[tree.species].name,tree.hits,rules.chop_hits]
	tree.cut=true; tree.hits=0
	# v0.41.2: drops are rolled per tree (deterministic by its id), and the tree is gone entirely.
	var Field=field.get_script(); var gen=int(tree.get("gen",0)); var key=id+":"+str(gen)
	var got=[]
	var timber=Field.span(D.timber,Field.roll(key,1)); field.stock.timber+=timber; got.append("木料 ×%d" % timber)
	if Field.roll(key,2)<float(D.seed): seeds[tree.species]+=1; got.append("%s ×1" % rules.species[tree.species].seed)
	if Field.roll(key,3)<float(D.fiber.chance) and field.can_add("fiber",int(D.fiber.amount[1])):
		var fiber=Field.span(D.fiber.amount,Field.roll(key,4)); field.stock.fiber+=fiber; got.append("植物纤维 ×%d" % fiber)
	if Field.roll(key,5)<float(D.fruit.get(tree.species,0.0)) and field.can_add("fruit",1): field.stock.fruit+=1; got.append("野果 ×1")
	field.revision+=1; touch(Vector2(tree.x,tree.z),t)
	return "%s倒下了：%s" % [rules.species[tree.species].name,"，".join(got)]

func plant(kind: String,p: Vector2,v) -> String:
	var t=v.construction.terrain; p=p.round()
	if not seeds.has(kind) or seeds[kind]<1: return "背包里没有这种树种；砍成熟的同种树可得到"
	if not t.inside(p,2) or t.height_at(p)<0.22 or t.bridge(p) or t.on_path(p): return "请选一块干燥的空地"
	if t.material(Vector3i(int(p.x),ceili(t.height_at(p))-1,int(p.y))) not in ["topsoil","clay"]: return SOIL_ONLY
	if t.blocked(p,v.construction.obstacles) or v.construction.overlaps(p,t.ground(p),5): return "这里有树木或建筑，换一块空地"
	for z in range(-1,2):
		for x in range(-1,2):
			for tree in records(t.chunk_at(p)+Vector2i(x,z),t):
				if not tree.cut and p.distance_to(Vector2(tree.x,tree.z))<2.2: return "树苗需要留出两米生长空间"
	var id="p:"+cell_key(p)
	if trees.has(id) and not trees[id].cut: return "这里已经有树苗"
	if not trees.has(id) and trees.size()>=int(rules.max_trees): return "林木记录已满"
	var chunk=t.chunk_at(p)
	if not planted_by_chunk.has(chunk): planted_by_chunk[chunk]=[]
	if id not in planted_by_chunk[chunk]: planted_by_chunk[chunk].append(id)
	seeds[kind]-=1; trees[id]={"id":id,"x":p.x,"z":p.y,"species":kind,"growth":0.12,"cut":false,"hits":0,"water":0.0}; touch(p,t)
	return "种下"+str(rules.species[kind].name)+"；雨水能让它慢慢长大，水样或水箱可加快生长"

func water_error(id: String,t) -> String:
	var tree=lookup(id,t)
	if tree.is_empty() or tree.cut or tree.growth>=1: return "请瞄准一棵还在生长的幼树"
	if tree.water>0.7: return "这棵树的土壤已经湿润"
	return ""

func water(id: String,t) -> void:
	trees[id].water=1.0; touch(Vector2(trees[id].x,trees[id].z),t)

func tick(t) -> void:
	for id in trees:
		var tree=trees[id]
		if tree.cut or tree.growth>=1: continue
		var phase=int(tree.growth*8)
		tree.growth=minf(1,tree.growth+(float(rules.watering_growth) if tree.water>0.1 else float(rules.rain_growth))/float(rules.growth_seconds))
		tree.water=maxf(0,tree.water-0.003)
		if int(tree.growth*8)!=phase: touch(Vector2(tree.x,tree.z),t)

## v0.26 voxel ground. Only cells that differ from the deterministic geology are stored.
func set_voxel(c: Vector3i,id: String,t) -> void:
	var natural: String=t.natural_material(c)
	var restores=id==natural and (id=="" or t.natural_cell_height(c)>=1.0 or voxels.get(c,"x")=="")
	var column=Vector2i(c.x,c.z)
	if restores:
		voxels.erase(c)
		if columns.has(column):
			columns[column].erase(c.y)
			if columns[column].is_empty(): columns.erase(column)
	else:
		voxels[c]=id
		if not columns.has(column): columns[column]={}
		columns[column][c.y]=true

func _structure_near(c: Vector3i,v) -> String:
	var con=v.construction; var t=con.terrain; var p=Vector2(c.x,c.z)
	if t.bridge(p) or t.on_path(p): return "公共桥梁和主路旁保留通行地面"
	if t.blocked(p,con.obstacles): return "先移开这里的树木或设施"
	for tree in records(t.chunk_at(p),t):
		if not tree.cut and p.distance_to(Vector2(tree.x,tree.z))<0.9: return "幼树正在这里扎根，换一块地施工"
	return ""

func dig(aim: Dictionary,v) -> String:
	var c=aim.get("voxel")
	if not c is Vector3i: return "请瞄准5米内的地面或岩壁"
	var con=v.construction; var t=con.terrain; var p=Vector2(c.x,c.z)
	if not t.inside(p,3): return "只能在探索区内施工"
	var id: String=t.material(c)
	if id=="": return "这里已经挖空了"
	if id=="bedrock": return "基岩是探索区的底部，当前工具无法破开"
	# v0.41.2 (user): digging is never refused for roads, and trees or facilities only guard the
	# surface cell they stand on — underground is always fair game.
	if c.y>=ceili(t.height_at(p))-1:
		if t.blocked(p,con.obstacles):
			for tree in records(t.chunk_at(p),t):
				if not tree.cut and p.distance_to(Vector2(tree.x,tree.z))<0.9: return "%s长在这里：先用斧头把它砍倒" % rules.species[tree.species].name
			return "先移开这里的设施"
	for dy in [0,1]:
		if con.blocks.has(con.key(c+Vector3i(0,dy,0))): return "先拆回上面的构件，以免建筑悬空或被掩埋"
	if c.y>=ceili(t.height_at(p))-1:
		for entity in v.combat.entities(v):
			if entity.position.distance_to(p)<0.9: return "生物正在这里，等它走开再施工"
	if not voxels.has(c) and voxels.size()>=int(rules.max_voxels): return "改造记录已满，先把一些方块放回原处"
	var spec: Dictionary=Geology.info(id); var soil=str(spec.get("yield",""))=="soil"
	if soil and not v.field.can_add("soil",1): return "土方格已满"
	if not soil and int(minerals.get(id,0))>=int(rules.max_mineral_stock): return "%s已装满，先放置或带回一些" % spec.name
	if mining.get("cell")!=c: mining={"cell":c,"hits":0}
	mining.hits+=1
	# v0.30: a pick softer than the rock needs more hits (hardness compared on the Vickers scale).
	var hv: float=pick_hv if pick_hv>0.0 else float(Fabricator.rules().starter_pick.hv)
	var need: int=Fabricator.dig_hits(id,int(spec.hits),hv)
	var drilled=not drill.is_empty() and float(drill.get("cap",0.0))>0.0 and float(drill.charge)>=float(drill.wh)
	if drilled: need=maxi(1,ceili(float(need)*float(drill.factor)))
	if mining.hits<need: return "%s · 采掘 %d/%d%s%s" % [spec.name,mining.hits,need,"（%s比岩石软，挖得慢）" % (pick_name if pick_name!="" else "镐头") if need>int(spec.hits) else "","（电钻 %d%%）" % roundi(100*float(drill.charge)/float(drill.cap)) if drilled else ""]
	mining={}
	if drilled: drill.charge=float(drill.charge)-float(drill.wh)
	set_voxel(c,"",t); touch(p,t)
	var found=_discover(id)
	if soil:
		v.field.stock.soil+=1; v.field.revision+=1
		return "挖出1份土方（表土），这一格已挖空"+found
	# v0.50 (user): a mined block gives a random 1-5 of its mineral (and of building stone for rock).
	# The roll is keyed by the cell, so the same block always yields the same amount.
	var Field=v.field.get_script(); var key="dig:%d:%d:%d" % [c.x,c.y,c.z]
	var got=mini(Field.span(rules.ore_yield,Field.roll(key,1)),maxi(0,int(rules.max_mineral_stock)-int(minerals.get(id,0))))
	minerals[id]=int(minerals.get(id,0))+maxi(got,0)
	var haul=" ×%d" % maxi(got,0)
	# v0.41.2: quarrying rock also leaves building stone (石料), the old 散石 piles' job.
	var rubble=""
	if id in rules.get("rubble_rocks",[]):
		var stones=mini(Field.span(rules.stone_yield,Field.roll(key,2)),maxi(0,int(v.field.rules.max_stock)-int(v.field.stock.stone)))
		if stones>0: v.field.stock.stone+=stones; v.field.revision+=1; rubble="，石料 ×%d" % stones
	return "采到%s%s%s%s%s" % [spec.name,(" "+str(spec.formula)) if str(spec.formula)!="" else "",haul,rubble,found]

func place(aim: Dictionary,id: String,v) -> String:
	var c=aim.get("target")
	if not c is Vector3i or not aim.has("voxel"): return "瞄准地面或岩壁的一个面来放置"
	var con=v.construction; var t=con.terrain; var p=Vector2(c.x,c.z)
	var spec: Dictionary=Geology.info(id)
	if spec.is_empty() or id=="bedrock": return "这种物质不能作为方块放置"
	if not t.inside(p,3): return "只能在探索区内施工"
	if t.solid(c) and t.cell_height(c)>=1.0: return "这里已经被岩土占据"
	if c.y<=Geology.bedrock_y() or c.y>mini(int(rules.build_ceiling),floori(t.natural_height(p))+int(rules.build_above)): return "太高了，当前最多在原地面上方堆16层"
	for b in con.blocks.values():
		if int(b.x)==c.x and int(b.z)==c.z: return "这一列有自建构件，不能把岩土压在构件上"
	var near=_structure_near(c,v)
	if not near.is_empty(): return near
	if not v.actor.is_empty():
		var feet: Vector3=v.actor.feet
		if absf(feet.x-c.x)<0.8 and absf(feet.z-c.z)<0.8 and feet.y<c.y+1 and feet.y+float(t.rules.body_height)>c.y: return "退开一点，不能把方块放到自己身上"
		if Vector3(c.x,c.y+0.5,c.z).distance_to(v.actor.eye)>float(con.rules.reach)+0.9: return "离得太远，请走近些"
	for entity in v.combat.entities(v):
		if entity.position.distance_to(p)<0.9 and c.y<=ceili(t.height_at(p))+1: return "生物正在这里，等它走开再施工"
	if not voxels.has(c) and voxels.size()>=int(rules.max_voxels): return "改造记录已满，先把一些方块放回原处"
	var soil=str(spec.get("yield",""))=="soil"
	if soil and v.field.stock.soil<1: return "需要1份土方；用采掘镐挖表土获得"
	if not soil and int(minerals.get(id,0))<1: return "背包里没有%s；先去地下采掘" % spec.name
	if soil: v.field.stock.soil-=1; v.field.revision+=1
	else: minerals[id]=int(minerals[id])-1
	set_voxel(c,id,t); touch(p,t)
	return "放下1份土方，地面抬高一格" if soil else "放下1块%s" % spec.name

## The analyser reads real composition; unknown things are never given invented properties.
func scan(aim: Dictionary,v) -> String:
	match str(aim.get("type","")):
		"terrain":
			var c: Vector3i=aim.voxel; var id=v.construction.terrain.material(c)
			return "分析仪 · %s · 深度 y=%d%s" % [Geology.summary(id),c.y,_discover(id)]
		"tree":
			var tree=lookup(str(aim.get("tree_id","")),v.construction.terrain)
			var found=v.specimens.record(str(tree.get("species","")),_biome(v,Vector2(tree.get("x",0.0),tree.get("z",0.0)))) if not tree.is_empty() else ""
			return "分析仪 · %s\n木材：纤维素 (C₆H₁₀O₅)ₙ + 半纤维素 + 木质素（混合物）%s" % [aim.name,found]
		"resource":
			var kinds={"timber":"枯枝：木材（纤维素 + 木质素，混合物）","stone":"石料：开采岩石时的碎石块（混合物，成分随母岩而异）","fiber":"纤维草：植物纤维，主要为纤维素 (C₆H₁₀O₅)ₙ","fruit":"野果：水分 + 糖类 + 纤维（混合物）"}
			return "分析仪 · "+str(kinds.get(aim.node.kind,aim.name))
		"animal","creature":
			var e: Dictionary=aim.get("entity",{})
			if e.get("type","") in ["resident","visitor"]: return "分析仪 · %s\n这是你的伙伴，不做标本。" % aim.name
			var species=str(e.get("row",{}).get("species",""))
			var spec: Dictionary=v.specimens.rules.species.get(species,{})
			var found=v.specimens.record(species,_biome(v,e.get("position",Vector2.ZERO)))
			if spec.is_empty(): return "分析仪 · %s" % aim.name
			return "分析仪 · %s · 原型 %s\n健康 %d%%%s" % [aim.name,spec.prototype,roundi(float(aim.get("health",1))*100),found if not found.is_empty() else "\n"+str(spec.facts)]
		"block": return "分析仪 · %s\n自建构件：材料来自浮岛工坊，来源编号保存在建造记录里。" % aim.name
	return "分析仪 · 瞄准5米内的岩土、树木或采集点"

func _biome(v,p: Vector2) -> String:
	return v.environment.biome_name(v.environment.biome_at(p)) if v.environment!=null else ""

func _discover(id: String) -> String:
	if id=="" or discovered.has(id): return ""
	discovered[id]=true
	return "\n★ 新发现！矿物图鉴 %d/%d" % [discovered.size(),Geology.rules().materials.size()]

func serialize() -> Dictionary:
	var cells={}
	for c in voxels: cells["%d:%d:%d" % [c.x,c.y,c.z]]=voxels[c]
	return {"version":2,"voxels":cells,"trees":trees.duplicate(true),"seeds":seeds.duplicate(),"minerals":minerals.duplicate(),"discovered":discovered.keys()}

func restore(data,t) -> bool:
	# JSON turns the version into a float; compare by value, not by Variant type.
	if not data is Dictionary or not _num(data.get("version"),1,2,true): return false
	for k in (["edits"] if data.version==1 else ["voxels","minerals"])+["trees","seeds"]:
		if not data.get(k) is Dictionary: return false
	if data.trees.size()>int(rules.max_trees) or data.seeds.size()!=seeds.size(): return false
	for k in seeds:
		if not _num(data.seeds.get(k),0,rules.max_seed_stock,true): return false
	var cells={}
	if data.version==1:
		# v0.25 and older: whole-column height offsets become explicit cells on the voxel grid.
		if data.edits.size()>int(rules.max_edits): return false
		for k in data.edits:
			var parts=str(k).split(":")
			if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
			var p=Vector2(int(parts[0]),int(parts[1]))
			if k!=cell_key(p) or not t.inside(p,3) or not _num(data.edits[k],-rules.height_change_limit,rules.height_change_limit,true): return false
			var top=t.natural_height(p); var delta=int(data.edits[k])
			for y in (range(floori(top),floori(top)+delta) if delta>0 else range(floori(top)+delta,ceili(top))):
				cells[Vector3i(int(p.x),y,int(p.y))]="topsoil" if delta>0 else ""
	else:
		if data.voxels.size()>int(rules.max_voxels) or not data.get("discovered") is Array: return false
		for k in data.voxels:
			var parts=str(k).split(":"); var id=data.voxels[k]
			if parts.size()!=3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int(): return false
			var c=Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))
			if k!="%d:%d:%d" % [c.x,c.y,c.z] or not t.inside(Vector2(c.x,c.z),3) or c.y<=Geology.bedrock_y() or c.y>int(rules.build_ceiling): return false
			if not id is String or id=="bedrock" or (id!="" and Geology.info(id).is_empty()): return false
			cells[c]=id
		for id in data.minerals:
			if Geology.info(str(id)).is_empty() or id in ["topsoil","bedrock"] or not _num(data.minerals[id],0,rules.max_mineral_stock,true): return false
		for id in data.discovered:
			if not id is String or Geology.info(id).is_empty(): return false
	for id in data.trees:
		var row=data.trees[id]
		if not row is Dictionary or not rules.species.has(row.get("species")) or not row.get("cut") is bool: return false
		if not _num(row.get("x"),-float(t.rules.radius),float(t.rules.radius)) or not _num(row.get("z"),-float(t.rules.radius),float(t.rules.radius)): return false
		var p=Vector2(row.x,row.z)
		if not t.inside(p,2): return false
		if str(id).begins_with("p:"):
			if p!=p.round() or id!="p:"+cell_key(p): return false
		elif lookup(str(id),t).is_empty() or id!=natural_id(p) or not p.is_equal_approx(Vector2(lookup(id,t).x,lookup(id,t).z)): return false
		if not _num(row.get("growth"),0.12,1) or not _num(row.get("water"),0,1) or not _num(row.get("hits"),0,int(rules.chop_hits)-1,true): return false
	voxels=cells; columns.clear(); mining={}
	for c in voxels:
		var column=Vector2i(c.x,c.z)
		if not columns.has(column): columns[column]={}
		columns[column][c.y]=true
	minerals={} if data.version==1 else data.minerals.duplicate()
	for id in minerals: minerals[id]=int(minerals[id])
	discovered={}
	if data.version==2:
		for id in data.discovered: discovered[id]=true
	trees=data.trees.duplicate(true); seeds=data.seeds.duplicate(); revision+=1; chunk_versions.clear(); planted_by_chunk.clear()
	for id in trees:
		if not str(id).begins_with("p:"): continue
		var chunk=t.chunk_at(Vector2(trees[id].x,trees[id].z))
		if not planted_by_chunk.has(chunk): planted_by_chunk[chunk]=[]
		planted_by_chunk[chunk].append(id)
	return true

func _num(n,lo: float,hi: float,whole: bool=false) -> bool:
	return (n is float or n is int) and is_finite(n) and n>=lo and n<=hi and (not whole or n==floor(n))
