extends RefCounted
## v0.27 Hometown: the tile grid inside each 3 m island plot. Pure geometry and rules; the wallet
## and residents stay in lab_state. Tile (0,0) is the plot's north-west corner at local (-1.5,-1.5).
## v0.31: every tile is buildable and tiles are global across the island (plot p's tile (x,z) is
## (p.x*12+x, p.z*12+z)). An item belongs to the plot holding its anchor tile, but its footprint may
## spill onto unlocked neighbours, so placement checks go through island_fits().
static var data: Dictionary={}
const LEGACY_WHOLE=["road","fence","sculpture"]

static func rules() -> Dictionary:
	if data.is_empty(): data=JSON.parse_string(FileAccess.get_file_as_string("res://data/town_items.json"))
	return data

static func tile() -> float: return float(rules().tile)
static func usable() -> int: return int(rules().usable)
static func grid() -> int: return int(rules().grid)

static func info(kind: String) -> Dictionary:
	return rules().items.get(kind,{})

static func building_kind(kind: String) -> String:
	if kind=="house": return "engineer_house"
	if kind=="garden": return "park"
	return kind

static func is_building(kind: String) -> bool:
	return rules().building_footprint.has(building_kind(kind))

static func is_decor(kind: String) -> bool:
	return rules().items.has(kind)

## Footprint in tiles after rotation (rot counts quarter turns).
static func size(kind: String, rot: int=0) -> Vector2i:
	if is_building(kind):
		var n=int(rules().building_footprint[building_kind(kind)])
		return Vector2i(n,n)
	var s: Array=info(kind).get("size",[1,1])
	return Vector2i(int(s[1]),int(s[0])) if posmod(rot,2)==1 else Vector2i(int(s[0]),int(s[1]))

## Local position (relative to the plot centre) of a footprint's centre.
static func center(at: Vector2i, footprint: Vector2i) -> Vector3:
	var t=tile()
	return Vector3(-1.5+(at.x+footprint.x*0.5)*t,0,-1.5+(at.y+footprint.y*0.5)*t)

static func tile_at(local: Vector3) -> Vector2i:
	return Vector2i(floori((local.x+1.5)/tile()),floori((local.z+1.5)/tile()))

## The 8 legacy courtyard slots (v0.9 props) keep their places on the rim.
static func prop_tile(slot: int) -> Vector2i:
	return [Vector2i(1,1),Vector2i(6,1),Vector2i(10,1),Vector2i(10,6),Vector2i(10,10),Vector2i(6,10),Vector2i(1,10),Vector2i(1,6)][clampi(slot,0,7)]

static func primary_anchor(plot: Dictionary) -> Vector2i:
	var at=plot.get("at",null)
	if at is Array and at.size()==2: return Vector2i(int(at[0]),int(at[1]))
	return default_anchor(plot,str(plot.kind))

## Legacy buildings (and callers that give no position) sit in the middle, clear of the 8 old prop
## slots, as they always looked; the corners are the fallback. Players pick corners in build mode.
static func default_anchor(plot: Dictionary, kind: String) -> Vector2i:
	var n=size(kind)
	var candidates=[Vector2i((usable()-n.x)/2,(usable()-n.y)/2),Vector2i(0,0),Vector2i(usable()-n.x,0),Vector2i(0,usable()-n.y),Vector2i(usable()-n.x,usable()-n.y)]
	if n.x>=8: candidates.push_front(Vector2i(2,2))
	var probe=plot.duplicate(); probe.kind="empty"; probe.items=[]
	for c in candidates:
		if fits(probe,kind,c,0).is_empty(): return c
	return candidates[0]

## Rect (position, size) reserved by the plot's main content, or an empty rect.
static func primary_rect(plot: Dictionary) -> Rect2i:
	var kind=str(plot.get("kind","empty"))
	if kind=="empty": return Rect2i()
	if kind=="plaza" or kind in LEGACY_WHOLE: return Rect2i(0,0,usable(),usable())
	if kind=="reactor":
		var r: Array=rules().reactor_footprint
		return Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
	if is_building(kind): return Rect2i(primary_anchor(plot),size(kind))
	return Rect2i(0,0,usable(),usable())

static func item_rect(item: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(item.x),int(item.z)),size(str(item.kind),int(item.get("rot",0))))

## Owner of each occupied tile: "p" for the main content, "s<slot>" for props, uid for items.
static func occupancy(plot: Dictionary, ignore_uid: int=-1, ignore_primary: bool=false) -> Dictionary:
	var cells={}
	if not ignore_primary:
		var main=primary_rect(plot)
		for x in range(main.position.x,main.end.x):
			for z in range(main.position.y,main.end.y): cells[Vector2i(x,z)]="p"
	for prop in plot.get("props",[]): cells[prop_tile(int(prop.slot))]="s%d" % int(prop.slot)
	for item in plot.get("items",[]):
		if int(item.uid)==ignore_uid: continue
		var r=item_rect(item)
		for x in range(r.position.x,r.end.x):
			for z in range(r.position.y,r.end.y): cells[Vector2i(x,z)]=int(item.uid)
	return cells

static func fits(plot: Dictionary, kind: String, at: Vector2i, rot: int, ignore_uid: int=-1, ignore_primary: bool=false) -> String:
	var n=size(kind,rot)
	if at.x<0 or at.y<0 or at.x+n.x>usable() or at.y+n.y>usable(): return "超出地块边界"
	var cells=occupancy(plot,ignore_uid,ignore_primary)
	for x in range(at.x,at.x+n.x):
		for z in range(at.y,at.y+n.y):
			if cells.has(Vector2i(x,z)): return "这里已经被占用了"
	return ""

## First free position scanning row by row, or (-1,-1).
static func first_fit(plot: Dictionary, kind: String, rot: int=0) -> Vector2i:
	var n=size(kind,rot)
	for z in range(usable()-n.y+1):
		for x in range(usable()-n.x+1):
			if fits(plot,kind,Vector2i(x,z),rot).is_empty(): return Vector2i(x,z)
	return Vector2i(-1,-1)

# --- v0.31 island-wide tiles ---------------------------------------------------------------

static func to_global(plot: Dictionary, local: Vector2i) -> Vector2i:
	return Vector2i(int(plot.x)*grid()+local.x,int(plot.z)*grid()+local.y)

## Global tile under a world-space point (plot centres sit on a 3 m pitch).
static func global_at(point: Vector3) -> Vector2i:
	return Vector2i(floori((point.x+1.5)/tile()),floori((point.z+1.5)/tile()))

static func plot_of(global: Vector2i) -> Vector2i:
	return Vector2i(floori(float(global.x)/grid()),floori(float(global.y)/grid()))

static func coord_lookup(plots: Array) -> Dictionary:
	var out={}
	for i in range(plots.size()): out[Vector2i(int(plots[i].x),int(plots[i].z))]=i
	return out

## Owner of every occupied global tile: [plot index, id] with id "p", "s<slot>" or the item uid as a
## string. With around>=0 only plots within two steps are read: a footprint (at most 8 tiles) can
## reach one neighbour, so nothing further away can touch a footprint anchored in that plot.
static func island_cells(plots: Array, around: int=-1) -> Dictionary:
	var cells={}
	var centre=Vector2i(int(plots[around].x),int(plots[around].z)) if around>=0 else Vector2i.ZERO
	for i in range(plots.size()):
		var p: Dictionary=plots[i]
		if around>=0 and (absi(int(p.x)-centre.x)>2 or absi(int(p.z)-centre.y)>2): continue
		var local: Dictionary=occupancy(p)
		for cell in local: cells[to_global(p,cell)]=[i,str(local[cell])]
	return cells

## Empty when every tile of rect (local to plot owner) lies on unlocked land and is free. ignore
## lists "plot:id" owners that don't count (the thing being moved).
static func island_free(plots: Array, owner: int, rect: Rect2i, ignore: Array=[]) -> String:
	var lookup=coord_lookup(plots)
	var cells=island_cells(plots,owner)
	var base=to_global(plots[owner],rect.position)
	for x in range(rect.size.x):
		for z in range(rect.size.y):
			var g=base+Vector2i(x,z)
			var host=int(lookup.get(plot_of(g),-1))
			if host<0 or not bool(plots[host].get("unlocked",false)): return "超出已开拓的土地"
			var who=cells.get(g)
			if who==null or "%d:%s" % [int(who[0]),who[1]] in ignore: continue
			if plots[host].kind=="plaza": return "迎客广场保留通行空间"
			return "这里已经被占用了"
	return ""

## The anchor stays inside the owner plot; the rest may spill over its edges. ignore as in island_free.
static func island_fits(plots: Array, owner: int, kind: String, at: Vector2i, rot: int, ignore: Array=[]) -> String:
	if owner<0 or owner>=plots.size(): return "请选择已开拓的地块"
	if at.x<0 or at.y<0 or at.x>=grid() or at.y>=grid(): return "请把物品放在所选地块内"
	return island_free(plots,owner,Rect2i(at,size(kind,rot)),ignore)

## A free anchor in the plot: footprints fully inside the plot first, then ones that spill over.
static func island_first_fit(plots: Array, owner: int, kind: String, rot: int=0) -> Vector2i:
	var n=size(kind,rot)
	for z in range(grid()-n.y+1):
		for x in range(grid()-n.x+1):
			if island_fits(plots,owner,kind,Vector2i(x,z),rot).is_empty(): return Vector2i(x,z)
	for z in range(grid()):
		for x in range(grid()):
			if x+n.x<=grid() and z+n.y<=grid(): continue
			if island_fits(plots,owner,kind,Vector2i(x,z),rot).is_empty(): return Vector2i(x,z)
	return Vector2i(-1,-1)

## Load check across plots: items never share a tile with anything, nothing crosses onto another
## plot's content, and every covered tile is unlocked land. A plot's own main content and legacy
## props may overlap each other, as they always could.
static func valid_island(plots: Array) -> bool:
	var lookup=coord_lookup(plots)
	var seen={}
	for i in range(plots.size()):
		var p: Dictionary=plots[i]
		var own: Array=[]
		var main=primary_rect(p)
		if main.size.x>0: own.append(main)
		for prop in p.get("props",[]): own.append(Rect2i(prop_tile(int(prop.slot)),Vector2i.ONE))
		var items: Array=[]
		for item in p.get("items",[]): items.append(item_rect(item))
		for stage in range(2):
			for r in [own,items][stage]:
				for x in range(r.position.x,r.end.x):
					for z in range(r.position.y,r.end.y):
						var g=to_global(p,Vector2i(x,z))
						if seen.has(g) and (stage==1 or int(seen[g])!=i): return false
						seen[g]=i
						var host=int(lookup.get(plot_of(g),-1))
						if host<0 or not bool(plots[host].get("unlocked",false)): return false
	return true

## Visual tier (1 wood, 2 brick, 3 glass) spread across a building's levels.
static func tier(level: int, max_level: int) -> int:
	if max_level<=1: return 1
	return 1+roundi(float(clampi(level,1,max_level)-1)*2.0/float(max_level-1))

static func _int(v, low: int, high: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)==floor(float(v)) and v>=low and v<=high

## Structural check of one saved plot; cross-plot rules (uids, exhibits) live in lab_state.
static func valid_plot(plot: Dictionary, building_kinds: Array) -> bool:
	var at=plot.get("at",null)
	if at!=null:
		if not at is Array or at.size()!=2 or not _int(at[0],0,grid()-1) or not _int(at[1],0,grid()-1): return false
		if not is_building(str(plot.get("kind",""))): return false
	var items=plot.get("items",[])
	if not items is Array or items.size()>int(rules().max_items_per_plot): return false
	if not items.is_empty() and not bool(plot.get("unlocked",false)): return false
	for item in items:
		if not item is Dictionary or not _int(item.get("uid"),1,100000000) or not _int(item.get("x"),0,grid()-1) or not _int(item.get("z"),0,grid()-1) or not _int(item.get("rot",0),0,3): return false
		var kind=str(item.get("kind",""))
		if is_building(kind):
			if not kind in building_kinds or not _int(item.get("level"),1,5): return false
		elif not is_decor(kind): return false
		var show=item.get("show",{})
		if not show is Dictionary: return false
		if not show.is_empty():
			if not bool(info(kind).get("display",false)) or show.get("type") not in ["mineral","mini"] or not show.get("id") is String: return false
	return true
