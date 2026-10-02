extends RefCounted
## Small persistent navigation record; it never generates inventory or terrain state.
var points={}
var serial=1
var revision=0
## v0.33.1: where the player has walked, as whole-metre points about TRAIL_STEP apart. A jump (fast
## travel, a teleport, respawn) starts a new segment so the map never draws a line across it.
const TRAIL_STEP=8.0
const TRAIL_MAX=4000
var trail: Array=[]
var segment=0
var trail_revision=0

## Called while walking. Returns true when a point was added.
func track(p: Vector2) -> bool:
	if not p.is_finite(): return false
	var at=Vector2(roundf(p.x),roundf(p.y))
	if not trail.is_empty():
		var last: Array=trail[-1]; var d=at.distance_to(Vector2(last[0],last[1]))
		if d<TRAIL_STEP: return false
		if d>TRAIL_STEP*5: segment+=1
	trail.append([int(at.x),int(at.y),segment])
	if trail.size()>TRAIL_MAX:
		# Thin the older half instead of forgetting the first trips.
		var half=trail.size()/2; var older=[]
		for i in range(0,half,2): older.append(trail[i])
		trail=older+trail.slice(half)
	trail_revision+=1
	return true

func remember(v) -> String:
	if not v.active or v.actor.is_empty(): return "先进入第一人称，再记录脚下的位置"
	var p=Vector2(v.actor.feet.x,v.actor.feet.z); var t=v.construction.terrain
	if not t.inside(p,4): return "请离开边界后再记录路标"
	for row in points.values():
		if p.distance_to(Vector2(row.x,row.z))<8: return "附近已经有路标，直接使用已有的即可"
	if points.size()>=int(t.rules.max_waypoints): return "路标已满，先移除一个旧路标"
	points[str(serial)]={"x":p.x,"z":p.y,"name":"我的路标 %d" % serial}; serial+=1; revision+=1
	return "已记录当前位置；远行页可返回这里，存档后仍保留"

func remove(id: String) -> String:
	if not points.has(id): return "这个路标已经移除"
	points.erase(id); revision+=1; return "已移除路标，地点上的建筑和资源仍保留"

func serialize() -> Dictionary:
	var flat=[]
	for row in trail: flat.append_array(row)
	return {"version":1,"serial":serial,"points":points.duplicate(true),"trail":flat,"segment":segment}

func restore(data,t) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("points") is Dictionary or data.points.size()>int(t.rules.max_waypoints): return false
	if not _number(data.get("serial"),1,1000000000) or data.serial!=floor(data.serial): return false
	for id in data.points:
		var row=data.points[id]
		if not id is String or not id.is_valid_int() or str(int(id))!=id or int(id)<1 or int(id)>=int(data.serial) or not row is Dictionary: return false
		if row.get("name")!="我的路标 %d" % int(id): return false
		if not _number(row.get("x"),-t.rules.radius,t.rules.radius) or not _number(row.get("z"),-t.rules.radius,t.rules.radius): return false
		if not t.inside(Vector2(row.x,row.z),4): return false
	var rows=[]; var last_segment=0
	if data.has("trail"):
		var flat=data.trail
		if not flat is Array or flat.size()%3!=0 or flat.size()>TRAIL_MAX*3+3: return false
		for i in range(0,flat.size(),3):
			var x=flat[i]; var z=flat[i+1]; var seg=flat[i+2]
			if not _number(x,-t.rules.radius,t.rules.radius) or not _number(z,-t.rules.radius,t.rules.radius) or not _number(seg,0,1000000000): return false
			if x!=floor(x) or z!=floor(z) or seg!=floor(seg) or seg<last_segment: return false
			last_segment=int(seg); rows.append([int(x),int(z),int(seg)])
		if not _number(data.get("segment",0),last_segment,1000000000): return false
	points=data.points.duplicate(true); serial=int(data.serial); revision+=1
	trail=rows; segment=int(data.get("segment",last_segment)); trail_revision+=1
	return true

func _number(value,lo: float,hi: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=lo and value<=hi
