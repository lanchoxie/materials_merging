extends "res://tests/test_ranch13.gd"

func act(s,action: String,extra: Dictionary={}) -> String:
	extra["token"]=s.planet.shipment_serial
	return s.planet.command(s,action,extra)

func balanced(o) -> bool:
	var b=o.balance(); return absf(b.input_g-b.held_g)<0.00001 and absf(b.input_l-b.held_l)<0.00001

func _initialize() -> void:
	var s=State.new(); var v=s.planet.v2; var o=v.organics; v.active=true
	var work=s.sandbox.from_baseline("urea")
	check(s.sandbox_validate(work) and s.sandbox_reference(work).get("reference_id")=="urea","organic identity resolves from actual topology")
	check(work.positions!=s.sandbox.baseline("urea").positions,"organic starter is perturbed, not a perfect structure")
	var fake=work.duplicate(true); fake.bonds[0][2]=1
	check(s.sandbox_reference(fake).get("reference_id")!="urea","same formula with wrong bond graph does not get urea properties")
	var water=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(water,10)
	var urea=s.product_snapshot(s._new_reactor(4,"urea",0)); s.storage.add_product(urea,12)
	var tank=place(v,"mixing_tank",Vector2(12,12)); look(v,Vector2(12,12),0.5)
	check(v.Target.query(v).get("key")==tank,"mixing tank is an actual ray-selected construction")
	var token=s.planet.shipment_serial; var payload={"batch_id":urea.id,"token":token}
	s.planet.command(s,"organic_add",payload); s.planet.command(s,"organic_add",payload)
	check(s.storage.batch(urea.id).quantity==11 and o.tanks[tank].solid_g==5,"repeat sample event consumes exactly once")
	for i in range(12): o.tick(v.field,v.construction)
	check(o.tanks[tank].solid_g==5 and o.tanks[tank].dissolved_g==0,"dry crystals cannot dissolve without water")
	act(s,"organic_add",{"batch_id":water.id}); v.advance(5)
	check(o.tanks[tank].solid_g>0 and o.tanks[tank].dissolved_g>0,"visible dissolution progresses over star-world time")
	var t=o.serialize(); v.world.paused=true; v.tick(15)
	check(o.serialize()==t,"paused world freezes dissolution")
	v.world.paused=false; v.advance(10)
	check(o.tanks[tank].solid_g==0 and is_equal_approx(o.concentration(o.tanks[tank]),5),"one sample plus one water yields 5 teaching g per liter")
	act(s,"organic_add",{"batch_id":water.id}); var count=s.storage.batch(water.id).quantity
	act(s,"organic_add",{"batch_id":water.id})
	check(s.storage.batch(water.id).quantity==count and o.tanks[tank].water_l==2,"full tank rejects water without consuming inventory")
	check(is_equal_approx(o.concentration(o.tanks[tank]),2.5),"dilution halves concentration, preserving urea mass")
	var oxygen=s.product_snapshot(s._new_reactor(5,"oxygen",0)); s.storage.add_product(oxygen,1)
	act(s,"organic_add",{"batch_id":oxygen.id})
	check(s.storage.batch(oxygen.id).quantity==1,"unsupported sample has no consumption or fake inferred property")
	var saved=v.serialize(); var restored=V2.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved))) and balanced(restored.organics),"partial and dissolved mass survive strict JSON save")
	check(restored.construction.occupied.has(tank),"restored loaded tank is protected against miniature/dismantle duplication")
	var bad=saved.duplicate(true); bad.organics.tanks[tank].dissolved_g+=1
	check(not V2.new().restore(bad),"save validator rejects unbacked material creation")
	bad=saved.duplicate(true); bad.organics.tanks[tank].water_l=-1
	check(not V2.new().restore(bad),"negative fluid quantity is rejected")
	bad=saved.duplicate(true); bad.organics.tanks[tank].temperature_c=30
	check(not V2.new().restore(bad),"unsupported temperature cannot silently use reference condition")
	var old=V2.new().serialize(); old.erase("organics")
	check(V2.new().restore(old),"old saves get an empty organic ledger")
	act(s,"organic_bottle"); var bottle=str(o.serial-1)
	check(o.bottles.has(bottle) and s.planet.v2.inventory.entries(s).has("solution:"+bottle),"finite bottled solution enters the existing backpack")
	check(is_equal_approx(o.bottles[bottle].mass_g,0.625) and balanced(o),"proportional aliquot conserves both solid mass and water")
	act(s,"organic_apply",{"id":bottle})
	check(o.bottles.has(bottle),"invalid application target does not consume a bottle")
	var plot=place(v,"planter",Vector2(17,14)); var control=place(v,"planter",Vector2(19,14))
	v.field.plant(plot,v.world,v.construction); v.field.plant(control,v.world,v.construction)
	v.field.gardens[plot].moisture=0.8; v.field.gardens[control].moisture=0.8
	look(v,Vector2(17,14),0.6); act(s,"organic_apply",{"id":bottle})
	check(not o.bottles.has(bottle) and o.soils.has(plot) and not o.soils.has(control),"dose goes only to targeted planter, no global planet bonus")
	var soil_mass=o.soils[plot].mass_g; act(s,"organic_apply",{"id":bottle})
	check(o.soils[plot].mass_g==soil_mass,"reusing spent bottle cannot create fertilizer")
	v.advance(25)
	check(v.field.gardens[plot].growth>v.field.gardens[control].growth,"same-water control crop grows slower than gentle fertilized crop")
	check(o.spent_g>0 and balanced(o),"crop uptake has a named conservation sink")
	look(v,Vector2(12,12),0.5); act(s,"organic_drain")
	check(o.waste_l>0 and o.waste_g>0 and balanced(o),"draining seals finite waste without refund or mass loss")
	for i in range(3): act(s,"organic_add",{"batch_id":urea.id})
	act(s,"organic_add",{"batch_id":water.id}); v.advance(30); act(s,"organic_bottle")
	bottle=str(o.serial-1); look(v,Vector2(17,14),0.6); act(s,"organic_apply",{"id":bottle})
	check(o.injury(plot)>0.3 and o.growth_factor(plot)<1,"concentrated dose visibly injures crop and slows growth")
	var injury=o.injury(plot); v.advance(20)
	check(o.injury(plot)<injury and o.injury(plot)>0 and balanced(o),"leaf injury recovers gradually, not by reopening UI")
	var copy=V2.new(); check(copy.restore(JSON.parse_string(JSON.stringify(v.serialize()))) and balanced(copy.organics),"soil injury, consumption and bottles survive save/reentry")
	# Real factory production path and top-level archive validation.
	var factory=State.new(); factory.coins=10000; factory.campus_build(3,"workshop"); factory.campus_road(3); factory.campus_assign_post(factory.campus.people[0].id,"workshop")
	factory.planet.command(factory,"join"); factory.planet.v2.field.stock.stone=3; factory.planet.v2.field.stock.timber=2
	var wallet=factory.coins; factory.planet.command(factory,"pack",{"recipe":"field_mixing_tank","production_mode":"island"}); factory.planet.tick(60,1)
	check(factory.planet.products.size()==1 and factory.planet.products[0].recipe=="field_mixing_tank" and factory.coins==wallet,"island workshop makes tank with real resources, no extra shop coins")
	check(factory.planet.v2.field.stock.stone==0 and factory.planet.v2.field.stock.timber==0,"tank recipe consumes exact natural stock")
	check(State.new().planet.restore(JSON.parse_string(JSON.stringify(factory.planet.serialize())),State.new()),"actual workshop output survives full product-source validation")
	var corrupt=factory.planet.serialize(); corrupt.v2.organics.inputs={"fake":{"reference":"urea","count":1,"work":fake}}; corrupt.v2.organics.waste_g=5
	check(not State.new().planet.restore(corrupt,State.new()),"top-level restore rejects fake-identity organic source even with balanced mass")
	var slots=v.inventory.serialize(); slots.slots[0]="solution:1"
	check(v.inventory.restore(slots),"bottle shortcut survives save even after bottle was used")
	check(o.rules.references.urea.toxicity_endpoints==null and o.rules.references.urea.water_solubility.value==null,"missing toxicity and ambiguous quantitative solubility remain unknown")
	look(v,Vector2(12,12),0.5); act(s,"organic_drain")
	var before_stock=s.storage.batch(urea.id).quantity
	var result=s.planet.command(s,"v2_dismantle")
	check(not v.construction.blocks.has(tank) and result.contains("拆回"),"empty sealed tank can be dismantled normally")
	check(V2.new().restore(JSON.parse_string(JSON.stringify(v.serialize()))),"immediate save after dismantling an empty tank remains valid")
	check(s.storage.batch(urea.id).quantity==before_stock and balanced(o),"dismantling does not refund used chemistry or duplicate mass")
	var fast=V2.new(); var ft=place(fast,"mixing_tank",Vector2(12,12))
	fast.organics.tank(ft,fast.construction); fast.organics.add_input(ft,"urea",urea); fast.organics.add_input(ft,"water",water)
	fast.active=true; fast.world.speed=4; fast.tick(1)
	check(fast.organics.tanks[ft].dissolved_g==2,"dissolution respects world speed instead of render frame rate")
	print("ORGANIC14: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
