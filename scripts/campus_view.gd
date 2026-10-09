extends Node3D
const Architecture=preload("res://scripts/campus_architecture.gd")
const StaticGeometry=preload("res://scripts/static_geometry.gd")
const IslandGuest=preload("res://scripts/island_guest.gd")
const Town=preload("res://scripts/island_town.gd")
const TownDecor=preload("res://scripts/town_decor.gd")
const Geology=preload("res://scripts/planet_geology.gd")
const RiverComponents=preload("res://scripts/river_component_geometry.gd")
const Figure=preload("res://scripts/figure_geometry.gd")
const ROLE_LOOKS={
	"engineer":{"coat":"e9963f","pants":"3e5c6c","hair":"4a3328"},
	"doctor":{"coat":"f1f4f2","pants":"4f7f86","hair":"2d2a30"},
	"professor":{"coat":"a49dc9","pants":"4a4e6a","hair":"d9d6d0"},
	"academician":{"coat":"c5ad83","pants":"6b5a45","hair":"9a9a9a"},
	"buyer":{"coat":"bf8eb6","pants":"4b4258","hair":"6b4a2e"}}
## Native building meshes are about 2.15 m wide; v0.27 scales them into their tile footprint.
const NATIVE_WIDTH=2.15
var spinners: Array=[]
## Level of every building/item at the last rebuild: new keys pop in, higher levels celebrate.
var _levels: Dictionary={}
var _glass: StandardMaterial3D
var effects_played=0
var guests: Dictionary={}
var output_markers: Dictionary={}
## Presentation only. Logical people keep updating when their meshes are hidden.
var state
var world
var scenery: Node3D
var actors: Dictionary={}
var geometry_key=""
var models: Dictionary={}
var materials: Dictionary={}
var time=0.0
var _actor_pool: Array=[]
var static_rebuilds=0
var avatar_rebuilds=0
## v0.33: merged figure meshes per role and part, shared by every resident of that role.
var figure_meshes: Dictionary={}
var _figure_material: StandardMaterial3D

func setup(model, island) -> void:
	state=model; world=island
	name="CampusLife"
	world.add_child(self)
	sync()

func material(color: Color) -> StandardMaterial3D:
	var key=color.to_html()
	if not materials.has(key):
		var m=StandardMaterial3D.new()
		m.albedo_color=color; m.roughness=0.85
		materials[key]=m
	return materials[key]

func box(parent: Node3D, dimensions: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var key="box"+str(dimensions)
	if not models.has(key):
		var shape=BoxMesh.new(); shape.size=dimensions; models[key]=shape
	return mesh(parent,models[key],at,color)

func ball(parent: Node3D, radius: float, at: Vector3, color: Color) -> MeshInstance3D:
	var key="ball"+str(radius)
	if not models.has(key):
		var shape=SphereMesh.new(); shape.radius=radius; shape.height=radius*2; shape.radial_segments=12; shape.rings=6; models[key]=shape
	return mesh(parent,models[key],at,color)

func mesh(parent: Node3D, shape: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node=MeshInstance3D.new(); node.mesh=shape; node.position=at; node.material_override=material(color)
	parent.add_child(node)
	return node

func _road_batch(transforms: Array) -> void:
	if transforms.is_empty(): return
	var surface=MultiMeshInstance3D.new()
	var batch=MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D
	if not models.has("road_unit"):
		var shape=BoxMesh.new(); shape.size=Vector3.ONE; models["road_unit"]=shape
	batch.mesh=models.road_unit
	batch.instance_count=transforms.size()
	for index in range(transforms.size()): batch.set_instance_transform(index,transforms[index])
	surface.multimesh=batch
	surface.material_override=material(Color("d6d2ad"))
	surface.name="ConnectedRoads"
	scenery.add_child(surface)

func sync() -> void:
	if state==null: return
	var key=str(state.layout.revision)+":"+str(world._detail_signature)
	if key!=geometry_key:
		geometry_key=key
		_rebuild_static()
	_sync_people()
	_sync_guests()
	_sync_output_markers()

func _rebuild_static() -> void:
	static_rebuilds+=1
	if is_instance_valid(scenery): scenery.queue_free()
	scenery=Node3D.new(); add_child(scenery)
	spinners.clear()
	var previous: Dictionary=_levels
	_levels=_town_levels()
	var joins: Dictionary=_join_map()
	# v0.31: no drawn edge roads; neighbouring plots are one lawn and players lay their own paths.
	# Connectivity is still plot adjacency (campus_layout.road_links).
	var road_transforms: Array=[]
	for i in range(state.plots.size()):
		var p: Dictionary=state.plots[i]
		if not p.unlocked: continue
		var base=Vector3(float(p.x)*3,0,float(p.z)*3)
		if not world._visible_plots.has(i): continue
		var detail=world._detailed_plots.has(i)
		var node=Node3D.new(); node.name="Plot_%d" % i; scenery.add_child(node); node.position=base
		if p.kind=="plaza": _plaza(node)
		elif not state.layout.building_info(p.kind).is_empty():
			var building=Node3D.new(); building.name="Building"; node.add_child(building)
			_place_building(building,str(p.kind),int(p.get("building_level",1)),Town.primary_anchor(p),detail)
			StaticGeometry.bake(building)
			_celebrate(building,"p%d" % i,previous)
		for item in p.get("items",[]): _item(node,p,item,joins,detail,previous)
		if detail:
			var find_kind=str(state.storage.finds.get(str(i),""))
			if not find_kind.is_empty() and find_kind!="collected":
				_prop(node,find_kind,4)
				var sparkle=Label3D.new(); sparkle.text="☆"; sparkle.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); sparkle.font_size=64; sparkle.pixel_size=0.007; sparkle.modulate=Color("ffe2a4"); sparkle.position=_prop_offset(4)+Vector3(0,1.0,0); sparkle.billboard=BaseMaterial3D.BILLBOARD_ENABLED; node.add_child(sparkle)
			for prop in p.get("props",[]): _prop(node,str(prop.kind),int(prop.slot))
			_connect_fences(node,p.get("props",[]))
		StaticGeometry.bake(node)
	_road_batch(road_transforms)

func _prop_offset(slot: int) -> Vector3:
	return [Vector3(-1.15,0,-1.15),Vector3(0,0,-1.15),Vector3(1.15,0,-1.15),Vector3(1.15,0,0),Vector3(1.15,0,1.05),Vector3(0,0,1.05),Vector3(-1.15,0,1.05),Vector3(-1.15,0,0)][clampi(slot,0,7)]

func _connect_fences(parent: Node3D, props: Array) -> void:
	var slots: Dictionary={}
	for prop in props:
		if prop.kind=="fence": slots[int(prop.slot)]=true
	for slot in slots:
		var next=(int(slot)+1)%8
		if not slots.has(next): continue
		var start=_prop_offset(int(slot)); var end=_prop_offset(next)
		for height in [0.26,0.43]:
			box(parent,Vector3(absf(end.x-start.x)+0.045,0.055,absf(end.z-start.z)+0.045),(start+end)*0.5+Vector3(0,height,0),Color("e8d4ad"))

func _plaza(parent: Node3D) -> void:
	box(parent,Vector3(2.8,0.05,2.8),Vector3(0,0.10,0),Color("d3ccaf"))
	# Continuous raised pedestrian rim. Expansion joins the rim, not the vehicle apron.
	box(parent,Vector3(0.30,0.03,2.85),Vector3(1.35,0.115,0),Color("d6d2ad"))
	box(parent,Vector3(2.85,0.03,0.30),Vector3(0,0.115,1.35),Color("d6d2ad"))
	for z in [-0.98,-0.53,-0.08,0.37]:
		box(parent,Vector3(0.035,0.32,0.035),Vector3(1.10,0.30,z),Color("76938b"))
	box(parent,Vector3(0.035,0.045,1.44),Vector3(1.10,0.47,-0.3),Color("e7d9b6"))
	box(parent,Vector3(2.3,0.04,0.56),Vector3(0,0.15,0.6),Color("a8b6ad"))
	box(parent,Vector3(1.8,0.08,0.6),Vector3(0,0.30,-0.75),Color("e8f2da"))
	box(parent,Vector3(1.8,0.06,0.7),Vector3(0,1.30,-0.75),Color("458c83"))
	for x in [-0.8,0.8]: box(parent,Vector3(0.07,1.08,0.07),Vector3(x,0.75,-0.75),Color("e8f2da"))
	ball(parent,0.17,Vector3(0,1.55,-0.75),Color("ffcf77"))
	var sign=Label3D.new(); sign.text="迎客广场"; sign.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); sign.font_size=40; sign.pixel_size=0.008
	sign.position=Vector3(0,1.58,0); sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED; parent.add_child(sign)
	box(parent,Vector3(0.07,0.65,0.07),Vector3(-1.10,0.43,0.65),Color("4c747c"))
	box(parent,Vector3(0.40,0.32,0.30),Vector3(-1.10,0.88,0.65),Color("dd9f70"))
	box(parent,Vector3(0.28,0.025,0.035),Vector3(-1.10,0.92,0.81),Color("385961"))

func _building(parent: Node3D, p: Dictionary, detail: bool) -> void:
	Architecture.build(self,parent,p,detail)

func glass() -> StandardMaterial3D:
	if _glass==null:
		_glass=StandardMaterial3D.new(); _glass.albedo_color=Color(0.75,0.92,0.96,0.28); _glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; _glass.roughness=0.1
	return _glass

## A building scaled into its footprint; the model keeps its silhouette and its tier look.
func _place_building(node: Node3D, kind: String, level: int, at: Vector2i, detail: bool) -> void:
	var footprint: Vector2i=Town.size(kind)
	node.position=Town.center(at,footprint)
	var s=footprint.x*Town.tile()/NATIVE_WIDTH
	node.scale=Vector3(s,s,s)
	node.set_meta("base_scale",s)
	var tier=Town.tier(level,int(state.layout.building_info(kind).get("max_level",1)))
	_building(node,{"kind":kind,"building_level":level,"tier":tier},detail)

func _town_levels() -> Dictionary:
	var levels={}
	for i in range(state.plots.size()):
		var p: Dictionary=state.plots[i]
		if not p.unlocked: continue
		if not state.layout.building_info(p.kind).is_empty(): levels["p%d" % i]=int(p.get("building_level",1))
		for item in p.get("items",[]): levels["u%d" % int(item.uid)]=int(item.get("level",1))
	return levels

## Global tile -> join group for fences, walls and hedges, so they link across plot edges too.
func _join_map() -> Dictionary:
	var map={}
	var grid=int(Town.rules().grid)
	for p in state.plots:
		if not p.unlocked: continue
		for item in p.get("items",[]):
			var group=str(Town.info(str(item.kind)).get("join",""))
			if not group.is_empty(): map[Vector2i(int(p.x)*grid+int(item.x),int(p.z)*grid+int(item.z))]=group
	return map

## A world-axis side seen from an item turned by rot quarter turns.
static func _local_side(side: Vector2i, rot: int) -> Vector2i:
	match posmod(rot,4):
		1: return Vector2i(side.y,-side.x)
		2: return -side
		3: return Vector2i(-side.y,side.x)
	return side

func _item(node: Node3D, p: Dictionary, item: Dictionary, joins: Dictionary, detail: bool, previous: Dictionary) -> void:
	var kind=str(item.kind)
	var key="u%d" % int(item.uid)
	var holder=Node3D.new(); holder.name="Item_%d" % int(item.uid); node.add_child(holder)
	if Town.is_building(kind):
		holder.set_meta("dynamic_geometry",true)
		_place_building(holder,kind,int(item.get("level",1)),Vector2i(int(item.x),int(item.z)),detail)
		StaticGeometry.bake(holder)
		_celebrate(holder,key,previous)
		return
	var rot=int(item.get("rot",0))
	holder.position=Town.center(Vector2i(int(item.x),int(item.z)),Town.size(kind,rot))
	holder.rotation.y=-rot*PI/2
	var links: Array=[]
	var group=str(Town.info(kind).get("join",""))
	if not group.is_empty():
		var grid=int(Town.rules().grid)
		var here=Vector2i(int(p.x)*grid+int(item.x),int(p.z)*grid+int(item.z))
		for side in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if str(joins.get(here+side,""))==group: links.append(_local_side(side,rot))
	TownDecor.build(self,holder,kind,links,detail)
	var show: Dictionary=item.get("show",{})
	if not show.is_empty(): _exhibit(holder,kind,show,detail)
	if not previous.is_empty() and not previous.has(key):
		holder.set_meta("dynamic_geometry",true)
		StaticGeometry.bake(holder)
		_pop(holder)

func _exhibit(holder: Node3D, kind: String, show: Dictionary, detail: bool) -> void:
	var top=TownDecor.display_top(kind)
	var stage: Node3D=holder.get_node_or_null("Spin")
	var lift=0.02
	if stage==null:
		stage=Node3D.new(); holder.add_child(stage); stage.position=Vector3(0,top,0); lift=0.0
	var caption=""
	if show.type=="mineral":
		var spec: Dictionary=Geology.info(str(show.id))
		var color=Color(str(spec.get("color","aaaaaa")))
		for i in range(3):
			var shard=box(stage,Vector3(0.07,0.12+i*0.04,0.07),Vector3((i-1)*0.06,lift+0.07+i*0.02,(i%2)*0.04-0.02),color.lightened(i*0.1))
			shard.rotation=Vector3(0.18*(i-1),0.6*i,0.22*(1-i))
		caption=str(spec.get("name",show.id))
		if str(spec.get("formula",""))!="": caption+="  "+str(spec.formula)
	else:
		var c=state.planet.home().construction
		var mini: Dictionary=c.miniatures.get(show.id,{})
		if not mini.is_empty():
			var mat=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.roughness=0.8
			var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_material(mat)
			var size=Vector3.ONE
			for b in mini.blocks: size=size.max(Vector3(b.x+1,b.y+1,b.z+1))
			for b in mini.blocks: RiverComponents.draw(st,Vector3(b.x,b.y+0.5,b.z)-Vector3((size.x-1)/2,0,(size.z-1)/2),b.kind,Color(c.rules.kinds[b.kind].color))
			var model=MeshInstance3D.new(); model.mesh=st.commit(); model.position.y=lift
			model.scale=Vector3.ONE*(0.34/maxf(size.x,maxf(size.z,size.y))); stage.add_child(model)
			caption=str(mini.get("name","河湾作品"))
	if detail and not caption.is_empty():
		var label=Label3D.new(); label.text=caption; label.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); label.font_size=34; label.pixel_size=0.0045
		label.modulate=Color("fff6dc"); label.outline_size=8; label.outline_modulate=Color("2a3b40"); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.position=Vector3(0,top+0.52,0); label.name="Caption"; holder.add_child(label)

func _pop(node: Node3D) -> void:
	effects_played+=1
	var s=float(node.get_meta("base_scale",1.0))
	node.scale=Vector3.ONE*s*0.2
	var tween=node.create_tween()
	tween.tween_property(node,"scale",Vector3.ONE*s*1.12,0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node,"scale",Vector3.ONE*s,0.12)
	_dust(node.get_parent(),node.position,0.35)

## New buildings pop in; upgraded ones squash, stretch and shed a scaffold, dust and a level star.
func _celebrate(node: Node3D, key: String, previous: Dictionary) -> void:
	if previous.is_empty(): return
	if not previous.has(key): _pop(node); return
	if int(_levels.get(key,1))<=int(previous[key]): return
	effects_played+=1
	var s=float(node.get_meta("base_scale",1.0))
	var tween=node.create_tween()
	tween.tween_property(node,"scale",Vector3(s*1.12,s*0.72,s*1.12),0.12)
	tween.tween_property(node,"scale",Vector3(s*0.94,s*1.18,s*0.94),0.14)
	tween.tween_property(node,"scale",Vector3.ONE*s,0.18).set_trans(Tween.TRANS_BACK)
	var parent: Node3D=node.get_parent()
	var frame=Node3D.new(); frame.position=node.position; frame.set_meta("dynamic_geometry",true); parent.add_child(frame)
	var half=s*NATIVE_WIDTH*0.52
	var height=s*2.4
	for x in [-half,half]:
		for z in [-half,half]: box(frame,Vector3(0.035,height,0.035),Vector3(x,height*0.5+0.1,z),Color("d9b173"))
	for h in [0.4,0.8]: box(frame,Vector3(half*2,0.03,0.05),Vector3(0,height*h+0.1,half),Color("c79a6b"))
	var fade=frame.create_tween(); fade.tween_interval(0.7); fade.tween_property(frame,"scale",Vector3(1,0.01,1),0.35); fade.tween_callback(frame.queue_free)
	_dust(parent,node.position,half*1.6)
	var star=Label3D.new(); star.text="★ Lv%d" % int(_levels[key]); star.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); star.font_size=56; star.pixel_size=0.006
	star.modulate=Color("ffd98a"); star.outline_size=10; star.outline_modulate=Color("5b3d1c"); star.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	star.position=node.position+Vector3(0,height+0.4,0); star.set_meta("dynamic_geometry",true); parent.add_child(star)
	var rise=star.create_tween(); rise.tween_property(star,"position:y",star.position.y+0.7,1.1); rise.parallel().tween_property(star,"modulate:a",0.0,1.1).set_delay(0.4); rise.tween_callback(star.queue_free)

func _dust(parent: Node3D, at: Vector3, radius: float) -> void:
	var puff=StandardMaterial3D.new(); puff.albedo_color=Color(0.95,0.91,0.82,0.8); puff.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; puff.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	var shape=SphereMesh.new(); shape.radius=0.06; shape.height=0.12; shape.radial_segments=8; shape.rings=4
	for i in range(8):
		var angle=i*TAU/8.0
		var cloud=MeshInstance3D.new(); cloud.mesh=shape; cloud.material_override=puff; cloud.position=at+Vector3(0,0.15,0); cloud.set_meta("dynamic_geometry",true); parent.add_child(cloud)
		var tween=cloud.create_tween()
		tween.tween_property(cloud,"position",at+Vector3(cos(angle)*radius,0.25+0.1*(i%3),sin(angle)*radius),0.5).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(cloud,"scale",Vector3.ONE*2.2,0.5)
		tween.tween_callback(cloud.queue_free)


func _prop(parent: Node3D, kind: String, slot: int) -> void:
	var node=Node3D.new(); parent.add_child(node); node.position=_prop_offset(slot)
	match kind:
		"crystal_fox":
			ball(node,0.19,Vector3(0,0.29,0),Color("a7d6df"))
			ball(node,0.15,Vector3(0,0.49,0.08),Color("b5e9eb"))
			for x in [-0.1,0.1]:
				var ear=PrismMesh.new(); ear.size=Vector3(0.13,0.21,0.12); mesh(node,ear,Vector3(x,0.63,0.06),Color("87c6db"))
				ball(node,0.02,Vector3(x*0.55,0.51,0.215),Color("304f68"))
			ball(node,0.035,Vector3(0,0.455,0.23),Color("ececcf"))
			var tail=ball(node,0.14,Vector3(0.22,0.24,-0.08),Color("d4edeb")); tail.scale=Vector3(1.5,0.8,0.8)
		"orbit_mobile":
			box(node,Vector3(0.04,0.64,0.04),Vector3(0,0.44,0),Color("e4c99f"))
			var ring=TorusMesh.new(); ring.inner_radius=0.17; ring.outer_radius=0.2; ring.rings=16; ring.ring_segments=8
			var orbit=mesh(node,ring,Vector3(0,0.64,0),Color("e4c99f")); orbit.rotation.z=0.6
			ball(node,0.075,Vector3(0,0.64,0),Color("b7adea")); ball(node,0.05,Vector3(0.20,0.64,0),Color("8de2cc"))
		"moon_lamp":
			box(node,Vector3(0.26,0.12,0.26),Vector3(0,0.20,0),Color("93c4c5"))
			ball(node,0.20,Vector3(0,0.47,0),Color("ffe3a1"))
			for x in [-0.06,0.06]: ball(node,0.015,Vector3(x,0.48,0.188),Color("9a815c"))
		"flower":
			box(node,Vector3(0.20,0.18,0.20),Vector3(0,0.20,0),Color("d79478"))
			ball(node,0.13,Vector3(0,0.39,0),Color("ceaff2"))
		"bench": box(node,Vector3(0.44,0.12,0.22),Vector3(0,0.30,0),Color("c49872"))
		"lamp":
			box(node,Vector3(0.035,0.65,0.035),Vector3(0,0.43,0),Color("386270"))
			ball(node,0.10,Vector3(0,0.8,0),Color("ffe0a7"))
		"fence":
			var dimensions=Vector3(0.63,0.30,0.04) if slot in [0,1,2,4,5,6] else Vector3(0.04,0.30,0.63)
			box(node,dimensions,Vector3(0,0.35,0),Color("e8d4ad"))
			box(node,Vector3(0.07,0.46,0.07),Vector3(0,0.33,0),Color("f4e5c7"))
		"trophy":
			box(node,Vector3(0.28,0.16,0.28),Vector3(0,0.18,0),Color("446c6b"))
			ball(node,0.13,Vector3(0,0.39,0),Color("f5ce78"))

func _figure(role: String,part: String) -> ArrayMesh:
	var key=role+":"+part
	if figure_meshes.has(key): return figure_meshes[key]
	if _figure_material==null:
		_figure_material=StandardMaterial3D.new(); _figure_material.vertex_color_use_as_albedo=true; _figure_material.roughness=0.8
	var look: Dictionary=ROLE_LOOKS.get(role,{"coat":"a8c7bf","pants":"3e5c6c","hair":"4a3328"})
	var coat=Color(look.coat); var pants=Color(look.pants); var hair=Color(look.hair)
	var skin=Color("f5dfbb"); var ink=Color("2b3a42")
	var st=Figure.G.surface(_figure_material)
	match part:
		"body":
			Figure.box(st,Vector3(0,0.2,0),Vector3(0.19,0.07,0.14),pants)
			Figure.box(st,Vector3(0,0.3,0),Vector3(0.2,0.17,0.15),coat)
			Figure.box(st,Vector3(0,0.385,0),Vector3(0.23,0.05,0.155),coat.lightened(0.08))
			Figure.box(st,Vector3(0,0.425,0),Vector3(0.07,0.04,0.07),skin.darkened(0.08))
			Figure.ball(st,Vector3(0,0.53,0),0.12,skin)
			# hair cap set back from the face, with a fringe
			Figure.ball(st,Vector3(0,0.565,-0.022),0.124,hair,Vector3(1.0,0.82,1.0))
			Figure.box(st,Vector3(0,0.615,0.07),Vector3(0.17,0.035,0.05),hair)
			for side in [-1,1]:
				Figure.ball(st,Vector3(side*0.042,0.535,0.106),0.017,ink)
				Figure.ball(st,Vector3(side*0.037,0.542,0.12),0.006,Color("ffffff"))
				Figure.ball(st,Vector3(side*0.072,0.505,0.092),0.016,Color("f2a99c"))
			Figure.box(st,Vector3(0,0.492,0.116),Vector3(0.032,0.009,0.01),Color("a25d52"))
			match role:
				"engineer":
					for y in [0.27,0.33]: Figure.box(st,Vector3(0,y,0),Vector3(0.205,0.018,0.156),Color("f6f1c8"))
					Figure.ball(st,Vector3(0,0.6,0),0.13,Color("f5cb6d"),Vector3(1.0,0.62,1.0))
					Figure.box(st,Vector3(0,0.595,0.02),Vector3(0.29,0.02,0.27),Color("e8b955"))
					Figure.box(st,Vector3(0,0.66,0),Vector3(0.03,0.03,0.2),Color("e8b955"))
				"doctor":
					Figure.box(st,Vector3(0,0.17,0),Vector3(0.21,0.1,0.156),coat)
					Figure.box(st,Vector3(0,0.33,0.077),Vector3(0.06,0.11,0.004),Color("69b6b1"))
					Figure.box(st,Vector3(0.055,0.35,0.078),Vector3(0.03,0.03,0.004),Color("e05a5a"))
					Figure.box(st,Vector3(0,0.4,0.07),Vector3(0.1,0.012,0.02),Color("4c6670"))
				"professor":
					for side in [-1,1]: Figure.box(st,Vector3(side*0.044,0.537,0.118),Vector3(0.052,0.038,0.008),Color("395a65"))
					Figure.box(st,Vector3(0,0.545,0.118),Vector3(0.03,0.008,0.008),Color("395a65"))
					Figure.box(st,Vector3(0,0.33,0.077),Vector3(0.05,0.12,0.004),Color("f2efe6"))
				"academician":
					Figure.box(st,Vector3(0,0.15,0),Vector3(0.22,0.14,0.16),coat.darkened(0.06))
					Figure.ball(st,Vector3(0,0.33,0.082),0.026,Color("f5ce78"))
					Figure.box(st,Vector3(0,0.37,0.078),Vector3(0.012,0.06,0.004),Color("b8463e"))
				"buyer":
					Figure.box(st,Vector3(0,0.655,0),Vector3(0.29,0.03,0.24),Color("e2c894"))
					Figure.box(st,Vector3(0,0.7,0),Vector3(0.19,0.09,0.16),Color("e2c894"))
					Figure.box(st,Vector3(0,0.67,0),Vector3(0.195,0.02,0.165),Color("8f5a3a"))
					Figure.box(st,Vector3(-0.12,0.25,0.02),Vector3(0.05,0.1,0.1),Color("8f5a3a"))
		"arm":
			Figure.box(st,Vector3(0,-0.075,0),Vector3(0.055,0.15,0.06),coat)
			Figure.box(st,Vector3(0,-0.15,0),Vector3(0.058,0.02,0.064),coat.darkened(0.15))
			Figure.ball(st,Vector3(0,-0.18,0),0.03,skin)
		"leg":
			Figure.box(st,Vector3(0,-0.07,0),Vector3(0.068,0.14,0.08),pants)
			Figure.box(st,Vector3(0,-0.155,0.015),Vector3(0.074,0.04,0.11),Color("2c3236"))
	figure_meshes[key]=st.commit()
	return figure_meshes[key]

func _part(parent: Node3D,role: String,part: String,at: Vector3) -> MeshInstance3D:
	var node=MeshInstance3D.new(); node.mesh=_figure(role,part); node.position=at; parent.add_child(node)
	return node

func _avatar(role: String, resident: bool=true) -> Dictionary:
	if resident: avatar_rebuilds+=1
	var node=Node3D.new(); add_child(node)
	var body=Node3D.new(); node.add_child(body)
	_part(body,role,"body",Vector3.ZERO)
	var arms=[]
	for side in [-1,1]: arms.append(_part(body,role,"arm",Vector3(side*0.13,0.39,0)))
	var legs=[]
	for side in [-1,1]: legs.append(_part(node,role,"leg",Vector3(side*0.052,0.2,0)))
	var tool=box(body,Vector3(0.11,0.09,0.1),Vector3(0.15,0.2,0.07),Color("edc997"))
	box(tool,Vector3(0.07,0.02,0.02),Vector3(0,0.055,0),Color("6f5a46"))
	return {"node":node,"body":body,"legs":legs,"arms":arms,"tool":tool,"plot":-1,"target":-1,"path":[],"step":0,"role":role,"activity":"idle","revision":-1,"model_travel":false,"travel_progress":0.0,"travel_duration":0.0,"travel_elapsed":0.0,"arrived":false}

func _take_actor(role: String) -> Dictionary:
	for index in range(_actor_pool.size()):
		if _actor_pool[index].role==role:
			var actor: Dictionary=_actor_pool[index]; _actor_pool.remove_at(index)
			actor.target=-1; actor.revision=-1; actor.path=[]; actor.step=0
			actor.movement_signature=""; actor.travel_elapsed=0.0
			return actor
	return _avatar(role)

func _person_plot(person: Dictionary) -> int:
	var plot=int(person.get("current_plot",person.get("location_plot",person.get("target_plot",state.layout.plaza_index))))
	return int(state.layout.plaza_index) if plot<0 or plot>=state.plots.size() else plot

func _sync_people() -> void:
	var limit=clampi(int(state.layout.config.performance.visible_people),0,24)
	var chosen=[]
	# Cull meshes only: the separate simulation retains every resident and task.
	var candidates=state.campus.people.duplicate()
	candidates.sort_custom(func(a,b):
		var distance_a=state.layout.hub(state.plots,_person_plot(a)).distance_squared_to(world._camera_target)
		var distance_b=state.layout.hub(state.plots,_person_plot(b)).distance_squared_to(world._camera_target)
		return int(a.id)<int(b.id) if is_equal_approx(distance_a,distance_b) else distance_a<distance_b)
	for person in candidates:
		var plot=_person_plot(person)
		var target=int(person.target_plot) if int(person.target_plot)>=0 else int(state.layout.plaza_index)
		if (not world._visible_plots.has(plot) and not world._visible_plots.has(target)) or chosen.size()>=limit: continue
		chosen.append(int(person.id))
	# Retire before allocating, so camera movement can reuse role geometry.
	for id in actors.keys():
		if id not in chosen:
			actors[id].node.visible=false
			_actor_pool.append(actors[id]); actors.erase(id)
	for person in candidates:
		var id=int(person.id)
		if id not in chosen: continue
		var target=int(person.target_plot) if int(person.target_plot)>=0 else int(state.layout.plaza_index)
		if not actors.has(id):
			actors[id]=_take_actor(str(person.role))
			actors[id].plot=_person_plot(person)
			actors[id].node.position=state.layout.hub(state.plots,int(actors[id].plot))
		var actor: Dictionary=actors[id]
		actor.activity=person.activity
		actor.tool.visible=person.activity in ["construct","maintain","factory","deliver_meal","collect","install","snack"]
		_sync_actor_route(actor,person,target)
	while _actor_pool.size()>limit:
		var retired: Dictionary=_actor_pool.pop_back(); retired.node.queue_free()

func _sync_actor_route(actor: Dictionary, person: Dictionary, target: int) -> void:
	# When simulation supplies travel, its arrival determines when work is visible.
	# No rendering callback writes work or progress back into the model.
	actor.model_travel=person.has("current_plot") and person.has("movement_progress")
	if actor.model_travel:
		var source=_person_plot(person)
		var next=int(person.get("next_plot",source))
		var fraction=float(person.movement_progress)
		var signature="%d:%d:%f" % [source,next,fraction]
		if actor.get("movement_signature","")!=signature:
			actor.movement_signature=signature
			actor.travel_progress=fraction
			actor.travel_elapsed=0.0
		actor.path=[state.layout.hub(state.plots,source),state.layout.hub(state.plots,next)]
		actor.travel_duration=maxf(0.5,float(state.campus.config.get("travel_seconds_per_edge",2.5)))
		actor.model_moving=bool(person.get("moving",false))
		actor.target=target; actor.plot=source; actor.revision=state.layout.revision
		actor.arrived=bool(person.get("arrived",false))
		return
	if actor.target!=target or actor.revision!=state.layout.revision:
		actor.target=target; actor.revision=state.layout.revision
		actor.path=state.layout.route(state.plots,int(actor.plot),target)
		actor.step=0
		actor.arrived=int(actor.plot)==target

func _path_point(path: Array, progress: float) -> Vector3:
	if path.is_empty(): return Vector3.ZERO
	if path.size()==1: return path[0]
	var segment=clampf(progress,0,1)*(path.size()-1)
	var index=mini(int(segment),path.size()-2)
	return path[index].lerp(path[index+1],segment-index)

func _animate_actor(actor: Dictionary, moving: bool, phase: float) -> void:
	actor.body.position.y=absf(sin(phase))*0.018 if moving else 0.0
	for index in range(2): actor.legs[index].rotation.x=sin(phase+index*PI)*0.45 if moving else 0.0
	var working=not moving and actor.activity in ["construct","maintain","factory","collect","install"] and actor.arrived
	actor.tool.rotation.x=sin(time*5)*0.7 if working else 0.0
	var arms: Array=actor.get("arms",[])
	for index in range(arms.size()):
		var swing=sin(phase+(1-index)*PI)*0.4 if moving else sin(time*1.6+index)*0.04
		if working and index==1: swing=-0.6+sin(time*5)*0.5
		arms[index].rotation.x=swing

func _process(delta: float) -> void:
	if state==null: return
	time+=delta
	for spinner in spinners:
		if is_instance_valid(spinner): spinner.rotation+=Vector3(spinner.get_meta("spin",Vector3.ZERO))*delta
	for id in actors:
		var actor: Dictionary=actors[id]
		var node: Node3D=actor.node
		var moving=false
		if actor.model_travel:
			actor.travel_elapsed+=delta
			var progress=float(actor.travel_progress)
			if actor.model_moving and actor.travel_duration>0: progress=minf(1.0,progress+minf(float(actor.travel_elapsed),1.0)/actor.travel_duration)
			moving=actor.model_moving and progress<1.0
			if not actor.path.is_empty():
				var point=_path_point(actor.path,progress)
				var direction=_path_point(actor.path,minf(1.0,progress+0.01))-_path_point(actor.path,maxf(0.0,progress-0.01))
				node.position=point
				if direction.length_squared()>0.0001: node.rotation.y=atan2(direction.x,direction.z)
		else:
			moving=int(actor.step)<actor.path.size()
			if moving:
				var point: Vector3=actor.path[int(actor.step)]
				var direction=point-node.position
				node.position=node.position.move_toward(point,delta*1.05)
				if direction.length_squared()>0.001: node.rotation.y=atan2(direction.x,direction.z)
				if node.position.distance_to(point)<0.03:
					actor.step+=1
					if actor.step>=actor.path.size(): actor.plot=actor.target; actor.arrived=true
		var indoors=actor.arrived and not moving and actor.activity in ["home","research","eat"]
		node.visible=not indoors
		_animate_actor(actor,moving,time*7+int(id))

func _sync_guests() -> void:
	var current=[]
	for v in state.market.visitors:
		var id=int(v.id); current.append(id)
		if not guests.has(id):
			var guest=IslandGuest.new(); add_child(guest); guest.setup(state,world,self,id); guests[id]=guest
	for id in guests.keys():
		if id not in current: guests[id].queue_free(); guests.erase(id)

func mailbox_point() -> Vector3:
	var p: Dictionary=state.plots[state.layout.plaza_index]
	return Vector3(float(p.x)*3-1.10,1.15,float(p.z)*3+0.65)

func _sync_output_markers() -> void:
	for r in state.reactors:
		var id=str(r.id)
		var show=int(r.pending)>0 and world._detailed_plots.has(int(r.plot))
		if not output_markers.has(id) and show:
			var node=Node3D.new(); add_child(node)
			box(node,Vector3(0.34,0.25,0.30),Vector3(0,0.22,0),Color("e8c591"))
			for x in [-0.1,0.1]: ball(node,0.065,Vector3(x,0.40,0),Color("a5efd1"))
			var label=Label3D.new(); label.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); label.font_size=32; label.pixel_size=0.007; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.position=Vector3(0,0.7,0); node.add_child(label)
			output_markers[id]={"node":node,"label":label}
		if not output_markers.has(id): continue
		var marker: Dictionary=output_markers[id]
		marker.node.visible=show
		if show:
			var plot: Dictionary=state.plots[int(r.plot)]
			marker.node.position=Vector3(float(plot.x)*3+0.95,0.1,float(plot.z)*3+0.9)
			marker.label.text="满仓 · 待收" if int(r.pending)>=state.reactor_capacity(r) else "待收 ×%d" % int(r.pending)
			marker.label.modulate=Color("ffcf83") if int(r.pending)>=state.reactor_capacity(r) else Color("b9f2d8")
