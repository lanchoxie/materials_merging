extends SceneTree
## Performance probe (not a test): offline catch-up on a heavy save, game start, and entering the
## island walk. Run windowed: ... --script res://tests/benchmark_startup.gd -- --release-ui-test
const State=preload("res://scripts/lab_state.gd")
const Main=preload("res://scripts/main.gd")
const Industry=preload("res://scripts/industry.gd")

func ms(t0: int) -> float:
	return (Time.get_ticks_usec()-t0)/1000.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# A late-game save: every factory looping, refinery looping, solar, staff, contracts.
	var s=State.new(); var ind=s.industry
	preload("res://scripts/test_mode.gd").open_starforge(s,900); ind.gain(Industry.step(16)); s.coins=900000; ind.plots=16
	ind.solar=[0.4,0.4,0.4,0.4,0.4,0.4,0.4,0.4,0.4,0.4,0.4,0.4]
	for k in ["metal_works","polymer_works","trade_hub","home_studio","staff_housing","inorganic_works","silicon_works","test_bench","chip_fab","packaging_plant","battery_works","vehicle_assembly"]: ind.build(s,ind.buildings.size(),k)
	for el in s.elements: s.element_inventory[el]=9000
	for f in ["Fe3C","Cu3Sn","Al2Cu","LiAl","CaO","Cl3HSi","Si","H3O4P","C2H4","C2H3Cl","C2F4","CsPbBr3","C6H6O","PbSO4","LiFePO4"]:
		var keys: Array=Industry._keys_for(f)
		if not keys.is_empty(): s.index_found[keys[0]]=true
	ind.set_repeat(0,"carbon_steel"); ind.set_repeat(1,"pvc"); ind.set_repeat(5,"cement"); ind.set_repeat(8,"power_diode")
	var m: Dictionary=s.planet.v2.nature.minerals
	for id in ["hematite","coal","limestone","sand","clay","apatite","halite","malachite"]: m[id]=999
	s.refinery.set_repeat("hematite_iron")
	s.saved_at=int(Time.get_unix_time_from_system())-8*3600
	var t0=Time.get_ticks_usec()
	var r=s.offline_catch_up(int(Time.get_unix_time_from_system()))
	print("BENCH offline catch-up 8h: %.0f ms (simulated %.0f s)" % [ms(t0),float(r.get("simulated",0))])
	t0=Time.get_ticks_usec()
	var game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	print("BENCH Main ready+1 frame: %.0f ms" % ms(t0))
	for i in range(30): await process_frame
	t0=Time.get_ticks_usec()
	game._show_island_walk(); await process_frame
	print("BENCH island walk open+1 frame: %.0f ms" % ms(t0))
	var times=[]
	for i in range(120):
		var f0=Time.get_ticks_usec(); await process_frame; times.append(Time.get_ticks_usec()-f0)
	times.sort()
	print("BENCH island walk frames: median %.1f ms p95 %.1f ms max %.1f ms" % [times[60]/1000.0,times[114]/1000.0,times[119]/1000.0])
	game._close_all(); await process_frame
	times=[]
	for i in range(120):
		var f0=Time.get_ticks_usec(); await process_frame; times.append(Time.get_ticks_usec()-f0)
	times.sort()
	print("BENCH island view frames: median %.1f ms p95 %.1f ms max %.1f ms" % [times[60]/1000.0,times[114]/1000.0,times[119]/1000.0])
	quit(0)
