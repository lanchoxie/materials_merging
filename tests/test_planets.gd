extends SceneTree
## v0.48 星际飞船 · 第二颗星球 (agreed plan: multiple planets reached by spaceship, No Man's Sky style):
## planet profiles shift the same generator (Earth's profile reproduces today's Earth exactly); 赤砂星
## is hotter, drier, more land, taller ranges, rich in hematite. The ship jumps between planets; the
## backpack goes along, each planet keeps its own world; Earth's timelines keep their keys.
const State=preload("res://scripts/lab_state.gd")
const PlanetV2=preload("res://scripts/planet_v2.gd")
const Shape=preload("res://scripts/planet_shape.gd")
const Geology=preload("res://scripts/planet_geology.gd")
const Globe=preload("res://scripts/planet_globe.gd")
var failures=[]
var checks=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	# --- Profiles.
	check(Shape.planets().order==["earth","ember"],"two planets on the star map")
	var earth=Shape.profile_of("earth"); var ember=Shape.profile_of("ember")
	var same=true
	for i in range(40):
		var x=-8000.0+i*397.0; var z=-7000.0+i*350.0
		if absf(Shape.continent(x,z,earth)-Shape.continent(x,z))>1e-9 or Shape.mountains(x,z,0.6,earth)!=Shape.mountains(x,z,0.6): same=false
	check(same,"Earth's profile is exactly today's generator")
	var land_e=0; var land_r=0; var peak_e=0.0; var peak_r=0.0
	for i in range(64):
		for j in range(48):
			var x=-8192.0+(i+0.5)*256.0; var z=Shape.NORTH+(j+0.5)*(Shape.SOUTH-Shape.NORTH)/48.0
			var ce=Shape.continent(x,z); var cr=Shape.continent(x,z,ember)
			if ce>0.0: land_e+=1
			if cr>0.0: land_r+=1
			peak_e=maxf(peak_e,Shape.mountains(x,z,ce)); peak_r=maxf(peak_r,Shape.mountains(x,z,cr,ember))
	check(land_r>land_e+300,"赤砂星 is mostly land (%d vs Earth %d of 3072 samples)" % [land_r,land_e])
	check(peak_r>peak_e,"its ranges are taller (%.0f m vs %.0f m)" % [peak_r,peak_e])
	var hem_e=0; var hem_r=0
	for x in range(0,60):
		for y in range(-30,-13):
			for z in range(0,6):
				if Geology.natural(Vector3i(x*3,y,z*3),1.0,false)=="hematite": hem_e+=1
				if Geology.natural(Vector3i(x*3,y,z*3),1.0,false,ember)=="hematite": hem_r+=1
	check(hem_r>hem_e*2,"its crust is rich in hematite (%d vs %d cells)" % [hem_r,hem_e])
	# --- A world generated as 赤砂星.
	var v=PlanetV2.new(); v.begin_planet("ember")
	check(v.planet=="ember" and v.world_key()=="ember:present" and v.construction.terrain.profile.get("name")=="赤砂星","a new world is generated as 赤砂星")
	var home=PlanetV2.new()
	check(v.environment.baseline(3000,-1500).y>home.environment.baseline(3000,-1500).y+5.0 and v.environment.baseline(3000,-1500).x<home.environment.baseline(3000,-1500).x,"it is hotter and drier than Earth")
	var differs=false
	for i in range(30):
		var q=Vector2(-3000+i*211,1500-i*97)
		if absf(v.construction.terrain.natural_height(q)-home.construction.terrain.natural_height(q))>0.4: differs=true
	check(differs,"the ground itself is different")
	check(Globe.equirect(v.environment)!=Globe.equirect(home.environment),"the globe paints each planet separately")
	var data=JSON.parse_string(JSON.stringify(v.serialize()))
	var back=PlanetV2.new()
	check(back.restore(data) and back.planet=="ember" and absf(back.construction.terrain.natural_height(Vector2(2000,500))-v.construction.terrain.natural_height(Vector2(2000,500)))<1e-6,"a 赤砂星 world saves and loads as itself")
	var bad=data.duplicate(true); bad.planet="mars"
	check(not PlanetV2.new().restore(bad),"an unknown planet is rejected")
	var old=JSON.parse_string(JSON.stringify(home.serialize())); old.erase("planet"); old.erase("ship")
	check(PlanetV2.new().restore(old),"worlds saved before planets load as Earth")
	# --- Voyages.
	var s=State.new(); var p=s.planet; var ind=s.industry
	check(p.voyage(s,"ember").contains("星际飞船"),"no ship, no voyage")
	preload("res://scripts/test_mode.gd").give_ship(s)
	var c=p.v2.construction
	c.sources["1"]={"product":{"id":1,"recipe":"field_wall","recipe_version":1,"source_batch":"river:1"},"remaining":7}
	var y=c.base(Vector3i(15,0,14)); c.blocks[c.key(Vector3i(15,y,14))]={"x":15,"y":y,"z":14,"kind":"block","source":"1"}
	p.v2.field.crafts["1"]={"recipe":"field_wall","complete":true,"inputs":p.v2.field.rules.recipes.field_wall.natural_inputs.duplicate()}
	p.serial=maxi(p.serial,2)
	p.v2.field.stock.timber=7; p.v2.nature.minerals["hematite"]=3; p.v2.ship_at={"x":12.0,"z":18.0,"heading":0.0}
	var charge=float(ind.ship_state.charge)
	var said=p.voyage(s,"ember")
	check(said.begins_with("跃迁完成") and p.v2.planet=="ember","the ship jumps to 赤砂星 (%s)" % said)
	check(absf(float(ind.ship_state.charge)-(charge-float(ind.rules().ship.jump_wh)))<0.01,"a jump costs %d Wh" % int(ind.rules().ship.jump_wh))
	check(int(p.v2.field.stock.timber)==7 and int(p.v2.nature.minerals.hematite)==3,"the backpack came along")
	check(not p.v2.ship_at.is_empty() and p.timelines.has("present") and p.timelines.present.ship.is_empty(),"so did the ship; Earth keeps none")
	check(p.v2.construction.blocks.is_empty() and p.timelines.present.construction.blocks.size()==1,"Earth's buildings stay on Earth")
	check(p.home().construction.blocks.size()==1 and not p.at_home(),"the island still reaches Earth's home world")
	check(p.travel("ice").contains("地球"),"the time gate only works on Earth")
	# Dig on 赤砂星, fly home, fly back: the hole is still there.
	var t=p.v2.construction.terrain; var cell=Vector3i(30,floori(t.ground(Vector2(30,30)))-1,30)
	p.v2.nature.set_voxel(cell,"",t)
	ind.ship_state.charge=float(ind.ship_state.cap)
	check(p.voyage(s,"earth").begins_with("跃迁完成") and p.v2.planet=="earth" and p.v2.construction.blocks.size()==1 and p.timelines.has("ember:present"),"back on Earth, its buildings are waiting")
	ind.ship_state.charge=float(ind.ship_state.cap)
	p.voyage(s,"ember")
	check(p.v2.planet=="ember" and p.v2.construction.terrain.material(cell)=="","赤砂星 keeps its own terrain edits")
	ind.ship_state.charge=100.0
	check(p.voyage(s,"earth").contains("电量不足"),"a flat ship battery can't jump")
	# --- The whole game saves with two planets; bad timeline data is rejected.
	var path="res://saves/test_planets.json"
	for f in [path,path+".bak"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	check(s.save_game(path).begins_with("已保存"),"the game saves on 赤砂星")
	var loaded=State.new()
	check(loaded.load_game(path) and loaded.planet.v2.planet=="ember" and loaded.planet.timelines.has("present") and loaded.planet.home().construction.blocks.size()==1,"and loads back there, Earth stored")
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var twice=raw.duplicate(true); twice.planet.timelines.present.ship={"x":1.0,"z":1.0,"heading":0.0}
	check(not State.new()._validate_save(twice),"two ships (one per world) are rejected")
	var wrong=raw.duplicate(true); wrong.planet.timelines["mars:present"]=wrong.planet.timelines.present; wrong.planet.timelines.erase("present")
	check(not State.new()._validate_save(wrong),"an unknown world key is rejected")
	for f in [path,path+".bak"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	if failures.is_empty(): print("PLANETS OK (%d checks)" % checks); quit(0)
	else: print("PLANETS FAILED: ",failures); quit(1)
