extends SceneTree
## v0.31 "Builder": island-wide tiles (footprints cross plot edges), undo, eraser/recycle, and the
## doctor + element gates on new reactors, template swaps and composition edits. Save v27.
const State=preload("res://scripts/lab_state.gd")
const Town=preload("res://scripts/island_town.gd")
const Fixtures=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func plot_at(s, x: int, z: int) -> int:
	for i in range(s.plots.size()):
		if int(s.plots[i].x)==x and int(s.plots[i].z)==z: return i
	return -1

func _run() -> void:
	var s=State.new()
	s.coins=5000.0
	# Start: plots 3 (-1,0), 4 (0,0, the water reactor), 5 (1,0) and 7 (0,1) are open.
	var west=plot_at(s,-1,0); var middle=plot_at(s,0,0); var east=plot_at(s,1,0); var south_west=plot_at(s,-1,1)
	check(Town.usable()==12 and Town.grid()==12,"every tile of a plot is buildable")
	check(s.plots[middle].kind=="reactor" and not s.plots[south_west].unlocked,"the starting island has a reactor in the middle and locked land to the south-west")
	# Footprints spill across plot edges onto unlocked land, never onto locked land.
	var spill=s.town_place(west,"stone_path",11,4)
	check(spill.contains("已摆放"),"a path can straddle two plots: %s" % spill)
	var uid=int(s.plots[west].items.back().uid)
	var hit: Dictionary=s.town_at(Town.to_global(s.plots[middle],Vector2i(0,4)))
	check(hit.get("plot",-1)==west and hit.get("id","")==str(uid),"the spilled tile belongs to the path's own plot")
	check(s.town_place(middle,"wood_fence",0,5).contains("占用"),"the neighbour can't build over the spilled tile")
	check(s.town_place(west,"stone_path",4,11).contains("超出已开拓"),"footprints can't reach locked land")
	check(s.town_place(west,"stone_path",12,0).contains("所选地块内"),"the anchor must stay inside its plot")
	# The reactor keeps its centre 8×8; its rim takes decor and extra buildings.
	check(s.town_place(middle,"wood_fence",4,4).contains("占用"),"the reactor core stays clear")
	var house=s.town_place(middle,"engineer_house",10,3)
	check(house.contains("落成"),"a house fits on the reactor rim and spills into the next plot: %s" % house)
	var house_uid=int(s.plots[middle].items.back().uid)
	check(s.layout.kind_capacity(s.plots,middle,"engineer_house")>0,"a house on a reactor plot adds beds there")
	check(s.town_move(middle,house_uid,east,0,0).contains("本地块"),"buildings keep their anchor in their own plot")
	# Placement helpers respect neighbours.
	var spot: Vector2i=s.town_spot(east,"institute")
	check(spot.x>=0 and s.town_fits(east,"institute",spot).is_empty(),"town_spot finds a free anchor that avoids the spilled house")
	check(Town.island_first_fit(s.plots,east,"institute").x>=0,"first fit scans the plot island-wide")
	# Undo: placing from coins refunds the coins.
	var coins: float=s.coins
	s.town_place(east,"stone_path",0,10)
	var placed_uid=int(s.plots[east].items.back().uid)
	check(s.coins<coins and s.town_undo_text().contains("石板路"),"the journal names the last step: %s" % s.town_undo_text())
	var undone=s.town_undo()
	check(undone.begins_with("已撤销") and is_equal_approx(s.coins,coins) and s.town_item(east,placed_uid).is_empty(),"undo takes the path back and refunds it: %s" % undone)
	# Undo a move.
	s.town_move(west,uid,east,6,6)
	check(s.town_item(west,uid).is_empty() and not s.town_item(east,uid).is_empty(),"decor moves to another plot")
	s.town_undo()
	var back: Dictionary=s.town_item(west,uid)
	check(not back.is_empty() and int(back.x)==11 and int(back.z)==4,"undo moves it back to the old plot and tile")
	# Undo a store, and a toolbox placement returns the toolbox stock.
	s.town_store(west,uid)
	var stock=int(s.storage.decorations.get("stone_path",0))
	s.town_undo()
	check(not s.town_item(west,uid).is_empty() and int(s.storage.decorations.get("stone_path",0))==stock-1,"undo puts a stored path back with its uid")
	s.storage.decorations["wood_fence"]=2
	coins=s.coins
	s.town_place(east,"wood_fence",3,3)
	s.town_undo()
	check(int(s.storage.decorations.wood_fence)==2 and is_equal_approx(s.coins,coins),"undoing a toolbox placement returns it to the toolbox")
	# A painted stroke is one undo step.
	s.town_group_begin()
	for x in [0,1,2,3]: s.town_place(east,"wood_fence",x,0)
	s.town_group_end()
	check(s.town_undo_text().contains("×") and s.town_undo().begins_with("已撤销"),"a stroke undoes as one step")
	check(s.town_items(east).filter(func(i): return i.kind=="wood_fence").is_empty(),"the whole stroke is gone")
	# Undoing a building refunds it while nobody lives there.
	coins=s.coins
	s.town_place(east,"park",6,6)
	check(s.town_undo().begins_with("已撤销") and is_equal_approx(s.coins,coins) and s.plots[east].kind=="empty","undo of a first building empties the plot again")
	# Recycle: one plot's decor, then every path on the island; both are one undo step.
	s.town_place(east,"stone_path",0,0); s.town_place(east,"hedge",5,5); s.town_place(west,"wood_path",0,0)
	var before_paths=int(s.storage.decorations.get("stone_path",0))
	check(s.town_recyclable(east).size()==2,"the plot lists its two decorations")
	var recycled=s.town_recycle(east)
	check(recycled.contains("2件") and s.town_items(east).filter(func(i): return not Town.is_building(str(i.kind))).is_empty() and int(s.storage.decorations.stone_path)==before_paths+1,"recycling a plot sends its decor to the toolbox: %s" % recycled)
	s.town_undo()
	check(s.town_recyclable(east).size()==2,"undo restores the recycled plot")
	var paths=s.town_recyclable(-1).size()
	check(paths==3,"island-wide recycle lists only paths: %d" % paths)
	s.town_recycle(-1)
	check(s.town_recyclable(-1).is_empty() and s.town_items(east).any(func(i): return i.kind=="hedge"),"island-wide recycle leaves hedges and buildings")
	check(s.town_items(middle).any(func(i): return int(i.uid)==house_uid),"buildings are never recycled")
	s.town_undo()
	check(s.town_recyclable(-1).size()==3,"undo lays the paths again")
	# Save v27 round trip and validation of cross-plot footprints.
	var path="res://saves/test_builder.json"
	for f in [path,path+".bak"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	check(s.save_game(path).begins_with("已保存"),"builder save succeeds")
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(raw.version)==28,"saves are version 28")
	var loaded=State.new()
	check(loaded.load_game(path) and loaded.town_journal.is_empty() and not loaded.town_at(Town.to_global(loaded.plots[middle],Vector2i(0,4))).is_empty(),"spilled footprints survive save and load; the undo journal does not")
	var bad: Dictionary=raw.duplicate(true)
	bad.plots[middle].items.append({"uid":90001,"kind":"wood_fence","x":0,"z":4,"rot":0})
	check(not loaded._validate_save(bad),"an item on a neighbour's spilled tile is rejected")
	bad=raw.duplicate(true)
	bad.plots[west].items.append({"uid":90002,"kind":"stone_path","x":0,"z":11,"rot":0})
	check(not loaded._validate_save(bad),"an item reaching locked land is rejected")
	bad=raw.duplicate(true)
	bad.plots[west].items.append({"uid":90003,"kind":"wood_fence","x":12,"z":0,"rot":0})
	check(not loaded._validate_save(bad),"an anchor outside its plot is rejected")
	raw.version=26
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(raw)); file.close()
	check(State.new().load_game(path),"a v26 save still loads")
	for f in [path,path+".bak"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))

	# --- gates ---
	var g=State.new()
	g.coins=5000.0
	var empty=plot_at(g,1,0)
	check(not g.install_status().ok and g.install_status().message.contains("需要装炉博士"),"a new island has no installing doctor")
	var refused=g.place_reactor(empty,"water")
	check(refused.contains("需要装炉博士") and g.reactors.size()==1 and is_equal_approx(g.coins,5000.0),"no doctor, no new reactor: %s" % refused)
	check(g.change_template(0,"hydrogen").contains("需要装炉博士"),"no doctor, no template swap")
	var r: Dictionary=g.reactors[0]; r.build_left=0.0
	var moved: Array=r.positions.duplicate(true); moved[0]=[float(moved[0][0])+0.05,float(moved[0][1]),float(moved[0][2])]
	var tune: Dictionary=g.edit_quote(0,moved,g.atom_symbols(r))
	check(tune.ready,"coordinate tuning stays allowed without a doctor: %s" % tune.message)
	var swapped: Array=g.atom_symbols(r).duplicate(); swapped[0]="S"
	g.element_inventory.S=5
	var swap: Dictionary=g.edit_quote(0,r.positions,swapped)
	check(not swap.ready and swap.message.contains("需要装炉博士") and swap.message.contains("微调坐标"),"element swaps need a doctor: %s" % swap.message)
	var work: Dictionary=g.reactor_work(r)
	var sculpt: Dictionary=work.duplicate(true); sculpt.positions[0]=[float(sculpt.positions[0][0])+0.1,float(sculpt.positions[0][1]),float(sculpt.positions[0][2])]
	check(g.sandbox_reactor_quote(0,sculpt).ready,"the workshop may move atoms without a doctor")
	var grown: Dictionary=work.duplicate(true); grown.atoms.append("H"); grown.positions.append([2.0,0.0,0.0])
	check(g.sandbox_reactor_quote(0,grown).message.contains("需要装炉博士"),"the workshop can't add atoms without a doctor")
	var busy=Fixtures.doctor(g); busy.post="research"
	check(not g.install_status().ok and g.install_status().message.contains("其他岗位"),"a doctor on research doesn't install")
	busy.post="auto"
	check(g.install_status().ok,"a doctor on auto installs")
	# Elements: a new reactor takes the structure's atoms; a swap takes only the new ones.
	for symbol in g.element_inventory: g.element_inventory[symbol]=0
	var short: Dictionary=g.reactor_quote(empty,"water")
	check(not short.ready and short.required=={"O":1,"H":2} and short.message.contains("不足") and short.message.contains("来源"),"a water reactor needs H×2 and O×1 and says where to get them: %s" % short.message)
	g.element_inventory.H=2; g.element_inventory.O=1
	coins=g.coins
	var built=g.place_reactor(empty,"water")
	check(built.contains("开始建造") and g.reactors.size()==2 and int(g.element_inventory.H)==0 and int(g.element_inventory.O)==0 and is_equal_approx(g.coins,coins-100.0),"building takes 100 coins and the atoms: %s" % built)
	var tq: Dictionary=g.template_quote(0,"ammonia")
	check(tq.required=={"N":1,"H":1} and not tq.ready,"water → ammonia needs only N×1 and one more H: %s" % [tq.required])
	g.element_inventory.N=1; g.element_inventory.H=1
	coins=g.coins
	var queued=g.change_template(0,"ammonia")
	check(queued.contains("排队") and int(g.element_inventory.N)==0 and is_equal_approx(g.coins,coins-25.0),"a template swap reserves its new atoms: %s" % queued)
	check(g.cancel_installation(0).contains("退回") and int(g.element_inventory.N)==1 and int(g.element_inventory.H)==1 and is_equal_approx(g.coins,coins),"cancelling refunds the coins and the atoms")
	check(g.template_quote(0,"oxygen").required=={"O":1},"water → O₂ reuses the O it holds")
	for st in [s,loaded,g]: st.close_science()
	print("BUILDER: ",checks," checks, ",failures.size()," failures")
	if not failures.is_empty(): print(failures)
	quit(0 if failures.is_empty() else 1)
