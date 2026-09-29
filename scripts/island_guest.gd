extends Node3D
## One visitor's animation; model phases remain authoritative across reloads.
var state
var world
var artist
var models: Dictionary={}
var visitor_id=-1
var transport: Node3D
var visitor_key=-1
var buyer: Dictionary={}
var vehicle_rider: Node3D
var vehicle_rebuilds=0
var time=0.0
var head=Vector3.ZERO
var animation_key=""
var interpolation_elapsed=0.0
var material_cargo: Node3D

func setup(model, island, factory, id: int) -> void:
	state=model; world=island; artist=factory; visitor_id=id
	var v=state.market.visitor(id)
	var style=["bicycle","car","minibus"].find(str(v.get("order",{}).get("vehicle","")))
	_create_transport(id-1 if style<0 else style)
	if state.contracts.is_material(v):
		material_cargo=Node3D.new(); transport.add_child(material_cargo)
		var height=.65 if style==0 else .88
		box(material_cargo,Vector3(.36,.12,.44),Vector3(0,height,.18),Color("dba46e"))
		box(material_cargo,Vector3(.36,.08,.44),Vector3(0,height+.10,.18),Color("bed5dc"))
		material_cargo.hide()

func box(parent, dimensions, at, color): return artist.box(parent,dimensions,at,color)
func ball(parent, radius, at, color): return artist.ball(parent,radius,at,color)
func mesh(parent, shape, at, color): return artist.mesh(parent,shape,at,color)
func _avatar(role: String, resident: bool=false) -> Dictionary:
	var result: Dictionary=artist._avatar(role,resident)
	result.node.reparent(self)
	return result

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


func _process(delta: float) -> void:
	if state==null: return
	var v: Dictionary=state.market.visitor(visitor_id)
	if v.is_empty(): return
	if is_instance_valid(material_cargo): material_cargo.visible=bool(v.get("fulfilled",false))
	time+=delta
	var key=str(v.phase)+":"+str(v.age)
	if key!=animation_key: animation_key=key; interpolation_elapsed=0.0
	else: interpolation_elapsed+=delta
	var age=float(v.age)+minf(interpolation_elapsed,0.2)
	var plot: Dictionary=state.plots[state.layout.plaza_index]
	var slot=int(v.slot)
	var stop=Vector3(float(plot.x)*3+(slot-1)*0.85,0.13,float(plot.z)*3+0.55)
	var start=stop+Vector3(0,0,4)
	var person_stop=stop+Vector3(0,0,-1.1)
	var car=1.0; var walk=1.0
	if v.phase=="arriving":
		var progress=clampf(age/float(state.island_rules.visitors.arrival_seconds),0,1)
		car=clampf(progress/0.65,0,1); walk=clampf((progress-0.65)/0.35,0,1)
	elif v.phase=="leaving":
		var progress=clampf(age/float(state.island_rules.visitors.departure_seconds),0,1)
		walk=1.0-clampf(progress/0.3,0,1); car=1.0-clampf((progress-0.3)/0.7,0,1)
	transport.position=start.lerp(stop,car)
	transport.rotation.y=PI if v.phase=="leaving" else 0.0
	if is_instance_valid(vehicle_rider): vehicle_rider.visible=walk<=0
	buyer.node.visible=walk>0; buyer.node.position=stop.lerp(person_stop,walk)
	buyer.node.rotation.y=PI if v.phase!="leaving" else 0
	artist._animate_actor(buyer,walk>0 and walk<1,time*7)
	head=buyer.node.position+Vector3(0,1.1,0)
