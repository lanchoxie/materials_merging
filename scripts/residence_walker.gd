extends "res://scripts/river_walker.gd"
## Rest anchors belong to furniture, not the place from which the player clicked it.
var resting=""
var return_pose={}

func rest(item: Dictionary) -> void:
	if not resting.is_empty(): return
	return_pose={"at":position,"yaw":yaw,"pitch":pitch}
	resting=str(item.type); stop()
	position=Vector2(item.at.x,item.at.z)
	reset_height()
	match resting:
		"bed":
			position.y-=0.64; yaw=PI; pitch=0.38; terrain.rules.eye_height=0.89
		"sofa": yaw=PI; pitch=-0.08; terrain.rules.eye_height=1.19
		_: yaw=0; pitch=-0.08; terrain.rules.eye_height=1.15
	last_position=position

func stand() -> void:
	if resting.is_empty(): return
	resting=""; stop(); terrain.rules.eye_height=terrain.layout.rules.eye_height
	position=terrain.safe_stand(return_pose.at); yaw=return_pose.yaw; pitch=return_pose.pitch; reset_height()
	return_pose.clear()

func jump() -> bool:
	if not resting.is_empty(): stand(); return false
	return super.jump()

func step(dt: float) -> void:
	if not resting.is_empty(): stop(); return
	super.step(dt)
	# Keep the observer's head below the ceiling even when jumping beside a wall.
	var maximum_feet=3.10-float(terrain.rules.body_height)
	if feet_y>maximum_feet: feet_y=maximum_feet; vertical_speed=minf(vertical_speed,0.0)
