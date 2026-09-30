extends SceneTree
## v0.28 refinery: data integrity, extractors, mineral processes, upgrades, saves and the panel.
const State=preload("res://scripts/lab_state.gd")
const Geology=preload("res://scripts/planet_geology.gd")
const Main=preload("res://scripts/main.gd")
var checks=0
var failures=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1440,900)
	_run.call_deferred()

func _run() -> void:
	var s=State.new(); var r=s.refinery; var rules=r.rules()
	# Data: every process uses real mined minerals and yields real game elements; every element has a source.
	var sourced={}
	for id in rules.processes:
		var p: Dictionary=rules.processes[id]
		var ok=not str(p.equation).is_empty() and float(p.seconds)>0
		for m in p.inputs: ok=ok and not Geology.info(m).is_empty() and not Geology.info(m).get("formula","").is_empty() or m=="coal"
		for symbol in p.outputs: ok=ok and s.elements.has(symbol); sourced[symbol]=true
		check(ok,"process "+id+" uses minerals from the planet and outputs game elements")
	for id in rules.extractors:
		for symbol in rules.extractors[id].outputs: check(s.elements.has(symbol),"extractor "+id+" outputs a game element"); sourced[symbol]=true
	for symbol in s.elements: check(sourced.has(symbol),"element %s has at least one source" % symbol)
	for id in rules.processes:
		for m in rules.processes[id].inputs:
			var elements: Dictionary=Geology.info(m).get("elements",{})
			for symbol in rules.processes[id].outputs:
				check(elements.has(symbol) or m=="limestone" or rules.processes[id].inputs.size()>1,"%s really contains the %s it yields" % [m,symbol])
	# Extractors trickle up to the cap and pause there.
	var n0=int(s.element_inventory.N)
	r.tick(s,59.0); check(int(s.element_inventory.N)==n0,"air separation needs a full cycle")
	r.tick(s,1.0); check(int(s.element_inventory.N)==n0+1,"air separation adds N every 60 s")
	r.tick(s,60.0*30)
	check(int(s.element_inventory.N)==r.extractor_cap() and int(s.element_inventory.H)==r.extractor_cap(),"extractors stop at the cap")
	s.element_inventory.N=20; r.tick(s,600.0)
	check(int(s.element_inventory.N)==20,"extractors never reduce stock above the cap")
	# Queue: only the first job runs; limited length; minerals reserved up front.
	var minerals=s.planet.v2.nature.minerals
	minerals.merge({"coal":6,"sulfur":1,"fluorite":1},true)
	for i in range(r.queue_limit()): r.start(s,"coal_coking")
	check(r.jobs.size()==r.queue_limit() and int(minerals.coal)==6-r.queue_limit(),"queue fills and reserves coal")
	check(not r.quote(s,"coal_coking").ready and r.quote(s,"coal_coking").message.contains("队列"),"a full queue refuses more work")
	var c0=int(s.element_inventory.C)
	r.tick(s,15.0); check(int(s.element_inventory.C)==c0+2 and r.jobs.size()==r.queue_limit()-1,"only the first batch finishes after its own time")
	r.tick(s,100.0); check(r.jobs.is_empty() and int(s.element_inventory.C)>=c0+2*r.queue_limit(),"the rest of the queue runs in order")
	# Two-mineral process and the where-to-get text.
	check(r.how_to_get("F").contains("萤石") and r.how_to_get("N").contains("空气分离塔"),"each element names its real source")
	var f0=int(s.element_inventory.F); r.start(s,"fluorite_fluorine"); r.tick(s,45.0)
	check(int(s.element_inventory.F)==f0+4 and int(minerals.fluorite)==0 and int(minerals.sulfur)==0,"fluorite + sulfuric acid route gives F×4")
	check(r.quote(s,"pollucite_cesium").message.contains("铯榴石"),"missing mineral names the mineral and where to dig")
	# Upgrades cost coins and speed everything up.
	s.coins=100; check(r.upgrade(s).contains("金币") and r.level==1,"upgrade needs coins")
	s.coins=10000; r.upgrade(s)
	check(r.level==2 and s.coins==10000-int(rules.upgrade_costs[0]) and is_equal_approx(r.speed(),1.25) and r.extractor_cap()==18,"upgrade raises speed and cap")
	# Save round trip mid-batch, old saves, tampered saves.
	minerals.merge({"halite":1},true); r.start(s,"halite_electrolysis"); r.tick(s,4.0)
	var path="res://saves/test-refinery.json"; s.save_game(path)
	var copy=State.new()
	check(copy.load_game(path) and copy.refinery.level==2 and copy.refinery.jobs.size()==1 and is_equal_approx(float(copy.refinery.jobs[0].left),15.0),"save keeps level and the running batch")
	var text=FileAccess.get_file_as_string(path); var data=JSON.parse_string(text)
	data.refinery.jobs[0].process="gold_from_lead"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data)); DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	check(not State.new().load_game(path),"a save with an unknown refinery process is rejected")
	data=JSON.parse_string(text); data.version=23; data.erase("refinery")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(data))
	var old=State.new()
	check(old.load_game(path) and old.refinery.level==1 and old.refinery.jobs.is_empty() and int(old.element_inventory.F)==int(s.element_inventory.F),"v23 saves load with a fresh refinery and keep element stock")
	# Offline catch-up also refines.
	old.planet.v2.nature.minerals["sulfur"]=1; old.refinery.start(old,"sulfur_melting")
	old.saved_at=int(Time.get_unix_time_from_system())-600; var s0=int(old.element_inventory.S)
	old.offline_catch_up(int(Time.get_unix_time_from_system()))
	check(int(old.element_inventory.S)==s0+2,"offline time finishes refinery batches")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Panel: opened from the toolbar route, explains a symbol, starts a batch with a real button.
	var game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.state.planet.v2.nature.minerals["malachite"]=1; game.state.planet.v2.nature.minerals["coal"]=1
	game._navigate_materials("refinery"); await process_frame
	var panel=game.modal
	check(panel.get_script().resource_path.ends_with("refinery_panel.gd") and panel.tiles.size()==game.state.elements.size(),"refinery shows every element")
	panel._explain("Cu"); check(panel.status.text.contains("孔雀石"),"clicking copper explains malachite smelting")
	var start: Button=null
	for b in panel.processes.find_children("*","Button",true,false):
		if b.text=="开始精炼" and b.get_parent().get_child(0).text.begins_with("孔雀石炼铜"): start=b
	var first_two=[]
	for i in range(2): first_two.append(panel.processes.get_child(i).get_child(0).get_child(0).text.get_slice(" ",0))
	check(start!=null and "孔雀石炼铜" in first_two and "煤干馏焦化" in first_two,"ready processes are listed first")
	if start: start.pressed.emit(); await process_frame
	check(game.state.refinery.jobs.size()==1 and panel.job_bar!=null,"the button starts a batch and shows its progress")
	game.state.tick(30.0); await process_frame; await create_timer(0.3).timeout
	check(int(game.state.element_inventory.Cu)>=4 and panel.tiles.Cu.find_children("*","Label",true,false).any(func(l): return l.text=="%d 份" % int(game.state.element_inventory.Cu)),"finished copper appears on its tile")
	if DisplayServer.get_name()!="headless":
		game.toast_panel.hide(); await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/refinery-panel.png")
	panel.handle_back(); await process_frame
	check(game.modal==null,"back closes the refinery")
	var st=game.state
	game.queue_free(); await process_frame
	st.close_science()
	print("REFINERY: ",checks," checks, ",failures.size()," failures")
	if not failures.is_empty(): print(failures)
	quit(0 if failures.is_empty() else 1)
