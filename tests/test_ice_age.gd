extends SceneTree
## v0.39 冰河期: the timeline climate offset, cold-adapted wild animals, campfires, felt temperature
## and cold damage, the 寒潮暴雪 incident, the 保温服, and the time gate (what travels, what stays,
## saves, miniatures that always belong to the present).
const State=preload("res://scripts/lab_state.gd")
const PlanetV2=preload("res://scripts/planet_v2.gd")
const PlanetProgram=preload("res://scripts/planet_program.gd")
const Mini=preload("res://scripts/river_miniatures.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

## A real workshop product: an issued id below the program serial and a finished craft record.
var program=null
func issue(v,recipe: String) -> Dictionary:
	var id=900+v.field.crafts.size()
	if program!=null: id=int(program.serial); program.serial+=1
	v.field.crafts[str(id)]={"recipe":recipe,"complete":true,"inputs":v.field.rules.recipes[recipe].natural_inputs.duplicate()}
	return {"id":id,"recipe":recipe,"recipe_version":1,"source_batch":"river:"+str(id)}

func block(v,kind: String,recipe: String,x: int,z: int,dy: int=0) -> void:
	var c=v.construction; var key=""
	for k in c.sources:
		if c.sources[k].product.recipe==recipe: key=k
	if key=="":
		var product=issue(v,recipe); key=str(int(product.id)); c.sources[key]={"product":product,"remaining":0}
	var b={"x":x,"y":c.base(Vector3i(x,0,z))+dy,"z":z,"kind":kind,"source":key}
	c.blocks[c.key(c.cell(b))]=b; c.revision+=1
	# Keep the material ledger balanced: units = remaining + placed.
	var placed=0
	for other in c.blocks.values():
		if other.source==key: placed+=1
	c.sources[key].remaining=int(c.rules.recipes[recipe].units)-placed

func _initialize() -> void:
	# --- Climate offset.
	var now=PlanetV2.new(); var ice=PlanetV2.new(); ice.begin_epoch("ice")
	for i in range(5): now.world.elapsed+=1; now._step(); ice.world.elapsed+=1; ice._step()
	var dt=float(now.world.regions.meadow.temperature)-float(ice.world.regions.meadow.temperature)
	check(absf(dt+float(ice.epoch_info().temperature))<0.5,"the 冰河期 meadow is colder by the era's offset (%.1f °C)" % dt)
	check(ice.world.regions.meadow.crops.is_empty() and ice.world.events[0].text.contains("末次冰盛期"),"the ice age starts without sown crops, with its own story")
	check(ice.environment.biome_at(Vector2(0,-3000))=="tundra","the cold north is tundra")
	check(ice.incident_kinds()==["blizzard"] and ice.incidents_all_seasons() and now.incident_kinds().has("storm"),"each timeline has its own weather")
	# --- Wild animals.
	var site=ice.population._site("t",Vector2(500,500),false)
	check(site.animals.all(func(a): return a.species in ["mammoth","woolly_rhino"]),"wild sites in the ice age hold mammoths and woolly rhinos")
	check(ice.population._suitable({"moisture":0.5,"water":0.5,"temperature":-12.0,"pollution":0.0}) and not now.population._suitable({"moisture":0.5,"water":0.5,"temperature":-12.0,"pollution":0.0}),"cold-adapted fauna thrive at −12 °C; today's do not")
	check(str(ice.combat.WILD_NAMES.mammoth)=="猛犸象" and ice.combat.reaction({"fish":false,"type":"wild","row":{"species":"mammoth"}})=="反击","mammoths fight back")
	check(ice.specimens.record("mammoth","tundra").contains("Mammuthus primigenius"),"the analyser records a mammoth specimen with its real prototype")
	# --- Felt temperature, campfire, roof, suit, cold damage.
	ice.world.elapsed=12*60   # winter
	var p=Vector2(30,30); var ground=ice.construction.terrain.ground(p)
	var feet=Vector3(p.x,ground,p.y)
	ice.actor={"eye":feet+Vector3(0,1.62,0),"feet":feet,"direction":Vector3.FORWARD}
	var air=ice.felt_temperature(feet)
	check(air<0.0,"winter in the ice age is below freezing (%.1f °C)" % air)
	var hp=ice.combat.player_health
	ice.combat._cold(10.0,ice)
	check(ice.combat.player_health<hp,"the cold drains health (%.1f → %.1f)" % [hp,ice.combat.player_health])
	block(ice,"campfire","field_campfire",31,30)
	check(absf(ice.felt_temperature(feet)-air-12.0)<0.01,"a campfire within 4.5 m adds 12 °C")
	hp=ice.combat.player_health; ice.combat._cold(10.0,ice)
	check(is_equal_approx(ice.combat.player_health,hp) or ice.felt_temperature(feet)<0,"by the fire the drain stops when it is warm enough")
	ice.combat.suit_warmth=14.0
	check(absf(ice.felt_temperature(feet)-air-26.0)<0.01,"the 保温服 adds its warmth on top")
	ice.combat.suit_warmth=0.0
	block(ice,"roof","field_roof",30,30,2)
	check(ice.construction.roof_over(feet),"a roof two cells up shelters the player")
	# --- Blizzard.
	var s=State.new(); var v=s.planet.v2; v.world.elapsed=12*60
	v.incidents.warn(v,"blizzard",1); for i in range(3): v.world.elapsed+=1; v._step()
	check(str(v.incidents.active.get("kind",""))=="blizzard" and float(v.incidents.region_mods("meadow").chill)>0,"a 寒潮暴雪 starts and chills the air")
	check(v.incidents.sky(v).get("snow",0.0)>0.0,"it snows instead of rains")
	var cold_prep=v.incidents.preparation(v,"blizzard")
	var at=v.settlement.center()
	for i in range(2): block(v,"campfire","field_campfire",int(at.x)+2+i*2,int(at.y))
	check(v.incidents.preparation(v,"blizzard")>=cold_prep+0.49,"two campfires at camp give half the preparation")
	# --- Time gate.
	s=State.new(); var pg=s.planet; program=pg
	check(not pg.gate_ready() and pg.travel("ice").contains("农耕"),"the gate stays shut before the camp farms")
	pg.v2.settlement.era=1
	check(pg.gate_ready(),"farming opens the gate")
	pg.v2.nature.minerals["limestone"]=5; pg.v2.field.stock["timber"]=7; pg.v2.specimens.found["woodland_boar"]=["forest"]
	block(pg.v2,"block","field_wall",19,14)
	var here_blocks=pg.v2.construction.blocks.size()
	check(pg.travel("ice").begins_with("穿过") and pg.v2.epoch=="ice","the player goes to the ice age")
	check(int(pg.v2.nature.minerals.get("limestone",0))==5 and int(pg.v2.field.stock.timber)==7 and pg.v2.specimens.found.has("woodland_boar"),"minerals, raw stock and the specimen book travel along")
	check(pg.v2.construction.blocks.is_empty() and pg.timelines.has("present"),"buildings stay in the present")
	check(pg.timelines.present.nature.minerals.is_empty() and int(pg.timelines.present.field.stock.timber)==0,"nothing is duplicated left behind")
	check(pg.command(s,"v2_mini_pack",{}).contains("当代") or not pg.v2.active,"the 微缩器 only works on present-day builds")
	pg.v2.nature.minerals["limestone"]=9
	check(pg.travel("present").begins_with("穿过") and pg.v2.construction.blocks.size()==here_blocks and int(pg.v2.nature.minerals.limestone)==9,"back home the buildings are there and the backpack came back")
	check(pg.timelines.has("ice") and pg.travel("ice").begins_with("穿过") and pg.v2.epoch=="ice","the ice age world is kept between trips")
	# --- Saves.
	var path="res://saves/ice-age-check.json"
	check(s.save_game(path).begins_with("已保存"),"a game in the ice age saves")
	var loaded=State.new()
	check(loaded.load_game(path) and loaded.planet.v2.epoch=="ice" and loaded.planet.timelines.has("present") and loaded.planet.gate_open,"it loads back in the ice age with the present stored")
	var data=JSON.parse_string(JSON.stringify(s.planet.serialize()))
	var bad=data.duplicate(true); bad.timelines["ice"]=bad.timelines.present
	check(not PlanetProgram.new().restore(bad,s),"a stored timeline for the live era is rejected")
	bad=data.duplicate(true); bad.timelines.present.epoch="mars"
	check(not PlanetProgram.new().restore(bad,s),"an unknown era is rejected")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path)); DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	# --- Miniatures belong to the present.
	s=State.new(); pg=s.planet; program=pg; pg.v2.settlement.era=1; s.coins=5000
	var c=pg.v2.construction
	var wall=issue(pg.v2,"field_wall"); var wk=str(int(wall.id))
	c.sources={wk:{"product":wall,"remaining":6}}
	var b1={"x":19,"y":c.base(Vector3i(19,0,14)),"z":14,"kind":"block","source":wk}; var b2=b1.duplicate(); b2.y+=1
	c.blocks={c.key(c.cell(b1)):b1,c.key(c.cell(b2)):b2}
	Mini.pack(c,{"type":"block","key":c.key(c.cell(b1))})
	pg.travel("ice")
	check(pg.home().construction.miniatures.size()==1,"in the ice age the island still sees the present-day miniatures")
	check(pg.command(s,"v2_mini_exhibit",{"id":"1","plot":4}).contains("摆上") or pg.command(s,"v2_mini_exhibit",{"id":"1","plot":5}).contains("摆上"),"a miniature can be exhibited from the ice age")
	check(int(pg.timelines.present.construction.miniatures["1"].plot)>=0,"the exhibit is written to the stored present")
	check(s.replicate_miniature("1").begins_with("复刻了") and pg.timelines.present.construction.miniatures.size()==2,"复刻 works from the ice age too")
	path="res://saves/ice-age-mini.json"
	check(s.save_game(path).begins_with("已保存") and State.new().load_game(path),"the island with present-day exhibits saves and loads while in the ice age")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path)); DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	pg.travel("present")
	check(pg.v2.construction.miniatures.size()==2,"back home both miniatures are in the live world")
	if failures.is_empty(): print("ICE AGE OK (%d checks)" % checks); quit(0)
	else: print("ICE AGE FAILED: ",failures); quit(1)
