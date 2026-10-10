extends Node3D
## v0.34 星锻岛 diorama: a floating gunmetal deck of 3 m plots on anti-gravity thrusters, with the
## Blender-made factories (assets/models/starforge/*.glb) on their plots.
## v0.43: the deck takes any shape (plots sit at `industry.plot_center`), free cells beside it show
## as buyable holograms, island-Ⅰ decorations stand on empty plots, the staff are on the deck (at
## their factory, in the lounge or by their apartment), and `walk_mode` hands the camera to a
## first-person visitor (no orbit, no bobbing).
const MODELS="res://assets/models/starforge/"
const Town=preload("res://scripts/island_town.gd")
const TownDecor=preload("res://scripts/town_decor.gd")
const ROLE_COLORS={"engineer":Color("ffb547"),"doctor":Color("7fd8ff")}
var camera: Camera3D
var deck: Node3D
var decor_root: Node3D
var staff_root: Node3D
## Factory models (they sway a little); `spinners` are decoration parts that turn (town decor API).
var models: Array=[]
var spinners: Array=[]
var seen=""
var staff_seen=""
var yaw=0.6
var selected=-1
var marker: MeshInstance3D
var walk_mode=false
var industry
var figures: Dictionary={}   # staff id -> Node3D
var _scenes: Dictionary={}
var _materials: Dictionary={}
var _meshes: Dictionary={}
var _glass: StandardMaterial3D
## v0.35: the cargo airship docks at the trade hub and flies out while a contract is in transit.
var airship: Node3D
var flying=false
var dock=Vector3.INF

func _ready() -> void:
	var env=Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=Color("0d1d2b")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("9fb4c8"); env.ambient_light_energy=0.9
	var world_env=WorldEnvironment.new(); world_env.environment=env; add_child(world_env)
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-52,-35,0); sun.light_energy=1.2; sun.light_color=Color("fff1d8"); add_child(sun)
	var rim=DirectionalLight3D.new(); rim.rotation_degrees=Vector3(-20,150,0); rim.light_energy=0.35; rim.light_color=Color("7fd8ff"); add_child(rim)
	camera=Camera3D.new(); camera.fov=40; add_child(camera); camera.current=true
	deck=Node3D.new(); add_child(deck)
	decor_root=Node3D.new(); deck.add_child(decor_root)
	staff_root=Node3D.new(); deck.add_child(staff_root)
	marker=MeshInstance3D.new(); var ring=TorusMesh.new(); ring.inner_radius=1.35; ring.outer_radius=1.5; ring.rings=32; ring.ring_segments=4; marker.mesh=ring
	var m=StandardMaterial3D.new(); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color=Color("35e0ff"); marker.material_override=m
	add_child(marker); marker.hide()
	airship=_scene("airship").instantiate(); airship.scale=Vector3.ONE*0.55; add_child(airship); airship.hide()

func _scene(name: String) -> PackedScene:
	if not _scenes.has(name): _scenes[name]=load(MODELS+name+".glb")
	return _scenes[name]

## The old fixed grid position of plot i (kept for callers that only know an index).
static func plot_center(i: int) -> Vector3:
	return Vector3((i%4-1.5)*3.0,0,(i/4-1.5)*3.0)

# --- Mesh helpers (the island-Ⅰ decoration builders call box/ball/glass and fill `spinners`) -----
func material(color: Color) -> StandardMaterial3D:
	var key=color.to_html()
	if not _materials.has(key):
		var m=StandardMaterial3D.new(); m.albedo_color=color; m.roughness=0.85; _materials[key]=m
	return _materials[key]

func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node=MeshInstance3D.new(); node.mesh=shape; node.position=at; node.material_override=material(color)
	parent.add_child(node)
	return node

func box(parent: Node3D, dimensions: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var key="box"+str(dimensions)
	if not _meshes.has(key):
		var shape=BoxMesh.new(); shape.size=dimensions; _meshes[key]=shape
	return mesh(parent,_meshes[key],at,color)

func ball(parent: Node3D, radius: float, at: Vector3, color: Color) -> MeshInstance3D:
	var key="ball"+str(radius)
	if not _meshes.has(key):
		var shape=SphereMesh.new(); shape.radius=radius; shape.height=radius*2; shape.radial_segments=12; shape.rings=6; _meshes[key]=shape
	return mesh(parent,_meshes[key],at,color)

func glass() -> StandardMaterial3D:
	if _glass==null:
		_glass=StandardMaterial3D.new(); _glass.albedo_color=Color(0.75,0.92,0.96,0.28); _glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; _glass.roughness=0.1
	return _glass

## Rebuilds only when the deck, the buildings or the decorations change.
func sync(ind) -> void:
	industry=ind
	flying=not ind.airship.is_empty(); dock=Vector3.INF
	for k in ind.buildings:
		if ind.buildings[k].kind=="trade_hub": dock=ind.plot_center(int(k))+Vector3(1.2,2.9,0)
	airship.visible=dock!=Vector3.INF
	ind._sync_deck()
	var key=JSON.stringify([ind.unlocked,ind.plots,ind.deck,ind.buildings.keys(),ind.buildings.values().map(func(b): return [b.kind,b.level]),ind.deck_items])
	if key!=seen:
		seen=key; _rebuild(ind)
	_sync_staff(ind)

func _rebuild(ind) -> void:
	models=[]; spinners=[]
	for c in deck.get_children():
		if c!=decor_root and c!=staff_root: c.queue_free()
	for c in decor_root.get_children(): c.queue_free()
	var lo=Vector2(INF,INF); var hi=Vector2(-INF,-INF)
	for i in range(ind.plots):
		var at: Vector3=ind.plot_center(i)
		var tile: Node3D=_scene("deck_tile").instantiate(); tile.position=at; deck.add_child(tile)
		lo=Vector2(minf(lo.x,at.x),minf(lo.y,at.z)); hi=Vector2(maxf(hi.x,at.x),maxf(hi.y,at.z))
	# Cells that can be built out next: a faint hologram of the deck to come.
	var ghosts: Array=[]
	if ind.plots>0 and ind.plots<int(ind.rules().plots.max):
		for c in ind.frontier(): ghosts.append(ind.cell_center(c))
	elif ind.plots==0:
		for i in range(int(ind.rules().plots.start)): ghosts.append(plot_center(i))
	for at in ghosts:
		var ghost=MeshInstance3D.new(); var b=BoxMesh.new(); b.size=Vector3(2.9,0.08,2.9); ghost.mesh=b
		var gm=StandardMaterial3D.new(); gm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; gm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.albedo_color=Color(0.2,0.85,1.0,0.16 if ind.unlocked else 0.07); ghost.material_override=gm; ghost.position=at+Vector3(0,-0.1,0); deck.add_child(ghost)
		if ind.plots==0: lo=Vector2(minf(lo.x,at.x),minf(lo.y,at.z)); hi=Vector2(maxf(hi.x,at.x),maxf(hi.y,at.z))
	for key2 in ind.buildings:
		var bld: Dictionary=ind.buildings[key2]; var spec: Dictionary=ind.rules().buildings[bld.kind]
		var model: Node3D=_scene(str(spec.model)).instantiate(); model.position=ind.plot_center(int(key2))
		model.scale=Vector3.ONE*(1.0+0.08*(int(bld.level)-1)); deck.add_child(model)
		models.append(model)
	if lo.x==INF: lo=Vector2(-4.5,-4.5); hi=Vector2(4.5,4.5)
	# The hull follows the deck: a slab under every plot, a keel cone under the middle, and the
	# thrusters hung under the outermost plots (west, east, north, south).
	var hull=StandardMaterial3D.new(); hull.albedo_color=Color("1f2630"); hull.metallic=0.5; hull.roughness=0.6
	var slab=BoxMesh.new(); slab.size=Vector3(3.0,1.1,3.0)
	var sum=Vector3.ZERO; var ends={}
	for i in range(ind.plots):
		var at: Vector3=ind.plot_center(i); sum+=at
		var s2=MeshInstance3D.new(); s2.mesh=slab; s2.material_override=hull; s2.position=at+Vector3(0,-0.86,0); deck.add_child(s2)
		for side in [["w",-at.x],["e",at.x],["n",-at.z],["s",at.z]]:
			if not ends.has(side[0]) or side[1]>ends[side[0]][0]: ends[side[0]]=[side[1],at]
	if ind.plots==0:
		for at in ghosts: sum+=at
	var mid=sum/maxf(1.0,float(ind.plots if ind.plots>0 else ghosts.size()))
	var span=maxf(hi.x-lo.x,hi.y-lo.y)*0.5+1.5
	var keel=MeshInstance3D.new(); var cone=CylinderMesh.new(); cone.top_radius=minf(span*0.75,6.0); cone.bottom_radius=0.6; cone.height=3.6; cone.radial_segments=6
	keel.mesh=cone; keel.material_override=hull; keel.position=Vector3(mid.x,-3.2,mid.z); keel.rotation.y=PI/6; deck.add_child(keel)
	var hung={}
	for k in ends:
		var at: Vector3=ends[k][1]
		if hung.has(at): continue
		hung[at]=true
		var t: Node3D=_scene("thruster").instantiate(); t.position=at+Vector3(0,-1.6,0); deck.add_child(t)
	_decorations(ind)

func _decorations(ind) -> void:
	var grid=int(Town.rules().grid); var joins={}
	for row in ind.decorations():
		var group=str(Town.info(str(row.item.kind)).get("join",""))
		if group.is_empty(): continue
		var c=ind.cell(int(row.plot)); var r=Town.item_rect(row.item)
		for x in range(r.position.x,r.end.x):
			for z in range(r.position.y,r.end.y): joins[Vector2i(c.x*grid+x,c.y*grid+z)]=group
	for row in ind.decorations():
		var item: Dictionary=row.item; var kind=str(item.kind); var rot=int(item.get("rot",0))
		var holder=Node3D.new(); decor_root.add_child(holder)
		holder.position=ind.plot_center(int(row.plot))+Town.center(Vector2i(int(item.x),int(item.z)),Town.size(kind,rot))+Vector3(0,0.06,0)
		holder.rotation.y=-rot*PI/2; holder.set_meta("uid",int(item.uid)); holder.set_meta("plot",int(row.plot))
		var links: Array=[]; var group=str(Town.info(kind).get("join",""))
		if not group.is_empty():
			var c=ind.cell(int(row.plot)); var here=Vector2i(c.x*grid+int(item.x),c.y*grid+int(item.z))
			for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				if str(joins.get(here+side,""))==group: links.append(_local_side(side,rot))
		TownDecor.build(self,holder,kind,links,true)

## A neighbour side in the item's own (rotated) axes, as island Ⅰ's town does.
static func _local_side(side: Vector2i, rot: int) -> Vector2i:
	match posmod(rot,4):
		1: return Vector2i(side.y,-side.x)
		2: return -side
		3: return Vector2i(-side.y,side.x)
	return side

# --- Staff on the deck ---------------------------------------------------------------------------
## Where a staff member stands now: by their factory while working, in the lounge or by their
## apartment while resting, a slot each so they never stack.
func staff_spot(ind,s: Dictionary) -> Vector3:
	var status: String=ind.status_of(s); var slot=int(s.id)%4
	var offsets=[Vector3(-1.15,0,1.2),Vector3(1.15,0,1.2),Vector3(-1.15,0,-1.2),Vector3(1.15,0,-1.2)]
	if status in ["工作中","待命"] and ind.buildings.has(str(int(s.factory))): return ind.plot_center(int(s.factory))+offsets[slot]
	if status=="休息室":
		for k in ind.buildings:
			if ind.buildings[k].kind=="staff_lounge": return ind.plot_center(int(k))+offsets[slot]*0.6
	if ind.buildings.has(str(int(s.home))): return ind.plot_center(int(s.home))+offsets[slot]
	return Vector3.ZERO

func _sync_staff(ind) -> void:
	var key=JSON.stringify(ind.staff.map(func(s): return [s.id,s.role,ind.status_of(s),s.factory,s.home]))+str(ind.deck)
	if key==staff_seen: return
	staff_seen=key
	var alive={}
	for s in ind.staff:
		var id=int(s.id); alive[id]=true
		if not figures.has(id): figures[id]=_figure(Color(ROLE_COLORS.get(str(s.role),Color("dddddd"))))
		var f: Node3D=figures[id]; f.set_meta("target",staff_spot(ind,s)); f.set_meta("status",ind.status_of(s))
		if not f.has_meta("placed"): f.position=f.get_meta("target"); f.set_meta("placed",true)
	for id in figures.keys():
		if not alive.has(id): figures[id].queue_free(); figures.erase(id)

## A chibi worker in a coloured jumpsuit, to scale with the factories (about 0.7 m).
func _figure(suit: Color) -> Node3D:
	var f=Node3D.new(); staff_root.add_child(f)
	box(f,Vector3(0.24,0.3,0.16),Vector3(0,0.36,0),suit)
	box(f,Vector3(0.08,0.2,0.1),Vector3(-0.06,0.1,0),Color("2c3440")); box(f,Vector3(0.08,0.2,0.1),Vector3(0.06,0.1,0),Color("2c3440"))
	ball(f,0.13,Vector3(0,0.62,0),Color("f2c9a0"))
	box(f,Vector3(0.22,0.06,0.22),Vector3(0,0.72,0),suit.darkened(0.3))
	return f

func _process(dt: float) -> void:
	if camera==null: return
	var t=Time.get_ticks_msec()/1000.0
	if not walk_mode:
		yaw+=dt*0.08
		var target=Vector3(0,0.6,0); var distance=22.0
		if industry!=null and industry.plots>16: distance=22.0+float(industry.plots-16)*0.45
		camera.position=target+Vector3(sin(yaw)*distance,distance*0.62,cos(yaw)*distance)
		camera.look_at(target)
		deck.position.y=sin(Time.get_ticks_msec()/1600.0)*0.18
	else:
		deck.position.y=0.0
	for i in range(models.size()):
		var n: Node3D=models[i]
		if is_instance_valid(n): n.rotation.y=sin(t*0.3+i)*0.05
	for spinner in spinners:
		if is_instance_valid(spinner): spinner.rotation+=Vector3(spinner.get_meta("spin",Vector3.ZERO))*dt
	for id in figures:
		var f: Node3D=figures[id]; var goal: Vector3=f.get_meta("target",f.position)
		var step=goal-f.position; step.y=0
		if step.length()>0.02:
			f.position+=step.limit_length(dt*0.9); f.rotation.y=lerp_angle(f.rotation.y,atan2(-step.x,-step.z),minf(1.0,dt*8.0))
			f.position.y=absf(sin(t*9.0+int(id)))*0.04
		else:
			f.position.y=absf(sin(t*4.0+int(id)))*0.03 if f.get_meta("status","")=="工作中" else 0.0
	if airship.visible:
		if flying:
			# A wide loop out beyond the island and back, nose along the path.
			var a=t*0.45; var at=Vector3(cos(a)*6.5,5.5+sin(t*0.9)*0.4,sin(a)*5.0)
			airship.look_at_from_position(at,at+Vector3(-sin(a)*6.5,0,cos(a)*5.0)); airship.rotate_object_local(Vector3.UP,PI/2)
		else:
			airship.position=dock+Vector3(0,deck.position.y+sin(t*1.3)*0.06,0); airship.rotation=Vector3(0,PI/2,0)
	marker.visible=selected>=0 and industry!=null and selected<industry.plots
	if marker.visible: marker.position=industry.plot_center(selected)+Vector3(0,0.3+deck.position.y,0); marker.rotation.y=t
