extends Node3D
## Bounded, incremental render cache. Ground/collision queries do not wait for meshes.
const G=preload("res://scripts/river_geometry.gd")
var terrain
var material: Material
var chunks={}
var pending=[]
var center_key=Vector2i(99999,99999)
var season=-1
var nature_revision=-1
var last_build_us=0

func schedule(at: Vector2,new_season: int) -> void:
	var center=terrain.chunk_at(at)
	var rev=terrain.nature.revision if terrain.nature!=null else 0
	if center==center_key and new_season==season and nature_revision==rev: return
	nature_revision=rev
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
		if not chunks.has(key) or chunks[key].get_meta("season",-1)!=season or chunks[key].get_meta("nature",-1)!=revision: pending.append(key)
	pending.sort_custom(func(a,b): return Vector2(a-center).length_squared()<Vector2(b-center).length_squared())

func drain(limit: int) -> void:
	for i in range(mini(limit,pending.size())):
		var key=pending.pop_front(); var start=Time.get_ticks_usec(); var mesh=_build(key)
		if not chunks.has(key):
			var n=MeshInstance3D.new(); add_child(n); chunks[key]=n
		chunks[key].mesh=mesh; chunks[key].set_meta("nature",int(terrain.nature.chunk_versions.get(key,0)) if terrain.nature!=null else 0); chunks[key].set_meta("season",season); last_build_us=Time.get_ticks_usec()-start

func _process(_dt: float) -> void:
	if terrain!=null: drain(int(terrain.rules.chunks_per_frame))

func _build(key: Vector2i) -> Mesh:
	var st=G.surface(material); var span=int(terrain.rules.chunk_cells); var cell=float(terrain.rules.cell_size); var tiles=0
	for iz in range(key.y*span,(key.y+1)*span):
		for ix in range(key.x*span,(key.x+1)*span):
			var p=Vector2(ix,iz)*cell
			if not terrain.inside(p): continue
			tiles+=1
			var h=terrain.height_at(p)
			var c=Color(["749b64","6f9a60","b4a262","bdcfbd"][season])
			if h<0.1: c=Color("708f89")
			elif p.x>0 and p.y<0: c=c.lerp(Color("9ba49a"),0.35)
			if terrain.on_path(p) and h>0.1: c=Color("bdad83")
			c=c.lightened((sin(p.x*13+p.y*17)+1)*0.035)
			G.face(st,[Vector3(p.x-cell/2,h+0.055,p.y-cell/2),Vector3(p.x+cell/2,h+0.055,p.y-cell/2),Vector3(p.x+cell/2,h+0.055,p.y+cell/2),Vector3(p.x-cell/2,h+0.055,p.y+cell/2)],c)
			for d in [Vector2(1,0),Vector2(-1,0),Vector2(0,1),Vector2(0,-1)]:
				var q=p+d*cell; var low=terrain.height_at(q)+0.055 if terrain.inside(q) else -1.5
				if low>=h+0.055: continue
				var a=p+d*cell/2; var tangent=Vector2(-d.y,d.x)*cell/2
				G.face(st,[Vector3(a.x-tangent.x,low,a.y-tangent.y),Vector3(a.x+tangent.x,low,a.y+tangent.y),Vector3(a.x+tangent.x,h+0.055,a.y+tangent.y),Vector3(a.x-tangent.x,h+0.055,a.y-tangent.y)],Color("958369"))
	# Outside the original experiment: the continued river is natural scenery.
	for iz in range(key.y*span,(key.y+1)*span):
		var z=float(iz)*cell; var x=terrain.river_x(z)
		if absf(z)<=29 or terrain.chunk_at(Vector2(x,z)).x!=key.x or not terrain.inside(Vector2(x,z),1.0): continue
		G.cube(st,Vector3(x,0.20,z),Vector3(2.85,0.06,cell+0.02),Color("59aab8"))
	for tree in terrain.tree_records(key):
		var p=Vector2(tree.x,tree.z); var h=terrain.ground(p)
		var spec=terrain.nature.rules.species[tree.species] if terrain.nature!=null else {"height":3.1,"leaf":"629956","wood":"956f4c"}
		if tree.cut:
			G.cube(st,Vector3(p.x,h+0.12,p.y),Vector3(0.42,0.24,0.42),Color(spec.wood)); continue
		var scale=0.25+float(tree.growth)*0.75; var tall=float(spec.height)*scale
		var wood=Color(spec.wood); var leaf=Color(spec.leaf).lerp(Color("cf9457"),0.45 if season==2 else 0)
		if season==3: leaf=leaf.lerp(Color("e3ede4"),0.55)
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
	return st.commit() if tiles>0 else null
