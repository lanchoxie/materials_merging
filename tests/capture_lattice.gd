extends "res://tests/capture_starforge.gd"
## Screenshot helper (not a test) for v0.52: the crystal workbench — a perovskite opened as a real
## cell with its lattice readout, α/β/γ controls, the periodic-site readout and snap-to-boundary.

func shot(file: String) -> void:
	await create_timer(0.9).timeout
	if DisplayServer.get_name()=="headless": return
	game.toast_panel.hide(); await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/v052"))
	root.get_texture().get_image().save_png("res://artifacts/v052/%s-%s.png" % [file,tag])

## Every scroll container inside the editor (the tool column is the one we want to move).
func _scrolls(node: Node,out: Array=[]) -> Array:
	if node is ScrollContainer: out.append(node)
	for child in node.get_children(): _scrolls(child,out)
	return out

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	for i in range(20): await process_frame
	s.campus.people.append(s.campus._new_person("doctor",-1,true))
	for el in ["Cs","Pb","Br"]: s.element_inventory[el]=40
	s.coins=9000
	var plot=-1
	for i in range(s.plots.size()):
		if s.plots[i].unlocked and s.plots[i].kind=="empty": plot=i; break
	# A crystal baseline opens as a crystal: 6.3 Å cell, 15 sites, PBC on.
	var perov=s.new_sandbox_structure("钙钛矿晶胞")
	perov=s.sandbox.from_baseline("perovskite","钙钛矿晶胞")
	game._open_sandbox_editor(perov.duplicate(true),plot); for i in range(14): await process_frame
	var ed=game.modal
	ed.selected=0                     # a Cs corner atom: fractional (0,0,0), 角点 · 1/8
	ed._render(); ed._update_readout()
	# Bring the cell/site readout into view: it sits below the element palette in the tool column.
	for node in _scrolls(ed): node.scroll_vertical=100000
	for i in range(12): await process_frame
	print("V052 readout: %s | %s" % [ed.lattice_label.text,ed.site_label.text])
	await shot("cell-and-sites")
	# Snap on: move a corner atom slightly off the boundary and watch it land back on it.
	ed.snap_toggle.set_pressed_no_signal(true); ed.snap_to_cell=true
	ed.selected=9                     # a Br on +a/2
	ed.draft.positions[9]=[3.30,0.0,0.0]
	ed._nudge(0,0.10)
	ed._render(); ed._update_readout()
	for node in _scrolls(ed): node.scroll_vertical=100000
	for i in range(12): await process_frame
	print("V052 snapped: %s | %s" % [ed.lattice_label.text,ed.site_label.text])
	await shot("snap-boundary")
	print("V052 CAPTURE done (%s)" % tag); quit(0)
