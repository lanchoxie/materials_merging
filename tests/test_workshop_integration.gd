extends SceneTree
const Main=preload("res://scripts/main.gd")
const Access=preload("res://scripts/workshop_access.gd")
var game
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func button(node: Node,text: String):
	if node is Button and node.text.contains(text): return node
	for child in node.get_children():
		var found=button(child,text)
		if found!=null: return found
	return null
func press(text: String) -> void:
	var b=button(game.modal if game.modal!=null else game.side,text)
	check(b!=null and not b.disabled,"available workshop action: "+text)
	if b!=null and not b.disabled: b.pressed.emit()
	await process_frame; await process_frame
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(60).timeout.connect(func(): quit(2))
func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.set_process(false) # Explicit simulation steps keep accounting assertions deterministic.
	var s=game.state; var p=s.planet; s.coins=10000
	var sample=s.product_snapshot(s._new_reactor(3,"water",0)); s.storage.add_product(sample,4)
	p.command(s,"join"); p.command(s,"qualify",{"batch_id":sample.id}); p.command(s,"buy_feed",{"input":"frame_kit"})
	var payload={"recipe":"frame_bundle","production_mode":"island"}
	var wallet=s.coins; var supply=p.input_count("frame_kit")
	p.command(s,"pack",payload)
	check(p.job.is_empty() and s.coins==wallet and p.input_count("frame_kit")==supply and p.production_mode=="partner","no workshop rejects without debit or changing existing production mode")
	s.campus_build(3,"workshop"); wallet=s.coins
	p.command(s,"pack",payload)
	check(not Access.status(s).ready and p.job.is_empty() and s.coins==wallet,"disconnected workshop cannot accept a new order")
	s.campus_road(3); wallet=s.coins
	p.command(s,"pack",payload)
	check(not Access.status(s).ready and p.job.is_empty() and s.coins==wallet,"workshop without assigned engineers cannot accept a new order")
	s.campus_assign_post(s.campus.people[0].id,"workshop")
	check(Access.status(s).ready and Access.status(s).rate==0,"assigned engineer allows reservation but travel grants no production")
	p.command(s,"pack",{"recipe":"modern_silicon","production_mode":"island"})
	check(p.job.is_empty() and s.coins==wallet and p.production_mode=="partner","missing supply also leaves cash and mode unchanged")
	game._select_plot(3)
	await press("制造材料与器件")
	check(game.modal.get_script()==preload("res://scripts/factory_panel.gd"),"physical workshop opens the shared manufacturing panel")
	var options=[]
	for i in range(1,game.modal.recipe_menu.item_count): options.append(game.modal.recipe_menu.get_item_metadata(i))
	check("frame_bundle" in options and "modern_silicon" in options and "modern_perovskite" in options and options.size()==Access.recipe_ids(p).size(),"manufacturing includes both construction photovoltaic recipes without duplicates")
	game.modal._choose_recipe("frame_bundle")
	check(game.modal.view.displayed_recipe=="frame_bundle","wood supply has its own manufacturing preview")
	await press("安排工程师")
	check(game.modal.current_tab=="people","workshop links to real staffing controls")
	await press("工艺车间")
	check(game.modal.selected_recipe=="frame_bundle","staffing round trip keeps the selected recipe")
	await press("开始制作")
	check(p.production_mode=="island" and p.job.recipe=="frame_bundle" and p.input_count("frame_kit")==supply-1 and s.coins==wallet-p.recipe("frame_bundle").fee,"workshop order reserves real supply and charges the recipe fee once")
	var remaining=p.job.left; wallet=s.coins
	p.command(s,"pack",payload)
	check(s.coins==wallet and p.input_count("frame_kit")==supply-1,"repeated request cannot duplicate or charge a running order")
	s.tick(0.5)
	check(p.job.left==remaining,"actual game clock waits for engineer arrival")
	var restored=preload("res://scripts/planet_program.gd").new()
	check(restored.restore(JSON.parse_string(JSON.stringify(p.serialize())),s) and restored.production_mode=="island" and restored.job.id==p.job.id,"in-flight local order survives JSON restore")
	for i in range(180):
		if p.job.is_empty(): break
		s.tick(1)
	check(p.job.is_empty() and p.available_products("frame_bundle")==1 and p.products[0].source_batch==sample.id,"road travel and real engineer labor produce one traceable component package")
	game.modal._choose_recipe("modern_silicon"); p.command(s,"buy_feed",{"input":"modern_silicon_kit"}); game.modal._redraw()
	await press("开始制作")
	check(p.job.get("recipe")=="modern_silicon" and p.production_mode=="island","photovoltaic manufacture uses the same island workshop")
	# Old partner work must not silently change owner when viewing the workshop.
	p.command(s,"production_mode",{"mode":"partner"}); var before=p.job.duplicate(true)
	game._show_factory("modern_silicon")
	check(p.production_mode=="partner" and p.job==before,"opening the workshop preserves an existing legacy partner job")
	p.tick(60,0); game.modal._redraw()
	check(p.available_products("modern_silicon")==1,"legacy partner order finishes exactly once")
	if DisplayServer.get_name()!="headless":
		game.toast_panel.hide(); await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/workshop-integration-solar.png")
	await press("进入星球"); game.modal._tab("build")
	check(p.v2.construction.available("block",p.products)==8 and p.v2.construction.available("solar",p.products)==1,"planet toolbox sees the actual workshop output without extra purchases")
	await press("去车间制作光伏")
	check(game.modal.selected_recipe=="modern_silicon" and not p.v2.active,"planet shortcut opens its precise recipe and closes the planet observer")
	game._show_planet_v2(); game.modal._tab("build"); await press("去车间制作木构件")
	check(game.modal.selected_recipe=="frame_bundle","wood shortcut opens the corresponding component recipe")
	game.queue_free(); await process_frame
	print("WORKSHOP INTEGRATION: ",checks," checks, ",failures.size()," failures")
	FileAccess.open("res://artifacts/workshop-integration-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
