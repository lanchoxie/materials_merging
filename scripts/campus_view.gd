extends Node3D
const Architecture=preload("res://scripts/campus_architecture.gd")
const StaticGeometry=preload("res://scripts/static_geometry.gd")
const IslandGuest=preload("res://scripts/island_guest.gd")
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
	var links: Dictionary=state.layout.road_links(state.plots)
	var road_transforms: Array=[]
	for i in range(state.plots.size()):
		var p: Dictionary=state.plots[i]
		if not p.unlocked: continue
		var base=Vector3(float(p.x)*3,0,float(p.z)*3)
		if p.get("road",false):
			# Road hubs sit at parcel corners, clear of building footprints.
			var hub=state.layout.hub(state.plots,i)
			if world._visible_plots.has(i): road_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.3,0.025,0.3)),hub))
			for neighbor in links.get(i,[]):
				if int(neighbor)<i: continue
				if not world._visible_plots.has(i) and not world._visible_plots.has(int(neighbor)): continue
				var next=state.layout.hub(state.plots,int(neighbor))
				road_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(absf(next.x-hub.x)+0.3,0.025,absf(next.z-hub.z)+0.3)),(hub+next)*0.5))
		if not world._visible_plots.has(i): continue
		var detail=world._detailed_plots.has(i)
		var node=Node3D.new(); node.name="Plot_%d" % i; scenery.add_child(node); node.position=base
		if p.kind=="plaza": _plaza(node)
		elif not state.layout.building_info(p.kind).is_empty():
			var building=Node3D.new(); building.name="Building"; node.add_child(building)
			_building(building,p,detail)
			StaticGeometry.bake(building)
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

func _avatar(role: String, resident: bool=true) -> Dictionary:
	if resident: avatar_rebuilds+=1
	var node=Node3D.new(); add_child(node)
	var body=Node3D.new(); node.add_child(body)
	var color=Color({"engineer":"dfa858","doctor":"69b6b1","professor":"a49dc9","academician":"c5ad83","buyer":"bf8eb6"}.get(role,"a8c7bf"))
	box(body,Vector3(0.20,0.24,0.15),Vector3(0,0.29,0),color)
	ball(body,0.12,Vector3(0,0.53,0),Color("f5dfbb"))
	if role=="engineer": box(body,Vector3(0.29,0.05,0.23),Vector3(0,0.64,0),Color("f5cb6d"))
	elif role=="buyer":
		box(body,Vector3(0.29,0.04,0.24),Vector3(0,0.65,0),Color("e2c894"))
		box(body,Vector3(0.19,0.1,0.16),Vector3(0,0.70,0),Color("e2c894"))
	else: box(body,Vector3(0.20,0.04,0.05),Vector3(0,0.54,0.105),Color("395a65"))
	for side in [-1,1]: ball(body,0.014,Vector3(side*0.04,0.56,0.107),Color("395a65"))
	var legs=[]
	for side in [-1,1]:
		var leg=box(node,Vector3(0.065,0.18,0.08),Vector3(side*0.065,0.13,0),Color("3e5c6c")); legs.append(leg)
	var tool=box(body,Vector3(0.13,0.11,0.12),Vector3(0.19,0.28,0),Color("edc997"))
	return {"node":node,"body":body,"legs":legs,"tool":tool,"plot":-1,"target":-1,"path":[],"step":0,"role":role,"activity":"idle","revision":-1,"model_travel":false,"travel_progress":0.0,"travel_duration":0.0,"travel_elapsed":0.0,"arrived":false}

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
	for index in range(2): actor.legs[index].rotation.x=sin(phase+index*PI)*0.35 if moving else 0.0
	actor.tool.rotation.x=sin(time*5)*0.7 if not moving and actor.activity in ["construct","maintain","factory","collect","install"] and actor.arrived else 0.0

func _process(delta: float) -> void:
	if state==null: return
	time+=delta
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
