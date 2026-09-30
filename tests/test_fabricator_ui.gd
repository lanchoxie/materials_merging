extends SceneTree
## v0.30 制造台 UI: toolbar entry, first-time tour, material cards with real stats, crafting a pick and a panel,
## the rock table reacting to the pick, the refinery speed label, the sources overlay, and back navigation.
const Main=preload("res://scripts/main.gd")
const Fab=preload("res://scripts/fabricator.gd")
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

func texts(node: Node) -> String:
	var out=""
	for l in node.find_children("*","Label",true,false): out+=str(l.text)+"\n"
	for b in node.find_children("*","Button",true,false): out+=str(b.text)+"\n"
	return out

func button(node: Node, prefix: String) -> Button:
	for b in node.find_children("*","Button",true,false):
		if str(b.text).strip_edges().begins_with(prefix) and b.is_visible_in_tree(): return b
	return null

func harvest(s, atoms: Array, units: int) -> String:
	var r: Dictionary=s.reactors[0]
	r.build_left=0.0; r.template="sodium_chloride"; r.atoms=atoms; r.positions=[[-1.3,0,0],[1.3,0,0]]; r.pending=units; r.stored_coins=0.0
	s.harvest(0)
	return s.signature(r)

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames(4)
	var s=game.state
	# Empty workshop explains how to get a crystal.
	var entry=button(game,"制造台")
	check(entry!=null,"the toolbar has a 制造台 entry")
	game.coach_autostart=true
	entry.pressed.emit(); await frames(4)
	var panel=game.modal
	check(panel!=null and panel.has_method("_craft"),"the fabricator opens as a modal")
	check(texts(panel.materials).contains("AlN") and texts(panel.materials).contains("CsPbBr"),"with no crystals, the list suggests real recipes")
	check(texts(panel.picks).contains("起步镐") and texts(panel.picks).contains("5.43 GPa"),"the starter pick shows its baseline hardness")
	check(texts(panel.rocks).contains("花岗岩") and texts(panel.rocks).contains("原 5"),"the rock table shows granite is slow with the starter pick")
	# First-time tour: every step finds its control.
	check(game.coach.active() and game.coach.tour=="fabricator","the fabricator tour starts on the first visit")
	var found=[]
	for i in range(game.coach.steps.size()):
		await frames(2)
		found.append(game.coach.target!=null and game.coach.frame.visible)
		game.coach.next_button.pressed.emit()
	await frames(2)
	check(found.size()==5 and not found.has(false) and s.coach_seen.has("fabricator"),"every fabricator tour step highlights a real control: %s" % [found])
	game._close_all(); await frames()
	# Stock an AlN batch and a PbS batch, reopen.
	s.coins=1000.0
	var aln=harvest(s,["Al","N"],6); var pbs=harvest(s,["Pb","S"],8)
	game._show_fabricator(); await frames(4)
	panel=game.modal
	var mats=texts(panel.materials)
	check(mats.contains("AlN") and mats.contains("GPa") and mats.contains("P6_3mc"),"the AlN card shows its index entry and pick hardness")
	check(mats.contains("PbS") and mats.contains("eV"),"the PbS card shows its band gap")
	var pick_button: Button=panel.craft_buttons.get(aln+":pick")
	check(pick_button!=null and not pick_button.disabled,"the AlN pick can be crafted")
	pick_button.pressed.emit(); await frames(3)
	check(s.fabricator.pick!="" and panel.status.text.contains("已换上"),"crafting equips the new pick: %s" % panel.status.text)
	check(texts(panel.picks).contains("● AlN镐"),"the equipped pick is highlighted")
	check(not texts(panel.rocks).contains("原 5"),"granite is no longer slow with the AlN pick")
	check(is_equal_approx(s.planet.v2.nature.pick_hv,s.fabricator.pick_hv()),"the planet uses the new pick")
	var panel_button: Button=panel.craft_buttons.get(pbs+":panel")
	check(panel_button!=null and not panel_button.disabled,"the PbS panel can be crafted")
	panel_button.pressed.emit(); await frames(3)
	check(s.fabricator.panels.size()==1 and panel.power_label.text.contains("已装 1 / 3"),"the panel is installed on the roof: %s" % panel.power_label.text)
	check(texts(panel.panels_box).contains("PbS") and texts(panel.panels_box).contains("拆下"),"the panel row can be removed")
	# Sources overlay and back handling.
	panel.sources_button.pressed.emit(); await frames()
	var credits=texts(panel.overlay)
	check(credits.contains("10.1016/j.intermet.2011.03.026") and credits.contains("10.2138/am.2006.1844") and credits.contains("10.1063/1.1736034") and credits.contains("Materials Project"),"the sources overlay cites Chen, Broz, Shockley–Queisser and MP")
	check(panel.handle_back() and panel.overlay==null and game.modal==panel,"back closes the overlay first")
	# Refinery shows the solar bonus.
	button(panel,"去精炼厂看看").pressed.emit(); await frames(4)
	check(game.modal!=null and texts(game.modal).contains("含太阳能"),"the refinery level line shows the solar bonus")
	game._close_all(); await frames()
	var st=game.state
	game.queue_free(); await process_frame
	st.close_science()
	print("FABRICATOR UI: ",checks," checks, ",failures.size()," failures")
	if not failures.is_empty(): print(failures)
	quit(0 if failures.is_empty() else 1)
