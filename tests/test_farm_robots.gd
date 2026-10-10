extends SceneTree
## v0.46 农业机器人 (user: 我们种植和收获可以加入机器人吗): a placeable robot built from 星锻岛 parts
## that tends the planters around it — harvests ripe crops into its own hopper, sows empty boxes from
## its seed bin, waters dry ones — and is emptied/refilled by the player with E. It never touches
## the backpack on its own, keeps out of the settlement farmer's way, and saves its hopper.
const State=preload("res://scripts/lab_state.gd")
const PlanetV2=preload("res://scripts/planet_v2.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

var serial=900
func put(v,kind: String,recipe: String,x: int,z: int) -> String:
	var c=v.construction; var id=str(serial); serial+=1
	c.sources[id]={"product":{"id":int(id),"recipe":recipe,"recipe_version":1,"source_batch":"river:"+id},"remaining":int(c.rules.recipes[recipe].units)-1}
	var y=c.base(Vector3i(x,0,z)); var k=c.key(Vector3i(x,y,z))
	c.blocks[k]={"x":x,"y":y,"z":z,"kind":kind,"source":id}; c.revision+=1
	return k

func run(v,seconds: int) -> void:
	for i in range(seconds): v.world.elapsed=int(v.world.elapsed)+1; v._step()

func _initialize() -> void:
	# --- Data and crafting from 星锻岛 parts.
	var s=State.new(); s.coins=100000; var p=s.planet; var f=p.v2.field; var ind=s.industry
	var r: Dictionary=f.rules.recipes.field_farm_robot
	check(r.industry_inputs.has("motor") and r.industry_inputs.has("logic_chip") and p.v2.construction.rules.kinds.farm_robot.get("machine",false),"the robot is a machine made with motors and a logic chip from 星锻岛")
	f.stock.timber=4
	check(f.crafting_error("field_farm_robot",ind).contains("星锻岛"),"without the parts it can't be made")
	for id in ["motor","logic_chip","lead_acid"]: ind.items[id]=2; ind._reconcile(id)
	check(f.crafting_error("field_farm_robot",ind).is_empty(),"with them it can")
	# --- A robot among three planters: one ripe, one empty, one planted but dry; one more out of reach.
	var v=PlanetV2.new(); v.world.paused=false; v.world.seeds=10
	var fv=v.field; var c=v.construction
	var robot=put(v,"farm_robot","field_farm_robot",30,30)
	var ripe=put(v,"planter","field_planter",32,30); var empty=put(v,"planter","field_planter",30,33); var dry=put(v,"planter","field_planter",28,30)
	var far=put(v,"planter","field_planter",30,45)
	fv.gardens[ripe]={"growth":1.0,"moisture":0.6,"waterings":1}
	fv.gardens[dry]={"growth":0.3,"moisture":0.1,"waterings":0}
	fv.gardens[far]={"growth":1.0,"moisture":0.6,"waterings":1}
	fv.hopper(robot).seeds=1
	var grain=int(fv.stock.grain); var seeds=int(v.world.seeds); var harvests=int(v.settlement.harvests)
	run(v,int(fv.rules.robots.period)+1)
	check(not fv.gardens.has(ripe) and int(fv.robots[robot].grain)>=2 and int(v.settlement.harvests)==harvests+1,"first it harvests the ripe box into its hopper (%d grain)" % int(fv.robots[robot].grain))
	check(fv.robot_work[robot].action=="收获" and fv.robot_work[robot].target==ripe,"and says so")
	run(v,int(fv.rules.robots.period))
	check(fv.gardens.has(empty) or fv.gardens.has(ripe),"next it sows an empty box from its seed bin")
	run(v,int(fv.rules.robots.period)*4)
	check(float(fv.gardens[dry].moisture)>=float(fv.rules.robots.dry),"and waters the dry one (moisture %.2f)" % float(fv.gardens[dry].moisture))
	check(fv.gardens.has(far) and float(fv.gardens[far].growth)>=1.0,"a box beyond %d m is left alone" % int(fv.rules.robots.radius))
	check(int(fv.stock.grain)==grain and int(v.world.seeds)==seeds,"it never touches the backpack on its own")
	# --- The settlement farmer's target is left to the farmer.
	fv.gardens[ripe]={"growth":1.0,"moisture":0.6,"waterings":1}
	v.ranch.jobs["1"]={"action":"收获","item":"","target":ripe,"stage":"work","cargo":{},"left":4.0}
	var before=int(fv.robots[robot].grain)
	# Robot ticks only (the ranch tick would drop this hand-made job: there is no resident 1 here).
	for i in range(int(fv.rules.robots.period)*2): v.world.elapsed=int(v.world.elapsed)+1; fv.robot_tick(v)
	check(fv.gardens.has(ripe) and int(fv.robots[robot].grain)==before,"a box the farmer is walking to is left to the farmer")
	v.ranch.jobs.erase("1")
	# --- E: take the harvest, load seeds; a loaded robot can't be taken down.
	v.ranch.sync(v)
	check(c.occupied.has(robot),"a robot with something in its hopper can't be dismantled")
	var said=fv.robot_service(robot,v.world,c)
	check(int(fv.stock.grain)>grain and int(fv.robots[robot].grain)==0 and int(fv.robots[robot].seeds)==int(fv.rules.robots.seed_load),"E takes the grain and tops up the seed bin (%s)" % said)
	check(int(v.world.seeds)<seeds,"the seeds came from the backpack")
	# --- Save: the hopper; bad hoppers rejected.
	var data=JSON.parse_string(JSON.stringify(fv.serialize()))
	var copy=preload("res://scripts/river_field.gd").new()
	check(copy.restore(data,c,int(v.world.elapsed)) and int(copy.robots[robot].seeds)==int(fv.robots[robot].seeds),"the hopper is saved")
	var bad=data.duplicate(true); bad.robots[robot].grain=999
	check(not preload("res://scripts/river_field.gd").new().restore(bad,c,0),"an overfull hopper is rejected")
	bad=data.duplicate(true); bad.robots[ripe]={"grain":0,"seeds":0}
	check(not preload("res://scripts/river_field.gd").new().restore(bad,c,0),"a hopper on a planter is rejected")
	var old=data.duplicate(true); old.erase("robots")
	check(preload("res://scripts/river_field.gd").new().restore(old,c,0),"saves from before robots still load")
	# --- Removing the robot clears its hopper record.
	fv.robots[robot]={"grain":0,"seeds":0}; c.blocks.erase(robot); c.revision+=1
	run(v,1)
	check(not fv.robots.has(robot) and not fv.robot_work.has(robot),"a removed robot leaves nothing behind")
	# --- Prompt and view.
	var v2=PlanetV2.new(); var r2=put(v2,"farm_robot","field_farm_robot",40,40); var p2=put(v2,"planter","field_planter",42,40)
	v2.field.gardens[p2]={"growth":1.0,"moisture":0.5,"waterings":0}; v2.world.paused=false
	run(v2,int(v2.field.rules.robots.period)+1)
	var text=v2.Target.prompt(v2,{"type":"block","key":r2,"kind":"farm_robot","name":"农业机器人","distance":2.0})
	check(text.contains("料斗") and text.contains("收获"),"aiming at it shows what it is doing and its hopper (%s)" % text)
	var view=preload("res://scripts/river_field_view.gd").new(); view.material=StandardMaterial3D.new(); root.add_child(view)
	view.sync_robots(v2.field,v2.construction,Vector2(40,40),int(v2.world.elapsed))
	var body: Node3D=view.bots.get(r2)
	check(body!=null and Vector2(body.get_meta("goal").x,body.get_meta("goal").z).distance_to(Vector2(42,40))<1.2,"its body drives out to the box it is working")
	view.queue_free()
	if failures.is_empty(): print("FARM ROBOTS OK (%d checks)" % checks); quit(0)
	else: print("FARM ROBOTS FAILED: ",failures); quit(1)
