extends RefCounted
## Shared geometry queries: renderer and walker always use the same ground.
const CENTERS={"wetland":Vector3(-10,0,10),"riverbank":Vector3(-10,0,-10),"meadow":Vector3(10,0,10),"highland":Vector3(10,0,-10)}
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_exploration.json"))
var nature
var trees: Array[Vector2]=[]
var tree_cache={}
const LANDMARKS={"home":{"name":"起始河湾","at":Vector2(10,15)},"homestead":{"name":"采集坡 · 小屋营地","at":Vector2(16,22)},"camp":{"name":"旅人林间营地","at":Vector2(68,68)},"woods":{"name":"西岸林地","at":Vector2(-124,68)},"ridge":{"name":"远方高原","at":Vector2(196,-188)},"frontier":{"name":"千米林海 · 远征起点","at":Vector2(1348,1348)},"far_river":{"name":"六公里外 · 上游河谷","at":Vector2(-8,-6140)}}

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
			result.append(p)
	if tree_cache.size()>=96: tree_cache.erase(tree_cache.keys()[0])
	tree_cache[key]=result
	return result

func chunk_trees(key: Vector2i) -> Array[Vector2]:
	if nature==null: return chunk_tree_origins(key)
	var result: Array[Vector2]=[]
	for tree in nature.records(key,self):
		if not tree.cut and tree.growth>=0.5: result.append(Vector2(tree.x,tree.z))
	return result

func tree_records(key: Vector2i) -> Array:
	if nature!=null: return nature.records(key,self)
	var result=[]
	for p in chunk_tree_origins(key): result.append({"id":"","x":p.x,"z":p.y,"species":"oak","growth":1.0,"cut":false,"hits":0,"water":0.0})
	return result

func region_at(p: Vector2) -> String:
	return ("riverbank" if p.y<0 else "wetland") if p.x<0 else ("highland" if p.y<0 else "meadow")

func inside(p: Vector2,margin: float=0.0) -> bool:
	return p.length()<=float(rules.radius)-margin

func river_x(z: float) -> float:
	return -10.0+sin(z*0.15)*1.1+sin(z*0.017)*8.0*clampf((absf(z)-30)/60.0,0,1)

func cell_center(p: Vector2) -> Vector2:
	return (p/float(rules.cell_size)).round()*float(rules.cell_size)

func height_at(p: Vector2) -> float:
	return natural_height(p)+(float(nature.edits.get(nature.cell_key(cell_center(p)),0)) if nature!=null else 0.0)

func natural_height(p: Vector2) -> float:
	var c=cell_center(p)
	if absf(c.x-river_x(c.y))<2.0: return 0.03
	var h=0.55+floor((sin(c.x*0.22)+cos(c.y*0.23))*1.2)*0.14
	var far=clampf((c.length()-32)/30.0,0,1)
	if c.x>0 and c.y<0:
		var plateau=floor(minf(22,maxf(0,c.x-c.y-6)*0.23))
		var edge=clampf(minf(c.x,-c.y)/24.0,0,1)
		h+=floor(plateau*lerpf(1.0,edge,far))*0.28
	h+=floor((sin(c.x*0.025)*cos(c.y*0.027)+1)*7*far)*0.16
	return maxf(h,0.27)

func bridge(p: Vector2) -> bool:
	return absf(p.y)<1.0 and absf(p.x-river_x(0))<3.3

func ground(p: Vector2) -> float:
	return maxf(height_at(p)+0.055,0.72) if bridge(p) else height_at(p)+0.055

func on_path(p: Vector2) -> bool:
	return absf(p.y)<0.65 or (absf(p.x-10)<0.6 and absf(p.y)<11)

func blocked(p: Vector2,barriers: Array=[]) -> bool:
	var radius=float(rules.player_radius)
	if not inside(p,0.9): return true
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

