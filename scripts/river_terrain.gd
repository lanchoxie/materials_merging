extends RefCounted
## Shared geometry queries: renderer and walker always use the same ground.
const Geology=preload("res://scripts/planet_geology.gd")
## v0.42: continents, oceans, mountain ranges, poles and the wrap (scripts/planet_shape.gd).
const Shape=preload("res://scripts/planet_shape.gd")
const CENTERS={"wetland":Vector3(-10,0,10),"riverbank":Vector3(-10,0,-10),"meadow":Vector3(10,0,10),"highland":Vector3(10,0,-10)}
## v0.48: this world's planet profile (data/planets.json; {} = Earth). Set by PlanetV2.set_planet().
var profile: Dictionary={}
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_exploration.json"))
var nature
## v0.32: the climate field (PlanetEnvironment) for ground colours; null in bare tests.
var environment
var trees: Array[Vector2]=[]
var tree_cache={}
## v0.33.2 legacy pads: chunk keys where a pre-v0.33.2 save already built or dug far from home.
## Relief and caves ease back to the old flat ground around them, so nothing gets buried.
const PAD_FLAT=24.0
const PAD_RAMP=64.0
var pads: Dictionary={}
var _pad_near: Dictionary={}
var _cave_columns: Dictionary={}
## v0.33.2: natural column tops are pure functions of x/z (and the pads), so they are cached.
var _height_cache: Dictionary={}
var _trunks: Dictionary={}
var _cave_cells: Dictionary={}
## v0.42: no fixed far-away places; only the home camp (and its gathering slope) can be returned to.
## Everything else is found by walking and remembered with the player's own waypoints.
const LANDMARKS={"home":{"name":"起始河湾","at":Vector2(10,15)},"homestead":{"name":"采集坡 · 小屋营地","at":Vector2(16,22)}}

func _init() -> void:
	# Compatibility/sample list only; walking queries nearby chunks, never this list.
	for z in range(-2,2):
		for x in range(-2,2): trees.append_array(chunk_trees(Vector2i(x,z)))

func chunk_at(p: Vector2) -> Vector2i:
	var span=float(rules.cell_size)*int(rules.chunk_cells)
	return Vector2i(floori((p.x+0.5)/span),floori((p.y+0.5)/span))

func chunk_tree_origins(key: Vector2i) -> Array[Vector2]:
	if tree_cache.has(key): return tree_cache[key]
	var result: Array[Vector2]=[]; var span=float(rules.cell_size)*int(rules.chunk_cells)
	var start=Vector2(key)*span
	for iz in range(floori((start.y-1)/3.3),ceili((start.y+span+1)/3.3)):
		for ix in range(floori((start.x-1)/3.3),ceili((start.x+span+1)/3.3)):
			var p=Vector2(ix*3.3+sin(iz*12.7+ix)*0.8,iz*3.3+cos(ix*4.3)*0.8)
			if chunk_at(p)!=key or not inside(p,2.0) or absf(p.x-river_x(p.y))<3.0 or on_path(p): continue
			var clearing=false
			for c in CENTERS.values():
				if p.distance_to(Vector2(c.x,c.z))<6.0: clearing=true
			var site=(p/float(rules.site_spacing)).round()*float(rules.site_spacing)
			if site.length()>40 and p.distance_to(site)<8: clearing=true
			if clearing or sin(ix*21.1+iz*43.8)<-0.1: continue
			# v0.42: no trees in the sea or on beaches; how dense a wood is depends on the biome.
			if p.length()>300.0:
				var cont=Shape.continent(p.x,p.y,profile)
				if cont<0.08 and pad_mask(p)>=1.0: continue
				# Tree line: bare rock and snow high on the ranges.
				if Shape.mountains(p.x,p.y,cont,profile)>20.0: continue
				if environment!=null:
					var keep={"forest":1.0,"wetland":0.6,"grassland":0.35,"tundra":0.15,"desert":0.03,"ice":0.0,"ocean":0.0}.get(environment.biome_at(p),0.5)
					if Geology._hash(ix,iz,7,11)>float(keep): continue
			result.append(p)
	if tree_cache.size()>=96: tree_cache.erase(tree_cache.keys()[0])
	tree_cache[key]=result
	return result

## Standing trunks per chunk. Cached against nature.revision (every chop, planting and growth
## stage bumps it): walking and aiming ask this hundreds of times a second.
func chunk_trees(key: Vector2i) -> Array[Vector2]:
	if nature==null: return chunk_tree_origins(key)
	var hit=_trunks.get(key)
	if hit!=null and int(hit[0])==int(nature.revision): return hit[1]
	var result: Array[Vector2]=[]
	for tree in nature.records(key,self):
		if not tree.cut and tree.growth>=0.5: result.append(Vector2(tree.x,tree.z))
	if _trunks.size()>=96: _trunks.clear()
	_trunks[key]=[int(nature.revision),result]
	return result

## Returns the nature ids of all mature trees within `radius` of `p` (used by TBM to clear the path).
func trees_near(p: Vector2, radius: float=1.8) -> Array:
	if nature==null: return []
	var result=[]
	var key=chunk_at(p)
	for dz in range(-1,2):
		for dx in range(-1,2):
			for tree in nature.records(key+Vector2i(dx,dz),self):
				if not tree.cut and tree.growth>=0.99 and Vector2(tree.x,tree.z).distance_to(p)<=radius:
					result.append(tree.id)
	return result

func tree_records(key: Vector2i) -> Array:
	if nature!=null: return nature.records(key,self)
	var result=[]
	for p in chunk_tree_origins(key): result.append({"id":"","x":p.x,"z":p.y,"species":"oak","growth":1.0,"cut":false,"hits":0,"water":0.0})
	return result

func region_at(p: Vector2) -> String:
	return ("riverbank" if p.y<0 else "wetland") if p.x<0 else ("highland" if p.y<0 else "meadow")

## v0.42: the surface wraps east–west; only the polar caps bound it.
func inside(p: Vector2,margin: float=0.0) -> bool:
	return Shape.on_surface(p,margin)

func river_x(z: float) -> float:
	return -10.0+sin(z*0.15)*1.1+sin(z*0.017)*8.0*clampf((absf(z)-30)/60.0,0,1)

func cell_center(p: Vector2) -> Vector2:
	return (p/float(rules.cell_size)).round()*float(rules.cell_size)

func height_at(p: Vector2) -> float:
	var c=cell_center(p)
	return top_at(roundi(c.x),roundi(c.y))

## v0.26: the ground is a 1 m voxel grid. The natural column top keeps the old landscape,
## floored to half metres so the top cell is a full block or a slab. floor() keeps every old
## building's base cell (floor of the old ground) exactly where it was.
func natural_height(p: Vector2) -> float:
	var c=cell_center(p); var k=Vector2i(roundi(c.x),roundi(c.y))
	var cached=_height_cache.get(k)
	if cached!=null: return cached
	var h=0.0
	if not river_cell(c):
		var raw=legacy_height(c)
		h=floor(raw*2.0)/2.0 if raw<0.0 else maxf(0.5,floor((raw+0.055)*2.0)/2.0)
	if _height_cache.size()>=120000: _height_cache.clear()
	_height_cache[k]=h
	return h

func river_cell(c: Vector2) -> bool:
	# The river runs over land only; at the coast it meets the sea.
	return absf(c.x-river_x(c.y))<2.0 and Shape.continent(c.x,c.y,profile)>0.03

## River water, or the sea over a sea floor below sea level.
func water_at(p: Vector2) -> bool:
	return (river_cell(cell_center(p)) or natural_height(p)<Shape.SEA_LEVEL-0.05) and not bridge(p)

## Deep sea (more than a metre and a bit): no walking or driving in until boats exist.
func deep_water(p: Vector2) -> bool:
	return natural_height(p)<-1.25 and not _edited(roundi(p.x),roundi(p.y))

func _edited(x: int,z: int) -> bool:
	return nature!=null and nature.columns.has(Vector2i(x,z))

func top_at(x: int,z: int) -> float:
	var natural=natural_height(Vector2(x,z))
	if not _edited(x,z):
		if not column_has_cave(x,z): return natural
		# A cave mouth carves the top cells: the standing surface is the first solid cell below.
		var cy=ceili(natural)-1
		while cy>Geology.bedrock_y() and not natural_solid(Vector3i(x,cy,z)): cy-=1
		return natural if cy==ceili(natural)-1 else float(cy+1)
	var ys: Dictionary=nature.columns[Vector2i(x,z)]; var top=-INF
	for y in ys:
		if nature.voxels[Vector3i(x,y,z)]!="": top=maxf(top,y+1)
	var y=ceili(natural)-1
	while y>Geology.bedrock_y() and nature.voxels.get(Vector3i(x,y,z),"x")=="": y-=1
	return maxf(top,natural if y==ceili(natural)-1 else float(y+1))

func natural_solid(c: Vector3i) -> bool:
	if c.y<=Geology.bedrock_y(): return true
	if c.y>=ceili(natural_height(Vector2(c.x,c.z))): return false
	return not cave(c)

func solid(c: Vector3i) -> bool:
	if nature!=null and nature.voxels.has(c): return nature.voxels[c]!=""
	return natural_solid(c)

## Natural top cells may be half-height slabs; every placed cell is a full block.
func cell_height(c: Vector3i) -> float:
	if nature!=null and nature.voxels.has(c): return 1.0
	return natural_cell_height(c)

func natural_cell_height(c: Vector3i) -> float:
	var top=natural_height(Vector2(c.x,c.z))
	return top-c.y if c.y==ceili(top)-1 and top-c.y<1.0 else 1.0

func material(c: Vector3i) -> String:
	if nature!=null and nature.voxels.has(c): return nature.voxels[c]
	return natural_material(c)

func natural_material(c: Vector3i) -> String:
	if not natural_solid(c): return ""
	var p=Vector2(c.x,c.z)
	return Geology.natural(c,natural_height(p),river_cell(p),profile)

## Highest standing surface in one column at or below `ceiling`.
func floor_below(x: int,z: int,ceiling: float) -> float:
	if not _edited(x,z) and not column_has_cave(x,z):
		var top=natural_height(Vector2(x,z))
		return top if top<=ceiling+0.001 else float(floori(ceiling+0.001))
	if not _edited(x,z):
		var y=floori(ceiling+0.001)
		while y>Geology.bedrock_y():
			if natural_solid(Vector3i(x,y,z)): return float(y+1)
			y-=1
		return float(Geology.bedrock_y()+1)
	var y=floori(ceiling+0.001)
	while y>Geology.bedrock_y():
		var c=Vector3i(x,y,z)
		if solid(c) and y+cell_height(c)<=ceiling+0.001: return y+cell_height(c)
		y-=1
	return float(Geology.bedrock_y()+1)

## Does a body (feet..feet+height, radius) intersect solid ground cells?
func overlaps(p: Vector2,feet: float,height: float) -> bool:
	var radius=float(rules.player_radius)
	for x in range(floori(p.x-radius+0.5),floori(p.x+radius+0.5)+1):
		for z in range(floori(p.y-radius+0.5),floori(p.y+radius+0.5)+1):
			if not _edited(x,z) and not column_has_cave(x,z):
				if natural_height(Vector2(x,z))>feet+0.001: return true
				continue
			if not _edited(x,z):
				for y in range(floori(feet+0.001),floori(feet+height-0.001)+1):
					if natural_solid(Vector3i(x,y,z)): return true
				continue
			for y in range(floori(feet+0.001),floori(feet+height-0.001)+1):
				var c=Vector3i(x,y,z)
				if solid(c) and y+cell_height(c)>feet+0.001: return true
	return false

func legacy_height(c: Vector2) -> float:
	if river_cell(c): return 0.03
	var h=0.55+floor((sin(c.x*0.22)+cos(c.y*0.23))*1.2)*0.14
	var far=clampf((c.length()-32)/30.0,0,1)
	if c.x>0 and c.y<0:
		var plateau=floor(minf(22,maxf(0,c.x-c.y-6)*0.23))
		var edge=clampf(minf(c.x,-c.y)/24.0,0,1)
		h+=floor(plateau*lerpf(1.0,edge,far))*0.28
	h+=floor((sin(c.x*0.025)*cos(c.y*0.027)+1)*7*far)*0.16
	h+=relief(c)
	h=maxf(h,0.27)
	# v0.42: the continent shapes the land. Legacy pads (old far builds) always stay dry land.
	var cont=Shape.continent(c.x,c.y,profile)
	if pad_mask(c)<1.0: cont=maxf(cont,0.15)
	if cont<0.0: return -Shape.ocean_depth(cont)
	h=lerpf(0.35,h,Shape.coast(cont))
	h+=Shape.mountains(c.x,c.y,cont,profile)*pad_mask(c)*smoothstep(3.0,90.0,absf(c.x-river_x(c.y)))
	return h

## v0.33.2 relief: rolling hills and ridges that stay flat inside the start bend (so home, the
## river, placed buildings and field nodes never move) and fade in beyond it. Floored to whole
## metres so hillsides read as clean voxel steps the walker can climb or route around.
func relief(c: Vector2) -> float:
	var fade=clampf((c.length()-float(rules.relief_begin))/float(rules.relief_fade),0.0,1.0)
	if fade<=0.0: return 0.0
	# The river keeps a wide valley instead of cutting a slot canyon through the mountains.
	fade*=pad_mask(c)*smoothstep(3.0,90.0,absf(c.x-river_x(c.y)))
	if fade<=0.0: return 0.0
	var hills=(sin(c.x*0.013+cos(c.y*0.011)*2.0)+cos(c.y*0.015+sin(c.x*0.009)*2.0)+2.0)*0.25
	var detail=(sin(c.x*0.043+c.y*0.017)*cos(c.y*0.039-c.x*0.011)+1.0)*0.5
	# Ridged mountains: sharp crests where the fold lines meet, in broad bands across the map.
	var fold=1.0-absf(sin(c.x*0.0047+sin(c.y*0.0031)*1.6)*cos(c.y*0.0043-sin(c.x*0.0029)*1.4))
	var band=smoothstep(0.15,0.75,sin(c.x*0.0011+0.6)*cos(c.y*0.0013-0.4)*0.5+0.5)
	var ridge=fold*fold*fold*band
	return floor((hills*float(rules.relief_hills)+detail*float(rules.relief_detail)+ridge*float(rules.relief_ridge))*fade)

## v0.33.2 caves: hollow cells carved out of the rock below the top crust, beyond the start bend.
## Two tunnel fields intersect into connected galleries; a hillside slices them open as cave mouths.
func cave(c: Vector3i) -> bool:
	if c.y<=Geology.bedrock_y()+1: return false
	if not column_has_cave(c.x,c.z): return false
	return _cave_at(c,natural_height(Vector2(c.x,c.z)))

func _cave_at(c: Vector3i,top: float) -> bool:
	var hit=_cave_cells.get(c)
	if hit!=null: return hit
	var carved=_cave_shape(c,top)
	if _cave_cells.size()>=400000: _cave_cells.clear()
	_cave_cells[c]=carved
	return carved

func _cave_shape(c: Vector3i,top: float) -> bool:
	# A roof of at least 2 m, except in sparse mouth patches where tunnels break the surface.
	var roof=0.0 if cave_mouth(Vector2(c.x,c.z)) else 2.0
	if float(c.y)>top-roof-0.001 or float(c.y)<top-float(rules.cave_depth) or c.y<=Geology.bedrock_y()+1: return false
	var worm=sin(c.x*0.063+c.y*0.021)+sin(c.z*0.058-c.y*0.019)+sin((c.x+c.z)*0.037)
	var seam=cos(c.x*0.044-c.z*0.051)+sin(c.y*0.1)
	return absf(worm)<float(rules.cave_width) and absf(seam)<1.05

## Sparse patches (roughly one every few hundred metres) where the cave opens to the sky.
func cave_mouth(p: Vector2) -> bool:
	return sin(p.x*0.021+0.7)*cos(p.y*0.017-1.3)+0.35*sin((p.x-p.y)*0.009)>float(rules.cave_mouth)

## True if a column might contain a carved cell, so the mesher scans it the slow way instead of
## the heightmap fast path. Cheap radius reject keeps the whole start area on the fast path.
func column_has_cave(x: int,z: int) -> bool:
	var p=Vector2(x,z)
	if p.length()<float(rules.cave_begin) or river_cell(p) or pad_mask(p)<1.0: return false
	var k=Vector2i(x,z)
	if _cave_columns.has(k): return _cave_columns[k]
	var top=natural_height(p); var found=false
	# v0.42: no caves under the sea (the floor stays whole); ranges keep theirs, cut open on the slopes.
	if top<0.5:
		if _cave_columns.size()>=60000: _cave_columns.clear()
		_cave_columns[k]=false
		return false
	# The tunnel field changes by at most ~0.04 per metre of depth, so one sample at mid-depth
	# rules out most columns without testing every cell.
	var mid=top-float(rules.cave_depth)*0.5
	var worm=sin(x*0.063+mid*0.021)+sin(z*0.058-mid*0.019)+sin((x+z)*0.037)
	if absf(worm)>float(rules.cave_width)+0.04*float(rules.cave_depth)*0.5+0.05:
		if _cave_columns.size()>=60000: _cave_columns.clear()
		_cave_columns[k]=false
		return false
	for y in range(ceili(top-float(rules.cave_depth)),ceili(top)):
		if _cave_at(Vector3i(x,y,z),top): found=true; break
	if _cave_columns.size()>=60000: _cave_columns.clear()
	_cave_columns[k]=found
	return found

## 0 on a legacy pad, easing to 1 at PAD_RAMP metres away.
func pad_mask(c: Vector2) -> float:
	if _pad_near.is_empty(): return 1.0
	var near=_pad_near.get(chunk_at(c))
	if near==null: return 1.0
	var d=INF
	for at in near: d=minf(d,c.distance_to(at))
	return smoothstep(PAD_FLAT,PAD_RAMP,d)

## v0.48: switch this terrain to another planet's generator (and forget everything cached).
func set_profile(p: Dictionary) -> void:
	profile=p
	_cave_columns.clear(); _cave_cells.clear(); _height_cache.clear(); tree_cache.clear(); _trunks.clear()
	trees=[]
	for z in range(-2,2):
		for x in range(-2,2): trees.append_array(chunk_trees(Vector2i(x,z)))

func set_pads(keys: Array) -> void:
	pads={}; _pad_near={}; _cave_columns.clear(); _cave_cells.clear(); _height_cache.clear(); tree_cache.clear(); _trunks.clear()
	var span=float(rules.cell_size)*int(rules.chunk_cells); var reach=ceili((PAD_RAMP+span)/span)
	for key in keys:
		pads[key]=true
		var at=(Vector2(key)+Vector2(0.5,0.5))*span
		for dz in range(-reach,reach+1):
			for dx in range(-reach,reach+1):
				var k=key+Vector2i(dx,dz)
				if not _pad_near.has(k): _pad_near[k]=[]
				_pad_near[k].append(at)

## Far chunks an old save touched (placed blocks, dug or placed voxels). Home stays untouched anyway.
func legacy_pads(points: Array) -> Array:
	var seen={}
	for p in points:
		if p.length()<float(rules.relief_begin)-PAD_RAMP: continue
		seen[chunk_at(p)]=true
	return seen.keys()

func pads_serialize() -> Dictionary:
	var flat=[]
	for key in pads: flat.append_array([key.x,key.y])
	return {"version":1,"pads":flat}

func pads_restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("pads") is Array: return false
	var flat: Array=data.pads
	if flat.size()%2!=0 or flat.size()>8192: return false
	var keys=[]; var limit=ceili(float(rules.radius)/(float(rules.cell_size)*int(rules.chunk_cells)))+1
	for i in range(0,flat.size(),2):
		for v in [flat[i],flat[i+1]]:
			if not (v is int or v is float) or v!=floor(v) or absf(v)>limit: return false
		keys.append(Vector2i(int(flat[i]),int(flat[i+1])))
	set_pads(keys)
	return true

func bridge(p: Vector2) -> bool:
	return absf(p.y)<1.0 and absf(p.x-river_x(0))<3.3

func ground(p: Vector2) -> float:
	return maxf(height_at(p),0.72) if bridge(p) else height_at(p)

func on_path(p: Vector2) -> bool:
	return (absf(p.y)<0.65 and absf(p.x)<400.0) or (absf(p.x-10)<0.6 and absf(p.y)<11)

func blocked(p: Vector2,barriers: Array=[]) -> bool:
	var radius=float(rules.player_radius)
	if not inside(p,0.9) or deep_water(p): return true
	var key=chunk_at(p)
	for dz in range(-1,2):
		for dx in range(-1,2):
			for tree in chunk_trees(key+Vector2i(dx,dz)):
				if p.distance_squared_to(tree)<pow(radius+0.20,2): return true
	for rect in barriers:
		if rect.grow(radius).has_point(p): return true
	return false

func spawn(region: String) -> Vector2:
	var c: Vector3=CENTERS[region]
	# Face the shared animal clearing, not a freshly generated world.
	return Vector2(c.x+3.8,c.z+5.0)

func building_barriers(regions: Dictionary) -> Array:
	var result=[]
	for id in CENTERS:
		if not regions.has(id): continue
		var r=regions[id]; var c: Vector3=CENTERS[id]; var p=Vector2(c.x,c.z)
		for key in r.buildings:
			if key=="frame_bundle":
				for side in [-1,1]:
					result.append(Rect2(p+Vector2(-1.35,side*1.3-0.05),Vector2(2.7,0.1)))
					if r.enclosed:
						result.append(Rect2(p+Vector2(side*1.3-0.05,-1.3),Vector2(0.1,2.6)))
					else:
						for z in [-1.3,0.55]: result.append(Rect2(p+Vector2(side*1.3-0.05,z),Vector2(0.1,0.75)))
			elif key in ["oxygen_station","screen_station"]:
				var at=p+Vector2(0.5,0.8 if key=="screen_station" else 1.8)
				result.append(Rect2(at-Vector2(0.28,0.33),Vector2(0.56,0.66)))
	return result

