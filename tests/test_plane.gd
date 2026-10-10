extends SceneTree
## v0.47 水陆两栖小飞机 (agreed plan: airplane, then spaceship): an electric floatplane built at the
## vehicle assembly plant; takes off from ground or water, climbs, turns, stalls and sinks, lands
## (hard if too steep), wraps around the planet, turns back at the poles; the far terrain below is
## built from the real terrain and globe colours.
const State=preload("res://scripts/lab_state.gd")
const PlanetV2=preload("res://scripts/planet_v2.gd")
const Craft=preload("res://scripts/planet_plane.gd")
const Industry=preload("res://scripts/industry.gd")
const Shape=preload("res://scripts/planet_shape.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func fly(p,seconds: float) -> void:
	for i in range(int(seconds*20.0)): p.step(0.05)

func _initialize() -> void:
	var R=Industry.rules()
	# --- Data, slot, save.
	check(R.items.plane.get("plane",false) and R.recipes.plane.building=="vehicle_assembly" and R.recipes.plane.inputs.has("item:duralumin"),"the floatplane is built at the vehicle assembly plant from duralumin")
	var s=State.new(); var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,100)
	check(ind.deploy_plane("plane").contains("没有"),"no plane, nothing to deploy")
	ind.items["plane"]=1; ind._reconcile("plane")
	check(ind.deploy_plane("plane").contains("派往地球") and ind.reserved("plane")==1 and is_equal_approx(float(ind.plane_state.cap),float(R.plane.cap_wh)),"deployed with a %d Wh battery, not sellable" % int(R.plane.cap_wh))
	ind.recharge_plane(float(R.plane.recharge_seconds)*0.25)
	var copy=Industry.new(); check(copy.restore(JSON.parse_string(JSON.stringify(ind.serialize()))) and copy.plane=="plane" and absf(float(copy.plane_state.charge)-float(R.plane.cap_wh)*0.25)<0.01,"slot and charge are saved")
	# --- Take off from the sea west of home, climb, turn.
	var v=PlanetV2.new(); var t=v.construction.terrain
	var shore=Vector2.INF
	for i in range(1,900):
		var q=Vector2(-i*8.0,445.0)
		if Shape.is_ocean(q.x,q.y): shore=q; break
	var p=Craft.new(R.plane); p.terrain=t; p.construction=v.construction; p.state={"charge":float(R.plane.cap_wh),"cap":float(R.plane.cap_wh)}
	p.place(shore+Vector2(-200,0),PI/2)
	check(absf(p.altitude-Shape.SEA_LEVEL)<0.01 and not p.airborne,"it floats on the sea")
	p.movement=Vector2(0,-1); p.pitch_target=0.3
	fly(p,3.0)
	check(not p.airborne and p.speed>10.0,"it skims the water while speeding up (%.1f m/s)" % p.speed)
	fly(p,4.0)
	check(p.airborne,"past %d m/s the nose comes up and it lifts off" % int(R.plane.takeoff_speed))
	fly(p,8.0)
	check(p.height_above_ground()>25.0 and p.position.x<shore.x-300.0,"it climbs out over the sea (%.0f m up)" % p.height_above_ground())
	var used=float(R.plane.cap_wh)-float(p.state.charge)
	check(used>0.0 and used<float(R.plane.wh_per_km)*p.travelled/1000.0*1.01,"the battery pays per kilometre (%.1f Wh for %.0f m)" % [used,p.travelled])
	var heading=p.heading; p.movement=Vector2(1,-1); fly(p,2.0)
	check(p.heading<heading-0.5 and p.bank<-0.2,"D banks right and turns")
	p.movement=Vector2(0,-1); p.jump(); fly(p,1.5)
	check(absf(p.pitch)<0.15 and absf(p.bank)<0.1,"space levels it")
	# --- Stall and a gentle water landing.
	p.movement=Vector2(0,1); fly(p,2.0); p.movement=Vector2.ZERO
	var alt=p.altitude
	fly(p,120.0)
	check(not p.airborne and p.message.contains("落水") and p.landed==1,"throttle off: it slows, sinks and settles on the water (%s)" % p.message)
	check(p.altitude<alt,"it came down")
	# --- Hard landing: diving fast into the ground is caught (stops short, no damage).
	var hard=Craft.new(R.plane); hard.terrain=t; hard.state={"charge":999.0,"cap":3000.0}
	hard.place(shore+Vector2(-300,0),PI/2); hard.airborne=true; hard.altitude=40.0; hard.speed=50.0; hard.throttle=1.0; hard.pitch=-0.4; hard.pitch_target=-0.45
	fly(hard,12.0)
	check(not hard.airborne and hard.message.contains("硬着陆"),"a steep dive ends in a hard landing (%s)" % hard.message)
	# --- The poles turn you back; the date line wraps.
	var north=Craft.new(R.plane); north.terrain=t; north.state={"charge":999.0,"cap":3000.0}
	north.place(Vector2(-8000,Shape.NORTH+120.0),0.0); north.airborne=true; north.altitude=200.0; north.speed=50.0; north.throttle=1.0
	fly(north,4.0)
	check(north.position.y>Shape.NORTH+60.0 and north.message.contains("极地"),"the polar cap turns it back")
	var east=Craft.new(R.plane); east.terrain=t; east.state={"charge":999.0,"cap":3000.0}
	east.place(Vector2(8180,0),-PI/2); east.airborne=true; east.altitude=200.0; east.speed=50.0; east.throttle=1.0
	fly(east,1.0)
	check(east.position.x<-8100.0,"flying east past the date line comes out in the far west (x %.0f)" % east.position.x)
	# --- A flat battery: no thrust, it glides down.
	var flat=Craft.new(R.plane); flat.terrain=t; flat.state={"charge":0.0,"cap":3000.0}
	flat.place(shore+Vector2(-500,0),PI/2); flat.movement=Vector2(0,-1); fly(flat,2.0)
	check(flat.speed<0.1 and flat.message.contains("电量耗尽"),"with no charge the propeller won't turn")
	# --- Far terrain: the real terrain's heights and the globe's colours, curved by a shader.
	var far=preload("res://scripts/planet_far_terrain.gd").new(); far.terrain=t; far.env=v.environment; root.add_child(far)
	far.build_now(Vector2(0,0))
	var n=far.size()
	check(far.mesh!=null and far.mesh.surface_get_array_len(0)==n*n,"a %d×%d far grid is built" % [n,n])
	var land=far.sample(500.0,500.0); var sea=far.sample(shore.x-400.0,shore.y)
	check(absf(float(land[0])-(t.legacy_height(Vector2(500,500))-far.SINK))<0.01,"land heights follow the terrain (a little below the real ground)")
	check(absf(float(sea[0])-(Shape.SEA_LEVEL-0.3))<0.01 and Color(sea[1]).b>Color(sea[1]).r,"the sea is a flat blue surface")
	far.set_origin(Vector3(10,0,20))
	check(far.shader_material.get_shader_parameter("origin")==Vector3(10,0,20),"the curvature follows the plane")
	var shader_code: String=far.shader_material.shader.code
	check(shader_code.contains("dot(d, d) / (2.0 * radius)") and shader_code.contains("2607.6"),"the horizon drops by d²/2R with the planet's radius")
	far.queue_free()
	# --- Planet save: where it is parked.
	v.plane_at={"x":-3200.0,"z":445.0,"heading":1.57}
	var data=JSON.parse_string(JSON.stringify(v.serialize()))
	var back=PlanetV2.new()
	check(back.restore(data) and float(back.plane_at.x)==-3200.0,"the parking spot is saved")
	data.plane.z=9000.0
	check(not PlanetV2.new().restore(data),"a parking spot past the pole is rejected")
	if failures.is_empty(): print("PLANE OK (%d checks)" % checks); quit(0)
	else: print("PLANE FAILED: ",failures); quit(1)
