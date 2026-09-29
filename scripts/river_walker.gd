extends RefCounted
## A terrain-bound observer; never owns ecosystem or inventory state.
var terrain
var position=Vector2.ZERO
var yaw=0.0
var pitch=-0.12
var movement=Vector2.ZERO
var running=false
var barriers: Array=[]
var construction
var feet_y=NAN
var vertical_speed=0.0
var grounded=true
var last_position=Vector2(INF,INF)

func _init(surface) -> void:
	terrain=surface

func enter(region: String) -> void:
	position=terrain.spawn(region); yaw=0.55; pitch=-0.12; reset_height(); stop()

func reset_height() -> void:
	feet_y=terrain.ground(position); vertical_speed=0.0; grounded=true; last_position=position
	if construction!=null: feet_y=construction.floor_at(position,feet_y+9)

func jump() -> bool:
	if not is_finite(feet_y): reset_height()
	if not grounded: return false
	vertical_speed=float(terrain.rules.jump_speed); grounded=false
	return true

func stop() -> void:
	movement=Vector2.ZERO; running=false

func look(delta: Vector2,sensitivity: float) -> void:
	yaw=wrapf(yaw-delta.x*sensitivity,-PI,PI)
	pitch=clampf(pitch-delta.y*sensitivity,-1.25,1.1)

func step(dt: float) -> void:
	if not is_finite(feet_y) or position.distance_to(last_position)>2: reset_height()
	dt=clampf(dt,0,0.1)
	var frames=maxi(1,ceili(dt*120))
	for frame in range(frames): _step_motion(dt/frames)
	last_position=position

func _floor(p: Vector2,ceiling: float) -> float:
	return construction.floor_at(p,ceiling) if construction!=null else terrain.ground(p)

func _step_motion(dt: float) -> void:
	var direction=Vector3(movement.x,0,movement.y).limit_length(1).rotated(Vector3.UP,yaw)
	var speed=float(terrain.rules.run_speed if running else terrain.rules.walk_speed)
	if terrain.height_at(position)<0.1 and not terrain.bridge(position): speed*=float(terrain.rules.wading_multiplier)
	var offset=Vector2(direction.x,direction.z)*speed*dt
	# Small substeps prevent tunnelling through a trunk or fence on slow frames.
	var steps=maxi(1,ceili(offset.length()/0.10))
	for i in range(steps):
		var d=offset/steps
		for axis in [Vector2(d.x,0),Vector2(0,d.y)]:
			var next=position+axis
			var ground=_floor(next,feet_y+(float(terrain.rules.step_height) if grounded else 0.01))
			var low_barriers=[]
			for rect in barriers:
				if feet_y<terrain.ground(rect.get_center())+1.0: low_barriers.append(rect)
			var can_step=ground<=feet_y+float(terrain.rules.step_height) if grounded else ground<=feet_y+0.01
			var next_y=maxf(feet_y,ground) if grounded else feet_y
			if terrain.blocked(next,low_barriers) or not can_step: continue
			if construction!=null and construction.overlaps(next,next_y,float(terrain.rules.body_height)): continue
			position=next; feet_y=next_y
	var floor_height=_floor(position,feet_y+0.001)
	if grounded and floor_height<feet_y-0.01: grounded=false
	if not grounded:
		vertical_speed-=float(terrain.rules.gravity)*dt
		var next_y=feet_y+vertical_speed*dt
		if vertical_speed>0 and construction!=null and construction.overlaps(position,next_y,float(terrain.rules.body_height)):
			vertical_speed=0
		elif vertical_speed<=0 and next_y<=floor_height:
			feet_y=floor_height; vertical_speed=0; grounded=true
		else: feet_y=next_y

func eye() -> Vector3:
	return Vector3(position.x,(feet_y if is_finite(feet_y) else terrain.ground(position))+float(terrain.rules.eye_height),position.y)
