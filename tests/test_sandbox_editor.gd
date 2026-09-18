extends SceneTree

const State = preload("res://scripts/lab_state.gd")
const Editor = preload("res://scripts/sandbox_editor.gd")
var checks := 0
var failures: Array[String] = []

class TestState extends State:
	func sandbox_saved_root() -> String:
		return "res://artifacts/sandbox-ui-test-works"

func _initialize() -> void:
	root.size = Vector2i(1440, 900)
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var model = TestState.new()
	var coins: float = model.coins
	var inventory: Dictionary = model.element_inventory.duplicate(true)
	var editor = Editor.new()
	root.add_child(editor)
	editor.setup(model, model.new_sandbox_structure("交互检查"))
	await process_frame
	await process_frame
	check(editor.selected == -1 and editor.draft.atoms.is_empty(), "empty canvas opens")
	editor._choose_element("O")
	editor._add_atom()
	editor._choose_element("H")
	editor._add_atom()
	editor._add_atom()
	check(editor.draft.atoms == ["O", "H", "H"], "element grid adds chosen species")
	check(editor.selected == 2, "last added atom selected")
	editor.pair_a.select(0)
	editor.pair_b.select(2)
	editor.bond_order.select(1)
	editor._set_bond()
	check(editor.draft.bonds == [[0, 2, 2]], "arbitrary nonadjacent pair gets chosen order")
	editor.bond_order.select(2)
	editor._set_bond()
	check(editor.draft.bonds == [[0, 2, 3]], "changing bond order replaces existing edge")
	editor._remove_bond()
	check(editor.draft.bonds.is_empty(), "explicit bond removal")
	editor._undo()
	check(editor.draft.bonds == [[0, 2, 3]], "undo restores removed bond")
	editor._select(1)
	editor._delete_atom()
	check(editor.draft.bonds == [[0, 1, 3]], "delete remaps surviving endpoints")
	editor._undo()
	check(editor.draft.atoms.size() == 3, "undo restores deleted atom")
	editor._select(0)
	editor._nudge(2, 0.1)
	check(is_equal_approx(float(editor.draft.positions[0][2]), 0.1), "depth nudge changes selected atom")
	editor._choose_element("S")
	editor._replace_atom()
	check(editor.draft.atoms[0] == "S", "replacement applies to selection")
	editor._undo()
	check(editor.draft.atoms[0] == "O", "undo restores replacement")
	editor._periodic_changed(true)
	editor._cell_changed(7.2, 0)
	editor.repeat_toggle.button_pressed = true
	check(editor.draft.periodic and is_equal_approx(float(editor.draft.cell[0]), 7.2), "periodic cell editable")
	check(editor.balls.size() == 3 and editor.specimens.get_child_count() > 24, "repeat preview keeps only original cell editable")
	editor._set_mode(1)
	check(editor.draft.mode == "art" and editor.reference_label.text.contains("不声称"), "art mode separates science claims")
	editor._set_mode(0)
	editor._periodic_changed(false)
	editor._fit_view()
	await process_frame
	await process_frame
	var p: Vector2 = editor.camera.unproject_position(editor.balls[0].position)
	var local: Vector2 = p * editor.viewbox.size / Vector2(editor.viewport.size)
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.pressed = true
	touch.position = local
	editor._view_input(touch)
	check(editor.selected == 0 and editor.dragging, "native touch selects atom")
	var before: Array = editor.draft.positions[0].duplicate()
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = local + Vector2(35, 10)
	editor._view_input(drag)
	check(editor.draft.positions[0] != before, "touch drag edits coordinates")
	touch.pressed = false
	editor._input(touch)
	check(not editor.dragging and editor.active_touch == -1, "release outside viewport ends gesture")
	editor._undo()
	check(editor.draft.positions[0] == before, "single undo restores whole drag")
	check(model.coins == coins and model.element_inventory == inventory, "all draft operations preserve inventory and coins")
	editor.name_input.text = "交互检查作品"
	editor._save()
	var restored: Dictionary = model.load_sandbox_structure("交互检查作品")
	var positions_match: bool = restored.positions.size() == editor.draft.positions.size()
	for i in range(restored.positions.size()):
		for axis in range(3): positions_match = positions_match and is_equal_approx(float(restored.positions[i][axis]), float(editor.draft.positions[i][axis]))
	check(restored.atoms == editor.draft.atoms and positions_match, "named work persists actual edited coordinates")
	check(restored.bonds == editor.draft.bonds and restored.mode == "science", "named work persists topology and mode")
	check(model.coins == coins and model.element_inventory == inventory, "saving work has no production charge")
	check(not editor.apply_button.is_visible_in_tree() or editor.apply_button.disabled, "no selected reactor cannot apply")
	editor._add_atom()
	editor.handle_back()
	check(editor.confirmation.visible, "back offers draft discard without losing work immediately")
	editor.handle_back()
	check(not editor.confirmation.visible, "back dismisses confirmation first")
	editor._undo()
	await process_frame
	await process_frame
	for button in [editor.save_button, editor.apply_button, editor.name_input]:
		check(Rect2(Vector2.ZERO, Vector2(1440, 900)).encloses(button.get_global_rect()), "persistent editor action fits viewport")
	for button in editor.element_buttons.values():
		check(button.get_global_rect().end.x < 1406.0, "element grid does not overflow sidebar")
	editor.draft = model.sandbox_from_baseline("water", "我的第一滴星水")
	editor.draft.cell = [6.0, 6.0, 6.0]
	editor.draft.periodic = false
	editor.draft.mode = "science"
	editor.selected = 0
	editor._rebuild(true)
	editor._message("可从基线起步，也可以从空白画布自由创造。")
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/sandbox-editor-070.png")
	editor.queue_free()
	await process_frame
	print("SANDBOX EDITOR: %d checks; %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
