extends RefCounted
## Small persistent navigation record; it never generates inventory or terrain state.
var points={}
var serial=1
var revision=0

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
	return {"version":1,"serial":serial,"points":points.duplicate(true)}

func restore(data,t) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("points") is Dictionary or data.points.size()>int(t.rules.max_waypoints): return false
	if not _number(data.get("serial"),1,1000000000) or data.serial!=floor(data.serial): return false
	for id in data.points:
		var row=data.points[id]
		if not id is String or not id.is_valid_int() or str(int(id))!=id or int(id)<1 or int(id)>=int(data.serial) or not row is Dictionary: return false
		if row.get("name")!="我的路标 %d" % int(id): return false
		if not _number(row.get("x"),-t.rules.radius,t.rules.radius) or not _number(row.get("z"),-t.rules.radius,t.rules.radius): return false
		if not t.inside(Vector2(row.x,row.z),4): return false
	points=data.points.duplicate(true); serial=int(data.serial); revision+=1; return true

func _number(value,lo: float,hi: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=lo and value<=hi
