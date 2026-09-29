extends SceneTree
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	for path in ["res://scripts/planet_worlds.gd","res://scripts/planet_panel.gd","res://scripts/planet_view.gd","res://scripts/planet_modern.gd","res://data/planet_balance.json","res://data/planet_modern.json"]:
		check(not ResourceLoader.exists(path),"retired resource absent: "+path)
	for path in ["res://scripts/planet_v2.gd","res://scripts/planet_v2_panel.gd","res://scripts/factory_panel.gd","res://data/factory_recipes.json","res://data/river_population.json"]:
		check(ResourceLoader.exists(path),"current resource present: "+path)
	print("SINGLE_WORLD_PACKAGE: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
