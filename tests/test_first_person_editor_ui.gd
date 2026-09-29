extends "res://tests/test_river_field_ui.gd"

var island
var position_before: Vector2
var yaw_before: float
var pitch_before: float

func returned(reason: String) -> void:
	check(game.modal==island and is_instance_valid(island) and game.editor_return_view==null,reason+": same first-person scene returns")
	check(island.walker.position.is_equal_approx(position_before) and is_equal_approx(island.walker.yaw,yaw_before) and is_equal_approx(island.walker.pitch,pitch_before),reason+": position and orientation preserved")
	check(island.world.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and island.input.walking and island.input.has_focus() and island.process_mode==Node.PROCESS_MODE_INHERIT,reason+": perspective and movement input resume")

func interact() -> void:
	island.input.grab_focus()
	await key(KEY_E)
	await process_frame

func escape() -> void:
	var e=InputEventKey.new(); e.keycode=KEY_ESCAPE; e.physical_keycode=KEY_ESCAPE; e.pressed=true
	Input.parse_input_event(e); await process_frame
	e=InputEventKey.new(); e.keycode=KEY_ESCAPE; e.physical_keycode=KEY_ESCAPE; e.pressed=false
	Input.parse_input_event(e); await process_frame

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); game.set_process(false)
	var s=game.state; s.coins=10000
	game._show_island_walk(); await process_frame; island=game.modal
	island.walker.position=Vector2(0,1.3); island.walker.reset_height(); island.walker.yaw=0; island.walker.pitch=-0.1; island._camera()
	position_before=island.walker.position; yaw_before=island.walker.yaw; pitch_before=island.walker.pitch
	await capture("reactor-return-before")
	await interact(); var editor=game.modal
	check(editor.get_script().resource_path.contains("atom_editor") and game.editor_return_view==island,"reactor input suspends the caller instead of freeing it")
	check(island.process_mode==Node.PROCESS_MODE_DISABLED and not island.input.walking and island.walker.movement==Vector2.ZERO,"editor pauses walking and clears held inputs")
	check(island.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and game.world_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"both background 3D views stop rendering while editing")
	check(editor.return_button.text.contains("返回漫步"),"reactor exit names the real return destination")
	await key(KEY_W); await key(KEY_E)
	check(game.modal==editor and island.walker.position==position_before,"editor inputs cannot move the suspended player or reopen the reactor")
	await capture("reactor-return-editor")
	var tap=editor.return_button.get_global_rect().get_center()
	await game._test_touch(tap,true); await game._test_touch(tap,false); await process_frame
	returned("touch cancel")
	await capture("reactor-return-after")
	await interact(); editor=game.modal
	var coins=s.coins; editor.points[0][0]+=0.08; var edited=editor.points.duplicate(true)
	editor._apply(); await process_frame
	check(s.coins<coins and s.reactors[game.selected_reactor].positions==edited,"successful edit saves geometry and debits its fee")
	returned("apply")
	await interact(); editor=game.modal; s.coins=0; editor.points[0][0]+=0.06; editor._apply(); await process_frame
	check(game.modal==editor and game.editor_return_view==island,"failed payment leaves the editor open")
	s.coins=10000; editor._show_palette(); await process_frame; await escape()
	check(game.modal==editor and editor.palette==null,"first Escape dismisses only the element palette")
	await escape(); returned("Escape")
	await interact(); game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST); await process_frame
	returned("Android back")
	# Exercise the real custom-reactor routing, not only a direct editor call.
	var work=s.reactor_work(s.reactors[game.selected_reactor]); work.positions[0][0]+=0.05; s.apply_sandbox_to_reactor(game.selected_reactor,work)
	check(s.reactors[game.selected_reactor].get("sandbox",false),"fixture is an actual custom reactor")
	await interact(); editor=game.modal
	check(editor.get_script().resource_path.contains("sandbox_editor") and editor.return_label=="返回漫步","custom reactor uses the same return destination")
	editor.draft.positions[0][0]+=0.08; editor.handle_back(); await process_frame
	check(editor.confirmation.visible and game.modal==editor and editor.confirmation.dialog_text.contains("返回漫步"),"unsaved custom structure confirms before leaving")
	editor.handle_back(); await process_frame
	check(not editor.confirmation.visible and game.modal==editor,"back from confirmation continues editing")
	editor.handle_back(); await process_frame; editor.confirmation.confirmed.emit(); await process_frame
	returned("custom editor discard")
	await interact(); editor=game.modal; editor.handle_back(); await process_frame
	returned("custom editor clean close")
	await key(KEY_S); await process_frame
	check(island.walker.position!=position_before,"walking works again after repeated edit visits")
	game._open_editor(); game._show_planet_v2(); await process_frame; await process_frame
	check(not is_instance_valid(island) and game.editor_return_view==null and game.modal.has_method("_enter"),"leaving for another destination frees the suspended scene")
	game._close_modal(); s.reactors[game.selected_reactor].erase("sandbox"); game._open_editor(); await process_frame
	editor=game.modal; check(editor.return_button.text.contains("返回工坊") and game.editor_return_view==null,"management view keeps its own return label")
	editor._cancel(); await process_frame
	check(game.modal==null and game.world_viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"management editor closes to the management view")
	game._open_sandbox_editor(s.reactor_work(s.reactors[game.selected_reactor])); await process_frame
	game.modal.handle_back(); await process_frame
	check(game.modal!=null and button(game.modal,"新建空白探索作品")!=null,"standalone sandbox still returns to the works library")
	game.queue_free(); await process_frame
	print("FIRST PERSON EDITOR UI: %d checks, %d failures" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
