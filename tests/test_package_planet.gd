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
	check(str(ProjectSettings.get_setting("application/config/version"))=="0.14.0","packaged application version")
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
	game.modal._replay()
	s.planet.command(s,"compare_materials",{"mode":"same_mass"})
	var info=s.planet.recipe("aluminum_light")
	s.planet.command(s,"buy_feed",{"input":info.input}); s.planet.command(s,"pack",{"recipe":info.id}); s.planet.tick(info.seconds)
	s.planet.command(s,"deploy",{"world_id":"home","site_id":"fish","recipe":info.id,"token":s.planet.shipment_serial})
	check(s.planet.worlds.get_world().ecology.regions.fish.component.recipe=="aluminum_light","packaged material evidence, recipe and installed slot work")
	game.modal._open_materials(); await process_frame
	check(game.modal.view.material_view.parts.size()==2 and s.planet.lab.design("aluminum_light").conductance_W_K>s.planet.lab.design("copper_light").conductance_W_K,"packaged reference data and procedural comparison work")
	s.planet.command(s,"activate_watershed",{"era":"carboniferous"})
	for recipe in ["screen_station","screen_cartridge"]:
		info=s.planet.recipe(recipe)
		s.planet.command(s,"buy_feed",{"input":info.input}); s.planet.command(s,"pack",{"recipe":recipe}); s.planet.tick(info.seconds)
		s.planet.command(s,"deploy",{"world_id":"home","site_id":"headwater","recipe":recipe,"token":s.planet.shipment_serial})
	s.planet.command(s,"step_world")
	var river=s.planet.worlds.get_world().watershed
	check(river.regions.headwater.retained>0 and river.regions.headwater.screen_energy==50 and s.planet.worlds.watershed.valid(river,s.planet.worlds.get_world().seconds),"packaged watershed recipes, finite filter and nutrient conservation work")
	game.modal._scene("watershed","screen_cartridge"); game.modal._live(); await process_frame
	check(game.modal.view.watershed_view.sites.size()==3 and game.modal.watershed_widgets.has("chart"),"packaged era vegetation, connected water and observation chart construct")
	game.modal._replay(); game.modal.replay_index=0; game.modal._live()
	check(game.modal.view.watershed_view.snapshot.watershed.elapsed==0 and river.elapsed==30,"packaged watershed history changes only the view")
	game.modal._replay(); s.planet.command(s,"fork",{"era":"devonian"})
	check(s.planet.worlds.get_world().watershed.era=="devonian" and river.era=="carboniferous","packaged worlds preserve separate era starting points")
	s.planet.command(s,"select",{"world_id":"home"}); s.planet.command(s,"activate_village")
	for recipe in ["drinking_barrel","frame_bundle","tool_chest"]:
		info=s.planet.recipe(recipe)
		s.planet.command(s,"buy_feed",{"input":info.input}); s.planet.command(s,"pack",{"recipe":recipe}); s.planet.tick(info.seconds)
		s.planet.command(s,"deploy",{"world_id":"home","site_id":"village_depot","recipe":recipe,"token":s.planet.shipment_serial})
	var village=s.planet.worlds.get_world().village
	check(village.added.drink==24 and village.added.frames==6 and village.added.tools==24,"packaged village supply recipes manufacture and deliver distinct resources")
	s.planet.command(s,"step_world")
	check(village.projects.cistern.committed and s.planet.worlds.village.valid(village,s.planet.worlds.get_world().seconds),"packaged residents walk, reserve and construct with valid ledgers")
	game.modal._scene("village","frame_bundle"); game.modal._live(); await process_frame
	check(game.modal.view.village_view.people.size()==6 and game.modal.view.village_view.scaffolds.cistern.visible,"packaged village view exposes six residents and construction scaffold")
	game.modal._replay(); game.modal.replay_index=0; game.modal._live()
	check(game.modal.view.village_view.snapshot.village.elapsed==0 and village.elapsed==30,"packaged village replay leaves the present intact")
	game.modal._replay()
	s.planet.command(s,"buy_feed",{"input":"frame_kit"}); s.planet.command(s,"pack",{"recipe":"frame_bundle"}); s.planet.command(s,"production_mode",{"mode":"island"})
	var left=s.planet.job.left; s.planet.tick(20,0)
	check(s.planet.job.left==left,"packaged island workshop waits for real staffing")
	s.campus_assign_post(s.campus.people[0].id,"workshop")
	check(s.campus.people[0].post=="workshop" and s.layout.config.buildings.has("workshop"),"packaged campus supports workshop building and resident posts")
	check(preload("res://scripts/planet_program.gd").new().restore(JSON.parse_string(JSON.stringify(s.planet.serialize())),s),"packaged new world histories and production mode restore")
	game._close_modal(); s.close_science()
	print("PACKAGE PLANET SMOKE: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
