extends SceneTree
## v0.41 rover kinematics and economy: acceleration and top speed, bicycle steering, reversing,
## trees and buildings stop it, it climbs one block but not two, energy per km, crawling when flat,
## the range model, the vehicle chain, deploying and the save.
const State=preload("res://scripts/lab_state.gd")
const Industry=preload("res://scripts/industry.gd")
const Rover=preload("res://scripts/river_rover.gd")
const PlanetV2=preload("res://scripts/planet_v2.gd")
const Model=preload("res://scripts/material_model.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

var highest=-INF
func drive(r,seconds: float,move: Vector2,boost: bool=false) -> void:
	r.movement=move; r.running=boost; highest=-INF
	for i in range(int(seconds*60)): r.step(1.0/60); highest=maxf(highest,r.body_y)
	r.movement=Vector2.ZERO

## A flat, tree-free straight 30 m stretch heading north from somewhere near home.
func open_lane(t) -> Vector2:
	for x in range(-200,200,7):
		for z in range(-200,200,7):
			var p=Vector2(x,z); var ok=true; var g=t.ground(p)
			for d in range(0,32,2):
				var q=p+Vector2(0,-d)
				for w in [-1.2,0.0,1.2]:
					var s=q+Vector2(w,0)
					if not t.inside(s,4) or t.blocked(s,[]) or absf(t.ground(s)-g)>0.01 or t.water_at(s): ok=false; break
				if not ok: break
			if ok: return p
	return Vector2.INF

func _initialize() -> void:
	var v=PlanetV2.new(); var t=v.construction.terrain; var R: Dictionary=t.rules.rover
	var r=Rover.new(t,R); r.construction=v.construction; r.state={"charge":1000.0,"cap":1000.0,"wh_per_km":80.0}
	var lane=open_lane(t)
	check(lane!=Vector2.INF,"a flat open lane exists near home")
	r.place(lane,0.0)
	drive(r,1.0,Vector2(0,-1))
	check(absf(r.speed-float(R.accel))<0.3,"throttle accelerates at about %.1f m/s² (%.1f)" % [float(R.accel),r.speed])
	drive(r,3.0,Vector2(0,-1))
	check(is_equal_approx(r.speed,float(R.max_speed)) or r.speed<=float(R.max_speed),"top speed is capped at %.0f m/s" % float(R.max_speed))
	check(r.position.y<lane.y-15,"it drove forward (north) about 20 m (%.1f)" % (lane.y-r.position.y))
	var used=1000.0-float(r.state.charge)
	check(absf(used-r.travelled/1000.0*80.0)<0.01 and used>1.0,"energy used is 80 Wh per km (%.2f Wh for %.1f m)" % [used,r.travelled])
	# Braking and reversing.
	drive(r,2.0,Vector2(0,1))
	check(r.speed<=0.0,"holding back brakes and then reverses")
	r.place(lane,0.0)
	# Steering: right turns clockwise seen from above (heading decreases).
	drive(r,1.5,Vector2(0,-1)); drive(r,1.0,Vector2(1,-1))
	check(r.heading<-0.05,"steering right turns right (%.2f rad)" % r.heading)
	# A building: one block can be climbed, two cannot.
	r.place(lane,0.0)
	var c=v.construction
	var b1={"x":int(round(lane.x)),"y":c.base(Vector3i(int(round(lane.x)),0,int(round(lane.y))-8)),"z":int(round(lane.y))-8,"kind":"floor","source":"1"}
	c.sources={"1":{"product":{"id":1,"recipe":"field_floor","recipe_version":1,"source_batch":"t"},"remaining":0}}
	for dx in [-1,0,1]:
		var b=b1.duplicate(); b.x+=dx; c.blocks[c.key(c.cell(b))]=b
	drive(r,4.0,Vector2(0,-1))
	check(r.position.y<lane.y-9.5 and highest>=float(b1.y)+0.9,"it climbs over a one-block ramp (top %.2f)" % highest)
	r.place(lane,0.0)
	for dx in [-1,0,1]:
		var b=b1.duplicate(); b.x+=dx; b.y+=1; c.blocks[c.key(c.cell(b))]=b
	drive(r,4.0,Vector2(0,-1))
	check(r.position.y>lane.y-8.0,"a two-block wall stops it (%.1f m before)" % (r.position.y-(lane.y-8)))
	check(r.bumped<4.0,"the bump is registered for the HUD")
	c.blocks={}
	# Trees stop it too.
	var tree=Vector2.INF
	for k in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1),Vector2i(2,0),Vector2i(0,2)]:
		for tr in t.chunk_trees(k):
			var start=tr+Vector2(0,10)
			if t.inside(start,4) and not t.blocked(start,[]) and absf(t.ground(start)-t.ground(tr))<0.6:
				tree=tr; break
		if tree!=Vector2.INF: break
	if tree!=Vector2.INF:
		r.place(tree+Vector2(0,10),0.0)
		drive(r,5.0,Vector2(0,-1))
		check(r.position.distance_to(tree)>0.6,"a tree trunk stops the rover (%.1f m away)" % r.position.distance_to(tree))
	# Empty battery: crawl.
	r.place(lane,0.0); r.state.charge=0.0
	drive(r,4.0,Vector2(0,-1))
	check(r.speed<=float(R.crawl)+0.01 and r.speed>0.0,"with a flat battery it only crawls")
	# --- Range model and chain.
	var p=Model.props("rover",{"t":90})
	check(float(p.pack_wh)>150 and float(p.range_km)>1.5 and absf(float(p.range_km)-float(p.pack_wh)/80.0)<0.001,"16 cells give about %.0f Wh and %.1f km" % [float(p.pack_wh),float(p.range_km)])
	var s=State.new(); var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,900); ind.gain(Industry.step(16)); s.coins=900000; ind.plots=10; ind.solar=[0.4,0.4,0.4,0.4,0.4,0.4,0.4,0.4,0.4,0.4]
	check(ind.build(s,0,"vehicle_assembly").contains("建成"),"the vehicle assembly is built")
	for id in ["steel_ingot","rubber","glass","motor","control_board"]: ind.items[id]=6; ind._reconcile(id)
	ind.items["battery_pack"]=2; ind.lots["battery_pack"]=[{"n":2,"k":{"t":90.0},"q":1.0,"m":false}]
	check(ind.start(s,0,"rover").begins_with("已投料"),"a rover is assembled")
	ind.tick(s,200.0)
	check(int(ind.items.get("rover",0))==1 and absf(float(ind.lots_of("rover")[0].k.t)-90.0)<0.01,"the rover inherits its packs' coating")
	check(ind.deploy_rover("rover").contains("续航") and float(ind.rover_state.cap)>150,"deploying it gives the battery capacity")
	ind.rover_state.charge=10.0; s.planet.v2.active=false; s.tick(20.0)
	check(float(ind.rover_state.charge)>10.0,"it charges on the island")
	check(ind.sell(s,"rover",1).contains("不能卖") or ind.sell(s,"rover",1).contains("先建"),"the deployed rover cannot be sold")
	var again=Industry.new()
	check(again.restore(JSON.parse_string(JSON.stringify(ind.serialize()))) and again.vehicle=="rover","the deployed rover survives a save")
	var bad=JSON.parse_string(JSON.stringify(ind.serialize())); bad.vehicle="pe"
	check(not Industry.new().restore(bad),"a non-vehicle cannot be deployed")
	# --- Parked position in the planet save.
	v=s.planet.v2; v.rover_at={"x":12.0,"z":-30.0,"heading":0.4}
	var w=PlanetV2.new()
	check(w.restore(JSON.parse_string(JSON.stringify(v.serialize()))) and is_equal_approx(float(w.rover_at.z),-30.0),"where the rover is parked is saved with its era")
	var data=JSON.parse_string(JSON.stringify(v.serialize())); data.rover.x=99999
	check(not PlanetV2.new().restore(data),"a parked rover outside the world is rejected")
	if failures.is_empty(): print("ROVER OK (%d checks)" % checks); quit(0)
	else: print("ROVER FAILED: ",failures); quit(1)
