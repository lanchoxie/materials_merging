extends SceneTree
const Planet=preload("res://scripts/planet_v2.gd")
const State=preload("res://scripts/lab_state.gd")
const Program=preload("res://scripts/planet_program.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	var p=Planet.new()
	check(p.world.regions.size()==4,"four terrain regions are created")
	check(p.region().animals.size()==4 and p.world.regions.wetland.crops.size()==1,"initial life and crop plots exist")
	var before=p.world.regions.wetland.water
	var receipt={"id":101,"recipe":"standard_water_crate","source_batch":"batch-1"}
	check(p.deploy("wetland","standard_water_crate",receipt).begins_with("已消耗"),"water product deploys")
	check(p.world.regions.wetland.water>before and p.world.receipts.size()==1,"water changes region and records batch")
	check(p.quote("highland","oxygen_cartridge")!="","oxygen cartridge is scoped to an oxygen station")
	check(p.deploy("wetland","oxygen_station",{"id":102,"recipe":"oxygen_station"}).begins_with("已消耗"),"oxygen station installs")
	check(p.deploy("wetland","oxygen_cartridge",{"id":103,"recipe":"oxygen_cartridge"}).begins_with("已消耗"),"oxygen cartridge deploys after station")
	check(p.plant("grain")=="已播种，湿度和温度合适时生长","player can plant a crop")
	p.active=true; p.advance(60.0*4.0)
	check(p.day()>=4,"time advances through several days")
	check(p.world.events.size()<=32,"event history is bounded")
	var saved=JSON.parse_string(JSON.stringify(p.serialize())); var q=Planet.new()
	check(q.restore(saved),"planet roundtrip restores")
	check(q.world.elapsed==p.world.elapsed and q.world.receipts.size()==p.world.receipts.size(),"roundtrip preserves elapsed and product receipts")
	var forged=saved.duplicate(true); forged.world.regions.wetland.water=2.0
	check(not Planet.new().restore(forged),"restore rejects forged environment values")
	var deterministic=Planet.new(); deterministic.active=true; deterministic.advance(120)
	var deterministic2=Planet.new(); deterministic2.active=true; deterministic2.advance(120)
	check(JSON.stringify(deterministic.world)==JSON.stringify(deterministic2.world),"same seed produces deterministic ecology")
	var fine=Planet.new(); fine.active=true
	for i in range(3840): fine.tick(1.0/32.0)
	check(Same.same(deterministic.world,fine.world),"simulation independent of render frame duration")
	fine.world.paused=true; var stopped=fine.serialize(); fine.tick(10)
	check(Same.same(stopped,fine.serialize()),"pause does not accumulate a hidden backlog")
	fine.world.paused=false; fine.active=false; fine.tick(10)
	check(fine.world.elapsed==120,"leaving river freezes it")
	fine.active=true; fine.set_speed(8); fine.tick(10)
	check(fine.world.elapsed==200,"8x advances exactly eighty seconds")
	var speed=fine.world.speed; fine.set_speed(7); check(fine.world.speed==speed,"invalid speed rejected")
	var json=JSON.parse_string(JSON.stringify(deterministic.serialize())); var reload=Planet.new()
	check(reload.restore(json),"JSON float counters accepted")
	deterministic.advance(60); reload.advance(60)
	if not Same.same(deterministic.world,reload.world):
		FileAccess.open("res://artifacts/v021-before-reload.json",FileAccess.WRITE).store_string(JSON.stringify(deterministic.world,"\t"))
		FileAccess.open("res://artifacts/v021-after-reload.json",FileAccess.WRITE).store_string(JSON.stringify(reload.world,"\t"))
	check(Same.same(deterministic.world,reload.world),"save reload continues same trajectory")
	var s=State.new(); var pg=s.planet; var coins=s.coins
	var sample=s.product_snapshot(s._new_reactor(3,"water",0.0)); s.storage.add_product(sample,5)
	var payload={"batch_id":sample.id,"region_id":"meadow","token":pg.shipment_serial}
	pg.command(s,"v2_deploy_sample",payload); var water=pg.v2.world.regions.meadow.water
	check(s.storage.batch(sample.id).quantity==4 and water>0.22 and s.coins==coins,"raw water consumes one batch unit and no coins")
	pg.command(s,"v2_deploy_sample",payload)
	check(s.storage.batch(sample.id).quantity==4 and pg.v2.world.regions.meadow.water==water,"duplicate sample token does not consume twice")
	var bad=s.product_snapshot(s._new_reactor(3,"sodium_chloride",0.0)); bad.reference="water"; s.storage.add_product(bad,2)
	before=pg.serialize()
	pg.command(s,"v2_deploy_sample",{"batch_id":bad.id,"region_id":"wetland","token":pg.shipment_serial})
	check(Same.same(before,pg.serialize()) and s.storage.batch(bad.id).quantity==2,"forged water label cannot authorize NaCl use")
	pg.command(s,"join"); pg.command(s,"qualify",{"batch_id":sample.id})
	pg.command(s,"pack"); pg.tick(25)
	var product_id=int(pg.products[0].id); coins=s.coins
	var item={"product_id":product_id,"region_id":"invalid"}
	before=pg.serialize(); pg.command(s,"v2_deploy_product",item)
	check(Same.same(before,pg.serialize()),"invalid product target is fully atomic")
	item.region_id="meadow"; pg.command(s,"v2_deploy_product",item); water=pg.v2.world.regions.meadow.water
	check(pg.products.is_empty() and s.coins==coins,"finished product consumes once without planet purchase")
	pg.command(s,"v2_deploy_product",item)
	check(pg.v2.world.regions.meadow.water==water,"same product id cannot be replayed")
	pg.command(s,"buy_feed",{"input":"frame_kit"}); pg.command(s,"pack",{"recipe":"frame_bundle"}); pg.tick(26)
	check(pg.products.size()==1,"existing factory can make pen components")
	item={"product_id":int(pg.products[0].id),"region_id":"meadow"}
	pg.command(s,"v2_deploy_product",item); pg.v2.enter("meadow"); pg.command(s,"v2_pen")
	check(pg.v2.region().enclosed,"real component installs working pen")
	var restored=Program.new(); saved=JSON.parse_string(JSON.stringify(pg.serialize()))
	check(restored.restore(saved,s),"raw and finished receipts survive combined save validation")
	forged=saved.duplicate(true); forged.v2.world.receipts[0].reference="oxygen"
	check(not Program.new().restore(forged,s),"altered sample proof rejected")
	forged=saved.duplicate(true)
	for entry in forged.v2.world.receipts:
		if entry.kind=="product": forged.products.append(entry.product.duplicate(true)); break
	check(not Program.new().restore(forged,s),"installed product cannot simultaneously exist in inventory")
	forged=saved.duplicate(true); forged.v2.world.regions.highland.buildings.shade_canopy=true
	check(not Program.new().restore(forged,s),"unpaid forged building rejected")
	var old=State.new(); var legacy=old.planet.serialize(); legacy.erase("v2")
	check(Program.new().restore(legacy,old),"older planet saves initialize new river without inventory grants")
	var farm=Planet.new(); farm.enter("meadow"); var seeds=farm.world.seeds
	farm.plant("grain"); check(farm.world.seeds==seeds-1,"sowing costs seed")
	farm.advance(260); var food=farm.world.food; farm.harvest()
	check(farm.world.food>food and farm.world.seeds>seeds,"mature harvest yields feed and seed")
	food=farm.world.food; seeds=farm.world.seeds; farm.harvest()
	check(farm.world.food==food and farm.world.seeds==seeds,"harvest cannot repeat on cleared plot")
	var children=0
	for a in farm.region().animals:
		if a.generation>0: children+=1
	check(children>0,"mature healthy parents produce inherited offspring")
	farm.region().animals=[]; farm.population.enabled=false
	farm.advance(240); check(farm.region().animals.is_empty(),"disabled renewal preserves closed extinction experiments")
	var oxygen=Planet.new(); oxygen.world.regions.wetland.oxygen=0.0
	oxygen.advance(60)
	var health=oxygen.region().animals[0].health
	check(health<0.9,"low oxygen stresses fish")
	oxygen.deploy("wetland","oxygen_station",{"kind":"fixture"})
	oxygen.deploy("wetland","oxygen_cartridge",{"kind":"fixture"})
	oxygen.advance(60)
	check(oxygen.region().oxygen_fuel==0 and oxygen.region().oxygen>0.2,"oxygen equipment uses a finite cartridge")
	var dry=Planet.new(); dry.enter("highland"); dry.plant("grain"); var growth=dry.region().crops[0].growth
	dry.advance(60); check(dry.region().crops[0].growth==growth,"dry soil does not grow crops")
	var long_run=Planet.new(); var start=Time.get_ticks_msec()
	for i in range(30): long_run.advance(60)
	check(long_run.world.events.size()<=32,"thirty-minute event history stays bounded")
	for r in long_run.world.regions.values():
		check(r.animals.size()<=18,"region population bounded after thirty minutes")
	check(Planet.new().restore(JSON.parse_string(JSON.stringify(long_run.serialize()))),"long-run state remains valid")
	print("30 minute model advance: %d ms" % (Time.get_ticks_msec()-start))
	FileAccess.open("res://artifacts/v021-model-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("planet_v2 checks=%d failures=%d" % [checks,failures.size()])
	if not failures.is_empty():
		for f in failures: print(f)
	quit(0 if failures.is_empty() else 1)
