extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): push_error("Player save isolation flag required"); quit(2); return
	root.size=Vector2i(1440,900); run.call_deferred()
	create_timer(70).timeout.connect(func(): push_error("Player materials UI timeout"); quit(2))
func find_button(node: Node,text: String):
	if node is Button and node.text.begins_with(text): return node
	for child in node.get_children():
		var found=find_button(child,text)
		if found!=null: return found
	return null
func button(text: String) -> void:
	var b=find_button(game.modal,text); check(b!=null,"button exists: "+text)
	if b!=null: b.pressed.emit()
	await process_frame; await process_frame
func drop(site: String) -> void:
	var p=game.modal; var start=p.tray.get_global_rect().get_center(); var finish=p.viewport_box.global_position+p.view.project_site(site)*p.viewport_box.size/Vector2(p.viewport.size)
	await game._test_touch(start,true)
	var drag=InputEventScreenDrag.new(); drag.index=0; drag.position=finish; drag.relative=finish-start; Input.parse_input_event(drag); await process_frame
	await game._test_touch(finish,false); await process_frame
func capture(name: String) -> void:
	game.toast_panel.hide(); await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+"-v018.png")
func run() -> void:
	Input.emulate_touch_from_mouse=true
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var p=s.planet
	var work=s.new_sandbox_structure("星桥 · 自创结构")
	for atom in [["C",[-1.5,0,0]],["C",[-.5,.8,0]],["O",[.5,0,0]],["H",[1.5,.8,0]],["Br",[.5,1.6,0]]]: s.sandbox_add_atom(work,atom[0],atom[1])
	for i in range(4): s.sandbox_toggle_bond(work,i,i+1)
	s.storage.add_product({"id":"creative-ui","name":work.name,"formula":s.sandbox_formula(work),"reference":"","quality":0.0,"work":work},3)
	game._show_planet(); await process_frame; await button("领取合作"); await button("我的材料")
	var panel=game.modal; var select: OptionButton
	for child in panel.body.get_children():
		if child is OptionButton: select=child; break
	check(select!=null,"archive entry lists collected specimens")
	select.select(1); select.item_selected.emit(1); await process_frame; await process_frame
	check(p.materials.records.size()==1 and s.storage.batch("creative-ui").quantity==2,"UI action archives exactly one unknown sample")
	check(panel.view.player_view.atom_count==5 and panel.view.player_view.visible and not panel.view.modern_view.visible,"archive renders the player's actual five-atom structure in its own stage")
	check(panel.dossier_save.disabled and panel.dossier_draft.density_kg_m3==null,"missing properties do not receive silent defaults")
	await create_timer(.4).timeout; await capture("player-archive")
	var scroll=panel.body.get_parent(); var start=Vector2(1280,688)
	await game._test_touch(start,true)
	for i in range(9):
		var drag=InputEventScreenDrag.new(); drag.index=0; drag.relative=Vector2(0,-34); drag.position=start+Vector2(0,-34*(i+1)); Input.parse_input_event(drag); await process_frame
	await game._test_touch(start+Vector2(0,-306),false); await process_frame
	check(scroll.scroll_vertical>100,"phone-style swipe scrolls material controls without dragging the scrollbar")
	var toggles=[]; var spins=[]
	for child in panel.body.get_children():
		if child is HBoxContainer:
			for input in child.get_children():
				if input is CheckButton: toggles.append(input)
				if input is SpinBox: spins.append(input)
	check(toggles.size()==2 and spins.size()==2,"purpose exposes only two necessary editable assumptions")
	toggles[0].button_pressed=true; spins[0].value=2700; toggles[1].button_pressed=true; spins[1].value=235
	check(not panel.dossier_save.disabled and panel.dossier_quote.text.contains("W/K"),"editing assumptions updates the conditional calculation")
	await button("保存假设方案")
	check(p.materials.designs.size()==1 and s.storage.batch("creative-ui").quantity==2,"saving design uses no second specimen")
	var id=str(p.materials.designs.keys()[0]); await button("试用散热芯")
	check(panel.selected_recipe==id and panel.view.display_mode=="modern" and panel.section=="observe","choose saved design opens correct world and deployment tray")
	await button("开启现代城市"); await button("复制城市")
	await drop("modern_cooling")
	check(p.worlds.get_world().modern.custom_sink.get("id","")==id,"touch drag installs immutable custom design into experimental city")
	await button("生产工坊")
	check(find_button(panel,"开始制作")==null and find_button(panel,"查看材料档案")!=null,"custom product never enters standard paid factory workflow")
	await button("查看材料档案")
	check(panel.dossier_id==p.materials.designs[id].record_id,"return preserves structural identity")
	var before=p.materials.serialize(); panel.dossier_draft.conductivity_W_mK=.02; panel._redraw()
	check(before==p.materials.serialize(),"editing displayed hypothesis leaves saved evidence and installed device unchanged")
	panel.dossier_kind="wire"; panel.dossier_mode="same_size"; panel.dossier_draft.resistivity_ohm_m=2e-8; panel._redraw(); await button("保存假设方案"); await button("试用导线")
	await button(str(p.worlds.industry.rules.eras.ww1.name)); await drop("industry_clinic")
	check(p.worlds.get_world().industry.custom_cables.has("clinic"),"saved electrical purpose routes to industrial clinic")
	panel.view.industry_view._process(.05)
	check(panel.view.industry_view.wires.clinic.line.visible,"actual custom wire appears even with no standard wire installed")
	await capture("player-wire")
	await button("我的材料"); panel.body.get_parent().scroll_vertical=550; await process_frame; await capture("player-assumptions")
	check(panel.body.size.x<=panel.body.get_parent().size.x+2,"materials sidebar retains portrait-height scrolling without horizontal overflow")
	check(s.planet.materials.restore(JSON.parse_string(JSON.stringify(s.planet.materials.serialize())),s),"UI-created records and designs restore from JSON")
	game.queue_free(); await process_frame; print("PLAYER MATERIAL UI: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
