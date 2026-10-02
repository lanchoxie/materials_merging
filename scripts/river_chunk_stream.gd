extends Node3D
## Bounded, incremental render cache. Ground/collision queries do not wait for meshes.
const G=preload("res://scripts/river_geometry.gd")
var terrain
var material: Material
var water_material: Material
var chunks={}
var pending=[]
var center_key=Vector2i(99999,99999)
var season=-1
var nature_revision=-1
var env_revision=-1
var last_build_us=0

func schedule(at: Vector2,new_season: int) -> void:
	var center=terrain.chunk_at(at)
	var rev=terrain.nature.revision if terrain.nature!=null else 0
	var climate=terrain.environment.revision if terrain.environment!=null else 0
	if center==center_key and new_season==season and nature_revision==rev and env_revision==climate: return
	nature_revision=rev; env_revision=climate
	season=new_season; center_key=center
	var wanted={}; var radius=int(terrain.rules.stream_radius); var span=float(terrain.rules.chunk_cells)*terrain.rules.cell_size
	for z in range(-radius,radius+1):
		for x in range(-radius,radius+1):
			var key=center+Vector2i(x,z)
			if not terrain.inside((Vector2(key)+Vector2(0.5,0.5))*span,-span): continue
			wanted[key]=true
	for key in chunks.keys():
		if not wanted.has(key): chunks[key].queue_free(); chunks.erase(key)
	pending=[]
	for key in wanted:
		var revision=int(terrain.nature.chunk_versions.get(key,0)) if terrain.nature!=null else 0
		if not chunks.has(key) or chunks[key].get_meta("season",-1)!=season or chunks[key].get_meta("nature",-1)!=revision or chunks[key].get_meta("env",-1)!=_env_version(key): pending.append(key)
	pending.sort_custom(func(a,b): return Vector2(a-center).length_squared()<Vector2(b-center).length_squared())

func drain(limit: int) -> void:
	for i in range(mini(limit,pending.size())):
		var key=pending.pop_front(); var start=Time.get_ticks_usec(); var mesh=_build(key)
		if not chunks.has(key):
			var n=MeshInstance3D.new(); add_child(n); chunks[key]=n
		chunks[key].mesh=mesh; chunks[key].set_meta("nature",int(terrain.nature.chunk_versions.get(key,0)) if terrain.nature!=null else 0); chunks[key].set_meta("season",season); chunks[key].set_meta("env",_env_version(key)); last_build_us=Time.get_ticks_usec()-start

func _env_version(key: Vector2i) -> int:
	if terrain.environment==null: return 0
	var span=float(terrain.rules.chunk_cells)*terrain.rules.cell_size
	return terrain.environment.chunk_version((Vector2(key)+Vector2(0.5,0.5))*span)

func _process(_dt: float) -> void:
	if terrain!=null: drain(int(terrain.rules.chunks_per_frame))

## v0.26 voxel mesher: per column, emit the faces of solid cells that touch air or a lower slab.
## Unedited columns skip straight to their visible band, so a plain chunk costs about what the
## old heightmap did; only dug or built columns walk deeper cells.
const DIRS=[Vector3i(1,0,0),Vector3i(-1,0,0),Vector3i(0,0,1),Vector3i(0,0,-1)]
var palette={}

func _color(id: String) -> Color:
	if not palette.has(id): palette[id]=Color(str(terrain.Geology.info(id).get("color","958369")))
	return palette[id]

## get() would evaluate a default eagerly; only fall back to the formula outside the cache.
func _top(c: Vector3i,tops: Dictionary) -> float:
	var k=Vector2i(c.x,c.z)
	return tops[k] if tops.has(k) else terrain.natural_height(Vector2(c.x,c.z))

func _solid(c: Vector3i,voxels: Dictionary,tops: Dictionary,bedrock: int) -> bool:
	if voxels.has(c): return voxels[c]!=""
	return c.y<=bedrock or c.y<ceili(_top(c,tops))

func _height(c: Vector3i,voxels: Dictionary,tops: Dictionary) -> float:
	if voxels.has(c): return 1.0
	var top=_top(c,tops)
	return top-c.y if c.y==ceili(top)-1 and top-c.y<1.0 else 1.0

## v0.32 render-only biome decor: cacti, snow mounds, reeds, ferns and flowers. No collision, no state.
func _decor(st: SurfaceTool,p: Vector2,top: float,v: Vector4,roll: float) -> void:
	var b=Vector3(p.x+(roll*50-0.5)*0.4,top,p.y+(fposmod(roll*977,1)-0.5)*0.4)
	if v.y<2.0:
		# Snow drifts lie flat on the ground; the odd boulder wears a snow cap.
		G.cube(st,b+Vector3(0,0.012,0),Vector3(0.9,0.024,0.7),Color("eef3f4"))
		if roll<0.008:
			G.cube(st,b+Vector3(0.2,0.16,0.1),Vector3(0.4,0.3,0.34),Color("8a8f8c"))
			G.cube(st,b+Vector3(0.2,0.33,0.1),Vector3(0.42,0.06,0.36),Color("f4f7f8"))
	elif v.x<0.25:
		if roll<0.01:
			G.cube(st,b+Vector3(0,0.75,0),Vector3(0.26,1.5,0.26),Color("5d8a4a"))
			G.cube(st,b+Vector3(0.25,0.75,0),Vector3(0.3,0.16,0.16),Color("5d8a4a")); G.cube(st,b+Vector3(0.36,1.0,0),Vector3(0.16,0.45,0.16),Color("6a9a55"))
			G.cube(st,b+Vector3(-0.22,0.55,0),Vector3(0.24,0.14,0.14),Color("5d8a4a")); G.cube(st,b+Vector3(-0.3,0.75,0),Vector3(0.14,0.32,0.14),Color("6a9a55"))
			G.cube(st,b+Vector3(0,1.53,0),Vector3(0.12,0.08,0.12),Color("e68aa0"))
		else:
			for i in range(3): G.cube(st,b+Vector3((i-1)*0.16,0.16,(i%2)*0.1),Vector3(0.05,0.32,0.05),Color("9c8150"))
	elif v.x>0.78:
		for i in range(5):
			var h=0.9+fposmod(roll*(31+i*7),1)*0.6
			G.cube(st,b+Vector3((i-2)*0.11,h*0.5,fposmod(roll*(13+i),1)*0.25),Vector3(0.04,h,0.04),Color("8fae6a"))
			G.cube(st,b+Vector3((i-2)*0.11,h+0.08,fposmod(roll*(13+i),1)*0.25),Vector3(0.07,0.18,0.07),Color("7a5a3a"))
	elif v.x>=0.45 and v.z>0.46 and v.y>5.0 and v.y<28.0:
		for i in range(3): G.cube(st,b+Vector3(0,0.18,0),Vector3(0.9 if i!=1 else 0.12,0.05,0.12 if i!=1 else 0.9),Color("3f7a3c").lightened(i*0.08))
		G.cube(st,b+Vector3(0,0.3,0),Vector3(0.1,0.3,0.1),Color("4b8a45"))
	elif roll<0.012:
		var bloom=[Color("f1d35a"),Color("e98fb0"),Color("f4f0e6"),Color("9b8cf0")][int(roll*1000)%4]
		for i in range(3):
			var at=b+Vector3((i-1)*0.18,0,fposmod(roll*(17+i*5),1)*0.3-0.15)
			G.cube(st,at+Vector3(0,0.17,0),Vector3(0.03,0.34,0.03),Color("5b8a45")); G.cube(st,at+Vector3(0,0.36,0),Vector3(0.11,0.07,0.11),bloom)

## Grass follows the season on topsoil; the river bed shows water; rock shows its mineral colour.
func _top_color(id: String,p: Vector2,river: bool,natural_top: bool,grass: Color,shade: float,x: int,y: int,z: int) -> Color:
	if id=="topsoil":
		var c=grass
		if p.x>0 and p.y<0: c=c.lerp(Color("9ba49a"),0.35)
		if terrain.on_path(p): c=Color("bdad83")
		return c.lightened(shade)
	if river and natural_top: return Color("708f89").lightened(shade*0.85)
	return _color(id).lightened(terrain.Geology._hash(x,y,z,5)*0.08)

func _side_color(id: String,d: Vector3i,x: int,y: int,z: int) -> Color:
	if id=="topsoil": return Color("958369")
	return _color(id).lightened(terrain.Geology._hash(x,y,z,5)*0.08).darkened(0.08 if d.x!=0 else 0.14)

func _build(key: Vector2i) -> Mesh:
	var st=G.surface(material); var span=int(terrain.rules.chunk_cells); var cell=float(terrain.rules.cell_size); var tiles=0
	var nature=terrain.nature; var voxels={} if nature==null else nature.voxels; var columns={} if nature==null else nature.columns
	var Geology=terrain.Geology; var bedrock: int=Geology.bedrock_y()
	var tops={}
	for iz in range(key.y*span-1,(key.y+1)*span+1):
		for ix in range(key.x*span-1,(key.x+1)*span+1): tops[Vector2i(ix,iz)]=terrain.natural_height(Vector2(ix,iz))
	# Only chunks at the far rim of the world need per-cell boundary checks.
	var corner=Vector2(key)*span*cell; var rim=not terrain.inside(corner,span*2*cell) or not terrain.inside(corner+Vector2(span,span)*cell,span*2*cell)
	var grass=Color(["749b64","6f9a60","b4a262","bdcfbd"][season])
	# v0.32 Earth: a chunk never crosses a cell centre line, so the blended climate is bilinear
	# inside it; four corner samples are enough.
	var env=terrain.environment; var climate=[]; var decor=[]
	if env!=null:
		for at in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]: climate.append(env.blend((Vector2(key)+at)*span*cell))
	for iz in range(key.y*span,(key.y+1)*span):
		for ix in range(key.x*span,(key.x+1)*span):
			var p=Vector2(ix,iz)*cell
			if rim and not terrain.inside(p): continue
			tiles+=1
			var col=Vector2i(ix,iz); var top: float=tops[col]; var river=terrain.river_cell(p)
			var x0=p.x-cell/2; var x1=p.x+cell/2; var z0=p.y-cell/2; var z1=p.y+cell/2
			var near_edit=columns.has(col)
			for d in DIRS:
				if columns.has(col+Vector2i(d.x,d.z)): near_edit=true
			var shade=(sin(p.x*13+p.y*17)+1)*0.035
			var tile_grass=grass
			if env!=null:
				var u=(p.x/cell-key.x*span)/span; var w=(p.y/cell-key.y*span)/span
				var v: Vector4=climate[0].lerp(climate[1],u).lerp(climate[2].lerp(climate[3],u),w)
				tile_grass=env.tint(v,grass)
				var roll=fposmod(sin(ix*12.9898+iz*78.233)*43758.5453,1.0)
				if roll<0.02 and not near_edit and not river and p.length()>40 and not terrain.on_path(p): decor.append([p,top,v,roll])
			if not near_edit and not rim:
				# Fast path: untouched heightmap column. One top face plus the exposed side bands.
				var yc=ceili(top)-1; var id: String=Geology.natural(Vector3i(ix,yc,iz),top,river)
				G.face(st,[Vector3(x0,top,z0),Vector3(x1,top,z0),Vector3(x1,top,z1),Vector3(x0,top,z1)],_top_color(id,p,river,true,tile_grass,shade,ix,yc,iz))
				for d in DIRS:
					var low: float=tops[col+Vector2i(d.x,d.z)]
					if low>=top: continue
					var a=p+Vector2(d.x,d.z)*cell/2; var tangent=Vector2(-d.z,d.x)*cell/2
					for y in range(floori(low),yc+1):
						var y0=maxf(low,y); var y1=minf(top,y+1)
						var mid: String=id if y==yc else Geology.natural(Vector3i(ix,y,iz),top,river)
						G.face(st,[Vector3(a.x-tangent.x,y0,a.y-tangent.y),Vector3(a.x+tangent.x,y0,a.y+tangent.y),Vector3(a.x+tangent.x,y1,a.y+tangent.y),Vector3(a.x-tangent.x,y1,a.y-tangent.y)],_side_color(mid,d,ix,y,iz))
				continue
			var lo=ceili(top)-1; var hi=ceili(top)-1; var edge=false
			if columns.has(col):
				for y in columns[col]:
					lo=mini(lo,y-1); hi=maxi(hi,y)
			for d in DIRS:
				var n=col+Vector2i(d.x,d.z)
				if rim and not terrain.inside(Vector2(n)*cell): edge=true; continue
				lo=mini(lo,floori(tops[n]))
				if columns.has(n):
					for y in columns[n]: lo=mini(lo,y)
			if edge: lo=mini(lo,ceili(top)-3)
			lo=maxi(lo,bedrock)
			for y in range(lo,hi+1):
				var c=Vector3i(ix,y,iz)
				if not _solid(c,voxels,tops,bedrock): continue
				var h=_height(c,voxels,tops); var id: String=voxels[c] if voxels.has(c) else Geology.natural(c,top,river); var yt=y+h
				if h<1.0 or not _solid(c+Vector3i.UP,voxels,tops,bedrock):
					G.face(st,[Vector3(x0,yt,z0),Vector3(x1,yt,z0),Vector3(x1,yt,z1),Vector3(x0,yt,z1)],_top_color(id,p,river,not voxels.has(c) and y==ceili(top)-1,tile_grass,shade,ix,y,iz))
				if y>bedrock and not _solid(c+Vector3i.DOWN,voxels,tops,bedrock):
					G.face(st,[Vector3(x0,y,z1),Vector3(x1,y,z1),Vector3(x1,y,z0),Vector3(x0,y,z0)],_color(id).darkened(0.25))
				for d in DIRS:
					var n=c+d; var low=float(y)
					if (not rim or terrain.inside(Vector2(n.x,n.z)*cell)) and _solid(n,voxels,tops,bedrock):
						low=y+_height(n,voxels,tops)
						if low>=yt: continue
					var a=p+Vector2(d.x,d.z)*cell/2; var tangent=Vector2(-d.z,d.x)*cell/2
					G.face(st,[Vector3(a.x-tangent.x,low,a.y-tangent.y),Vector3(a.x+tangent.x,low,a.y+tangent.y),Vector3(a.x+tangent.x,yt,a.y+tangent.y),Vector3(a.x-tangent.x,yt,a.y-tangent.y)],_side_color(id,d,ix,y,iz))
	# Outside the original experiment: the continued river is natural scenery.
	var wet=G.surface(water_material) if water_material!=null else st; var rivers=0
	for iz in range(key.y*span,(key.y+1)*span):
		var z=float(iz)*cell; var x=terrain.river_x(z)
		if absf(z)<=29 or terrain.chunk_at(Vector2(x,z)).x!=key.x or not terrain.inside(Vector2(x,z),1.0): continue
		G.cube(wet,Vector3(x,0.20,z),Vector3(2.85,0.06,cell+0.02),Color("59aab8")); rivers+=1
	for item in decor: _decor(st,item[0],item[1],item[2],item[3])
	for tree in terrain.tree_records(key):
		var p=Vector2(tree.x,tree.z); var h=terrain.ground(p)
		var spec=terrain.nature.rules.species[tree.species] if terrain.nature!=null else {"height":3.1,"leaf":"629956","wood":"956f4c"}
		if tree.cut:
			G.cube(st,Vector3(p.x,h+0.12,p.y),Vector3(0.42,0.24,0.42),Color(spec.wood)); continue
		var scale=0.25+float(tree.growth)*0.75; var tall=float(spec.height)*scale
		var wood=Color(spec.wood); var leaf=Color(spec.leaf).lerp(Color("cf9457"),0.45 if season==2 else 0)
		if season==3: leaf=leaf.lerp(Color("e3ede4"),0.55)
		if env!=null:
			var tv: Vector4=env.blend(p)
			leaf=leaf.lerp(Color("a7955a"),smoothstep(0.34,0.18,tv.x)*0.6).lerp(Color("e3ede4"),smoothstep(4.0,-1.0,tv.y)*0.6)
		G.cube(st,Vector3(p.x,h+tall*0.42,p.y),Vector3(0.35*scale,tall*0.84,0.35*scale),wood)
		if tree.species=="pine":
			for tier in range(4):
				var wide=(2.2-tier*0.45)*scale
				G.cube(st,Vector3(p.x,h+tall*(0.45+tier*0.17),p.y),Vector3(wide,0.65*scale,wide),leaf.lightened(tier*0.03))
		elif tree.species=="birch":
			for i in range(4): G.cube(st,Vector3(p.x,h+0.5*scale+i*0.6*scale,p.y),Vector3(0.37*scale,0.09*scale,0.37*scale),Color("515e57"))
			G.cube(st,Vector3(p.x,h+tall*0.86,p.y),Vector3(1.2,1.9,1.2)*scale,leaf)
			G.cube(st,Vector3(p.x,h+tall*1.14,p.y),Vector3(0.8,0.6,0.8)*scale,leaf.lightened(0.14))
		else:
			G.cube(st,Vector3(p.x,h+tall*0.9,p.y),Vector3(2.25,1.35,2.1)*scale,leaf)
			G.cube(st,Vector3(p.x+0.15,h+tall*1.17,p.y),Vector3(1.45,0.65,1.4)*scale,leaf.lightened(0.1))
	if key==terrain.chunk_at(Vector2(-10,0)):
		G.cube(st,Vector3(-10,0.65,0),Vector3(6.6,0.14,2),Color("bd9464"))
		for i in range(14): G.cube(st,Vector3(-13.2+i*0.48,0.73,0),Vector3(0.04,0.015,2),Color("836745"))
	if tiles<=0: return null
	var mesh: ArrayMesh=st.commit()
	return wet.commit(mesh) if wet!=st and rivers>0 else mesh
