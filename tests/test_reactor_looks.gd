extends SceneTree
## v0.28 reactor looks: tier hardware by level, sourced room-temperature phases, doctor install orbs.
const State=preload("res://scripts/lab_state.gd")
const Look=preload("res://scripts/reactor_look.gd")
const World=preload("res://scripts/world_view.gd")
const Main=preload("res://scripts/main.gd")
var checks=0
var failures=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	root.size=Vector2i(1280,800)
	_run.call_deferred()

func find(node: Node, name: String) -> Node:
	return node.find_child(name,true,false)

func world_for(s) -> Node3D:
	var world=World.new(); root.add_child(world); world.setup(s); world.rebuild(); return world

func _run() -> void:
	var s=State.new()
	# Every template has a sourced phase that agrees with its melting/boiling points at 25 °C.
	for id in s.templates:
		var p: Dictionary=Look.phase(id)
		check(not p.is_empty() and str(p.get("source","")).begins_with("https://"),"template %s has a sourced phase" % id)
		if p.is_empty(): continue
		var expected="solid"
		if p.get("sublimes",false): expected="gas" if float(p.bp)<25.0 else "solid"
		elif p.get("mp")!=null and float(p.mp)<25.0: expected="gas" if p.get("bp")!=null and float(p.bp)<25.0 else "liquid"
		check(str(p.phase)==expected,"%s phase %s matches its melting/boiling points" % [id,p.phase])
	check(Look.phase_text("water").contains("沸点 100") and Look.phase_text("carbon_dioxide").contains("升华"),"phase text quotes the real numbers")
	# Tiers.
	check(Look.tier(1)==0 and Look.tier(4)==0 and Look.tier(5)==1 and Look.tier(10)==2 and Look.tier(15)==3 and Look.tier(20)==3,"tiers change at Lv.5 / 10 / 15")
	check(Look.tier_step(7)==3 and Look.next_tier_level(7)==10 and Look.next_tier_level(16)==0,"pips count levels inside a tier; the next look is announced")
	var r=s.reactors[0]; r.build_left=0.0; r.level=4; s.coins=100000; s.upgrades=3
	check(s.upgrade_reactor(0).contains("夹套反应釜"),"reaching Lv.5 announces the new look")
	check(not s.upgrade_reactor(0).contains("外观"),"ordinary levels do not claim a new look")
	# Views carry phase and install progress; unidentified structures stay unlabelled.
	var view: Dictionary=s.reactor_views()[0]
	check(view.phase==s.reactor_phase(r) and view.phase==str(Look.phase(str(s.structure_data(r).reference_id)).get("phase","")),"view phase follows the identified structure")
	# World: tier hardware and phase contents are built, animated nodes stay out of static batches.
	r.level=11; r.template="sodium_chloride"; r.atoms=s.templates.sodium_chloride.atoms.duplicate(); r.positions=s.initial_positions("sodium_chloride",r.id); s._reset_product(r); s._structure_cache.clear()
	var world=world_for(s); await process_frame
	var gauge=find(world,"Gauge")
	check(gauge!=null and gauge.get_meta("dynamic_geometry",false),"autoclave tier builds a live pressure gauge")
	check(find(world,"GasCloud")==null and find(world,"LiquidSurface")==null,"a solid compound has no gas or liquid in the chamber")
	world.queue_free(); await process_frame
	r.level=16; r.template="methane"; r.atoms=s.templates.methane.atoms.duplicate(); r.positions=s.initial_positions("methane",r.id); s._reset_product(r); s._structure_cache.clear()
	world=world_for(s); await process_frame
	check(find(world,"PlasmaRings")!=null and find(world,"GasCloud")!=null,"plasma tier rings and a gas cloud for methane")
	var rings: Node3D=find(world,"PlasmaRings"); var spin=rings.rotation.y
	for i in range(5): await process_frame
	check(not is_equal_approx(rings.rotation.y,spin),"plasma rings rotate every frame without a rebuild")
	var builds=world.geometry_rebuilds
	# Doctor install: one orb per element, hovering high, sinking as the doctor works.
	s.coins=1000; s.change_template(0,"water")
	check(not r.get("installation",{}).is_empty(),"changing the recipe queues a doctor installation")
	world.setup(s); await process_frame
	var orbs: Node3D=find(world,"InstallOrbs")
	check(orbs!=null and orbs.get_child_count()==s.reactor_views()[0].install_elements.size() and orbs.get_child_count()>=2 and world.geometry_rebuilds==builds+1,"install orbs appear, one per reserved element, with a single rebuild")
	for i in range(10): await process_frame
	var high=orbs.get_child(0).position.y
	r.installation.remaining=float(s.island_rules.logistics.installation_seconds)*0.1
	world.setup(s)
	for i in range(90): await process_frame
	check(orbs.get_child(0).position.y<high-0.5 and world.geometry_rebuilds==builds+1,"orbs sink into the chamber as installation progresses, still without rebuilding")
	world.queue_free(); await process_frame
	# Finishing the installation changes gas → liquid and raises a phase notice.
	s.campus_build(5,"institute"); s.campus_road(5); s.campus_build(7,"doctor_dorm"); s.campus_road(7); s.campus_hire("doctor"); s.campus.elapsed=100
	for i in range(240):
		if r.get("installation",{}).is_empty(): break
		s.tick(1)
	check(r.get("installation",{}).is_empty() and s.reactor_phase(r)=="liquid","the doctor loads water into the reactor")
	check(s.phase_notice.get("from","")=="gas" and s.phase_notice.get("to","")=="liquid","gas → liquid raises a phase notice")
	# Main: the notice becomes a banner and the sidebar shows a phase badge and tier name.
	var game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gr=game.state.reactors[0]; gr.build_left=0.0
	game._select_plot(int(gr.plot)); await process_frame
	var badge=find(game,"PhaseBadge")
	check(badge!=null and badge.get_child(0).text==Look.PHASE_NAMES.get(game.state.reactor_phase(gr),"未鉴定"),"sidebar shows the phase badge")
	game.state.phase_notice={"reactor":"R001","formula":"H₂O","from":"gas","to":"liquid"}
	game._process(0.016); await process_frame
	check(game.state.phase_notice.is_empty(),"main consumes the phase notice")
	var st=game.state
	game.queue_free(); await process_frame
	st.close_science(); s.close_science()
	print("REACTOR LOOKS: ",checks," checks, ",failures.size()," failures")
	if not failures.is_empty(): print(failures)
	quit(0 if failures.is_empty() else 1)
