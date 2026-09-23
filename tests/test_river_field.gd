extends SceneTree
const State=preload("res://scripts/lab_state.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func above(v,x: float,z: float,y: float=4) -> void:
	var eye=Vector3(x,v.construction.terrain.ground(Vector2(x,z))+y,z)
	v.actor={"eye":eye,"feet":eye-Vector3(0,1.62,0),"direction":Vector3.DOWN}
func gather(s,id: String) -> void:
	var v=s.planet.v2; var n=v.field.node(id); above(v,n.x,n.z)
	for i in range(int(v.field.rules.resources[n.kind].hits)): s.planet.command(s,"v2_field_collect")
func craft(s,recipe: String) -> void:
	s.planet.command(s,"pack",{"recipe":recipe,"production_mode":"island"}); s.planet.tick(60,1)
func _initialize() -> void:
	var s=State.new(); s.coins=10000; var p=s.planet; var v=p.v2; var f=v.field; var c=v.construction; v.active=true; v.world.paused=true
	var n=f.node("home:0"); above(v,n.x,n.z)
	check(v.Target.query(v).get("type")=="resource","visible resource is resolved by authoritative aim ray")
	p.command(s,"v2_field_collect"); check(f.stock.timber==0 and f.changed[n.id].hits==1,"one action advances gathering rather than granting every click")
	p.command(s,"v2_field_collect"); p.command(s,"v2_field_collect")
	check(f.stock.timber==4 and f.remaining(n.id,0)==480,"gather completes into finite actual raw stock and exhausts the node")
	p.command(s,"v2_field_collect"); check(f.stock.timber==4,"depleted node cannot be replayed")
	var saved=v.serialize(); var next=preload("res://scripts/planet_v2.gd").new()
	check(next.restore(JSON.parse_string(JSON.stringify(saved))) and next.field.remaining(n.id,0)==480,"save and reload preserves depleted resources")
	v.active=false; p.tick(60); check(f.remaining(n.id,int(v.world.elapsed))==480,"leaving planet does not accelerate regeneration")
	v.active=true; v.advance(480); check(f.remaining(n.id,int(v.world.elapsed))==0,"regeneration uses elapsed simulation time")
	above(v,n.x,n.z,9); var stock=f.stock.duplicate(); p.command(s,"v2_field_collect"); check(f.stock==stock,"out-of-range aim cannot gather")
	# A solid wall must win the nearest-hit query even if a resource lies behind it.
	above(v,n.x,n.z); var cell=c.cell_at(Vector3(n.x,2,n.z)); var key=c.key(cell)
	c.blocks[key]={"x":cell.x,"y":cell.y,"z":cell.z,"kind":"block"}; p.command(s,"v2_field_collect")
	check(f.stock==stock,"cannot gather through an intervening block"); c.blocks.clear()
	gather(s,"home:0"); gather(s,"home:1"); gather(s,"home:2"); gather(s,"home:3"); gather(s,"home:4"); gather(s,"home:5"); gather(s,"home:6")
	check(f.stock.timber==12 and f.stock.stone==8 and f.stock.fiber==6 and f.stock.fruit==3,"distinct resource sites supply all raw categories")
	p.command(s,"join"); stock=f.stock.duplicate()
	p.command(s,"pack",{"recipe":"field_wall"}); check(p.job.is_empty() and f.stock==stock,"missing workshop cannot reserve materials")
	s.campus_build(3,"workshop"); s.campus_road(3); s.campus_assign_post(s.campus.people[0].id,"workshop")
	var coins=s.coins; p.command(s,"pack",{"recipe":"field_wall"})
	check(p.job.get("recipe")=="field_wall" and f.stock.timber==8 and s.coins==coins,"local workshop reserves four gathered timber without buying raw supplies")
	var left=p.job.left; p.tick(10,0); check(p.job.left==left,"engineer away from workshop grants no processing progress")
	p.command(s,"production_mode",{"mode":"partner"}); p.tick(10,0)
	check(p.production_mode=="island" and p.job.left==left,"natural order cannot bypass engineers by switching to partner mode")
	var restored=State.new(); check(restored.planet.restore(JSON.parse_string(JSON.stringify(p.serialize())),restored),"in-flight natural crafting restores with its reserved source record")
	stock=f.stock.duplicate(); p.command(s,"pack",{"recipe":"field_wall"}); check(f.stock==stock,"double start cannot consume twice")
	p.command(s,"cancel_pack"); check(f.stock.timber==12 and p.job.is_empty(),"cancel refunds exact reserved raw materials")
	p.command(s,"cancel_pack"); check(f.stock.timber==12,"cancel replay cannot duplicate resources")
	for recipe in ["field_wall","field_roof","field_floor","field_planter","field_fence"]: craft(s,recipe)
	check(p.products.size()==5,"five construction recipes complete into shared factory products")
	check(s.coins==coins and f.stock.timber==0 and f.stock.stone==2,"completed crafts conserve raw inputs and do not charge extra raw-material coins")
	# Use real products to build a column and two raised roof cells.
	for y in range(4):
		v.actor={"eye":Vector3(15,y+4,14),"feet":Vector3(15,y+2.38,14),"direction":Vector3.DOWN}
		p.command(s,"v2_build",{"kind":"block","recipe":"field_wall"})
	for x in [16,17]:
		v.actor={"eye":Vector3(x+1.8,3.5,14),"feet":Vector3(x+1.8,1.88,14),"direction":Vector3.LEFT}
		p.command(s,"v2_build",{"kind":"roof","recipe":"field_roof"})
	check(c.shelter_cells(Vector2(10,10),14)==2,"gathered-material walls and roof produce real shelter")
	for at in [Vector2(19,14),Vector2(19,15)]:
		above(v,at.x,at.y); p.command(s,"v2_build",{"kind":"planter","recipe":"field_planter"})
	var planters=[]
	for block_key in c.blocks:
		if c.blocks[block_key].kind=="planter": planters.append(block_key)
	check(planters.size()==2,"one manufactured planter package installs two physical planters")
	if planters.size()!=2: quit(1); return
	for planter_key in planters:
		var b=c.blocks[planter_key]; above(v,b.x,b.z); p.command(s,"v2_field_plant")
	check(f.gardens.size()==2 and v.world.seeds==4,"aimed planting consumes exactly one shared seed per box")
	var b=c.blocks[planters[0]]; above(v,b.x,b.z)
	p.command(s,"v2_field_plant"); check(v.world.seeds==4,"occupied planter rejects repeated sowing")
	var before=c.serialize(); p.command(s,"v2_dismantle"); check(Same.same(before,c.serialize()),"planted box cannot be dismantled to erase or duplicate crops")
	var water=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(water,4)
	var payload={"batch_id":water.id,"token":p.shipment_serial}
	p.command(s,"v2_field_water",payload)
	check(f.gardens[planters[0]].moisture>0.8 and f.gardens[planters[1]].moisture<0.2 and s.storage.batch(water.id).quantity==3,"water sample moistens only the aimed box and consumes one real sample")
	p.command(s,"v2_field_water",payload); check(s.storage.batch(water.id).quantity==3,"repeated water action on saturated box consumes nothing")
	v.advance(200)
	check(f.gardens[planters[0]].growth==1 and f.gardens[planters[1]].growth<0.05,"watered crops mature while adjacent dry crops remain small")
	p.command(s,"v2_field_collect")
	check(f.stock.grain==3 and not f.gardens.has(planters[0]),"mature crop harvest enters portable backpack stock")
	p.command(s,"v2_field_collect"); check(f.stock.grain==3,"harvest replay cannot duplicate grain")
	p.command(s,"v2_field_pantry",{"resource":"grain"}); check(f.stock.grain==2,"harvest can be moved from portable stock to food warehouse")
	check(restored.planet.restore(JSON.parse_string(JSON.stringify(p.serialize())),restored),"full loop source packages, crops, depletion and reserves pass full save validation")
	check(Same.same(restored.planet.v2.field.serialize(),f.serialize()),"field state roundtrip retains exact resources and local moisture")
	var malformed=p.serialize(); malformed.v2.field.gardens[planters[1]].moisture=3
	check(not restored.planet.restore(malformed,restored),"invalid local environmental values rejected")
	malformed=p.serialize(); malformed.v2.field.crafts.clear()
	check(not restored.planet.restore(malformed,restored),"construction sources cannot claim gathered products without matching craft records")
	var old=State.new().planet.serialize(); old.v2.erase("field")
	check(restored.planet.restore(old,restored) and restored.planet.v2.field.stock.timber==0,"old save migration creates no free natural materials")
	_effects(s)
	print("RIVER FIELD: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func _effects(s) -> void:
	var v=s.planet.v2; var p=s.planet; var f=v.field; var c=v.construction
	var n=f.node("home:0"); var distant=f.nodes(Vector2(150,180),25)
	check(not distant.is_empty() and f.node(distant[0].id)==distant[0],"distant resource identity regenerates deterministically outside the render cache")
	var target={"eye":Vector3(n.x+9,n.y+1,n.z),"direction":Vector3.LEFT,"feet":Vector3(n.x+9,n.y,n.z)}
	v.actor=target; var before=f.stock.duplicate(); p.command(s,"v2_field_collect")
	check(f.stock==before,"new region is not collectible by arbitrary payload coordinates")
	# Feeding is a finite stock transaction against the aimed living individual.
	var region=v.world.regions.meadow
	region.animals=[v._animal("meadow_herbivore",1,0)]; var animal=region.animals[0]
	animal.x=0; animal.z=0; animal.hunger=0.6
	var center=Vector3(10,c.terrain.ground(Vector2(10,10))+0.4,10)
	v.actor={"eye":center+Vector3(0,0.8,2.5),"feet":center+Vector3(0,-0.82,2.5),"direction":(center-(center+Vector3(0,0.8,2.5))).normalized()}
	var fruit=f.stock.fruit
	check(v.Target.query(v).get("type")=="animal","aim query identifies actual animal record")
	p.command(s,"v2_field_feed",{"resource":"fruit"})
	check(f.stock.fruit==fruit-1 and is_equal_approx(animal.hunger,0.25),"feeding one fruit changes this animal's hunger")
	animal.hunger=0.05; fruit=f.stock.fruit; p.command(s,"v2_field_feed",{"resource":"fruit"})
	check(f.stock.fruit==fruit,"sated animal rejects unnecessary food consumption")
	# Furniture geometry affects simulation independent of rendered meshes.
	var isolated=preload("res://scripts/planet_v2.gd").new(); var fc=isolated.construction; var ff=isolated.field
	for x in [10,12]:
		var k=fc.key(Vector3i(x,0,10)); fc.blocks[k]={"x":x,"y":0,"z":10,"kind":"planter"}
		ff.gardens[k]={"growth":0.1,"moisture":0.8,"waterings":1}
	fc.blocks[fc.key(Vector3i(10,3,10))]={"x":10,"y":3,"z":10,"kind":"roof"}
	isolated.world.elapsed=150; ff.tick(isolated.world,fc)
	check(ff.gardens["10:0:10"].moisture>ff.gardens["12:0:10"].moisture and ff.gardens["10:0:10"].growth<ff.gardens["12:0:10"].growth,"roof retains moisture while reduced light slows local crop growth")
	isolated.actor={"eye":Vector3(12,1.4,12),"feet":Vector3(12,0,12),"direction":Vector3.FORWARD}
	ff.gardens["12:0:10"].growth=1
	check(isolated.Target.query(isolated).get("key")=="12:0:10","aiming at mature stems above the box still targets the crop")
	isolated.world.regions.meadow.animals=[isolated._animal("meadow_herbivore",1,0)]; var a=isolated.world.regions.meadow.animals[0]
	fc.blocks.clear(); ff.gardens.clear()
	fc.blocks["11:0:10"]={"x":11,"y":0,"z":10,"kind":"fence"}
	a.x=0; a.z=0; a.target_x=1.4; a.target_z=0; a.task_left=20
	for i in range(5): isolated._step()
	check(a.x*2.2<0.5,"self-built fence prevents a meadow animal from walking through it")
	var malformed=p.serialize(); malformed.v2.field="bad"
	check(not State.new().planet.restore(malformed,s),"malformed field payload is rejected without a runtime error")
