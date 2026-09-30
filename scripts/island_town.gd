extends RefCounted
## v0.27 Hometown: the tile grid inside each 3 m island plot. Pure geometry and rules; the wallet
## and residents stay in lab_state. Tile (0,0) is the plot's north-west corner at local (-1.5,-1.5);
## the last row and column are the edge-road band and never hold anything.
static var data: Dictionary={}
const LEGACY_WHOLE=["road","fence","sculpture"]

static func rules() -> Dictionary:
	if data.is_empty(): data=JSON.parse_string(FileAccess.get_file_as_string("res://data/town_items.json"))
	return data

static func tile() -> float: return float(rules().tile)
static func usable() -> int: return int(rules().usable)

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
	if at.x<0 or at.y<0 or at.x+n.x>usable() or at.y+n.y>usable(): return "超出地块边界（边缘一格留给小路）"
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
		if not at is Array or at.size()!=2 or not _int(at[0],0,usable()) or not _int(at[1],0,usable()): return false
		if not is_building(str(plot.get("kind",""))): return false
	var items=plot.get("items",[])
	if not items is Array or items.size()>int(rules().max_items_per_plot): return false
	if not items.is_empty() and not bool(plot.get("unlocked",false)): return false
	var probe=plot.duplicate(); probe.items=[]
	var main=primary_rect(plot)
	if is_building(str(plot.get("kind",""))) and (main.position.x<0 or main.position.y<0 or main.end.x>usable() or main.end.y>usable()): return false
	for item in items:
		if not item is Dictionary or not _int(item.get("uid"),1,100000000) or not _int(item.get("x"),0,usable()) or not _int(item.get("z"),0,usable()) or not _int(item.get("rot",0),0,3): return false
		var kind=str(item.get("kind",""))
		if is_building(kind):
			if not kind in building_kinds or not _int(item.get("level"),1,5): return false
		elif not is_decor(kind): return false
		var show=item.get("show",{})
		if not show is Dictionary: return false
		if not show.is_empty():
			if not bool(info(kind).get("display",false)) or show.get("type") not in ["mineral","mini"] or not show.get("id") is String: return false
		if not fits(probe,kind,Vector2i(int(item.x),int(item.z)),int(item.get("rot",0))).is_empty(): return false
		probe.items.append(item)
	return true
