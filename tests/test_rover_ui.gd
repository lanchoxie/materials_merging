extends SceneTree
## v0.41 rover through the real planet panel: deployed rover parks beside the player, E (the action
## path) boards it, the input drives it, the chase camera follows, E climbs out beside it, Android back
## leaves the seat, and the parked spot is saved. Screenshots when windowed.
const Main=preload("res://scripts/main.gd")
var checks=0
var failures=[]
var game

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): quit(2); return
	root.size=Vector2i(1440,900); _run.call_deferred()
	create_timer(150).timeout.connect(func(): push_error("rover ui timeout"); quit(2))

func frames(n: int) -> void:
	for i in range(n): await process_frame

func shot(file: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await create_timer(0.6).timeout; game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v041"))
	root.get_texture().get_image().save_png("res://artifacts/v041/%s.png" % file)

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; var v=s.planet.v2
	await frames(5)
	preload("res://scripts/test_mode.gd").rover_kit(s)
	v.world.elapsed=60.0*4+30
	game._show_planet_v2(); await process_frame; var panel=game.modal
	panel._select_region("meadow"); panel._enter(); await frames(30)
	panel._sync(); await frames(5)
	var view=panel.view
	check(view.rover_parked and not v.rover_at.is_empty(),"the deployed rover parks beside the player")
	check(view.walker.position.distance_to(view.rover.position)<=4.5,"it is within reach (%.1f m)" % view.walker.position.distance_to(view.rover.position))
	panel._aim()
	check(panel.action_button.text=="上车 E" and panel.aim_label.text.contains("E 上车"),"the action button offers 上车")
	await shot("rover-parked")
	panel._collect(); await frames(3)
	check(view.driving and v.driving and view.pilot()==view.rover,"E boards the rover and the input now drives it")
	var start=view.rover.position; var charge=float(view.rover.state.charge)
	panel.explore_input.keys[KEY_W]=true; panel.explore_input._refresh_movement()
	await create_timer(2.5).timeout
	panel.explore_input.keys.erase(KEY_W); panel.explore_input._refresh_movement()
	var moved=view.rover.position.distance_to(start)
	check(moved>5.0,"holding W drives it (%.1f m)" % moved)
	check(float(view.rover.state.charge)<charge,"driving uses battery")
	check(view.walker.position==view.rover.position,"the seat carries the walker (observers, trail and targeting follow)")
	check(view.camera.position.distance_to(view.rover.eye())>3.0,"the chase camera sits behind the rover")
	panel._aim()
	check(panel.aim_label.text.contains("km/h") and panel.action_button.text=="下车 E","the HUD shows speed, charge and 下车")
	await shot("rover-driving")
	panel._collect(); await frames(3)
	check(not view.driving and view.walker.position.distance_to(view.rover.position)>1.5 and view.walker.position.distance_to(view.rover.position)<4.0,"E climbs out beside the rover")
	check(absf(float(v.rover_at.x)-view.rover.position.x)<0.01,"where it stopped is remembered")
	panel._collect(); await frames(2)
	check(view.driving,"boarding again")
	check(panel.handle_back() and not view.driving,"Android back leaves the seat first")
	var path="res://saves/rover-ui.json"
	check(s.save_game(path).begins_with("已保存"),"the game saves with a parked rover")
	var loaded=preload("res://scripts/lab_state.gd").new()
	check(loaded.load_game(path) and not loaded.planet.v2.rover_at.is_empty() and loaded.industry.vehicle=="rover","the parked rover and the deployment load back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path)); DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	s.industry.deploy_rover(""); panel._sync(); await frames(2)
	check(not view.rover_parked and v.rover_at.is_empty(),"recalling the rover removes it from Earth")
	game.queue_free(); await process_frame
	if failures.is_empty(): print("ROVER UI OK (%d checks)" % checks); quit(0)
	else: print("ROVER UI FAILED: ",failures); quit(1)
