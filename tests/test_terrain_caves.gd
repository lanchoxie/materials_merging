extends SceneTree
## v0.33.2 terrain and caves: home ground is unchanged, the far world has real relief, caves exist
## with mouths you can walk into, and old far-away builds keep their ground (legacy pads).
const Terrain=preload("res://scripts/river_terrain.gd")
const Walker=preload("res://scripts/river_walker.gd")
const State=preload("res://scripts/lab_state.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	var t=Terrain.new()
	# --- Home stays exactly the old ground.
	var same=true
	for x in range(-100,101,7):
		for z in range(-100,101,7):
			var p=Vector2(x,z)
			if p.length()>float(t.rules.relief_begin): continue
			if t.relief(p)!=0.0 or t.column_has_cave(x,z): same=false
	check(same,"no relief or caves inside the start area")
	# --- The far world has hills and mountains, not a ±2 m swell.
	var lo=INF; var hi=-INF; var steep=0; var cliff=0.0
	for i in range(400):
		var p=Vector2(600+i*9.0,-300+sin(i*0.7)*900)
		var h=t.natural_height(p); lo=minf(lo,h); hi=maxf(hi,h)
		var step=absf(t.natural_height(p+Vector2(1,0))-h); cliff=maxf(cliff,step)
		if step>1.01: steep+=1
	check(hi-lo>=20.0,"far terrain has real hills and mountains (%.1f m of relief)" % (hi-lo))
	# Hillsides are climbable block steps; only a few ridge crests form small cliffs.
	check(steep<=8 and cliff<=2.01,"cliffs are rare and at most 2 m (%d, max %.1f m)" % [steep,cliff])
	var bank=0.0
	for z in range(-6000,6001,400):
		var rx=t.river_x(z); bank=maxf(bank,t.natural_height(Vector2(rx+6,z)))
	check(bank<=4.0,"the river runs in a valley, not a canyon (bank %.1f m)" % bank)
	# --- Caves: hollow cells below the surface, some mouths open to the sky.
	var cave_cells=0; var mouth=Vector2i(99999,0); var deep=Vector3i(99999,0,0)
	for x in range(300,1500,3):
		for z in range(-900,900,9):
			if not t.column_has_cave(x,z): continue
			var top=t.natural_height(Vector2(x,z))
			for y in range(ceili(top)-14,ceili(top)):
				if t.cave(Vector3i(x,y,z)):
					cave_cells+=1
					if y==ceili(top)-1 and mouth.x==99999: mouth=Vector2i(x,z)
					if y<ceili(top)-4 and deep.x==99999: deep=Vector3i(x,y,z)
	check(cave_cells>200,"the far world has caves (%d sampled cells)" % cave_cells)
	check(mouth.x!=99999,"at least one cave mouth breaks the surface")
	if mouth.x!=99999:
		var p=Vector2(mouth)
		check(t.ground(p)<t.natural_height(p),"ground at a cave mouth drops into the hole")
		var w=Walker.new(t); w.position=p; w.reset_height()
		check(absf(w.feet_y-t.ground(p))<0.01 and not t.overlaps(w.position,w.feet_y,float(t.rules.body_height)) or t.overlaps(w.position,w.feet_y,float(t.rules.body_height))==false,"walker stands inside the mouth without clipping rock")
	if deep.x!=99999:
		check(not t.natural_solid(deep) and t.material(deep)=="","a deep cave cell is air for collision and digging")
		check(t.natural_solid(Vector3i(deep.x,Terrain.Geology.bedrock_y(),deep.z)),"bedrock is never carved")
	# --- Legacy pads: an old save with a far build keeps that build's ground.
	var s=State.new(); var v=s.planet.v2; var data=v.serialize()
	data.erase("terrain")
	var far=Vector2(700,0); var flat=Terrain.new(); flat.set_pads(flat.legacy_pads([far]))
	var base=floori(flat.ground(far))
	data.construction.sources["9"]={"product":{"id":9,"recipe":"field_wall","recipe_version":1,"source_batch":"t"},"remaining":7}
	data.construction.blocks["%d:%d:%d" % [far.x,base,far.y]]={"x":int(far.x),"y":base,"z":int(far.y),"kind":"block","source":"9"}
	var again=v.get_script().new()
	check(again.restore(data),"a pre-v0.33.2 save with a far-away build still loads")
	var at=again.construction.terrain
	check(at.relief(far)==0.0 and at.pad_mask(far+Vector2(200,0))==1.0,"relief is suppressed only around the old build")
	check(again.serialize().terrain.pads.size()>=2,"pads are saved so they stay put")
	var third=v.get_script().new()
	check(third.restore(again.serialize()) and third.construction.terrain.pads.size()==at.pads.size(),"pads survive a save round-trip")
	if failures.is_empty(): print("TERRAIN OK (%d checks)" % checks); quit(0)
	else: print("TERRAIN FAILED: ",failures); quit(1)
