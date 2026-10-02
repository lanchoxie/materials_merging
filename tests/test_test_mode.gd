extends SceneTree
## v0.33.1 测试版: the test panel's shortcuts keep the save valid, and a test session saves elsewhere.
const State=preload("res://scripts/lab_state.gd")
const TestMode=preload("res://scripts/test_mode.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	var s=State.new()
	check(s.save_name=="save.json" and TestMode.SAVE_NAME!="save.json","the normal save keeps its name and the test save has its own")
	check(not TestMode.enabled(),"test mode is off unless the build or the command line asks for it")
	TestMode.grant_coins(s,100000); TestMode.grant_materials(s,500); TestMode.grant_elements(s,20000)
	check(float(s.coins)>=100000 and int(s.materials[2])>=500,"coins and building pieces are granted")
	check(int(s.element_inventory.get("Fe",0))==TestMode.ELEMENT_CAP,"element grants stop at the save cap")
	TestMode.grant_minerals(s,5000); TestMode.grant_planet_stock(s,5000)
	var nature=s.planet.v2.nature
	check(int(nature.minerals.get("hematite",0))==int(nature.rules.max_mineral_stock),"mineral grants stop at the stock cap")
	check(int(s.planet.v2.field.stock.timber)==int(s.planet.v2.field.rules.max_stock),"planet stock grants stop at the cap")
	var before=s.unlocked_plot_count()
	TestMode.unlock_plots(s,3)
	check(s.unlocked_plot_count()==before+3,"three frontier plots open (%d → %d)" % [before,s.unlocked_plot_count()])
	TestMode.max_refinery(s)
	check(s.refinery.upgrade_cost()<0,"the refinery reaches its top level")
	var t0=float(s.planet.v2.world.elapsed)
	TestMode.skip_planet(s,240)
	check(float(s.planet.v2.world.elapsed)>=t0+239,"a season passes on the planet")
	var era=int(s.planet.v2.settlement.era)
	var said=TestMode.force_era(s)
	check(int(s.planet.v2.settlement.era)==era+1,"the era advances without its buildings: "+said)
	for b in TestMode.BIOMES:
		var at=TestMode.biome_spot(s.planet.v2.environment,b)
		check(at!=Vector2.INF and s.planet.v2.environment.biome_at(at)==b,"a teleport spot exists for "+b)
	var path="res://saves/test-mode-check.json"
	var saved=s.save_game(path)
	var again=State.new()
	check(again.load_game(path),"the boosted save loads back (%s)" % saved)
	check(int(again.planet.v2.settlement.era)==era+1 and again.unlocked_plot_count()==s.unlocked_plot_count(),"the boosted progress survives the reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty(): print("TEST MODE OK (%d checks)" % checks); quit(0)
	else: print("TEST MODE FAILED: ",failures); quit(1)
