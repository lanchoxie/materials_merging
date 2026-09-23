extends "res://tests/test_organic15.gd"
const V2=preload("res://scripts/planet_v2.gd")

func _initialize() -> void:
	var flow=Flow.new(); var helper=Placement.new()
	check(flow.reference_ids()==["urea","ethanol","glycerol"],"three organic recipes use the same data catalogue")
	for reference in ["ethanol","glycerol"]:
		var s=State.new(); doctor(s); var r=s.reactors[0]; var v=s.planet.v2; var o=v.organics
		var work=flow.draft(s,reference)
		check(s.sandbox_validate(work) and s.sandbox_reference(work).get("reference_id")==reference,reference+" graph identity is recognized")
		check(work.positions!=s.sandbox.baseline(reference).positions,reference+" starter is not perfect")
		var fake=work.duplicate(true); fake.bonds[0][2]=2
		check(s.sandbox_reference(fake).get("reference_id")!=reference,reference+" wrong bond graph cannot gain identity")
		flow.buy_missing(s,0,reference); var coins=s.coins; flow.start(s,0,reference); advance(s,1)
		check(r.has("installation") and s.coins==coins-12 and flow.stock(s,reference)==0,reference+" consumes only installation fee, no free products")
		for i in range(180):
			if not r.has("installation"): break
			advance(s,1)
		check(s.reference_id(r)==reference and s.quality(r)<0.98,reference+" doctor installs authored molecule into real reactor")
		for i in range(90):
			if r.pending>0: break
			advance(s,1)
		flow.harvest(s,0,reference)
		var batches=s.planet.sample_candidates(s,reference)
		check(batches.size()==1 and batches[0].quantity==1,reference+" real production yields exactly one collected sample")
		if batches.is_empty(): continue
		var sample=batches[0]; v.active=true
		var water=s.product_snapshot(s._new_reactor(5,"water",0)); s.storage.add_product(water,3)
		var tank=helper.place(v,"mixing_tank",Vector2(12,12)); helper.look(v,Vector2(12,12),0.5)
		var token=s.planet.shipment_serial
		var payload={"batch_id":sample.id,"token":token}
		s.planet.command(s,"organic_add",payload); s.planet.command(s,"organic_add",payload)
		check(sample.quantity==0 and o.tanks[tank].solid_g==5 and o.substance(o.tanks[tank])==reference,reference+" repeat events debit once and retain species")
		for i in range(12): o.tick(v.field,v.construction)
		check(o.tanks[tank].dissolved_g==0 and o.is_liquid(o.tanks[tank]),reference+" dry liquid aliquot waits for water without becoming a crystal")
		s.planet.command(s,"organic_add",{"batch_id":water.id,"token":s.planet.shipment_serial}); v.advance(10)
		check(o.tanks[tank].dissolved_g==5 and o.concentration(o.tanks[tank])==5,reference+" water mixing uses finite teaching mass")
		var other="glycerol" if reference=="ethanol" else "ethanol"
		check(not o.input_error(tank,other,"another",v.construction).is_empty(),"cross species mixing refuses before stock debit")
		s.planet.command(s,"organic_bottle",{"token":s.planet.shipment_serial}); var id=str(o.serial-1)
		check(o.bottles[id].mass_g==1.25 and o.substance(o.bottles[id])==reference,"aliquot carries correct compound and concentration")
		check(v.inventory.entries(s)["solution:"+id].name.contains(o.substance_name(reference)),"shared backpack labels correct organic solution")
		var plot=helper.place(v,"planter",Vector2(17,14)); v.field.plant(plot,v.world,v.construction)
		check(not o.apply_error(id,plot,v.field).is_empty() and o.bottles.has(id),"non fertilizer cannot silently become urea crop bonus")
		var saved=v.serialize(); var copy=V2.new()
		check(copy.restore(JSON.parse_string(JSON.stringify(saved))),"new compound mixtures and bottles survive strict save")
		var corrupt=saved.duplicate(true); corrupt.organics.bottles[id].reference=other
		check(not V2.new().restore(corrupt),"species swapped bottle fails save even when total mass balances")
		var other_tank=helper.place(v,"mixing_tank",Vector2(20,14))
		var fake_batch={"id":"other","work":flow.draft(s,other)}
		o.tank(other_tank,v.construction); o.add_input(other_tank,other,fake_batch)
		check(not o.return_error(id,other_tank,v.construction).is_empty(),"pouring into different compound is refused")
		helper.look(v,Vector2(12,12),0.5); token=s.planet.shipment_serial
		payload={"id":id,"token":token}; s.planet.command(s,"organic_apply",payload); s.planet.command(s,"organic_apply",payload)
		check(not o.bottles.has(id) and o.tanks[tank].water_l==1 and o.tanks[tank].dissolved_g==5,"pour back with retry cannot duplicate bottle or mass")
		s.planet.command(s,"organic_add",{"batch_id":water.id,"token":s.planet.shipment_serial})
		check(o.concentration(o.tanks[tank])==2.5,"dilution halves concentration without changing compound")
		o.drain(tank); var totals=o.species_balance()
		check(totals[reference].input==totals[reference].held and o.waste_by_reference[reference]==5,"sealed waste retains species and finite mass")
		check(V2.new().restore(JSON.parse_string(JSON.stringify(v.serialize()))),"mixed species waste ledgers restore")
		check(o.rules.references[reference].water_solubility.value==null and o.rules.references[reference].toxicity_endpoints==null,"miscibility never becomes invented saturation or toxicity")
		s.close_science()
	var legacy=V2.new(); var tank=helper.place(legacy,"mixing_tank",Vector2(12,12)); var o=legacy.organics
	o.tank(tank,legacy.construction); var s=State.new(); var batch=s.product_snapshot(s._new_reactor(1,"urea",0)); o.add_input(tank,"urea",batch); o.drain(tank)
	var data=legacy.serialize(); data.organics.version=1; data.organics.erase("waste_by_reference")
	for t in data.organics.tanks.values(): t.erase("reference")
	var loaded=V2.new(); check(loaded.restore(data) and loaded.organics.waste_by_reference.urea==5,"organic14/15 saves migrate urea waste without inventing new material")
	s.close_science(); helper.free()
	print("ORGANIC16: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
