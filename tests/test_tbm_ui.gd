extends SceneTree
## v0.45 盾构机 in play: deployed from 星锻岛, it appears in front of the player on the planet; E gets
## in, W bores (the dashboard shows what's ahead, the haul and the battery), space switches dive/
## climb, E gets out into the tunnel, and the machine's place is kept.
const Main=preload("res://scripts/main.gd")
var checks:=0
var failures=[]
var game
func check(ok: bool,msg: String)->void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func _initialize()->void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred(); create_timer(120).timeout.connect(func(): quit(2))
func _run()->void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2
	check(preload("res://scripts/test_mode.gd").give_tbm(s).contains("盾构机") and s.industry.tbm=="tbm","the test kit deploys a charged machine")
	game._show_starforge(); for i in range(3): await process_frame
	game.modal._tab("gear"); for i in range(3): await process_frame
	var found=false
	for b in _buttons(game.modal,[]):
		if b.text=="收回盾构机": found=true
	check(found,"星锻岛's gear tab shows the deployed machine")
	game._close_all(); await process_frame
	game._show_planet_v2(); await process_frame; var panel=game.modal
	v.world.paused=true
	panel._enter(); for i in range(4): await process_frame
	panel._sync(); await process_frame
	check(not v.tbm_at.is_empty() and panel.view.tbm_parked and panel.view.tbm_node.visible,"the machine appears in front of you")
	check(panel.near_tbm(),"it is close enough to get in")
	panel._collect(); await process_frame
	check(panel.view.boring and v.boring and panel.view.pilot()==panel.view.tbm,"E gets in; the controls drive the machine")
	panel._aim()
	check(panel.aim_label.text.begins_with("盾构机") and panel.aim_label.text.contains("电量"),"the dashboard replaces the aim line (%s)" % panel.aim_label.text.get_slice("\n",0))
	var start=panel.view.tbm.cell
	panel.view.pilot().jump()
	check(panel.view.tbm.grade==-1,"space switches to diving")
	panel.view.tbm.movement=Vector2(0,-1)
	await create_timer(6.0).timeout
	panel.view.tbm.movement=Vector2.ZERO
	await create_timer(1.0).timeout
	check(panel.view.tbm.metres>=2 and panel.view.tbm.cell.y<start.y,"holding W bores forward and down (%d m, y %d → %d)" % [panel.view.tbm.metres,start.y,panel.view.tbm.cell.y])
	check(not panel.view.tbm.haul.is_empty(),"the cut cells are collected")
	panel._sync()
	check(int(v.tbm_at.y)==panel.view.tbm.cell.y,"the planet keeps the machine's place while boring")
	panel._collect(); await process_frame
	check(not panel.view.boring and not v.boring and panel.message.contains("离开盾构机"),"E gets out (%s)" % panel.message)
	check(absf(panel.view.walker.feet_y-panel.view.tbm.cell.y)<2.6,"you stand in the tunnel behind the machine (feet %.1f, floor %d)" % [panel.view.walker.feet_y,panel.view.tbm.cell.y])
	var path="res://saves/test_tbm_ui.json"
	for f in [path,path+".bak"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	check(s.save_game(path).begins_with("已保存"),"the game saves with the machine underground")
	var loaded=preload("res://scripts/lab_state.gd").new()
	check(loaded.load_game(path) and int(loaded.planet.v2.tbm_at.y)==panel.view.tbm.cell.y and loaded.industry.tbm=="tbm","and loads it back")
	for f in [path,path+".bak"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	game.queue_free(); await process_frame
	if failures.is_empty(): print("TBM UI OK (%d checks)" % checks); quit(0)
	else: print("TBM UI FAILED: ",failures); quit(1)

func _buttons(node: Node,out: Array) -> Array:
	if node is Button: out.append(node)
	for child in node.get_children(): _buttons(child,out)
	return out
