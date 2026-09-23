extends RefCounted
## Finite materials and sparse solid cells. UI submits intent; ray and stock are checked here.
const Terrain = preload("res://scripts/river_terrain.gd")
var terrain = Terrain.new()
var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/river_construction.json"))
var sources: Dictionary = {}
var blocks: Dictionary = {}
var revision := 0
var obstacles: Array = []
var occupied: Dictionary = {}
var miniatures={}
var miniature_serial=1

func key(c: Vector3i) -> String:
	return "%d:%d:%d" % [c.x, c.y, c.z]

func cell(b: Dictionary) -> Vector3i:
	return Vector3i(int(b.x), int(b.y), int(b.z))

func cell_at(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x + 0.5), floori(p.y), floori(p.z + 0.5))

func base(c: Vector3i) -> int:
	return floori(terrain.ground(Vector2(c.x, c.z)))

func neighbors(c: Vector3i) -> Array:
	return [c+Vector3i.LEFT,c+Vector3i.RIGHT,c+Vector3i.UP,c+Vector3i.DOWN,c+Vector3i.FORWARD,c+Vector3i.BACK]

func connected(items: Dictionary) -> bool:
	var reached := {}; var queue: Array = []
	for k in items:
		if int(items[k].y) == base(cell(items[k])): reached[k] = true; queue.append(cell(items[k]))
	var i := 0
	while i < queue.size():
		for n in neighbors(queue[i]):
			var k := key(n)
			if items.has(k) and not reached.has(k): reached[k] = true; queue.append(n)
		i += 1
	return reached.size() == items.size()

func trace(origin: Vector3, direction: Vector3) -> Dictionary:
	var previous := cell_at(origin)
	for i in range(1, int(float(rules.reach) / 0.04) + 1):
		var p := origin + direction.normalized() * (i * 0.04)
		var c := cell_at(p); var k := key(c); var flat := Vector2(p.x,p.z)
		if blocks.has(k):
			var normal := previous - c
			if normal == Vector3i.ZERO: normal = Vector3i.UP
			# At an edge choose a single face, never a diagonal attachment.
			if normal.x != 0: normal = Vector3i(signi(normal.x),0,0)
			elif normal.y != 0: normal = Vector3i(0,signi(normal.y),0)
			else: normal = Vector3i(0,0,signi(normal.z))
			return {"hit":k,"target":c+normal,"point":p}
		if not terrain.inside(flat,1): return {}
		if p.y <= terrain.ground(flat): return {"hit":"","target":Vector3i(c.x,base(c),c.z),"point":p}
		if p.y < terrain.ground(flat)+4 and terrain.blocked(flat,obstacles): return {"blocked":true,"point":p}
		previous = c
	return {}

func overlaps(p: Vector2, feet: float, height: float) -> bool:
	var radius := float(terrain.rules.player_radius)
	for x in range(floori(p.x-radius+0.5),floori(p.x+radius+0.5)+1):
		for z in range(floori(p.y-radius+0.5),floori(p.y+radius+0.5)+1):
			for y in range(floori(feet+0.001),floori(feet+height-0.001)+1):
				if blocks.has(key(Vector3i(x,y,z))): return true
	return false

func floor_at(p: Vector2, ceiling: float) -> float:
	var h := terrain.ground(p)
	var radius := float(terrain.rules.player_radius)
	for x in range(floori(p.x-radius+0.5),floori(p.x+radius+0.5)+1):
		for z in range(floori(p.y-radius+0.5),floori(p.y+radius+0.5)+1):
			for y in range(floori(ceiling)-1, floori(h)-1, -1):
				if y+1 <= ceiling+0.001 and blocks.has(key(Vector3i(x,y,z))): h=maxf(h,y+1); break
	return h

func count_kind(kind: String, near: Vector2=Vector2(INF,INF), radius: float=INF) -> int:
	var count := 0
	for b in blocks.values():
		if b.kind == kind and (not is_finite(near.x) or Vector2(b.x,b.z).distance_to(near)<=radius): count+=1
	return count

func shelter_cells(near: Vector2, radius: float) -> int:
	var covered={}
	for b in blocks.values():
		var p=Vector2(b.x,b.z); var ground=terrain.ground(p)
		if not rules.kinds[b.kind].get("roof",false) or p.distance_to(near)>radius: continue
		ground=floor_at(p,float(b.y))
		if b.y-ground<float(terrain.rules.body_height): continue
		# Only the actual footprint under a roof counts, not exposed adjacent ground.
		if not overlaps(p,ground,float(terrain.rules.body_height)):
			covered["%d:%d" % [int(b.x),int(b.z)]]=true
	return covered.size()

func available(kind: String, products: Array, recipe_id: String="") -> int:
	var result := 0
	for s in sources.values():
		if rules.recipes[s.product.recipe].kind == kind and (recipe_id.is_empty() or s.product.recipe==recipe_id): result += int(s.remaining)
	for p in products:
		var r: Dictionary = rules.recipes.get(p.recipe,{})
		if r.get("kind") == kind and (recipe_id.is_empty() or p.recipe==recipe_id): result += int(r.units)
	return result

func place_error(c: Vector3i, actor: Dictionary) -> String:
	if blocks.size() >= int(rules.max_blocks): return "本星球已放满512块构件"
	if blocks.has(key(c)): return "这里已经有构件"
	var flat := Vector2(c.x,c.z)
	if not terrain.inside(flat,2) or c.y < base(c) or c.y > base(c)+int(rules.height_limit): return "请放在地表附近，建筑最高8层"
	if terrain.blocked(flat,obstacles): return "这里有树木或已有设施，请换一个位置"
	var feet: Vector3 = actor.feet
	if absf(feet.x-c.x)<0.8 and absf(feet.z-c.z)<0.8 and feet.y<c.y+1 and feet.y+float(terrain.rules.body_height)>c.y: return "构件会碰到你，请退开一点"
	if Vector3(c.x,c.y+0.5,c.z).distance_to(actor.eye)>float(rules.reach)+0.9: return "离得太远，请走近些"
	if c.y == base(c): return ""
	for n in neighbors(c):
		if blocks.has(key(n)): return ""
	return "构件需要连接地面或已有建筑"

func interact(mode: String, kind: String, products: Array, actor: Dictionary, recipe_id: String="") -> String:
	if actor.is_empty(): return "先进入第一人称，再瞄准近处地面或构件"
	var hit := trace(actor.eye,actor.direction)
	if hit.is_empty() or hit.has("blocked"): return "瞄准5米内的地面或自建构件；不能隔着树木施工"
	if mode == "remove":
		var k := str(hit.hit)
		if k.is_empty(): return "这里没有自建构件；挖土请装备铲子"
		if occupied.has(k): return "先收获种植箱里的作物，再拆回种植箱"
		var rest := blocks.duplicate(); rest.erase(k)
		if not connected(rest): return "上方或旁边还有依赖它的构件，请从边缘往回拆"
		var b: Dictionary = blocks[k]; sources[b.source].remaining+=1; blocks.erase(k); revision+=1
		return "已拆回1块"+str(rules.kinds[b.kind].name)+"，回到原材料包"
	if mode != "place" or not rules.kinds.has(kind): return "请选择建造工具"
	var reason := place_error(hit.target,actor)
	if not reason.is_empty(): return reason
	var source_id := ""
	for id in sources:
		if sources[id].remaining>0 and rules.recipes[sources[id].product.recipe].kind==kind and (recipe_id.is_empty() or sources[id].product.recipe==recipe_id): source_id=id; break
	if source_id.is_empty():
		if sources.size()>=int(rules.max_sources): return "施工材料包已满，请先把收齐的材料包送回浮岛"
		for i in range(products.size()):
			var p: Dictionary=products[i]; var recipe: Dictionary=rules.recipes.get(p.recipe,{})
			if recipe.get("kind")!=kind: continue
			if not recipe_id.is_empty() and p.recipe!=recipe_id: continue
			source_id=str(int(p.id)); sources[source_id]={"product":p.duplicate(true),"remaining":int(recipe.units)}
			products.remove_at(i); break
	if source_id.is_empty(): return "背包缺少对应成品；木构方块需要构件包，太阳能方块需要工坊光伏组件"
	var c: Vector3i=hit.target
	sources[source_id].remaining-=1
	blocks[key(c)]={"x":c.x,"y":c.y,"z":c.z,"kind":kind,"source":source_id}; revision+=1
	return "已搭建"+str(rules.kinds[kind].name)+"；消耗1块材料"

func repack(id: String, products: Array, limit: int) -> String:
	if not sources.has(id): return "这个材料包已收回"
	var s: Dictionary=sources[id]
	if s.remaining!=rules.recipes[s.product.recipe].units: return "先拆回这个材料包的全部构件"
	if products.size()>=limit: return "浮岛成品仓已满"
	products.append(s.product.duplicate(true)); sources.erase(id); revision+=1
	return "整包已收入浮岛成品工具箱，保留原编号与来源"

func serialize() -> Dictionary:
	return {"version":1,"sources":sources.duplicate(true),"blocks":blocks.duplicate(true),"miniatures":miniatures.duplicate(true),"miniature_serial":miniature_serial}

func restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("sources") is Dictionary or not data.get("blocks") is Dictionary: return false
	if data.sources.size()>int(rules.max_sources) or data.blocks.size()>int(rules.max_blocks): return false
	var counts := {}
	for id in data.sources:
		var s=data.sources[id]
		if not s is Dictionary or not s.get("product") is Dictionary or not rules.recipes.has(s.product.get("recipe")): return false
		if id!=str(int(s.product.get("id",-1))) or not _integer(s.get("remaining"),0,int(rules.recipes[s.product.recipe].units)): return false
		counts[id]=int(s.remaining)
	for k in data.blocks:
		var b=data.blocks[k]
		if not b is Dictionary or not rules.kinds.has(b.get("kind")) or not data.sources.has(b.get("source")): return false
		for axis in ["x","z"]:
			if not _integer(b.get(axis),-int(terrain.rules.radius),int(terrain.rules.radius)): return false
		if not _integer(b.get("y"),-16,100): return false
		var c:=cell(b)
		if key(c)!=k or not terrain.inside(Vector2(c.x,c.z),2) or c.y<base(c) or c.y>base(c)+int(rules.height_limit): return false
		if rules.recipes[data.sources[b.source].product.recipe].kind!=b.kind: return false
		counts[b.source]+=1
	var boxes=data.get("miniatures",{})
	if not boxes is Dictionary or boxes.size()>16 or not _integer(data.get("miniature_serial",1),1,1000000): return false
	for id in boxes:
		var box=boxes[id]
		if not box is Dictionary or box.get("id")!=id or not str(id).is_valid_int() or int(id)<1 or int(id)>=int(data.get("miniature_serial",1)): return false
		if not box.get("name") is String or box.name.length()>64 or not _integer(box.get("plot"),-1,4096) or not box.get("blocks") is Array or box.blocks.is_empty() or box.blocks.size()>64: return false
		var seen={}
		for b in box.blocks:
			if not b is Dictionary or not rules.kinds.has(b.get("kind")) or not data.sources.has(b.get("source")): return false
			for axis in ["x","y","z"]:
				if not _integer(b.get(axis),0,7): return false
			var k=key(cell(b))
			if seen.has(k) or rules.recipes[data.sources[b.source].product.recipe].kind!=b.kind: return false
			seen[k]=true; counts[b.source]+=1
	for id in counts:
		if counts[id]!=int(rules.recipes[data.sources[id].product.recipe].units): return false
	if not connected(data.blocks): return false
	sources=data.sources.duplicate(true); blocks=data.blocks.duplicate(true); miniatures=boxes.duplicate(true); miniature_serial=int(data.get("miniature_serial",1)); revision+=1
	return true

func _integer(value, lo: int, hi: int) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=lo and value<=hi
