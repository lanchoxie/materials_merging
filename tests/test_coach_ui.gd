extends SceneTree
## v0.28 coach marks: first-time tours per screen, blocked clicks outside the highlight, persistence.
const Main=preload("res://scripts/main.gd")
const State=preload("res://scripts/lab_state.gd")
var checks=0
var failures=[]
var game
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1440,900)
	_run.call_deferred()

func frames(n: int=3) -> void:
	for i in range(n): await process_frame

func tap(at: Vector2) -> void:
	await game._test_touch(at,true); await game._test_touch(at,false); await process_frame

## Walks a tour with the 下一步 button, recording which steps found their control.
func walk(tour: String) -> Array:
	var found=[]
	check(game.coach.active() and game.coach.tour==tour,"%s tour starts on first visit" % tour)
	if not game.coach.active(): return found
	for i in range(game.coach.steps.size()):
		await frames(2)
		found.append(game.coach.target!=null and game.coach.frame.visible)
		game.coach.next_button.pressed.emit()
	await frames(2)
	check(not game.coach.active() and game.state.coach_seen.has(tour),"%s tour finishes and is remembered" % tour)
	return found

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	check(not game.coach.active() and not game.state.default_slot_enabled,"script-driven runs start without tours and never touch the player's save slot")
	game.coach_autostart=true; game._coach("island")
	await frames(4)
	var s=game.state; s.coins=50000
	check(game.coach.active() and game.coach.tour=="island","the island tour starts in a new game")
	check(game.coach.target==game.world_box and game.coach.frame.visible,"the first step highlights the island view")
	# Clicks on the dimmed area must not reach the toolbar underneath.
	var box_button=preload("res://scripts/coach_tours.gd").find_button(game,"◇  探索盲盒")
	await tap(box_button.get_global_rect().get_center()); await frames()
	check(game.modal==null,"a dimmed toolbar button cannot be pressed during the tour")
	var found=await walk("island")
	check(found.size()==5 and not found.has(false),"every island step highlights a real control")
	# Refinery: the tour highlights the guide, stock, extractors, processes and the planet button.
	game._show_refinery(); await frames(4)
	found=await walk("refinery")
	check(found.size()==5 and not found.has(false),"every refinery step highlights a real control")
	game._close_modal(); await frames()
	game._show_refinery(); await frames(4)
	check(not game.coach.active(),"a seen tour does not repeat")
	game._close_modal(); await frames()
	# Organic reactor: the refinery button step may centre when nothing is missing, the rest are real.
	game._show_organic_synthesis(0); await frames(4)
	found=await walk("organic")
	check(found.size()==4 and found[0] and found[1] and found[3],"organic tour highlights recipe, requirements and start")
	game._close_all(); await frames()
	# Atom editor: pressing the highlighted control also advances.
	game._select_plot(int(s.reactors[0].plot)); s.reactors[0].build_left=0.0; game._open_editor(); await frames(4)
	check(game.coach.active() and game.coach.tour=="editor" and game.coach.target==game.modal.viewbox,"the editor tour starts on the drag area")
	game.coach.next_button.pressed.emit(); await frames(2)
	game.coach.next_button.pressed.emit(); await frames(2)
	check(game.coach.target==game.modal.apply_button,"third editor step highlights the apply button")
	game.coach.next_button.pressed.emit(); await frames(2)
	var back: Button=game.modal.return_button
	check(game.coach.target==back,"last editor step highlights the return button")
	await tap(back.get_global_rect().get_center()); await frames(3)
	check(not game.coach.active() and s.coach_seen.has("editor"),"pressing the highlighted control finishes the step (and the screen closing ends the tour)")
	game._close_all(); await frames()
	# Structure workshop dialog; leaving mid-tour ends it quietly.
	game._show_sandbox(); await frames(4)
	check(game.coach.active() and game.coach.tour=="sandbox" and game.coach.target!=null,"the workshop tour starts")
	game._close_modal(); await frames(3)
	check(not game.coach.active() and s.coach_seen.has("sandbox"),"closing the screen mid-tour stops the overlay")
	# Skipping.
	s.coach_seen.erase("refinery"); game._show_refinery(); await frames(4)
	game.coach.skip_button.pressed.emit(); await frames()
	check(not game.coach.active() and s.coach_seen.has("refinery") and game.toast_label.text.contains("重新播放"),"skip ends the tour and says how to replay")
	game._close_all(); await frames()
	# Persistence and replay.
	var path="res://saves/test-coach.json"; s.save_game(path)
	var copy=State.new(); check(copy.load_game(path) and copy.coach_seen.has("island") and copy.coach_seen.has("editor"),"seen tours survive save and load")
	var data=JSON.parse_string(FileAccess.get_file_as_string(path)); data.coach=[1,2]
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data)); DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	check(not State.new().load_game(path),"a malformed coach list is rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game._show_help(); await frames()
	preload("res://scripts/coach_tours.gd").find_button(game.modal,"重新播放新手指引").pressed.emit(); await frames(4)
	check(game.coach.active() and game.coach.tour=="island" and s.coach_seen.is_empty(),"help replays the tours from the start")
	var st=game.state
	game.queue_free(); await process_frame
	st.close_science(); copy.close_science()
	print("COACH UI: ",checks," checks, ",failures.size()," failures")
	if not failures.is_empty(): print(failures)
	quit(0 if failures.is_empty() else 1)
