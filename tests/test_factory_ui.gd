extends SceneTree
const Main=preload("res://scripts/main.gd")
const Fixture=preload("res://tests/laminate_fixture.gd")
var game
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred()
	create_timer(45).timeout.connect(func(): quit(2))
func button(n: Node,text: String):
	if n is Button and n.text.contains(text): return n
	for child in n.get_children():
		var found=button(child,text)
		if found!=null: return found
	return null
func press(text: String) -> void:
	var b=button(game.modal,text); check(b!=null,"available action "+text)
	if b!=null: b.pressed.emit()
	await process_frame; await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await create_timer(0.2).timeout; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func _run() -> void:
	if "--verify-retirement-package" in OS.get_cmdline_user_args():
		for path in ["scripts/planet_worlds.gd","scripts/planet_panel.gd","scripts/planet_view.gd","scripts/planet_modern.gd","data/planet_balance.json","data/planet_modern.json","docs/archive/legacy-planet/scripts/planet_panel.gd.txt"]:
			check(not FileAccess.file_exists("res://"+path) and not ResourceLoader.exists("res://"+path),"retired resource absent from exported package "+path)
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var p=s.planet; s.coins=10000
	s.storage.add_product(s.product_snapshot(s._new_reactor(3,"water",0.0)),4)
	game._show_market(); await process_frame
	check(button(game.modal,"材料试验星球")==null and button(game.modal,"湿地实验（新）")==null,"mail contains one current planet, no retired entry")
	await capture("v021-clean-mail")
	await press("工艺车间")
	check(game.modal.get_script()==preload("res://scripts/factory_panel.gd"),"mail factory opens independent module")
	check(button(game.modal,"副本")==null and button(game.modal,"观察 / 对照")==null,"factory contains no legacy world controls")
	s.campus_build(3,"workshop"); s.campus_road(3); s.campus_assign_post(s.campus.people[0].id,"workshop")
	await press("领取合作与首次供料"); await press("提交水样"); await press("开始装罐")
	p.tick(26,1); game.modal._redraw()
	check(p.products.size()==1,"retained workshop manufactures actual finite product")
	await capture("v021-clean-factory")
	await press("进入星球")
	check(game.modal.get_script()==preload("res://scripts/planet_v2_panel.gd") and p.v2.active,"factory opens only the living river world")
	game.modal._tab("bag"); await process_frame; await press("投放 标准水箱")
	check(p.products.is_empty() and p.v2.world.receipts.size()==1,"new world consumes the actual workshop output")
	await press("前往工艺车间")
	check(not p.v2.active and game.modal.get_script()==preload("res://scripts/factory_panel.gd"),"return opens factory and stops river observation")
	await press("导热对照"); await press("记录对照")
	check(p.reports.has("same_size"),"reference research still records evidence without legacy world")
	await capture("v021-clean-material-lab")
	await press("导线对照"); await press("记录导线对照")
	check(p.circuit_reports.has("same_size"),"wire reference calculation remains available")
	var id=Fixture.specimen(s); s.campus.unlocked_materials.append("laminate_design")
	game.modal.dossier_id=id; game.modal._open_dossiers(); await process_frame
	check(game.modal.view.player_view.atom_count==3 and game.modal.view.player_view.laminate.visible,"materials archive and layer visual are independent of planet renderer")
	await press("保存模型方案"); await press("装配 ")
	check(button(game.modal,"城市部署")==null and button(game.modal,"前往邮箱")!=null,"layer workshop routes to real orders and no retired city")
	await capture("v021-clean-layer-workshop")
	game._show_toolbox(); game.modal._tab("industrial"); await process_frame
	check(button(game.modal,"试验湾")==null and button(game.modal,"工艺车间")!=null,"inventory routes also use current factory")
	game.queue_free(); await process_frame
	print("FACTORY_UI: %d checks, %d failures" % [checks,failures.size()])
	FileAccess.open("res://artifacts/v021-factory-ui-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
