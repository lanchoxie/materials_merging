extends RefCounted
## v0.47 水陆两栖小飞机: an electric floatplane with an arcade flight model (no physics bodies).
## Throttle sets the target airspeed; it rolls on ground or water until it is fast enough, then the
## nose comes up and it climbs. Below stall speed it sinks. A/D bank and turn; dragging up/down (or
## the stick) sets the nose; space levels it. Touching down too fast or nose-first is a hard landing
## (it stops sharply but nothing breaks). It floats, so the sea is a runway, and oceans can be
## crossed. Energy is Wh per km, more at full throttle. It duck-types the walker for the input code.
const Shape=preload("res://scripts/planet_shape.gd")
var terrain
var construction
var rules: Dictionary={}
var state: Dictionary={"charge":0.0,"cap":0.0}
var position=Vector2.ZERO
var altitude=0.0         # height of the floats' bottom
var heading=0.0          # walker convention: forward is (−sin, −cos)
var pitch=0.0            # nose up is positive
var pitch_target=0.0
var bank=0.0
var speed=0.0            # airspeed along the nose, m/s
var throttle=0.0         # 0..1
var vertical=0.0         # m/s
var airborne=false
var movement=Vector2.ZERO
var running=false
var look_yaw=0.0
var look_pitch=-0.15
var travelled=0.0
var spin=0.0
var message=""
var landed=0             # landings this trip

func _init(spec: Dictionary) -> void:
	rules=spec

var yaw:
	get: return heading

func forward() -> Vector2:
	return Vector2(-sin(heading),-cos(heading))

func place(at: Vector2,facing: float) -> void:
	position=at; heading=facing; speed=0.0; throttle=0.0; pitch=0.0; pitch_target=0.0; vertical=0.0; bank=0.0; airborne=false
	altitude=floor_at(at,INF); stop()

func stop() -> void:
	movement=Vector2.ZERO; running=false

## Drag sets the nose (up drag = nose up).
func look(delta: Vector2,sensitivity: float) -> void:
	pitch_target=clampf(pitch_target-delta.y*sensitivity*1.5,-float(rules.max_pitch),float(rules.max_pitch))
	look_yaw=clampf(look_yaw-delta.x*sensitivity*0.5,-1.0,1.0)

## Space: level the wings and the nose.
func jump() -> bool:
	pitch_target=0.0; look_yaw=0.0; message="改平"
	return true

func eye() -> Vector3:
	return Vector3(position.x,altitude+1.5,position.y)

## What the plane rests on: ground, a building top, or the sea surface (it floats).
func floor_at(p: Vector2,ceiling: float) -> float:
	var f: float=terrain.ground(p)
	if construction!=null: f=maxf(f,construction.floor_at(p,ceiling))
	return maxf(f,Shape.SEA_LEVEL)

func height_above_ground() -> float:
	return altitude-floor_at(position,altitude+1.0)

func can_exit() -> bool:
	return not airborne and speed<3.0

func step(dt: float) -> void:
	var R: Dictionary=rules
	if movement.y<-0.3: throttle=minf(1.0,throttle+dt*0.6)
	elif movement.y>0.3: throttle=maxf(0.0,throttle-dt*0.6)
	if float(state.charge)<=0.0 and throttle>0.0: throttle=0.0; message="电量耗尽：滑翔下降，尽快找地方降落"
	var target=throttle*float(R.max_speed)
	# Ground reverse: when throttle is zero and S is held, allow slow backward taxi.
	var reverse_speed: float=0.0
	if not airborne and throttle<=0.0 and movement.y>0.3: reverse_speed=-4.0
	speed=move_toward(speed,target+reverse_speed,float(R.accel)*dt*(1.0 if speed<target else (0.5 if airborne else 1.6)))
	# Steering: bank and turn in the air, nose-wheel style on the ground (slower).
	var steer=-movement.x
	bank=lerpf(bank,steer*0.5 if airborne else 0.0,minf(1.0,dt*3.0))
	heading+=steer*float(R.turn_rate)*dt*(1.0 if airborne else 0.7*clampf(speed/6.0,0.0,1.0))
	pitch=move_toward(pitch,pitch_target if airborne or speed>=float(R.takeoff_speed) else 0.0,float(R.pitch_rate)*dt)
	if not airborne and speed>=float(R.takeoff_speed) and pitch_target>0.05:
		airborne=true; message="起飞！拖动控制机头，A/D 转弯"
	if airborne:
		# Off the throttle it glides down gently; below stall speed it sinks fast.
		var vy=sin(pitch)*speed-(1.0-throttle)*3.0
		if speed<float(R.stall_speed): vy=minf(vy,0.0)-float(R.sink)*(1.0-speed/float(R.stall_speed))
		vertical=lerpf(vertical,vy,minf(1.0,dt*2.0))
	# Move along the nose; the polar caps turn you back.
	var step2=forward()*cos(pitch)*speed*dt; var next=position+step2
	if not terrain.inside(next,40.0):
		next=position; speed*=0.6; heading+=PI*0.5*dt*4.0; message="前方是极地冰盖，转向返回"
	if not airborne:
		var ahead: float=floor_at(next,altitude+1.0)
		if ahead-altitude>0.7 or (speed>1.0 and terrain.blocked(next,[]) and not terrain.water_at(next) and not terrain.deep_water(next)):
			next=position; speed=0.0; message="前方有坡坎或树木，滑跑受阻：转个方向"
	var moved=(next-position).length()
	position=next
	if absf(position.x)>8192.0: position.x=fposmod(position.x+8192.0,16384.0)-8192.0
	travelled+=moved
	state.charge=maxf(0.0,float(state.charge)-moved/1000.0*float(R.wh_per_km)*(0.35+0.65*throttle))
	spin+=dt*(4.0+throttle*40.0)
	var ground=floor_at(position,altitude+1.0)
	if airborne:
		altitude=minf(altitude+vertical*dt,float(R.max_altitude))
		if altitude>=float(R.max_altitude): vertical=minf(vertical,0.0)
		if altitude<=ground:
			var hard=-vertical>float(R.crash_speed) or pitch<-0.25
			altitude=ground; airborne=false; vertical=0.0; pitch=0.0; pitch_target=0.0; landed+=1
			if hard: speed*=0.25; message="硬着陆！机身没事，但下次放慢一点、机头抬平"
			else: message="平稳%s" % ("落水" if terrain.water_at(position) or terrain.deep_water(position) else "着陆")
	else:
		altitude=ground
