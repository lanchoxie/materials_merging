extends SceneTree
## v0.43 星锻岛 · 第二浮岛 (user request): island Ⅱ like island Ⅰ — the deck grows onto any cell beside
## it, island-Ⅰ decorations stand on empty deck plots (shared toolbox), staff tire while working and
## rest at home or in the new 员工休息室, and all of it saves (with old saves still loading).
const State=preload("res://scripts/lab_state.gd")
const Industry=preload("res://scripts/industry.gd")
const Town=preload("res://scripts/island_town.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func roundtrip(ind) -> Industry:
	var copy=Industry.new()
	var ok=copy.restore(JSON.parse_string(JSON.stringify(ind.serialize())))
	return copy if ok else null

func _initialize() -> void:
	var R=Industry.rules()
	var s=State.new(); var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,800); s.coins=500000; ind.credits=900
	# --- The deck: old plots keep their places; expansion beside the deck, anywhere around it.
	check(ind.cell(0)==Vector2i(0,0) and ind.cell(3)==Vector2i(3,0) and ind.plot_center(1).is_equal_approx(Industry.cell_center(Vector2i(1,0))),"old plots keep the 4-wide grid")
	check(ind.plot_center(2).is_equal_approx(preload("res://scripts/starforge_view.gd").plot_center(2)),"plot centres match the old diorama")
	var f=ind.frontier()
	check(f.has(Vector2i(-1,0)) and f.has(Vector2i(0,1)) and f.has(Vector2i(2,-1)) and not f.has(Vector2i(5,5)) and not f.has(Vector2i(1,0)),"the frontier is every free cell beside the deck")
	var coins=s.coins; var credits=ind.credits
	check(ind.buy_plot_at(s,Vector2i(-1,0)).contains("扩建") and ind.plots==5 and ind.cell(4)==Vector2i(-1,0),"a plot can be added west of the deck")
	check(s.coins<coins and ind.credits<credits,"expansion costs coins and credits")
	check(ind.buy_plot_at(s,Vector2i(6,6)).contains("紧挨"),"cells away from the deck are refused")
	check(ind.buy_plot_at(s,Vector2i(0,0)).contains("紧挨"),"an owned cell is refused")
	ind.buy_plot(s)
	check(ind.plots==6 and ind.cell(5)==Vector2i(0,1),"the plain 扩建 button follows the old grid")
	check(int(R.plots.max)>16,"the deck can grow past the old 16 plots (%d)" % int(R.plots.max))
	var west=ind.buy_plot_at(s,Vector2i(-2,0)); check(ind.plot_at(Vector2i(-2,0))==6,"plot_at finds a plot by its cell")
	# --- Buildings stay keyed by plot index; the new staff lounge.
	check(ind.build(s,0,"staff_housing").contains("建成") and ind.build(s,1,"metal_works").contains("建成"),"apartments and a factory are built")
	check(ind.build(s,6,"staff_lounge").contains("建成") and ind.lounge_seats()==3,"the staff lounge seats three")
	ind.upgrade(s,6)
	check(ind.lounge_seats()==5 and ind.beds()==4,"a lounge level adds two seats; lounges are not beds")
	# --- Decorations from the shared toolbox.
	s.storage.decorations["flower_bed"]=2; s.storage.decorations["bench"]=1
	check(ind.place_decor(s,2,"flower_bed",Vector2i(0,0),0).contains("摆上") and int(s.storage.decorations.flower_bed)==1,"a toolbox flower bed is placed on an empty plot")
	check(ind.decor_error(s,2,"flower_bed",Vector2i(1,1),0)!="","overlapping tiles are refused")
	check(ind.decor_error(s,1,"flower_bed",Vector2i(0,0),0).contains("工厂"),"factory plots take no decorations")
	check(ind.decor_error(s,2,"engineer_house",Vector2i(4,4),0)!="","island-Ⅰ houses are not deck decorations")
	check(ind.place_decor(s,2,"bench",Vector2i(10,0),1).contains("摆上"),"a rotated bench fits at the edge")
	check(ind.decor_error(s,2,"bench",Vector2i(11,0),0)!="","off the plot is refused")
	var before=s.coins
	check(ind.place_decor(s,3,"sunflower",Vector2i(5,5),0).contains("摆上") and s.coins==before-s.town_price("sunflower"),"with none in the toolbox, a decoration is bought at the island-Ⅰ price")
	check(ind.decor_error(s,3,"sf_chair",Vector2i(0,0),0).contains("家居工坊"),"studio furniture can't be bought, only made")
	check(ind.build_error(s,2,"polymer_works").contains("装饰"),"a decorated plot must be cleared before building")
	var uid=int(ind.deck_items["2"][0].uid)
	check(ind.store_decor(s,2,uid).contains("收回") and int(s.storage.decorations.flower_bed)==2,"storing returns it to the toolbox")
	check(ind.decorations().size()==2,"two decorations remain on the deck")
	# --- Stamina: tire at work, rest at home or in the lounge, come back.
	ind.staff.append({"id":1,"name":"林工","role":"engineer","specialty":"","home":0,"factory":1,"energy":100.0,"resting":false})
	ind.staff.append({"id":2,"name":"周博","role":"doctor","specialty":"","home":0,"factory":-1,"energy":40.0,"resting":false})
	ind.staff_serial=3
	var E: Dictionary=R.staff.energy
	check(not ind.working(ind.staff[0]) and ind.status_of(ind.staff[0])=="待命","staff on an idle line stand by and do not tire")
	ind.tick(s,60.0); check(is_equal_approx(float(ind.staff[0].energy),100.0),"no work, no fatigue")
	ind.buildings["1"].jobs=[{"recipe":_metal_recipe(R),"left":float(R.recipes[_metal_recipe(R)].seconds)}]
	check(ind.working(ind.staff[0]) and ind.status_of(ind.staff[0])=="工作中","a running line makes them work")
	var bonus=ind.staff_bonus(1,"speed")
	ind._stamina(float(E.work_seconds)*0.5)
	check(absf(float(ind.staff[0].energy)-50.0)<0.01,"half a shift drains half the stamina")
	var notes=ind._stamina(float(E.work_seconds)*0.31)
	check(ind.staff[0].resting and notes.any(func(n): return n.contains("累了")),"at the tired line they stop to rest, with a note")
	check(ind.staff_bonus(1,"speed")==0.0 and bonus>0.0,"no bonus while resting")
	check(ind.status_of(ind.staff[0])=="休息室" and ind.in_lounge().has(1),"tired staff take a lounge seat")
	ind.staff[1].energy=40.0
	var e0=float(ind.staff[0].energy); var d0=float(ind.staff[1].energy)
	ind._stamina(10.0)
	var lounge_gain=float(ind.staff[0].energy)-e0
	check(lounge_gain>0.0 and absf(lounge_gain-100.0*10.0/float(E.rest_seconds)*(ind.comfort(0)+float(E.lounge_speed)))<0.01,"the lounge speeds up rest (%.2f per 10 s)" % lounge_gain)
	check(float(ind.staff[1].energy)>d0,"unassigned staff rest too")
	ind.furnished["0"]=4
	check(ind.comfort(0)>1.0,"furniture makes the apartments comfier (faster rest)")
	for i in range(60):
		notes=ind._stamina(10.0)
		if not ind.staff[0].resting: break
	check(not ind.staff[0].resting and float(ind.staff[0].energy)>=float(E.rested) and notes.any(func(n): return n.contains("回到工厂")),"rested staff go back to work")
	check(ind.staff_bonus(1,"speed")>0.0,"the bonus returns with them")
	# Without a lounge seat they rest at home, slower.
	var solo=Industry.new(); solo.staff=[{"id":1,"name":"甲","role":"engineer","specialty":"","home":0,"factory":-1,"energy":10.0,"resting":true}]
	solo.buildings={"0":{"kind":"staff_housing","level":1,"jobs":[]}}; solo.plots=1
	solo._stamina(10.0)
	check(solo.status_of(solo.staff[0])=="公寓休息" and float(solo.staff[0].energy)-10.0<lounge_gain,"without a lounge they rest in the apartment, more slowly")
	# --- Save and load.
	var copy=roundtrip(ind)
	check(copy!=null,"the island saves and loads")
	if copy!=null:
		check(copy.deck==ind.deck and copy.cell(4)==Vector2i(-1,0),"the deck shape survives a save")
		check(copy.deck_items.keys()==ind.deck_items.keys() and copy.decorations().size()==2 and copy.decor_serial==ind.decor_serial,"decorations survive a save")
		check(is_equal_approx(float(copy.staff[0].energy),float(ind.staff[0].energy)) and copy.staff[0].resting==ind.staff[0].resting,"stamina survives a save")
	var data=ind.serialize()
	var bad=JSON.parse_string(JSON.stringify(data)); bad.deck[4]=[9,9]
	check(not Industry.new().restore(bad),"a deck cell not beside the rest is rejected")
	bad=JSON.parse_string(JSON.stringify(data)); bad.deck[5]=bad.deck[0]
	check(not Industry.new().restore(bad),"a doubled cell is rejected")
	bad=JSON.parse_string(JSON.stringify(data)); bad.deck_items["1"]=[{"uid":1,"kind":"bench","x":0,"z":0,"rot":0}]
	check(not Industry.new().restore(bad),"decorations on a factory plot are rejected")
	bad=JSON.parse_string(JSON.stringify(data)); bad.deck_items["3"].append(bad.deck_items["3"][0].duplicate())
	check(not Industry.new().restore(bad),"overlapping or duplicate decorations are rejected")
	bad=JSON.parse_string(JSON.stringify(data)); bad.staff[0].energy=140
	check(not Industry.new().restore(bad),"stamina above 100 is rejected")
	# Old (v3) saves: no deck, no stamina.
	var old=JSON.parse_string(JSON.stringify(data)); old.version=3; old.erase("deck"); old.erase("deck_items"); old.erase("decor_serial")
	old.plots=6; for key in old.buildings.keys(): if int(key)>=6: old.buildings.erase(key)
	for st in old.staff: st.erase("energy"); st.erase("resting")
	var legacy=Industry.new()
	check(legacy.restore(old) and legacy.cell(5)==Vector2i(1,1) and legacy.cell(4)==Vector2i(0,1),"an old save gets the old 4-wide grid")
	check(float(legacy.staff[0].energy)==100.0 and not legacy.staff[0].resting,"old staff start rested")
	# The whole game save validates with the new island.
	var path="res://saves/test_starforge_isle.json"
	for f2 in [path,path+".bak"]:
		if FileAccess.file_exists(f2): DirAccess.remove_absolute(ProjectSettings.globalize_path(f2))
	check(s.save_game(path).begins_with("已保存"),"the game saves with the new island")
	var loaded=State.new()
	check(loaded.load_game(path) and loaded.industry.deck==ind.deck and loaded.industry.decorations().size()==2,"and loads it back whole")
	for f2 in [path,path+".bak"]:
		if FileAccess.file_exists(f2): DirAccess.remove_absolute(ProjectSettings.globalize_path(f2))
	if failures.is_empty(): print("STARFORGE ISLE OK (%d checks)" % checks); quit(0)
	else: print("STARFORGE ISLE FAILED: ",failures); quit(1)

func _metal_recipe(R: Dictionary) -> String:
	for id in R.recipes:
		if R.recipes[id].building=="metal_works": return id
	return ""
