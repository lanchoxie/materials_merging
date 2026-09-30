extends RefCounted
const Town=preload("res://scripts/island_town.gd")
## Island scale differs from the planet; share locomotion, not world coordinates.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_exploration.json"))
var state
var light_bridge
var parcels={}
var obstacles: Array=[]
## Collision radius of the island visitor, used for parcel edges and obstacle padding.
const BODY_RADIUS=0.09

func setup(model,portal) -> void:
	state=model; light_bridge=portal
	# v0.27.1: toy-town scale. Small houses render at 0.58x since v0.27, so the visitor's eye sits at a
	# villager's eye level (0.56) instead of towering at twice their height.
	rules.eye_height=0.6; rules.body_height=0.68; rules.player_radius=BODY_RADIUS
	rules.walk_speed=1.5; rules.run_speed=2.4; rules.jump_speed=2.6
	rules.step_height=0.32; rules.gravity=12.0
	parcels.clear(); obstacles.clear()
	for p in state.plots:
		if not p.unlocked: continue
		parcels[Vector2i(p.x,p.z)]=true
		var base=Vector2(p.x*3,p.z*3)
		# 0.27: courtyard items and extra buildings block by their real tile footprint; paths do not.
		for item in p.get("items",[]):
			if str(Town.info(str(item.kind)).get("category",""))=="path" or str(item.kind) in ["park","garden"]: continue
			obstacles.append(tile_rect(base,Town.item_rect(item)))
		if p.kind in ["empty","road","plaza","garden","park","fence","sculpture"]: continue
		if p.kind=="reactor": obstacles.append(Rect2(base-Vector2(0.86,0.86),Vector2(1.72,1.72)))
		elif Town.is_building(str(p.kind)): obstacles.append(tile_rect(base,Town.primary_rect(p)))
		else: obstacles.append(Rect2(base-Vector2(0.94,0.95),Vector2(1.88,1.9)))

## A tile rectangle of a plot as a world-space XZ rectangle, a hair smaller than the tiles.
static func tile_rect(base: Vector2, r: Rect2i) -> Rect2:
	var t=Town.tile()
	return Rect2(base+Vector2(-1.5,-1.5)+Vector2(r.position)*t+Vector2(0.02,0.02),Vector2(r.size)*t-Vector2(0.04,0.04))

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

## The island has no voxel ground or water; the shared walker still asks.
func water_at(_p: Vector2) -> bool:
	return false

func overlaps(_p: Vector2,_feet: float,_height: float) -> bool:
	return false

func ground(p: Vector2) -> float:
	return lerpf(light_bridge.start.y,light_bridge.tip.y,_bridge_t(p)) if bridge(p) else 0.12

func height_at(p: Vector2) -> float: return ground(p)
func river_x(_z: float) -> float: return 100000

func blocked(p: Vector2,_barriers: Array=[]) -> bool:
	var r=BODY_RADIUS
	for offset in [Vector2.ZERO,Vector2(r,0),Vector2(-r,0),Vector2(0,r),Vector2(0,-r)]:
		if not inside(p+offset): return true
	for rect in obstacles:
		if rect.grow(r).has_point(p): return true
	return false
