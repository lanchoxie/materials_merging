extends RefCounted
## Island scale differs from the planet; share locomotion, not world coordinates.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_exploration.json"))
var state
var light_bridge
var parcels={}
var obstacles: Array=[]

func setup(model,portal) -> void:
	state=model; light_bridge=portal
	rules.eye_height=1.12; rules.body_height=1.25; rules.player_radius=0.16
	rules.walk_speed=2.4; rules.run_speed=4.0; rules.jump_speed=4.2
	parcels.clear(); obstacles.clear()
	for p in state.plots:
		if not p.unlocked: continue
		parcels[Vector2i(p.x,p.z)]=true
		if p.kind in ["empty","road","plaza","garden","park","fence","sculpture"]: continue
		var half=Vector2(0.86,0.86) if p.kind=="reactor" else Vector2(0.94,0.95)
		obstacles.append(Rect2(Vector2(p.x*3,p.z*3)-half,half*2))

func spawn(_region: String) -> Vector2:
	for p in state.plots:
		if p.unlocked and p.kind=="plaza": return Vector2(p.x*3+0.95,p.z*3-1.12)
	return Vector2(1.1,1.1)

func _bridge_t(p: Vector2) -> float:
	var a=Vector2(light_bridge.plaza.x+light_bridge.start.x,light_bridge.plaza.z+light_bridge.start.z)
	var b=Vector2(light_bridge.plaza.x+light_bridge.tip.x,light_bridge.plaza.z+light_bridge.tip.z)
	return clampf((p-a).dot(b-a)/(b-a).length_squared(),0,1)

func bridge(p: Vector2) -> bool:
	var a=Vector2(light_bridge.plaza.x+light_bridge.start.x,light_bridge.plaza.z+light_bridge.start.z)
	var b=Vector2(light_bridge.plaza.x+light_bridge.tip.x,light_bridge.plaza.z+light_bridge.tip.z)
	return p.distance_to(a.lerp(b,_bridge_t(p)))<0.43

func inside(p: Vector2,_margin: float=0) -> bool:
	return parcels.has(Vector2i(roundi(p.x/3),roundi(p.y/3))) or bridge(p)

func ground(p: Vector2) -> float:
	return lerpf(light_bridge.start.y,light_bridge.tip.y,_bridge_t(p)) if bridge(p) else 0.12

func height_at(p: Vector2) -> float: return ground(p)
func river_x(_z: float) -> float: return 100000

func blocked(p: Vector2,_barriers: Array=[]) -> bool:
	for offset in [Vector2.ZERO,Vector2(0.17,0),Vector2(-0.17,0),Vector2(0,0.17),Vector2(0,-0.17)]:
		if not inside(p+offset): return true
	for rect in obstacles:
		if rect.grow(0.16).has_point(p): return true
	return false
