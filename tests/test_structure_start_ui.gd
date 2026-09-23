extends "res://tests/ui_harness.gd"

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + name + ".png")

func run() -> void:
	game = Main.new()
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.state.coins = 10000
	game._open_editor()
	await process_frame
	var editor = game.modal
	var q: float = game.state.quality(game.state.reactors[0])
	check(q < 0.85 and editor.response_label.text.contains("%d%%" % roundi(q * 100)), "starter editor displays actual imperfect geometry")
	var scroll = editor.response_label.get_parent().get_parent()
	check(scroll.get_global_rect().encloses(editor.response_label.get_global_rect()), "current match score is visible before scrolling")
	check(editor.apply_button.disabled, "opening initial draft does not allow an unchanged paid apply")
	await capture("structure-start-atom-editor")
	game._close_modal()
	game._show_templates(false)
	await process_frame
	check(find_button(game.modal, "装载初始结构") != null, "recipe selector makes initial geometry explicit")
	await capture("structure-start-recipes")
	game._close_modal()
	game._show_sandbox()
	await process_frame
	check(find_button(game.modal, "开始调节") != null and find_button(game.modal, "保存初始草稿") != null, "workshop actions distinguish drafts")
	await button("开始调节")
	editor = game.modal
	check(game.state.sandbox_validate(editor.draft), "workshop opens a valid initial sample")
	var ref: Dictionary = game.state.baseline_data(editor.draft.baseline_id)
	check(editor.draft.positions != ref.positions, "visible workshop uses actual offset coordinates")
	check(editor.reference_label.text.contains("配方参考"), "workshop keeps reference provenance visible")
	game._close_modal()
	game.state.close_science()
	game.queue_free()
	await process_frame
	print("STRUCTURE START UI: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
