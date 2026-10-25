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

# --- v0.44 building materials: a kind's shape decides how much of its cell is solid ---------------
func shape_of(kind: String) -> Dictionary:
	return rules.get("shapes",{}).get(str(rules.kinds.get(kind,{}).get("shape","")),{})

func is_door(b: Dictionary) -> bool:
	return bool(shape_of(str(b.get("kind",""))).get("door",false))

## The block filling cell c: its own, or the door standing in the cell below (doors are 2 cells).
func occupant(c: Vector3i) -> Dictionary:
	var b: Dictionary=blocks.get(key(c),{})
	if not b.is_empty(): return b
	var below: Dictionary=blocks.get(key(c+Vector3i.DOWN),{})
	if not below.is_empty() and is_door(below): return below
	return {}

## Which way a rotated piece faces: 0 −z, 1 +x, 2 +z, 3 −x (the way the builder was looking).
const FACING=[Vector2(0,-1),Vector2(1,0),Vector2(0,1),Vector2(-1,0)]
static func facing_rot(direction: Vector3) -> int:
	var d=Vector2(direction.x,direction.z)
	if d.length()<0.001: return 0
	var best=0
	for r in range(4):
		if d.dot(FACING[r])>d.dot(FACING[best]): best=r
	return best

## Solid height above the floor of cell `c` at ground point p (0 = you can walk through it).
## Slopes rise 0→1 away from where the builder stood; slabs are half a cell; open doors are open.
func solid_height(b: Dictionary, c: Vector3i, p: Vector2) -> float:
	var shape=shape_of(str(b.kind))
	if shape.is_empty(): return 1.0
	if shape.get("door",false): return 0.0 if b.get("open",false) else 1.0
	if shape.get("slope",false):
		var t=(p-Vector2(c.x,c.z)).dot(FACING[int(b.get("rot",0))])+0.5
		return clampf(t,0.05,1.0)
	return float(shape.get("height",1.0))

## Walls for the settlement: the old wooden block plus every brick and window kind.
func count_walls(near: Vector2=Vector2(INF,INF), radius: float=INF) -> int:
	var count := 0
	for b in blocks.values():
		if (b.kind=="block" or rules.kinds[b.kind].get("wall",false)) and not is_native(b) and (not is_finite(near.x) or Vector2(b.x,b.z).distance_to(near)<=radius): count+=1
	return count

## v0.44: open or close a door. Closing is refused while you stand in the doorway.
func toggle_door(k: String, actor: Dictionary) -> String:
	var b: Dictionary=blocks.get(k,{})
	if b.is_empty() or not is_door(b): return "这里没有门"
	if b.get("open",false) and actor.has("feet"):
		var feet: Vector3=actor.feet; var r=float(terrain.rules.player_radius)
		if absf(feet.x-b.x)<0.5+r and absf(feet.z-b.z)<0.5+r and feet.y<b.y+2 and feet.y+float(terrain.rules.body_height)>b.y: return "先走出门洞再关门"
	b.open=not b.get("open",false); revision+=1
	return "%s开了" % rules.kinds[b.kind].name if b.open else "%s关上了" % rules.kinds[b.kind].name

func neighbors(c: Vector3i) -> Array:
	return [c+Vector3i.LEFT,c+Vector3i.RIGHT,c+Vector3i.UP,c+Vector3i.DOWN,c+Vector3i.FORWARD,c+Vector3i.BACK]

func connected(items: Dictionary) -> bool:
	var reached := {}; var queue: Array = []
	# A door's upper half is part of the door: things beside or above it connect through it.
	var uppers := {}
	for k in items:
		if is_door(items[k]): uppers[key(cell(items[k])+Vector3i.UP)] = k
	for k in items:
		if int(items[k].y) == base(cell(items[k])):
			reached[k] = true; queue.append(cell(items[k]))
			if is_door(items[k]): queue.append(cell(items[k])+Vector3i.UP)
	var i := 0
	while i < queue.size():
		for n in neighbors(queue[i]):
			var k := key(n); var owner: String = k if items.has(k) else str(uppers.get(k,""))
			if owner != "" and not reached.has(owner):
				reached[owner] = true; queue.append(cell(items[owner]))
				if is_door(items[owner]): queue.append(cell(items[owner])+Vector3i.UP)
		i += 1
	return reached.size() == items.size()

func trace(origin: Vector3, direction: Vector3) -> Dictionary:
	var previous := cell_at(origin)
	for i in range(1, int(float(rules.reach) / 0.04) + 1):
		var p := origin + direction.normalized() * (i * 0.04)
		var c := cell_at(p); var flat := Vector2(p.x,p.z)
		var occ := occupant(c)
		if not occ.is_empty():
			# v0.44: only the solid part of a slab or slope stops the ray; doors are always aimable.
			var solid := 1.0 if is_door(occ) else solid_height(occ,c,flat)
			if p.y < c.y + solid + 0.001:
				return {"hit":key(cell(occ)),"target":c+_face(previous-c),"point":p}
		if not terrain.inside(flat,1): return {}
		if terrain.solid(c) and p.y < c.y + terrain.cell_height(c):
			var normal := _face(previous-c)
			# A slab's top face builds into the slab cell itself (the block encloses it).
			var target := c if normal == Vector3i.UP and terrain.cell_height(c) < 1.0 else c+normal
			return {"hit":"","voxel":c,"target":target,"point":p}
		if p.y < terrain.ground(flat)+4 and terrain.blocked(flat,obstacles): return {"blocked":true,"point":p}
		if terrain.bridge(flat) and p.y <= terrain.ground(flat): return {"hit":"","target":Vector3i(c.x,base(c),c.z),"point":p}
		previous = c
	return {}

## At an edge choose a single face, never a diagonal attachment.
func _face(normal: Vector3i) -> Vector3i:
	if normal == Vector3i.ZERO: return Vector3i.UP
	if normal.x != 0: return Vector3i(signi(normal.x),0,0)
	if normal.y != 0: return Vector3i(0,signi(normal.y),0)
	return Vector3i(0,0,signi(normal.z))

func overlaps(p: Vector2, feet: float, height: float) -> bool:
	var radius := float(terrain.rules.player_radius)
	for x in range(floori(p.x-radius+0.5),floori(p.x+radius+0.5)+1):
		for z in range(floori(p.y-radius+0.5),floori(p.y+radius+0.5)+1):
			for y in range(floori(feet+0.001),floori(feet+height-0.001)+1):
				var c := Vector3i(x,y,z); var occ := occupant(c)
				if occ.is_empty(): continue
				var top := y + solid_height(occ,c,p)
				if top > y + 0.001 and feet < top - 0.001: return true
	return false

func floor_at(p: Vector2, ceiling: float) -> float:
	if not p.is_finite() or is_nan(ceiling) or ceiling==-INF: return -INF
	var radius := float(terrain.rules.player_radius)
	var h := -INF
	for x in range(floori(p.x-radius+0.5),floori(p.x+radius+0.5)+1):
		for z in range(floori(p.y-radius+0.5),floori(p.y+radius+0.5)+1):
			h=maxf(h,terrain.floor_below(x,z,ceiling))
	if terrain.bridge(p) and terrain.ground(p) <= ceiling+0.001: h=maxf(h,terrain.ground(p))
	if not is_finite(h): return h
	# Aircraft placement asks for the highest surface with ceiling=INF. Converting
	# INF to an integer is platform-dependent and can start a near-endless loop on
	# ARM. For high/unbounded queries inspect actual blocks, never empty sky cells.
	if ceiling>h+float(rules.height_limit)+2.0:
		var min_x=floori(p.x-radius+0.5); var max_x=floori(p.x+radius+0.5)
		var min_z=floori(p.y-radius+0.5); var max_z=floori(p.y+radius+0.5)
		for b in blocks.values():
			if int(b.x)<min_x or int(b.x)>max_x or int(b.z)<min_z or int(b.z)>max_z: continue
			var height=solid_height(b,cell(b),p)
			var top=float(b.y)+height
			if height>0.0 and top<=ceiling+0.001: h=maxf(h,top)
		return h
	for x in range(floori(p.x-radius+0.5),floori(p.x+radius+0.5)+1):
		for z in range(floori(p.y-radius+0.5),floori(p.y+radius+0.5)+1):
			for y in range(floori(ceiling), floori(h)-1, -1):
				var c := Vector3i(x,y,z); var occ := occupant(c)
				if occ.is_empty(): continue
				var s := solid_height(occ,c,p)
				if s > 0.0 and y+s <= ceiling+0.001: h=maxf(h,y+s); break
	return h

func count_kind(kind: String, near: Vector2=Vector2(INF,INF), radius: float=INF) -> int:
	var count := 0
	for b in blocks.values():
		if b.kind == kind and not is_native(b) and (not is_finite(near.x) or Vector2(b.x,b.z).distance_to(near)<=radius): count+=1
	return count

## v0.39: a built piece of `kind` within `radius` m of a point (campfires for warmth).
func near_kind(kind: String, at: Vector3, radius: float) -> bool:
	for b in blocks.values():
		if str(b.kind)==kind and Vector3(b.x,b.y,b.z).distance_to(at)<=radius: return true
	return false

## A roof-type block in the 4 cells above the feet: the player stands under shelter.
func roof_over(feet: Vector3) -> bool:
	var c=cell_at(feet)
	for dy in range(1,5):
		var b: Dictionary=blocks.get(key(c+Vector3i(0,dy,0)),{})
		if not b.is_empty() and rules.kinds[b.kind].get("roof",false): return true
	return false

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

## v0.49: blocks a native tribe built (source "native:tribe") have their own cap and ledger.
func is_native(b: Dictionary) -> bool:
	return str(b.get("source","")).begins_with("native:")

func native_count() -> int:
	var n := 0
	for b in blocks.values(): n += 1 if is_native(b) else 0
	return n

func place_error(c: Vector3i, actor: Dictionary, check_reach: bool=true, kind: String="") -> String:
	if blocks.size()-native_count() >= int(rules.max_blocks): return "本星球已放满512块构件"
	if not occupant(c).is_empty(): return "这里已经有构件"
	var tall: bool = bool(shape_of(kind).get("door",false))
	if tall:
		var up := c+Vector3i.UP
		if not occupant(up).is_empty() or (terrain.solid(up) and terrain.cell_height(up) > 0.0): return "门有两格高，上面一格要空着"
		if up.y > base(c)+int(rules.height_limit): return "请放在地表附近，建筑最高8层"
	var below: Dictionary=blocks.get(key(c+Vector3i.DOWN),{})
	if not below.is_empty() and rules.kinds[below.kind].get("machine",false): return "环境设备上方要留空，不能叠放构件"
	var flat := Vector2(c.x,c.z)
	if not terrain.inside(flat,2) or c.y < base(c) or c.y > base(c)+int(rules.height_limit): return "请放在地表附近，建筑最高8层"
	if terrain.blocked(flat,obstacles): return "这里有树木或已有设施，请换一个位置"
	if terrain.solid(c) and terrain.cell_height(c) >= 1.0: return "这里被岩土占据，请换一个位置"
	var feet: Vector3 = actor.feet
	if absf(feet.x-c.x)<0.8 and absf(feet.z-c.z)<0.8 and feet.y<c.y+(2 if tall else 1) and feet.y+float(terrain.rules.body_height)>c.y: return "构件会碰到你，请退开一点"
	if check_reach and Vector3(c.x,c.y+0.5,c.z).distance_to(actor.eye)>float(rules.reach)+0.9: return "离得太远，请走近些"
	if c.y == base(c): return ""
	for n in neighbors(c):
		if not occupant(n).is_empty(): return ""
	return "构件需要连接地面或已有建筑"

func interact(mode: String, kind: String, products: Array, actor: Dictionary, recipe_id: String="") -> String:
	if actor.is_empty(): return "先进入第一人称，再瞄准近处地面或构件"
	var hit := trace(actor.eye,actor.direction)
	if hit.is_empty() or hit.has("blocked"): return "瞄准5米内的地面或自建构件；不能隔着树木施工"
	if mode == "remove":
		var k := str(hit.hit)
		if k.is_empty(): return "这里没有自建构件；挖土请装备铲子"
		if occupied.has(k): return "先收获作物、用完土壤余肥，或清空设施余料，再拆回"
		var rest := blocks.duplicate(); rest.erase(k)
		if not connected(rest): return "上方或旁边还有依赖它的构件，请从边缘往回拆"
		var b: Dictionary = blocks[k]
		if is_native(b):
			# v0.49: taking a tribe's block gives you nothing; they notice and rebuild it.
			blocks.erase(k); revision+=1
			return "拆下了部落的"+str(rules.kinds[b.kind].name)+"——这是他们的东西，部落会不高兴，也会把它补回去"
		sources[b.source].remaining+=1; blocks.erase(k); revision+=1
		return "已拆回1块"+str(rules.kinds[b.kind].name)+"，回到原材料包"
	if mode != "place" or not rules.kinds.has(kind): return "请选择建造工具"
	var reason := place_error(hit.target,actor,true,kind)
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
	var piece := {"x":c.x,"y":c.y,"z":c.z,"kind":kind,"source":source_id}
	var shape := shape_of(kind)
	if shape.get("rotate",false): piece["rot"]=facing_rot(actor.get("direction",Vector3.FORWARD))
	if shape.get("door",false): piece["open"]=false
	blocks[key(c)]=piece; revision+=1
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
	if data.sources.size()>int(rules.max_sources) or data.blocks.size()>int(rules.max_blocks)+NATIVE_MAX: return false
	var natives := 0
	var counts := {}
	for id in data.sources:
		var s=data.sources[id]
		if not s is Dictionary or not s.get("product") is Dictionary or not rules.recipes.has(s.product.get("recipe")): return false
		if id!=str(int(s.product.get("id",-1))) or not _integer(s.get("remaining"),0,int(rules.recipes[s.product.recipe].units)): return false
		counts[id]=int(s.remaining)
	for k in data.blocks:
		var b=data.blocks[k]
		if b is Dictionary and str(b.get("source","")).begins_with("native:"):
			# A tribe's block: no product ledger; its kind and place are checked by the natives model.
			natives += 1
			if str(b.source)!="native:tribe" or not b.get("kind") in NATIVE_KIT or natives>NATIVE_MAX: return false
			for axis in ["x","z"]:
				if not _integer(b.get(axis),-int(terrain.rules.radius),int(terrain.rules.radius)): return false
			if not _integer(b.get("y"),-16,100) or key(cell(b))!=k: return false
			continue
		if not b is Dictionary or not rules.kinds.has(b.get("kind")) or not data.sources.has(b.get("source")): return false
		for axis in ["x","z"]:
			if not _integer(b.get(axis),-int(terrain.rules.radius),int(terrain.rules.radius)): return false
		if not _integer(b.get("y"),-16,100): return false
		var c:=cell(b)
		if key(c)!=k or not terrain.inside(Vector2(c.x,c.z),2) or c.y<base(c) or c.y>base(c)+int(rules.height_limit): return false
		if rules.recipes[data.sources[b.source].product.recipe].kind!=b.kind: return false
		if not _piece_ok(b): return false
		if is_door(b) and (data.blocks.has(key(c+Vector3i.UP)) or c.y+1>base(c)+int(rules.height_limit)): return false
		counts[b.source]+=1
	var boxes=data.get("miniatures",{})
	if not boxes is Dictionary or boxes.size()>16 or not _integer(data.get("miniature_serial",1),1,1000000): return false
	for id in boxes:
		var box=boxes[id]
		if not box is Dictionary or box.get("id")!=id or not str(id).is_valid_int() or int(id)<1 or int(id)>=int(data.get("miniature_serial",1)): return false
		if not box.get("name") is String or box.name.length()>64 or not _integer(box.get("plot"),-2,4096) or not box.get("blocks") is Array or box.blocks.is_empty() or box.blocks.size()>256: return false
		# v0.37.1 display replicas copy the shape, not the material: their pieces are not counted.
		if not box.get("replica",false) is bool: return false
		var replica: bool=box.get("replica",false)
		var seen={}
		for b in box.blocks:
			if not b is Dictionary or not rules.kinds.has(b.get("kind")) or not data.sources.has(b.get("source")): return false
			for axis in ["x","y","z"]:
				if not _integer(b.get(axis),0,7): return false
			var k=key(cell(b))
			if seen.has(k) or rules.recipes[data.sources[b.source].product.recipe].kind!=b.kind or not _piece_ok(b): return false
			seen[k]=true
			if not replica: counts[b.source]+=1
	for id in counts:
		if counts[id]!=int(rules.recipes[data.sources[id].product.recipe].units): return false
	if data.blocks.size()-natives>int(rules.max_blocks): return false
	if not connected(data.blocks): return false
	sources=data.sources.duplicate(true); blocks=data.blocks.duplicate(true); miniatures=boxes.duplicate(true); miniature_serial=int(data.get("miniature_serial",1)); revision+=1
	return true

## v0.44: `rot` only on rotating shapes (0–3), `open` only on doors (bool).
func _piece_ok(b: Dictionary) -> bool:
	var shape := shape_of(str(b.kind))
	if b.has("rot") and (not shape.get("rotate",false) or not _integer(b.rot,0,3)): return false
	if b.has("open") and (not shape.get("door",false) or not b.open is bool): return false
	return true

const NATIVE_KIT := ["block","roof","campfire"]
const NATIVE_MAX := 64

func _integer(value, lo: int, hi: int) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=lo and value<=hi
