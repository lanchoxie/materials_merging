extends SceneTree
## v0.29 chemistry index UI: codex entry point, browser tabs/filters/pages, entry view with a 3D
## preview and sourced properties, credits, reactor sidebar line, find banner and first-time tour.
const Main=preload("res://scripts/main.gd")
const Index=preload("res://scripts/chem_index.gd")
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

func _run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames(4)
	var s=game.state
	# Codex → index.
	game._show_collection(); await frames()
	var open=button(game.modal,"化学索引")
	check(open!=null and open.text.contains("/ %d" % Index.size()),"the codex links to the chemistry index with its size")
	game.coach_autostart=true
	open.pressed.emit(); await frames(4)
	check(game.index_grid!=null and game.index_grid.get_child_count()==game.INDEX_PAGE,"the browser shows a full page of molecule cards")
	check(texts(game.modal).contains("PubChem") and texts(game.modal).contains("Materials Project"),"the header names both databases")
	# First-time tour: every step finds its control, and chips stay usable inside the highlight.
	check(game.coach.active() and game.coach.tour=="index","the index tour starts on the first visit")
	var found=[]
	for i in range(game.coach.steps.size()):
		await frames(2)
		found.append(game.coach.target!=null and game.coach.frame.visible)
		if i==1:
			game._toggle_index_element("Br"); await frames(2)
			check(game.coach.active() and game.coach.tour=="index","filtering inside the highlight keeps the tour running")
			game._toggle_index_element("Br")
		game.coach.next_button.pressed.emit()
	await frames(2)
	check(found.size()==4 and not found.has(false) and s.coach_seen.has("index"),"every index tour step highlights a real control: %s" % [found])
	# Tabs, filters, pages.
	button(game.modal,"晶体").pressed.emit(); await frames()
	check(game.index_kind=="crystal" and texts(game.index_grid).contains("mp-"),"the crystal tab lists Materials Project entries")
	game._toggle_index_element("Li"); game._toggle_index_element("Cl"); await frames()
	var listed=texts(game.index_grid)
	check(listed.contains("LiCl") and not listed.contains("NaBr"),"element chips filter to entries containing every chosen element")
	check(game.index_count.text.contains("含 Li、Cl"),"the count line names the filter")
	game.index_filter.clear(); game._refresh_index(); await frames()
	var first_page=texts(game.index_grid)
	button(game.modal,"下一页").pressed.emit(); await frames()
	check(game.index_page==1 and texts(game.index_grid)!=first_page and not button(game.modal,"上一页").disabled,"pages move through the list")
	button(game.modal,"只看已收录").pressed.emit(); await frames()
	check(game.index_found_only and game.index_grid.get_child_count()==0 and game.index_count.text.contains("还没有收录"),"found-only starts empty and explains how to fill it")
	game.index_found_only=false
	# Entry view: 3D preview plus sourced properties.
	var licl: Dictionary=s.structure_data({"template":"sodium_chloride","atoms":["Li","Cl"]}).index
	game._show_index_entry(str(licl.key)); await frames(3)
	var preview=game.modal.find_child("IndexPreview",true,false)
	check(preview!=null and preview.find_child("Spin",true,false).get_child_count()>=8,"crystal entries show a turning unit cell with its atoms and edges")
	var page=texts(game.modal)
	check(page.contains("空间群") and page.contains("Fm-3m") and page.contains("Materials Project") and page.contains("CC BY 4.0"),"crystal entries show the space group and the source with its licence")
	check(page.contains("尚未收录"),"an unfound entry says how to collect it")
	var water: Dictionary=s.structure_data({"template":"water","atoms":["O","H","H"]}).index
	game._show_index_entry(str(water.key)); await frames(3)
	preview=game.modal.find_child("IndexPreview",true,false)
	check(preview!=null and preview.find_child("Spin",true,false).get_child_count()==5,"molecule entries draw three atoms and two bonds")
	check(texts(game.modal).contains("PubChem CID 962"),"molecule entries cite the PubChem CID")
	button(game.modal,"数据来源与致谢").pressed.emit(); await frames()
	page=texts(game.modal)
	check(page.contains("CC BY 4.0") and page.contains("10.1063/1.4812323") and page.contains("10.1093/nar/gkae1059"),"credits list both databases with licence and citations")
	game._close_all(); await frames()
	# Reactor sidebar: an index line, and a link when it is a find.
	var r=s.reactors[0]; r.build_left=0.0; r.template="sodium_chloride"; r.atoms=["Li","Cl"]; r.positions=[[-1.3,0,0],[1.3,0,0]]
	game._select_plot(int(r.plot)); await frames()
	var line=game.find_child("IndexLine",true,false)
	check(line!=null and line.text.contains("LiCl") and line.text.contains("mp-"),"the reactor sidebar names the index match")
	var link=button(game.side,"查看真实数据")
	check(link!=null,"the sidebar links to the index entry")
	link.pressed.emit(); await frames(3)
	check(game.modal!=null and texts(game.modal).contains("LiCl"),"the link opens the entry")
	game._close_all(); await frames()
	# Harvest a find: banner notice is consumed, the card turns gold.
	r.stored_coins=5.0
	game._action(s.harvest(0)); await frames()
	game._process(0.016); await frames()
	check(s.index_found.has(str(licl.key)) and s.index_notice.is_empty(),"a find is recorded and its banner shown")
	game.index_kind="crystal"; game.index_found_only=true; game._show_index(); await frames(3)
	check(game.index_grid.get_child_count()==1 and texts(game.index_grid).contains("已收录"),"found-only lists the new find")
	game._close_all(); await frames()
	# Workshop: the reference line reports the index result live.
	game._open_sandbox_editor({"name":"HBr","atoms":["H","Br"],"positions":[[0,0,0],[1.41,0,0]],"bonds":[[0,1,1]],"mode":"science","periodic":false,"cell":[6.0,6.0,6.0],"baseline_id":""}); await frames(3)
	var editor=game.modal
	check(editor!=null and editor.reference_label.text.contains("溴化氢") and editor.reference_label.text.contains("CID"),"the workshop names a matching PubChem molecule")
	game._close_all(); await frames()
	var st=game.state
	game.queue_free(); await process_frame
	st.close_science()
	print("CHEM INDEX UI: ",checks," checks, ",failures.size()," failures")
	if not failures.is_empty(): print(failures)
	quit(0 if failures.is_empty() else 1)
