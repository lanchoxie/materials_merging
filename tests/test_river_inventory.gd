extends SceneTree
const State=preload("res://scripts/lab_state.gd")
const Inventory=preload("res://scripts/river_inventory.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func manufacture(s,recipe: String) -> void:
	s.planet.command(s,"buy_feed",{"input":s.planet.recipe(recipe).input})
	s.planet.command(s,"pack",{"recipe":recipe}); s.planet.tick(60)
func _initialize() -> void:
	var s=State.new(); var p=s.planet; var v=p.v2; var bag=v.inventory; s.coins=10000
	var sample=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(sample,4)
	p.command(s,"join"); p.command(s,"qualify",{"batch_id":sample.id})
	manufacture(s,"frame_bundle"); manufacture(s,"modern_silicon"); manufacture(s,"modern_perovskite")
	var items=bag.entries(s); var original=p.products.duplicate(true); var stock=s.storage.batches.duplicate(true); var wallet=s.coins
	check(items["recipe:frame_bundle"].quantity==8,"one actual factory package exposes eight loose building units")
	check(items["recipe:modern_silicon"].quantity==1 and items["recipe:modern_perovskite"].quantity==1,"same-kind solar technologies retain separate inventory identities")
	check(items["sample:"+sample.id].quantity==s.storage.batch(sample.id).quantity,"sample slot references its actual batch quantity after qualification")
	check(bag.bind_slot(4,"recipe:modern_perovskite",items),"owned recipe can be equipped")
	bag.bind_slot(6,"recipe:modern_perovskite",items)
	check(bag.slots[4]=="" and bag.slots[6]=="recipe:modern_perovskite","moving a shortcut does not duplicate the slot")
	bag.bind_slot(6,"tool:collect",items)
	check(bag.slots[0]=="recipe:modern_perovskite" and bag.slots[6]=="tool:collect","occupied shortcut swap preserves both references")
	check(not bag.bind_slot(-1,"tool:collect",items) and not bag.bind_slot(0,"recipe:fake",items),"invalid item and slot rejected")
	check(p.products==original and s.storage.batches==stock and s.coins==wallet,"organizing backpack neither copies nor spends any stock or money")
	v.active=true; var c=v.construction; var at=Vector2(19,14); var eye=Vector3(at.x,c.terrain.ground(at)+4,at.y)
	v.actor={"eye":eye,"feet":eye-Vector3(0,1.62,0),"direction":Vector3.DOWN}
	p.command(s,"v2_build",{"kind":"solar","recipe":"modern_perovskite"})
	check(c.sources.values()[0].product.recipe=="modern_perovskite" and p.available_products("modern_silicon")==1,"placement consumes the chosen solar recipe, never the first same-kind product")
	check(bag.entries(s)["recipe:modern_perovskite"].quantity==0,"empty equipped recipe remains visible with zero count")
	var before=c.serialize(); p.command(s,"v2_build",{"kind":"solar","recipe":"modern_perovskite"})
	check(Same.same(before,c.serialize()) and p.available_products("modern_silicon")==1,"depleted selection cannot silently consume silicon")
	p.command(s,"v2_dismantle")
	check(bag.entries(s)["recipe:modern_perovskite"].quantity==1,"dismantle replenishes the same shortcut from the original source")
	var saved=p.serialize(); var other=State.new()
	check(other.planet.restore(JSON.parse_string(JSON.stringify(saved)),other),"backpack bindings roundtrip with validated full game state")
	check(other.planet.v2.inventory.serialize()==bag.serialize(),"selected slot and rearrangement persist")
	var old=saved.duplicate(true); old.v2.erase("inventory")
	check(other.planet.restore(old,other) and other.planet.v2.inventory.slots==bag.rules.defaults,"old saves initialize shortcuts without granting products")
	var bad=bag.serialize(); bad.selected=99; check(not Inventory.new().restore(bad),"invalid saved selection rejected")
	bad=bag.serialize(); bad.slots[2]=bad.slots[0]; check(not Inventory.new().restore(bad),"duplicate saved references rejected")
	bad=bag.serialize(); bad.slots[2]=17; check(not Inventory.new().restore(bad),"non-string saved reference rejected")
	bag.bind_slot(2,"sample:"+sample.id,bag.entries(s))
	s.storage.batches.clear()
	check(not bag.entries(s).has("sample:"+sample.id) and bag.missing("sample:"+sample.id).quantity==0,"missing exact sample remains an empty reference, never swaps to another batch")
	# A lone high pillar used to incorrectly count adjacent unroofed ground.
	c.blocks.clear()
	for y in range(4): c.blocks[c.key(Vector3i(15,y,14))]={"x":15,"y":y,"z":14,"kind":"block"}
	check(c.shelter_cells(Vector2(10,10),14)==0,"exposed floor beside a pillar is not shelter")
	for x in [16,17]: c.blocks[c.key(Vector3i(x,3,14))]={"x":x,"y":3,"z":14,"kind":"block"}
	check(c.shelter_cells(Vector2(10,10),14)==2,"two clear floor cells directly below a roof count as two housing cells")
	print("RIVER INVENTORY: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
