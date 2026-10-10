extends RefCounted
## v0.41 星球越野车: a custom kinematic vehicle on the voxel heightfield (the game has no physics
## bodies). Bicycle-model steering, an acceleration/brake/drag speed curve, five footprint probes
## against trees, buildings and the world edge, ground sampled at the axles for climbing, pitch and
## roll. Energy comes from the battery packs (Wh per km), shared with LabState.industry.rover_state.
## It duck-types the walker for the input code: movement, running, look(), jump(), stop(), yaw, eye().
var terrain
var construction
var barriers: Array=[]
var rules: Dictionary={}
var position=Vector2.ZERO
var heading=0.0          # same convention as the walker's yaw: forward is (−sin, −cos)
var speed=0.0            # m/s along the heading, negative when reversing
var body_y=NAN
var tilt=Vector2.ZERO    # smoothed (pitch, roll) for the mesh and camera
var movement=Vector2.ZERO
var running=false
var look_yaw=0.0         # chase-camera orbit offset from the drag/touch look
var look_pitch=-0.25
var bumped=0.0           # seconds since the last collision (HUD and camera shake)
var state: Dictionary={"charge":0.0,"cap":0.0,"wh_per_km":80.0}
var travelled=0.0

func _init(surface,spec: Dictionary) -> void:
	terrain=surface; rules=spec

var yaw:
	get: return heading

func forward() -> Vector2:
	return Vector2(-sin(heading),-cos(heading))

func place(at: Vector2,facing: float) -> void:
	position=at; heading=facing; speed=0.0; body_y=_ground(at,INF); tilt=Vector2.ZERO; stop()

func stop() -> void:
	movement=Vector2.ZERO; running=false

## Drag/touch look orbits the chase camera; it never steers.
func look(delta: Vector2,sensitivity: float) -> void:
	look_yaw=clampf(look_yaw-delta.x*sensitivity,-2.6,2.6)
	look_pitch=clampf(look_pitch-delta.y*sensitivity,-0.9,0.2)

## Space is the handbrake.
func jump() -> bool:
	speed*=0.35; return true

func eye() -> Vector3:
	return Vector3(position.x,(body_y if is_finite(body_y) else terrain.ground(position))+1.7,position.y)

func max_speed() -> float:
	if float(state.cap)<=0.0 or float(state.charge)<=0.0: return float(rules.crawl)
	return float(rules.boost_speed if running else rules.max_speed)

func _ground(p: Vector2,ceiling: float) -> float:
	if construction!=null: return construction.floor_at(p,ceiling if is_finite(ceiling) else terrain.ground(p)+9)
	return terrain.ground(p)

## Five probes: centre, both axles, both sides. Trees, barriers, the world edge stop it, and so does
## anything built above climbing height (a one-block step is driven over, a two-block wall is not).
func _blocked(p: Vector2,y: float) -> bool:
	var f=Vector2(-sin(heading),-cos(heading)); var side=Vector2(-f.y,f.x)
	var half=float(rules.length)*0.5; var w=float(rules.width)*0.5
	for probe in [p,p+f*half,p-f*half,p+side*w,p-side*w]:
		if not terrain.inside(probe,2.0) or terrain.blocked(probe,barriers): return true
		if construction!=null and construction.overlaps(probe,y+float(rules.climb)+0.05,1.0): return true
	return false

func step(dt: float) -> void:
	if not is_finite(body_y): body_y=_ground(position,INF)
	dt=clampf(dt,0.0,0.1); bumped+=dt
	var throttle=-movement.y; var steer=movement.x
	var top=max_speed()
	if terrain.water_at(position): top*=float(rules.water_factor)
	if throttle>0.05:
		speed=speed+float(rules.brake)*dt if speed<0 else minf(top,speed+float(rules.accel)*throttle*dt)
	elif throttle<-0.05:
		speed=speed-float(rules.brake)*dt if speed>0 else maxf(-top*float(rules.reverse_share),speed+float(rules.accel)*throttle*dt)
	else:
		speed=move_toward(speed,0.0,float(rules.drag)*dt)
	speed=clampf(speed,-top,top)
	# Bicycle model: the turn rate grows with speed and steering angle.
	heading=wrapf(heading-speed/float(rules.wheelbase)*tan(steer*float(rules.max_steer))*dt,-PI,PI)
	var offset=forward()*speed*dt
	var steps=maxi(1,ceili(offset.length()/0.25))
	for i in range(steps):
		var next=position+offset/steps
		var g=_ground(next,body_y+float(rules.climb)+0.01)
		if g>body_y+float(rules.climb) or _blocked(next,maxf(g,body_y)):
			speed=-speed*0.2 if absf(speed)>3.0 else 0.0
			bumped=0.0; break
		var moved=next.distance_to(position)
		position=next
		body_y=g if g>=body_y else maxf(g,body_y-float(rules.fall)*dt/steps)
		travelled+=moved
		if float(state.cap)>0.0: state.charge=maxf(0.0,float(state.charge)-moved/1000.0*float(state.wh_per_km))
	# Suspension: pitch and roll from the ground under the axles and wheels, low-passed.
	var f=forward(); var side=Vector2(-f.y,f.x); var half=float(rules.length)*0.45; var w=float(rules.width)*0.45
	var front=terrain.ground(position+f*half); var back=terrain.ground(position-f*half)
	var left=terrain.ground(position+side*w); var right=terrain.ground(position-side*w)
	var aim=Vector2(atan2(front-back,half*2.0),atan2(left-right,w*2.0))
	tilt=tilt.lerp(Vector2(clampf(aim.x,-0.5,0.5),clampf(aim.y,-0.4,0.4)),minf(1.0,dt*float(rules.suspension)))

## Range left on the current charge.
func range_km() -> float:
	return float(state.charge)/maxf(1.0,float(state.wh_per_km))
