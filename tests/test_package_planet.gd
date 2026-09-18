extends SceneTree
## Run this external harness against the actual exported APK assets or Web PCK.
const Main=preload("res://scripts/main.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	check(str(ProjectSettings.get_setting("application/config/version"))=="0.12.0","packaged application version")
	game._show_planet(); await process_frame
	check(game.modal.view.sites.size()==2,"packaged planet scene builds both sites")
	var batch=s.product_snapshot(s.reactors[0]); s.storage.add_product(batch,2)
	s.planet.command(s,"join"); s.planet.command(s,"qualify",{"batch_id":batch.id}); s.planet.command(s,"pack"); s.planet.tick(25)
	check(s.planet.available_products()==1,"packaged data and compiled production code complete a crate")
	s.planet.command(s,"deploy",{"world_id":"home","site_id":"deep","token":s.planet.shipment_serial}); s.planet.tick(8)
	check(s.planet.worlds.get_world().zones[0].water==1,"packaged scene and simulation share the deployment contract")
	s.coins=2000
	batch=s.product_snapshot(s._new_reactor(3,"oxygen",0)); s.storage.add_product(batch,2)
	s.planet.command(s,"qualify",{"reference":"oxygen","batch_id":batch.id})
	for recipe in ["oxygen_station","oxygen_cartridge"]:
		var info=s.planet.recipe(recipe)
		s.planet.command(s,"buy_feed",{"input":info.input}); s.planet.command(s,"pack",{"recipe":recipe}); s.planet.tick(info.seconds)
	check(s.planet.available_products("oxygen_station")==1 and s.planet.available_products("oxygen_cartridge")==1,"packaged industrial recipes create distinct equipment and supply")
	for recipe in ["oxygen_station","oxygen_cartridge"]:
		s.planet.command(s,"deploy",{"world_id":"home","site_id":"fish","recipe":recipe,"token":s.planet.shipment_serial})
	s.planet.tick(13)
	check(s.planet.worlds.get_world().ecology.regions.fish.gas==47,"packaged ecology consumes finite oxygen and energy")
	game.modal._choose_recipe("oxygen_cartridge"); game.modal.section="observe"; game.modal._redraw(); game.modal._live(); await process_frame
	check(game.modal.view.ecology_view.sites.size()==2 and game.modal.eco_widgets.has("chart"),"packaged 3D ecology and observation chart construct")
	game.modal._replay(); game.modal.replay_index=0; game.modal._live()
	check(game.modal.view.snapshot.seconds==0 and s.planet.worlds.get_world().seconds>0,"packaged replay leaves live model at present")
	game._close_modal(); s.close_science()
	print("PACKAGE PLANET SMOKE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
