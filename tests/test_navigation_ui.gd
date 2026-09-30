extends SceneTree
## v0.28 navigation: side trips from the planet or the island walk come back to the same scene.
const Main=preload("res://scripts/main.gd")
var game
var checks=0
var failures=[]
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1440,900)
	_run.call_deferred()
func key(code: Key) -> void:
	var event=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true
	preload("res://scripts/core/test_input.gd").send(event); await process_frame
	event=event.duplicate(); event.pressed=false
	preload("res://scripts/core/test_input.gd").send(event); await process_frame

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; s.coins=5000
	var v=s.planet.v2
	# Planet in first person, walked away from the landing spot.
	game._show_planet_v2(); await process_frame
	var planet=game.modal
	planet.enter_first_person(); await process_frame
	check(planet.view.first_person,"planet starts in first person")
	planet.view.travel(Vector2(18,9)); planet._sync(); await process_frame
	var spot: Vector2=planet.view.walker.position
	# 1. Backpack → workshop → close: same planet, same spot, still first person.
	planet._open_backpack(); await process_frame
	planet.backpack.workshop_requested.emit(); await process_frame
	check(game.modal!=planet and game.return_stack.has(planet) and not v.active,"workshop suspends the planet")
	check(game.modal.close_button.text=="返回河湾","workshop close button names the planet")
	game.modal.close_button.pressed.emit(); await process_frame
	check(game.modal==planet and v.active and planet.view.first_person and planet.view.walker.position==spot,"closing the workshop returns to the same spot in first person")
	check(not is_instance_valid(planet.backpack),"the backpack that sent you away is closed on return")
	# 2. Organic route → reactor panel → back.
	planet.synthesis_requested.emit(); await process_frame
	check(game.modal!=planet and game.modal.return_button.text.begins_with("返回河湾"),"reactor panel opened from the planet says it returns there")
	game.modal.handle_back(); await process_frame
	check(game.modal==planet and v.active,"leaving the reactor panel returns to the planet")
	# 3. Workshop → campus → close still lands on the planet.
	planet.workshop_requested.emit(""); await process_frame
	game.modal.campus_requested.emit("people"); await process_frame
	check(game.modal.get_script()==preload("res://scripts/campus_panel.gd") and game.modal.close_button.text=="返回河湾","chained screens keep the planet underneath")
	game.modal._close(); await process_frame
	check(game.modal==planet and game.return_stack.is_empty(),"closing a chained screen returns to the planet")
	# 4. Workshop → 进入星球 resumes the same planet rather than building a new one.
	planet.workshop_requested.emit(""); await process_frame
	game.modal.planet_requested.emit(); await process_frame
	check(game.modal==planet and planet.view.walker.position==spot,"进入星球 from the workshop resumes the suspended planet")
	# 5. Back closes an open side panel before leaving first person, and first person before the planet.
	planet._toggle_details(); await process_frame
	check(planet.show_details,"details panel is open")
	await key(KEY_ESCAPE)
	check(game.modal==planet and planet.view.first_person and not planet.show_details,"first back closes only the side panel")
	await key(KEY_ESCAPE)
	check(game.modal==planet and not planet.view.first_person,"second back switches to the overview")
	await key(KEY_ESCAPE)
	check(game.modal==null and not v.active,"third back returns to the island")
	# 6. Island walk → planet → back: the walk comes back.
	game._show_island_walk(); await process_frame
	var walk=game.modal
	walk.walker.position=Vector2(0.4,1.2); walk.walker.reset_height()
	var walk_spot: Vector2=walk.walker.position
	walk.requested.emit("planet",-1); await process_frame
	check(game.modal.get_script()==preload("res://scripts/planet_v2_panel.gd") and game.modal.view.first_person and game.return_stack.has(walk),"walk steps aside for the planet")
	var second=game.modal
	second._close(); await process_frame
	check(game.modal==walk and walk.walker.position==walk_spot and walk.input.walking,"leaving the planet returns to the same walk")
	# 7. The explicit island route leaves everything.
	walk.requested.emit("planet",-1); await process_frame
	game._navigate_materials("island"); await process_frame; await process_frame
	check(game.modal==null and game.return_stack.is_empty() and not is_instance_valid(walk),"the island route closes the planet and the walk")
	game.queue_free(); await process_frame
	s.close_science()
	print("PASS: ",checks," navigation checks" if failures.is_empty() else " FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
