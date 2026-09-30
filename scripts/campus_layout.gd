extends RefCounted
## Geometry and topology only; wallet and population belong to other modules.
const PITCH=3.0
const DIRECTIONS=[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const Town=preload("res://scripts/island_town.gd")
var config: Dictionary={}
var revision: int=0
var plaza_index: int=-1
var _cached_revision: int=-1
var _links: Dictionary={}
var _routes: Dictionary={}

func _init() -> void:
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/campus_buildings.json"))

func building_kinds() -> Array:
	return config.buildings.keys()

func building_info(kind: String) -> Dictionary:
	if kind=="house": kind="engineer_house"
	if kind=="garden": kind="park"
	return config.buildings.get(kind,{}).duplicate(true)

func initialize(plots: Array, migrate: bool=false) -> void:
	plaza_index=-1
	for i in range(plots.size()):
		var p: Dictionary=plots[i]
		if not p.has("road"): p.road=bool(p.unlocked)
		p.building_level=int(p.get("building_level",1))
		if not p.has("props"): p.props=[]
		for prop in p.props: prop.slot=int(prop.slot)
		if p.kind=="road": p.kind="empty"; p.road=true
		if p.kind=="plaza": plaza_index=i
		pin(p)
	if plaza_index<0:
		# Attach to existing island, never replace an occupied player building.
		var candidates: Array=range(9,plots.size())
		for i in range(plots.size()):
			if plots[i].x==0 and plots[i].z==2 and i in candidates:
				candidates.erase(i); candidates.push_front(i); break
		for i in candidates:
			if plots[i].kind=="empty" and not plots[i].unlocked:
				for p in plots:
					if p.unlocked and absi(int(p.x)-int(plots[i].x))+absi(int(p.z)-int(plots[i].z))==1:
						plaza_index=i
						break
			if plaza_index>=0: break
		if plaza_index>=0:
			plots[plaza_index].kind="plaza"
			plots[plaza_index].unlocked=true
			plots[plaza_index].road=true
			plots[plaza_index].rid=-1
	mark_changed()

## v0.27: every unlocked plot carries an item list, and a main building gets a fixed tile anchor
## once, so later items can never shift a legacy building.
func pin(p: Dictionary) -> void:
	if not p.has("items"): p.items=[]
	for item in p.items:
		for key in ["uid","x","z","rot","level"]:
			if item.has(key): item[key]=int(item[key])
	if p.get("at") is Array: p.at=[int(p.at[0]),int(p.at[1])]
	if Town.is_building(str(p.kind)):
		if not p.get("at") is Array:
			var anchor=Town.default_anchor(p,str(p.kind))
			p.at=[anchor.x,anchor.y]
	elif p.has("at"): p.erase("at")

func mark_changed() -> void:
	revision+=1
	_routes.clear()

func road_links(plots: Array) -> Dictionary:
	if _cached_revision==revision: return _links
	_links={}
	var lookup={}
	for i in range(plots.size()):
		var p: Dictionary=plots[i]
		# v0.27.1: paths connect automatically; the saved road flag is legacy only.
		if bool(p.unlocked):
			lookup[Vector2i(int(p.x),int(p.z))]=i
			_links[i]=[]
	for coordinate in lookup:
		for direction in DIRECTIONS:
			if lookup.has(coordinate+direction): _links[lookup[coordinate]].append(lookup[coordinate+direction])
	_cached_revision=revision
	return _links

func reachable(plots: Array, origin: int=-1) -> Array:
	if origin<0: origin=plaza_index
	var graph=road_links(plots)
	if not graph.has(origin): return []
	var queue: Array=[origin]
	var seen={origin:true}
	var cursor=0
	while cursor<queue.size():
		var current=int(queue[cursor]); cursor+=1
		for neighbor in graph[current]:
			if not seen.has(neighbor): seen[neighbor]=true; queue.append(neighbor)
	return queue

func hub(plots: Array, index: int) -> Vector3:
	if index<0 or index>=plots.size(): return Vector3.ZERO
	return Vector3(float(plots[index].x)*PITCH+1.35,0.11,float(plots[index].z)*PITCH+1.35)

func route(plots: Array, from_index: int, to_index: int) -> Array:
	var key="%d:%d" % [from_index,to_index]
	if _routes.has(key): return _routes[key]
	var graph=road_links(plots)
	if not graph.has(from_index) or not graph.has(to_index): return []
	var queue: Array=[from_index]
	var previous={from_index:-1}
	var cursor=0
	while cursor<queue.size():
		var current=int(queue[cursor]); cursor+=1
		if current==to_index: break
		for neighbor in graph[current]:
			if not previous.has(neighbor): previous[neighbor]=current; queue.append(neighbor)
	if not previous.has(to_index): return []
	var path: Array=[]
	var step=to_index
	while step>=0:
		path.push_front(hub(plots,step))
		step=int(previous[step])
	_routes[key]=path
	return path

func capacity(plot: Dictionary) -> int:
	var info=building_info(str(plot.kind))
	return 0 if info.is_empty() else int(info.capacity)+(int(plot.get("building_level",1))-1)*int(info.capacity_per_level)

## One entry per (plot, kind): several homes of one kind on a plot pool their beds, because
## residents are addressed by plot.
func buildings(plots: Array) -> Array:
	var connected=reachable(plots)
	var output: Array=[]
	for i in range(plots.size()):
		var p: Dictionary=plots[i]
		if not p.unlocked: continue
		var parts: Array=[]
		if not building_info(p.kind).is_empty(): parts.append(p)
		for item in p.get("items",[]):
			if Town.is_building(str(item.kind)): parts.append({"kind":item.kind,"building_level":int(item.level)})
		var merged={}; var order: Array=[]
		for part in parts:
			var kind=Town.building_kind(str(part.kind))
			if not merged.has(kind):
				merged[kind]={"plot":i,"kind":kind,"capacity":0,"level":0,"count":0,"connected":i in connected}; order.append(kind)
			merged[kind].capacity+=capacity(part); merged[kind].count+=1
			merged[kind].level=maxi(int(merged[kind].level),int(part.get("building_level",1)))
		for kind in order: output.append(merged[kind])
	return output

func kind_capacity(plots: Array, plot: int, kind: String) -> int:
	for b in buildings(plots):
		if int(b.plot)==plot and b.kind==Town.building_kind(kind): return int(b.capacity)
	return 0

func valid_plot_fields(plot: Dictionary) -> bool:
	if not plot.get("road",false) is bool or not plot.get("props",[]) is Array: return false
	var level=plot.get("building_level",1)
	if not (level is float or level is int) or not is_finite(float(level)) or floor(float(level))!=float(level) or level<1 or level>5: return false
	if plot.get("props",[]).size()>8: return false
	var seen={}
	for prop in plot.get("props",[]):
		if not prop is Dictionary or not config.props.has(prop.get("kind","")): return false
		var slot=prop.get("slot",-1)
		if not (slot is float or slot is int) or slot!=floor(float(slot)) or slot<0 or slot>7 or seen.has(int(slot)): return false
		seen[int(slot)]=true
	return Town.valid_plot(plot,building_kinds())
