extends SceneTree
## v0.37.1 fixes from the user's phone play: batch and loop production (refinery, 星锻岛 factories,
## the 工艺车间), unfolding big boxed builds from any side, display replicas, and leaving 星锻岛.
const State=preload("res://scripts/lab_state.gd")
const Industry=preload("res://scripts/industry.gd")
const Refinery=preload("res://scripts/refinery.gd")
const Mini=preload("res://scripts/river_miniatures.gd")
const Construction=preload("res://scripts/river_construction.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	_refinery(); _industry(); _workshop(); _miniatures()
	if failures.is_empty(): print("QUEUES OK (%d checks)" % checks); quit(0)
	else: print("QUEUES FAILED: ",failures); quit(1)

func _refinery() -> void:
	var s=State.new(); var r=s.refinery; var m: Dictionary=s.planet.v2.nature.minerals
	m["hematite"]=10; m["coal"]=10
	check(r.can_queue(s,"hematite_iron")==r.queue_limit(),"queue space bounds a full refinery tap")
	var msg=r.start_many(s,"hematite_iron",99)
	check(r.jobs.size()==r.queue_limit() and msg.contains("×%d" % r.queue_limit()),"排满 fills the refinery queue in one tap: "+msg)
	check(int(m.hematite)==10-r.queue_limit(),"each queued batch reserves its ore")
	r.jobs.clear(); m["hematite"]=2; m["coal"]=10
	check(r.start_many(s,"hematite_iron",5).contains("×2"),"a batch stops when the ore runs out")
	r.jobs.clear(); m["hematite"]=6; m["coal"]=6
	check(r.set_repeat("hematite_iron").contains("循环"),"loop is set")
	var fe=int(s.element_inventory.get("Fe",0))
	r.tick(s,1.0)
	check(r.jobs.size()==r.queue_limit(),"the loop keeps the queue full")
	for i in range(40): r.tick(s,10.0)
	check(int(s.element_inventory.get("Fe",0))==fe+6*4 and r.jobs.is_empty() and int(m.get("hematite",0))==0,"the loop runs until the ore is used up (%d Fe)" % (int(s.element_inventory.get("Fe",0))-fe))
	m["hematite"]=1; m["coal"]=1; r.tick(s,0.1)
	check(r.jobs.size()==1,"new ore is picked up by the loop")
	var again=Refinery.new()
	check(again.restore(JSON.parse_string(JSON.stringify(r.serialize())),s.elements) and again.repeat=="hematite_iron","the loop survives a save")
	var bad=JSON.parse_string(JSON.stringify(r.serialize())); bad.repeat="gold_from_lead"
	check(not Refinery.new().restore(bad,s.elements),"an unknown loop process is rejected")
	var old=JSON.parse_string(JSON.stringify(r.serialize())); old.erase("repeat")
	check(Refinery.new().restore(old,s.elements),"saves before v0.37.1 load")
	check(r.set_repeat("").contains("停止") and r.repeat=="","loop can be stopped")

func _industry() -> void:
	var s=State.new(); var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,300); s.coins=100000
	ind.build(s,0,"metal_works")
	s.index_found[Industry._keys_for("Cu3Sn")[0]]=true
	s.element_inventory["Cu"]=60; s.element_inventory["Sn"]=10
	var room=ind.queue_room(0)
	check(ind.start_many(s,0,"bronze",room).contains("×%d" % room) and ind.queue_room(0)==0,"排满 fills a factory queue in one tap")
	check(ind.set_repeat(0,"pe").contains("不做"),"a loop must be a recipe of that factory")
	check(ind.set_repeat(0,"bronze").contains("循环"),"factory loop is set")
	ind.tick(s,400.0)
	check(int(ind.items.get("bronze_ingot",0))==20 and int(s.element_inventory.Sn)==0,"the loop re-queues until the tin is used up (%d ingots)" % int(ind.items.get("bronze_ingot",0)))
	var again=Industry.new()
	check(again.restore(JSON.parse_string(JSON.stringify(ind.serialize()))) and str(again.buildings["0"].get("repeat",""))=="bronze","factory loop survives a save")
	var bad=JSON.parse_string(JSON.stringify(ind.serialize())); bad.buildings["0"].repeat="pvc"
	check(not Industry.new().restore(bad),"a loop recipe of another factory is rejected")
	s.element_inventory["Cu"]=0; s.element_inventory["Sn"]=0
	for i in range(10): ind.tick(s,60.0)
	check(ind.buildings["0"].jobs.is_empty(),"the loop idles without inputs and does not go negative")
	check(int(s.element_inventory.Cu)==0 and int(s.element_inventory.Sn)==0,"no inputs are taken that were not there")

func _workshop() -> void:
	var s=State.new(); var pg=s.planet
	var sample=s.product_snapshot(s._new_reactor(3,"water",0.0)); s.storage.add_product(sample,5)
	pg.command(s,"join"); pg.command(s,"qualify",{"batch_id":sample.id})
	s.coins=100000
	var feed=pg.input_count("feed")
	check(pg.command(s,"buy_feed",{"input":"feed","count":10}).contains("10") and pg.input_count("feed")==feed+10,"supplies can be bought ten at a time")
	var msg=pg.command(s,"batch",{"recipe":"standard_water_crate","count":4,"production_mode":"partner"})
	check(not pg.job.is_empty() and int(pg.batch.left)==3,"连续制作 starts the first item and queues the rest: "+msg)
	for i in range(140): s.tick(1.0)
	check(pg.products.size()==4 and pg.batch.is_empty(),"the batch makes every item one after another (%d)" % pg.products.size())
	pg.command(s,"batch",{"recipe":"standard_water_crate","count":3,"production_mode":"partner"})
	var data=JSON.parse_string(JSON.stringify(pg.serialize()))
	check(int(data.batch.left)==2,"the batch is saved")
	check(pg.command(s,"batch",{"count":0}).contains("取消") and pg.batch.is_empty(),"a batch can be cancelled")

func _miniatures() -> void:
	var s=State.new(); var v=s.planet.v2; var c=v.construction; var t=c.terrain; v.active=true
	# A 3×4×3 cabin straight in the ledger: floor, walls and a roof layer.
	var x0=19; var z0=14; var y0=c.base(Vector3i(x0,0,z0))
	for x in range(x0,x0+3):
		for z in range(z0,z0+3):
			if c.base(Vector3i(x,0,z))!=y0: y0=-999
	check(y0!=-999,"test ground is flat")
	c.sources={"1":{"product":{"id":1,"recipe":"field_wall","recipe_version":1,"source_batch":"field:1"},"remaining":0}}
	var units=int(c.rules.recipes.field_wall.units); var placed=0
	c.blocks={}
	for y in range(4):
		for x in range(x0,x0+3):
			for z in range(z0,z0+3):
				if placed>=units: continue
				if y>0 and y<3 and x==x0+1 and z==z0+1: continue
				var b={"x":x,"y":y0+y,"z":z,"kind":"block","source":"1"}; c.blocks[c.key(c.cell(b))]=b; placed+=1
	c.sources["1"].remaining=units-placed
	check(Construction.new().restore(c.serialize()),"the test cabin is a valid ledger (%d blocks)" % placed)
	check(Mini.pack(c,{"type":"block","key":c.blocks.keys()[0]}).contains("装入"),"the cabin is packed")
	var id=c.miniatures.keys()[0]
	# Unfold it 6 m away from each side, looking at the ground the way a player does.
	var spots=[[Vector2(40,14),Vector2(46,14)],[Vector2(52,14),Vector2(46,14)],[Vector2(46,8),Vector2(46,14)],[Vector2(46,20),Vector2(46,14)]]
	var ok=0; var last=""
	for pair in spots:
		var feet=Vector3(pair[0].x,t.ground(pair[0]),pair[0].y); var eye=feet+Vector3(0,1.62,0)
		var aim=Vector3(pair[1].x,t.ground(pair[1])+0.02,pair[1].y)
		# Step in to 4 m (the reach is 5 m), as a player would.
		var dir=(aim-eye).normalized(); var flat=Vector2(aim.x-feet.x,aim.z-feet.z).normalized()
		feet=Vector3(aim.x-flat.x*4,0,aim.z-flat.y*4); feet.y=t.ground(Vector2(feet.x,feet.z)); eye=feet+Vector3(0,1.62,0); dir=(aim-eye).normalized()
		v.actor={"eye":eye,"feet":feet,"direction":dir}
		var plan=Mini.plan(c,id,v.actor)
		if plan.error.is_empty(): ok+=1
		else: last=plan.error
	check(ok==4,"a 3×4×3 build unfolds from every side, 4 m away (failed: %s)" % last)
	var total=c.blocks.size()
	check(Mini.unfold(c,id,v.actor).contains("展开") and c.blocks.size()==total+placed and c.miniatures.is_empty(),"unfolding puts every block back")
	var plan_low: Vector3i=Vector3i(99999,0,99999)
	for b in c.blocks.values(): plan_low=plan_low.min(c.cell(b))
	check(Construction.new().restore(c.serialize()),"the unfolded cabin keeps material conservation")
	# Replica: display only.
	Mini.pack(c,{"type":"block","key":c.blocks.keys()[0]}); id=c.miniatures.keys()[0]
	s.coins=1000
	var cost=Mini.replica_cost(c,id)
	check(s.replicate_miniature(id).begins_with("复刻了") and c.miniatures.size()==2 and is_equal_approx(s.coins,1000.0-cost),"复刻 makes a paid display replica")
	var copy=""
	for k in c.miniatures:
		if c.miniatures[k].get("replica",false): copy=k
	check(Mini.plan(c,copy,v.actor).error.contains("只用于展示"),"a replica never unfolds on the planet")
	check(Mini.exhibit(c,copy,4,s.plots).contains("摆上") or Mini.exhibit(c,copy,5,s.plots).contains("摆上"),"a replica can stand on the island")
	check(Construction.new().restore(c.serialize()),"replicas do not break material conservation in the save")
	var bad=c.serialize(); bad.miniatures[copy].replica="yes"
	check(not Construction.new().restore(bad),"a malformed replica flag is rejected")
