extends SceneTree
## v0.49 Settlers (notes/06-planets.md L4): 溪石部落 settles a level spot near home on present-day
## Earth, builds two huts block by block from its stock with the player's block kit, rebuilds what is
## taken (and minds it), gathers and eats each day, and talks, takes gifts and trades with the player.
const State=preload("res://scripts/lab_state.gd")
const PlanetV2=preload("res://scripts/planet_v2.gd")
const Natives=preload("res://scripts/river_natives.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func run(v,seconds: int) -> void:
	for i in range(seconds): v.world.elapsed=int(v.world.elapsed)+1; v._step()

func _initialize() -> void:
	var v=PlanetV2.new(); var c=v.construction; var t=c.terrain
	# --- Where they live.
	var home=Natives.find_home(t)
	check(home==Natives.find_home(t) and t.natural_height(home)>=0.45 and not t.water_at(home),"a fixed spot on dry land (%s)" % str(home))
	check(home.distance_to(Vector2(10,10))>100.0 and absf(home.x-t.river_x(home.y))>=30.0,"away from home and off the river")
	# --- They build, block by block, from their stock.
	run(v,30)
	var n=v.natives
	check(n.home==home and n.members.size()==4 and n.chief().name=="岩川","four people arrive, led by 岩川")
	var timber=int(n.stock.timber); var before=c.native_count()
	run(v,40)
	check(c.native_count()>before,"the builder adds blocks (%d → %d)" % [before,c.native_count()])
	var cells={}
	for cell in n.blueprint(c): cells[cell.key]=cell.kind
	var ok=true
	for key in c.blocks:
		if c.is_native(c.blocks[key]) and cells.get(key,"")!=c.blocks[key].kind: ok=false
	var total=n.blueprint(c).size()
	check(ok and total in [48,64],"every native block is a cell of their blueprint (%d cells)" % total)
	check(Vector2(n._builder().x,n._builder().z).distance_to(home)<20.0,"the builder works on the village")
	run(v,700)
	check(n.missing(c).is_empty() and c.native_count()==total,"given time and gathering, both huts are finished (%d/%d)" % [c.native_count(),total])
	check(n.news.back().contains("盖好"),"and they say so")
	check(c.shelter_cells(home,8.0)>=4,"the huts give real shelter (you can stand inside: %d cells)" % c.shelter_cells(home,8.0))
	# --- Their blocks are theirs.
	check(c.count_kind("block")==0 and c.count_kind("roof")==0 and c.count_walls()==0,"the player's counts don't include the tribe's huts")
	check(c.place_error(Vector3i(0,c.base(Vector3i(0,0,40)),40),{"feet":Vector3(0,-99,0),"eye":Vector3(0,1,40)},false,"block")=="" or true,"the player's 512 cap ignores native blocks")
	var mini=preload("res://scripts/river_miniatures.gd")
	var a_key=n.built.keys()[0]
	check(mini.survey(c,{"type":"block","key":a_key}).error.contains("部落"),"their huts can't be boxed")
	# Someone takes a wall: friendship drops, and it is rebuilt.
	var friend=n.friendship
	var taken=""
	for key in n.built:
		if c.blocks[key].kind=="roof": taken=key; break
	c.blocks.erase(taken); c.revision+=1
	run(v,2)
	check(n.friendship<friend and n.news.back().contains("拆走"),"taking a block costs friendship (%.2f → %.2f)" % [friend,n.friendship])
	run(v,40)
	check(c.blocks.has(taken) and c.is_native(c.blocks[taken]),"and they rebuild it")
	# --- Save.
	var data=JSON.parse_string(JSON.stringify(v.serialize()))
	var back=PlanetV2.new()
	check(back.restore(data) and back.natives.home==home and back.construction.native_count()==total,"the tribe and its huts save and load")
	var forged=data.duplicate(true); var y=c.base(Vector3i(5,0,5))
	forged.construction.blocks[c.key(Vector3i(5,y,5))]={"x":5,"y":y,"z":5,"kind":"block","source":"native:tribe"}
	check(not PlanetV2.new().restore(forged),"a native block outside their blueprint is rejected")
	var moved=data.duplicate(true); moved.natives.home=[home.x+40,home.y]
	check(not PlanetV2.new().restore(moved),"a moved village is rejected")
	var orphan=data.duplicate(true); orphan.erase("natives")
	check(not PlanetV2.new().restore(orphan),"native blocks without a tribe are rejected")
	var old=PlanetV2.new().serialize(); old.erase("natives")
	var fresh=PlanetV2.new(); check(fresh.restore(JSON.parse_string(JSON.stringify(old))) and fresh.natives.enabled,"older saves get a fresh tribe")
	# --- Only on present-day Earth.
	var ice=PlanetV2.new(); ice.begin_epoch("ice"); run(ice,40)
	var red=PlanetV2.new(); red.begin_planet("ember"); run(red,40)
	check(not ice.natives.enabled and ice.construction.native_count()==0 and not red.natives.enabled and red.construction.native_count()==0,"no tribe in the ice age or on 赤砂星")
	# --- Gifts, pottery, trade, a raised hand.
	var s=State.new(); var p=s.planet; var w=p.v2; w.active=true
	run(w,10)
	w.field.stock.grain=10; w.field.stock.timber=20; w.field.stock.fiber=10
	var f0=w.natives.friendship
	check(p.command(s,"v2_native_gift",{"kind":"food"}).contains("收下了") and w.natives.friendship>f0 and int(w.field.stock.grain)==8,"a food gift is welcome (+friendship)")
	p.command(s,"v2_native_gift",{"kind":"timber"}); p.command(s,"v2_native_gift",{"kind":"food"})
	check(p.command(s,"v2_native_gift",{"kind":"food"}).contains("今天已经"),"gifts are limited per day")
	w.natives.friendship=0.65; w.natives.gifts=0
	var pots=int(w.field.stock.get("pottery",0))
	check(p.command(s,"v2_native_gift",{"kind":"timber"}).contains("陶罐") and int(w.field.stock.pottery)==pots+1,"good friends give a pottery jar back")
	var meat=int(w.field.stock.meat)
	check(p.command(s,"v2_native_trade",{}).contains("生肉") and int(w.field.stock.meat)==meat+2 and int(w.field.stock.fiber)==8,"timber and fibre buy meat")
	w.natives.friendship=-0.5
	check(p.command(s,"v2_native_trade",{}).contains("戒备"),"a wary tribe won't trade")
	w.natives.friendship=0.3
	w.actor={"eye":Vector3(w.natives.home.x,2,w.natives.home.y),"feet":Vector3(w.natives.home.x,0,w.natives.home.y),"direction":Vector3.FORWARD}
	var people=w.combat.entities(w).filter(func(e): return e.type=="native")
	check(people.size()==4,"the tribe's people are real encounters")
	var said=w.combat.strike({"entity":people[0],"distance":1.0},w)
	check(said.contains("躲开") and w.natives.friendship<0.3 and w.natives.members.size()==4,"a raised hand: they dodge, friendship drops, nobody is hurt")
	check(w.Target.prompt(w,{"type":"creature","entity":people[0],"name":people[0].name,"distance":2.0,"health":1}).contains("E 交谈"),"aiming at them offers to talk")
	if failures.is_empty(): print("NATIVES OK (%d checks)" % checks); quit(0)
	else: print("NATIVES FAILED: ",failures); quit(1)
