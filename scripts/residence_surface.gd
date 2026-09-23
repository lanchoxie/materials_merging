extends RefCounted
## Finite room collision; furniture bounds are shared with rendering and ray picking.
var layout
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_exploration.json"))
var door_angle=0.0

func setup(plan) -> void:
	layout=plan
	for key in ["walk_speed","eye_height","body_height","player_radius"]: rules[key]=layout.rules[key]
	rules.run_speed=3.6; rules.jump_speed=3.2

func spawn(_region: String) -> Vector2: return Vector2(0,layout.depth/2-1.6)
func ground(_p: Vector2) -> float: return 0.12
func height_at(p: Vector2) -> float: return ground(p)
func bridge(_p: Vector2) -> bool: return false
func river_x(_z: float) -> float: return 100000

func door_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP,door_angle),Vector3(-0.6,0.12,layout.depth/2))

func door_blocks(p: Vector2,angle: float) -> bool:
	var transform=Transform3D(Basis(Vector3.UP,angle),Vector3(-0.6,0.12,layout.depth/2))
	var local=transform.affine_inverse()*Vector3(p.x,0.12,p.y)
	return Rect2(0,-0.05,1.2,0.10).grow(float(rules.player_radius)).has_point(Vector2(local.x,local.z))

func can_close(p: Vector2) -> bool:
	for i in range(13):
		if door_blocks(p,i*PI/24): return false
	return true

func blocked(p: Vector2,_barriers: Array=[]) -> bool:
	var radius=float(rules.player_radius)
	if absf(p.x)>layout.width/2-radius or p.y< -layout.depth/2+radius: return true
	if p.y>layout.depth/2-radius and (absf(p.x)>0.6-radius or p.y>layout.depth/2+1.0): return true
	# Transform to hinge space: the moving leaf itself blocks walking, even mid-swing.
	if door_blocks(p,door_angle): return true
	for item in layout.fixtures:
		var box: AABB=item.box
		if Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(radius).has_point(p): return true
	return false

func safe_stand(at: Vector2) -> Vector2:
	if not blocked(at): return at
	for radius in [0.6,1.0,1.5,2.0]:
		for i in range(16):
			var candidate=at+Vector2.from_angle(i*TAU/16)*radius
			if not blocked(candidate): return candidate
	return spawn("")
