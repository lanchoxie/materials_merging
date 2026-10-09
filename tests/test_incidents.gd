extends SceneTree
## v0.36 Earth: data-driven eras, the deterministic incident director, preparation measured from
## what was built, storm/flood/drought effects, silt after floods, PVC pipes, 标本图鉴, 岛主 XP
## from both, and the save round trip.
const State=preload("res://scripts/lab_state.gd")
const V2=preload("res://scripts/planet_v2.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func run_seconds(v,n: int) -> void:
	for i in range(n): v.world.elapsed+=1; v._step()

func _initialize() -> void:
	var s=State.new(); var v=s.planet.v2; var inc=v.incidents
	# --- Era framework.
	var rows=v.settlement.checklist(v.world,v.construction)
	check(rows.map(func(r): return r.id)==["blocks","shelter","harvests","food","water"],"era 0 rows come from data with their old ids")
	v.settlement.era=1
	check(v.settlement.checklist(v.world,v.construction).size()==8 and v.settlement.last_era()==2,"era 1 has eight requirements; the last era is 2")
	v.settlement.era=2
	check(v.settlement.checklist(v.world,v.construction).is_empty(),"the last era has no next requirements")
	check(v.settlement.incident_kinds().has("drought") and v.settlement.incident_chance()>0.2,"later eras face more and harsher weather")
	v.settlement.era=0
	# --- The director is deterministic and respects the first day.
	var a=V2.new(); var b=V2.new()
	for i in range(int(v.rules.clock.day_seconds)*24):
		a.world.elapsed+=1; a.incidents.step(a); b.world.elapsed+=1; b.incidents.step(b)
	check(JSON.stringify(a.incidents.serialize())==JSON.stringify(b.incidents.serialize()),"two identical worlds get identical weather")
	var c=V2.new(); var seen=false
	for i in range(int(v.rules.clock.day_seconds)*int(inc.rules.first_day)-1):
		c.world.elapsed+=1; c.incidents.step(c); seen=seen or not c.incidents.pending.is_empty()
	check(not seen,"no incident is announced before the first incident day")
	# --- Storm: warning, start, preparation from shelter, crop and health loss, history.
	v.world.regions.meadow.crops=[{"crop":"grain","growth":0.5,"ready":false}]
	v.settlement.era=1; v.settlement.people=[{"id":1,"name":"禾苗","health":0.9,"hunger":0.1,"x":13.0,"z":13.0,"task":"安家"}]
	check(inc.warn(v,"storm",5).begins_with("预警") and not inc.pending.is_empty(),"a storm is announced ahead")
	check(not inc.status_line(v).is_empty() and str(v.world.events[0].text).begins_with("预警"),"the warning shows in the HUD line and the 年鉴")
	run_seconds(v,6)
	check(str(inc.active.get("kind",""))=="storm" and is_equal_approx(float(inc.active.prepared),0.0),"the storm starts; an empty camp is unprepared")
	var water=float(v.world.regions.wetland.water)
	run_seconds(v,20)
	check(float(v.world.regions.wetland.water)>water,"storm rain raises the water")
	check(float(v.world.regions.meadow.crops[0].growth)<0.5 and float(v.settlement.people[0].health)<0.9,"an unprepared storm hurts crops and residents")
	run_seconds(v,int(v.rules.clock.day_seconds))
	check(inc.active.is_empty() and inc.history.size()==1 and inc.weathered==0,"the storm ends and is recorded")
	# --- Flood with a full levee: no crop loss, silt afterwards.
	var t=v.construction.terrain
	v.construction.sources["90"]={"product":{"id":90,"recipe":"field_wall","recipe_version":1,"source_batch":"t"},"remaining":0}
	for k in range(int(inc.rules.levee.full)):
		var z=-20+k*2; var x=int(round(t.river_x(z)+5)); var y=v.construction.base(Vector3i(x,0,z))
		v.construction.blocks[v.construction.key(Vector3i(x,y,z))]={"x":x,"y":y,"z":z,"kind":"block","source":"90"}
	check(inc.levee_blocks(v)>=int(inc.rules.levee.full) and is_equal_approx(inc.preparation(v,"flood"),1.0),"levee blocks along the river count as flood preparation")
	inc.last_end=-1; v.world.regions.riverbank.crops=[{"crop":"reed","growth":0.4,"ready":false}]
	var silt=float(v.world.regions.riverbank.nutrients)
	inc.warn(v,"flood",1); run_seconds(v,3)
	run_seconds(v,int(v.rules.clock.day_seconds)*2+2)
	check(inc.active.is_empty() and inc.weathered==1,"a fully prepared flood counts as weathered")
	check(float(v.world.regions.riverbank.nutrients)>silt+0.1,"the flood leaves fertile silt")
	check(float(v.world.regions.riverbank.crops[0].growth)>=0.4-0.001,"the levee protects the riverbank crops")
	# --- Drought and PVC pipes.
	s.industry.items["pvc"]=4
	check(s.lay_pipe().begins_with("铺设") and s.lay_pipe().begins_with("铺设") and not s.industry.items.has("pvc"),"PVC from 星锻岛 is laid as irrigation pipes")
	check(is_equal_approx(inc.preparation(v,"drought"),0.5),"two pipes are half the drought preparation")
	inc.last_end=-1; inc.warn(v,"drought",1); run_seconds(v,3)
	var mods: Dictionary=inc.region_mods("meadow")
	check(float(mods.rain)<0 and float(mods.evaporation)>1.0 and float(mods.evaporation)<2.5,"drought stops rain and raises evaporation, reduced by preparation")
	# --- Specimens and XP.
	var book=v.specimens
	check(book.record("marsh_fish","湿地").contains("新标本") and book.record("marsh_fish","湿地")=="" and book.record("marsh_fish","森林").contains("新栖地"),"specimens record species once and each new biome")
	check(book.record("dragon","湿地")=="","only real game species are recorded")
	var score=s.industry.legacy_score(s)
	book.record("oak","森林")
	check(s.industry.legacy_score(s)==score+25,"a new specimen pays 岛主 XP")
	# --- Analyser on a creature records it; people are not specimens.
	var e={"type":"wild","row":{"species":"woodland_boar"},"position":Vector2(600,0)}
	var text=v.nature.scan({"type":"creature","entity":e,"name":"林地野猪","health":1.0},v)
	check(text.contains("Sus scrofa") and book.found.has("woodland_boar"),"the analyser names the real prototype and records the specimen")
	check(v.nature.scan({"type":"creature","entity":{"type":"resident","row":{}},"name":"禾苗"},v).contains("不做标本"),"people are never specimens")
	# --- Save round trip and old saves (the fake levee blocks are not a real build).
	for k in v.construction.blocks.keys():
		if v.construction.blocks[k].source=="90": v.construction.blocks.erase(k)
	v.construction.sources.erase("90")
	var data=JSON.parse_string(JSON.stringify(v.serialize())); var again=V2.new()
	check(again.restore(data) and again.incidents.weathered==inc.weathered and again.specimens.count()==book.count() and again.incidents.pipes==2,"incidents and specimens survive a save")
	data.erase("incidents"); data.erase("specimens")
	check(V2.new().restore(data),"saves from before v0.36 still load")
	var bad=JSON.parse_string(JSON.stringify(v.serialize())); bad.specimens.found["unicorn"]=["森林"]
	check(not V2.new().restore(bad),"unknown specimens are rejected")
	if failures.is_empty(): print("INCIDENTS OK (%d checks)" % checks); quit(0)
	else: print("INCIDENTS FAILED: ",failures); quit(1)
