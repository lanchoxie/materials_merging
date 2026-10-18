extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.53: the sandbox editor's atom feedback — the selected
## atom's context, the fit sentence with stars and its bar, the rate, and hovering a ball.

func shot(file: String) -> void:
	await create_timer(0.9).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v053"))
	root.get_texture().get_image().save_png("res://artifacts/v053/%s-%s.png" % [file,tag])

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	for i in range(20): await process_frame
	s.campus.people.append(s.campus._new_person("doctor",-1,true))
	for el in ["C","O","H","N"]: s.element_inventory[el]=30
	s.coins=9000
	var plot=-1
	for i in range(s.plots.size()):
		if s.plots[i].unlocked and s.plots[i].kind=="empty": plot=i; break
	var work=s.sandbox.from_baseline("methane","甲烷 · 教学几何")
	game._open_sandbox_editor(work.duplicate(true),plot); for i in range(14): await process_frame
	var ed=game.modal
	ed.selected=0; ed._render(); ed._update_readout()
	for node in _scrolls(ed): node.scroll_vertical=0
	for i in range(14): await process_frame
	print("V053 feedback: %s | %s | %s" % [ed.context_label.text,ed.fit_label.text,ed.rate_label.text])
	await shot("atom-feedback")
	# Nudge a hydrogen away from its ideal length and watch the fit sentence change.
	ed.selected=1
	ed._nudge(0,0.40)
	for i in range(10): await process_frame
	print("V053 off-fit: %s | %s" % [ed.fit_label.text,ed.context_label.text])
	await shot("fit-after-nudge")
	print("V053 CAPTURE done (%s)" % tag); quit(0)

func _scrolls(node: Node,out: Array=[]) -> Array:
	if node is ScrollContainer: out.append(node)
	for child in node.get_children(): _scrolls(child,out)
	return out
