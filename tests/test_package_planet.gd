extends SceneTree
## Run this external harness against the actual exported APK assets or Web PCK.
const Main=preload("res://scripts/main.gd")
var failures=[]
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state
	check(str(ProjectSettings.get_setting("application/config/version"))=="0.11.0","packaged application version")
	game._show_planet(); await process_frame
	check(game.modal.view.sites.size()==2,"packaged planet scene builds both sites")
	var batch=s.product_snapshot(s.reactors[0]); s.storage.add_product(batch,2)
	s.planet.command(s,"join"); s.planet.command(s,"qualify",{"batch_id":batch.id}); s.planet.command(s,"pack"); s.planet.tick(25)
	check(s.planet.available_products()==1,"packaged data and compiled production code complete a crate")
	s.planet.command(s,"deploy",{"world_id":"home","site_id":"deep","token":s.planet.shipment_serial}); s.planet.tick(8)
	check(s.planet.worlds.get_world().zones[0].water==1,"packaged scene and simulation share the deployment contract")
	game._close_modal(); s.close_science()
	print("PACKAGE PLANET SMOKE: 4 checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
