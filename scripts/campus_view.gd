extends Node3D
## Presentation only. Logical people keep updating when their meshes are hidden.
var state
var world
var scenery: Node3D
var actors: Dictionary={}
var geometry_key=""
var models: Dictionary={}
var materials: Dictionary={}
var time=0.0
var transport: Node3D
var visitor_progress=0.0
var visitor_key=-1
var visitor_start=Vector3.ZERO
var visitor_stop=Vector3.ZERO
var visitor_phase="absent"
var buyer: Dictionary={}
var buyer_progress=0.0
var buyer_stop=Vector3.ZERO
var vehicle_rider: Node3D
var _actor_pool: Array=[]
var _visitor_available=false
var _visitor_next_key=0
var static_rebuilds=0
var avatar_rebuilds=0
var vehicle_rebuilds=0

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
	_sync_visitor()

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
		var node=Node3D.new(); scenery.add_child(node); node.position=base
		if p.kind=="plaza": _plaza(node)
		elif p.kind in state.layout.building_kinds(): _building(node,p,detail)
		if detail:
			for prop in p.get("props",[]): _prop(node,str(prop.kind),int(prop.slot))
			_connect_fences(node,p.get("props",[]))
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
	box(parent,Vector3(2.3,0.04,0.56),Vector3(0,0.15,0.6),Color("a8b6ad"))
	box(parent,Vector3(1.8,0.08,0.6),Vector3(0,0.30,-0.75),Color("e8f2da"))
	box(parent,Vector3(1.8,0.06,0.7),Vector3(0,1.30,-0.75),Color("458c83"))
	for x in [-0.8,0.8]: box(parent,Vector3(0.07,1.08,0.07),Vector3(x,0.75,-0.75),Color("e8f2da"))
	ball(parent,0.17,Vector3(0,1.55,-0.75),Color("ffcf77"))
	var sign=Label3D.new(); sign.text="迎客广场"; sign.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); sign.font_size=40; sign.pixel_size=0.008
	sign.position=Vector3(0,1.58,0); sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED; parent.add_child(sign)

func _building(parent: Node3D, p: Dictionary, detail: bool) -> void:
	var kind: String=p.kind
	if kind=="engineer_house" and detail and world.has_method("_build_house"):
		world._build_house(parent)
		return
	if kind=="park":
		box(parent,Vector3(2.0,0.08,1.8),Vector3(0,0.15,0),Color("81b890"))
		for x in [-0.60,0.60]:
			box(parent,Vector3(0.12,0.6,0.12),Vector3(x,0.45,-0.35),Color("ac8661"))
			ball(parent,0.42,Vector3(x,0.92,-0.35),Color("87cea0"))
		box(parent,Vector3(1,0.15,0.3),Vector3(0,0.4,0.65),Color("e5c99f")); return
	var level=int(p.get("building_level",1))
	var height=0.65+0.38*level
	var color=Color("e3e6ce")
	var roof=Color("559f9a")
	if kind=="doctor_dorm": roof=Color("7096b7")
	if kind=="professor_apartment": roof=Color("aa99be")
	if kind=="academician_villa": roof=Color("b99368")
	if kind=="canteen": roof=Color("d88f72")
	box(parent,Vector3(1.85,height,1.65),Vector3(0,height*0.5+0.12,0),color)
	box(parent,Vector3(2.03,0.16,1.85),Vector3(0,height+0.20,0),roof)
	box(parent,Vector3(0.3,0.6,0.035),Vector3(0,0.42,0.845),Color("40646c"))
	if detail:
		for floor_index in range(level):
			for x in [-0.6,0.6]: box(parent,Vector3(0.27,0.21,0.035),Vector3(x,0.58+floor_index*0.38,0.845),Color("9ad6cf"))
		if kind=="institute":
			ball(parent,0.27,Vector3(0,height+0.6,0),Color("91ded5"))
			box(parent,Vector3(0.07,0.4,0.07),Vector3(0,height+0.35,0),roof)

func _prop(parent: Node3D, kind: String, slot: int) -> void:
	var node=Node3D.new(); parent.add_child(node); node.position=_prop_offset(slot)
	match kind:
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
		actor.tool.visible=person.activity in ["construct","maintain","deliver_meal"]
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
	actor.tool.rotation.x=sin(time*5)*0.7 if not moving and actor.activity in ["construct","maintain"] and actor.arrived else 0.0

func _wheel(parent: Node3D, at: Vector3, radius: float) -> void:
	var key="wheel"+str(radius)
	if not models.has(key):
		var shape=TorusMesh.new(); shape.inner_radius=radius*0.62; shape.outer_radius=radius; shape.rings=12; shape.ring_segments=6
		models[key]=shape
	var wheel=mesh(parent,models[key],at,Color("33505b")); wheel.rotation.z=PI*0.5

func _beam(parent: Node3D, start: Vector3, end: Vector3, width: float, color: Color) -> void:
	var beam=box(parent,Vector3(width,width,start.distance_to(end)),(start+end)*0.5,color)
	beam.look_at_from_position((start+end)*0.5,end,Vector3.RIGHT)

func _create_transport(key: int) -> void:
	if is_instance_valid(transport): transport.queue_free()
	transport=Node3D.new(); add_child(transport)
	transport.name="BuyerTransport"
	vehicle_rebuilds+=1
	visitor_key=key
	var style=key%3
	transport.set_meta("vehicle_style",["bicycle","car","minibus"][style])
	vehicle_rider=null
	if style==0:
		for z in [-0.35,0.35]: _wheel(transport,Vector3(0,0.22,z),0.19)
		var frame=Color("dfae66")
		for edge in [[Vector3(0,0.23,-0.35),Vector3(0,0.50,-0.10)],[Vector3(0,0.50,-0.10),Vector3(0,0.23,0.35)],[Vector3(0,0.23,0.35),Vector3(0,0.23,-0.35)],[Vector3(0,0.23,-0.35),Vector3(0,0.59,-0.30)]]:
			_beam(transport,edge[0],edge[1],0.055,frame)
		box(transport,Vector3(0.31,0.035,0.04),Vector3(0,0.59,-0.30),Color("33505b"))
		box(transport,Vector3(0.16,0.05,0.20),Vector3(0,0.52,0.08),Color("7d614f"))
		vehicle_rider=Node3D.new(); transport.add_child(vehicle_rider)
		ball(vehicle_rider,0.12,Vector3(0,0.93,0.05),Color("f5dfbb"))
		box(vehicle_rider,Vector3(0.21,0.25,0.16),Vector3(0,0.72,0.05),Color("bf8eb6"))
	else:
		var length=1.2 if style==1 else 1.7
		box(transport,Vector3(0.62,0.27,length),Vector3(0,0.36,0),Color("7ebdc4") if style==1 else Color("e5bb77"))
		box(transport,Vector3(0.56,0.28,length*0.67),Vector3(0,0.62,-0.1),Color("ebecd7"))
		box(transport,Vector3(0.48,0.18,0.025),Vector3(0,0.65,-0.1-length*0.335),Color("7bafbb"))
		for z in [-length*0.33,length*0.33]:
			for x in [-0.32,0.32]: _wheel(transport,Vector3(x,0.22,z),0.14)
		for x in [-0.21,0.21]: box(transport,Vector3(0.12,0.075,0.03),Vector3(x,0.37,-length*0.5-0.02),Color("ffeac1"))
	if buyer.is_empty():
		buyer=_avatar("buyer",false)
		buyer.node.name="PlazaBuyer"
		buyer.tool.visible=true
	buyer.node.visible=false

func _sync_visitor() -> void:
	if state.layout.plaza_index<0: return
	_visitor_available=state.visitor_available()
	_visitor_next_key=int(state.visitor_visits)
	visitor_stop=state.layout.hub(state.plots,state.layout.plaza_index)+Vector3(-1.25,0,-0.6)
	visitor_start=visitor_stop+Vector3(0,0,5)
	buyer_stop=visitor_stop+Vector3(-0.6,0,-1.15)
	if visitor_phase=="absent" and _visitor_available: _start_arrival()
	elif visitor_phase not in ["absent","boarding","departing"] and (not _visitor_available or visitor_key!=_visitor_next_key):
		# Keep the outgoing car and buyer until boarding and departure finish.
		visitor_phase="boarding" if buyer_progress>0 else "departing"

func _start_arrival() -> void:
	_create_transport(_visitor_next_key)
	visitor_progress=0.0; buyer_progress=0.0
	visitor_phase="arriving"
	transport.position=visitor_start
	transport.visible=true

func _process_visitor(delta: float) -> void:
	if visitor_phase=="absent": return
	match visitor_phase:
		"arriving":
			visitor_progress=move_toward(visitor_progress,1.0,delta*0.30)
			if visitor_progress>=1.0: visitor_phase="disembarking"
		"disembarking":
			buyer_progress=move_toward(buyer_progress,1.0,delta*0.6)
			if buyer_progress>=1.0: visitor_phase="browsing"
		"boarding":
			buyer_progress=move_toward(buyer_progress,0.0,delta*0.7)
			if buyer_progress<=0.0: visitor_phase="departing"
		"departing":
			visitor_progress=move_toward(visitor_progress,0.0,delta*0.35)
			if visitor_progress<=0.0:
				visitor_phase="absent"
				transport.visible=false
				buyer.node.visible=false
				if _visitor_available: _start_arrival()
				return
	transport.position=visitor_start.lerp(visitor_stop,visitor_progress)
	transport.rotation.y=0.0 if visitor_phase!="departing" else PI
	if is_instance_valid(vehicle_rider): vehicle_rider.visible=buyer_progress<=0.0
	var walking=visitor_phase in ["disembarking","boarding"]
	buyer.node.visible=buyer_progress>0.0
	buyer.node.position=visitor_stop.lerp(buyer_stop,buyer_progress)
	var facing=buyer_stop-visitor_stop if visitor_phase!="boarding" else visitor_stop-buyer_stop
	buyer.node.rotation.y=atan2(facing.x,facing.z)
	_animate_actor(buyer,walking,time*7)
	if visitor_phase=="browsing": buyer.tool.rotation.z=sin(time*1.8)*0.12

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
	_process_visitor(delta)
