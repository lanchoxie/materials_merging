extends Node3D
## Bounded visual representatives of a connected river. No simulation decisions.
var builder
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_watershed.json"))
var sites: Dictionary={}
var snapshot: Dictionary={}
var time=0.0
var arrows: Array=[]
var refuge: Array=[]
var bypass: Node3D
var era=""
var poses={"headwater":Vector3(-2.25,0.35,-0.9),"marsh":Vector3(0,0.10,0),"estuary":Vector3(2.15,-0.08,0.95)}

func setup(host) -> void:
	builder=host; var b=builder
	var terrain=b._sphere(self,3.1,Vector3(0,-0.72,0),"446b61"); terrain.scale=Vector3(1.25,0.18,0.78)
	var cliffs=b._sphere(self,3.05,Vector3(0,-0.98,0),"344e54"); cliffs.scale=Vector3(1.24,0.20,0.77)
	for pair in [["headwater","marsh"],["marsh","estuary"]]:
		_stream(poses[pair[0]],poses[pair[1]],0.35,"5bb2bd",self)
		for i in range(5):
			var bead=b._sphere(self,0.035,Vector3.ZERO,"b9e9d9"); arrows.append({"node":bead,"a":poses[pair[0]],"b":poses[pair[1]],"offset":i/5.0,"first":pair[0]=="headwater"})
	bypass=Node3D.new(); add_child(bypass)
	_stream(poses.headwater+Vector3(0,0.04,-0.35),poses.estuary+Vector3(0,0.04,-0.35),0.16,"77b9ac",bypass)
	for id in poses: _region(str(id),poses[id])
	var edge=Vector3(3.18,-0.10,1.66)
	_stream(poses.estuary,edge,0.27,"77c4c4",self)
	b._cylinder(self,0.58,0.035,edge,"458eaa")
	for i in range(8): refuge.append(_fish(self,edge))
	for i in range(9):
		var angle=i*2.399; var stone=b._sphere(self,0.15,Vector3(cos(angle)*3.05,-0.38,sin(angle)*1.75),"819383"); stone.scale=Vector3(1.3,0.65,1)

func _stream(a: Vector3,c: Vector3,width: float,color: String,parent: Node3D) -> void:
	var piece=builder._box(parent,Vector3(width,0.05,a.distance_to(c)),(a+c)/2,color)
	piece.rotation.y=atan2(c.x-a.x,c.z-a.z)
	piece.rotation.x=-atan2(c.y-a.y,Vector2(c.x-a.x,c.z-a.z).length())

func _fish(parent: Node3D,pos: Vector3) -> Node3D:
	var root=Node3D.new(); root.position=pos; parent.add_child(root)
	var body=builder._sphere(root,0.085,Vector3.ZERO,"dbb987"); body.scale=Vector3(1.65,0.60,0.60)
	var head=builder._box(root,Vector3(0.10,0.08,0.10),Vector3(0.09,0,0),"90aca2"); head.rotation.y=0.2
	for side in [-1,1]:
		var fin=builder._box(root,Vector3(0.11,0.015,0.05),Vector3(-0.02,0,side*0.07),"c99164"); fin.rotation.y=side*0.6
	preload("res://scripts/static_geometry.gd").bake(root)
	return root

func _region(id: String,pos: Vector3) -> void:
	var b=builder; var root=Node3D.new(); root.position=pos; add_child(root)
	var bank=b._sphere(root,1.14,Vector3(0,-0.20,0),"719774"); bank.scale=Vector3(1,0.20,0.86)
	var water=b._cylinder(root,0.89,0.035,Vector3.ZERO,"4d9eb1"); water.scale.z=0.82
	var marker=b._ring(root,1.02,1.06,Vector3(0,0.015,0),"a5efd1"); marker.visible=false
	var patches=[]; var detritus=[]; var fish=[]; var plants=[]; var shells=[]
	for i in range(10):
		var angle=i*2.399; var radius=sqrt(i/10.0)*0.72
		patches.append(b._cylinder(root,0.14,0.012,Vector3(cos(angle)*radius,0.04,sin(angle)*radius*0.8),"a2b86b"))
		var speck=b._box(root,Vector3(0.055,0.016,0.085),Vector3(cos(angle+1)*radius,0.045,sin(angle+1)*radius*0.8),"a58c62"); speck.rotation.y=angle; detritus.append(speck)
	for i in range(6): fish.append(_fish(root,Vector3.ZERO))
	for i in range(4):
		var shell=b._sphere(root,0.085,Vector3(-0.4+i*0.24,0.02,0.46),"e0cfaa"); shell.scale=Vector3(1,0.5,0.8); shells.append(shell)
	for i in range(5 if id=="marsh" else 3):
		var plant=_plant(root,i); plant.root.position=Vector3(-0.82+i*0.33,0,-0.76-(i%2)*0.13); plants.append(plant)
	var station=Node3D.new(); station.position=Vector3(0.72,0.05,0.37); root.add_child(station)
	b._box(station,Vector3(0.3,0.10,0.24),Vector3.ZERO,"d3ddc8")
	b._cylinder(station,0.10,0.36,Vector3(0,0.20,0),"729fc5")
	var core=b._box(station,Vector3(0.07,0.30,0.20),Vector3(-0.17,0.17,0),"d99367")
	var light=b._sphere(station,0.055,Vector3(0,0.44,0),"a5efd1")
	var bubbles=[]
	for i in range(4): bubbles.append(b._sphere(root,0.025,Vector3.ZERO,"d7efe1"))
	var screen=Node3D.new(); screen.position=Vector3(-0.67,0.08,0.45); root.add_child(screen)
	b._box(screen,Vector3(0.34,0.25,0.30),Vector3.ZERO,"ddc998")
	for i in range(4): b._box(screen,Vector3(0.045,0.27,0.32),Vector3(-0.12+i*0.08,0.02,0),"718e87")
	var fill=b._box(screen,Vector3(0.32,0.07,0.29),Vector3(0,0.18,0),"b08d67")
	var rotor=b._box(screen,Vector3(0.27,0.04,0.05),Vector3(0,0.27,0),"a6e8d1")
	var boat=Node3D.new(); root.add_child(boat)
	b._box(boat,Vector3(0.23,0.08,0.15),Vector3.ZERO,"e6d1a5")
	b._box(boat,Vector3(0.055,0.17,0.05),Vector3(0,0.1,0),"c88960")
	var buffer=b._ring(root,0.94,0.99,Vector3(0,0.02,0),"b4cf79")
	sites[id]={"root":root,"marker":marker,"water":water,"patches":patches,"detritus":detritus,"fish":fish,"plants":plants,"shells":shells,"station":station,"core":core,"light":light,"bubbles":bubbles,"screen":screen,"fill":fill,"rotor":rotor,"boat":boat,"buffer":buffer}

func _frond(parent: Node3D,pos: Vector3,angle: float,length: float,color: String) -> void:
	var stem=Node3D.new(); stem.position=pos; stem.rotation.y=angle; parent.add_child(stem)
	builder._box(stem,Vector3(0.016,0.018,length),Vector3(0,0,length/2),color)
	for i in range(4):
		for side in [-1,1]:
			var leaf=builder._box(stem,Vector3(length*0.44*(1-i/6.0),0.014,length*0.10),Vector3(side*length*0.17,0.015,length*(0.15+i*0.19)),color)
			leaf.rotation.y=side*0.45

func _plant(parent: Node3D,index: int) -> Dictionary:
	var root=Node3D.new(); parent.add_child(root)
	var dev=Node3D.new(); root.add_child(dev)
	builder._cylinder(dev,0.030,0.78,Vector3(0,0.38,0),"90744f")
	for j in range(4): _frond(dev,Vector3(0,0.36+j*0.115,0),j*2.4,0.43-j*0.03,"6c9775")
	var coal=Node3D.new(); root.add_child(coal)
	builder._cylinder(coal,0.047 if index%2==0 else 0.026,1.30,Vector3(0,0.64,0),"83905c")
	for j in range(6): builder._ring(coal,0.026,0.049,Vector3(0,0.16+j*0.19,0),"bfd088")
	if index%2==0:
		for side in [-1,1]:
			var branch=builder._cylinder(coal,0.024,0.34,Vector3(side*0.08,1.29,0),"83905c"); branch.rotation.z=-side*0.50
			for j in range(3): _frond(coal,Vector3(side*0.16,1.43,0),j*TAU/3,0.34,"87b57b")
	else:
		for tier in range(4):
			for j in range(3): _frond(coal,Vector3(0,0.4+tier*0.23,0),j*TAU/3+tier,0.23,"96b57c")
	preload("res://scripts/static_geometry.gd").bake(dev); preload("res://scripts/static_geometry.gd").bake(coal)
	return {"root":root,"devonian":dev,"carboniferous":coal}

func sync(world: Dictionary) -> void:
	snapshot={"paused":world.paused,"seconds":world.seconds,"watershed":{}}
	for key in world.watershed:
		if key!="history": snapshot.watershed[key]=world.watershed[key]
	# Copy only the presentation state; bounded history stays in the model and chart.
	snapshot=snapshot.duplicate(true)

func _process(dt: float) -> void:
	if not visible or snapshot.is_empty(): return
	var w=snapshot.watershed
	if not snapshot.paused and w.enabled: time+=dt
	bypass.visible=w.bypass
	for info in arrows:
		info.node.visible=not (info.first and w.bypass)
		info.node.position=info.a.lerp(info.b,fmod(time*0.2+float(info.offset),1.0))+Vector3(0,0.07,0)
	for i in range(refuge.size()):
		var animal=refuge[i]; animal.visible=i<float(w.refuge)/6.5
		var angle=time*0.35+i*TAU/8
		animal.position=Vector3(3.18+cos(angle)*0.37,0.02,1.66+sin(angle)*0.37); animal.rotation.y=-angle
	for id in sites:
		var info=sites[id]; var r=w.regions[id]
		for i in range(info.patches.size()):
			info.patches[i].scale=Vector3.ONE*maxf(0.001,sqrt(r.algae/22.0)); info.detritus[i].visible=i<r.detritus*0.45
		for i in range(info.plants.size()):
			var plant=info.plants[i]
			plant.devonian.visible=w.era=="devonian"; plant.carboniferous.visible=w.era=="carboniferous"
			plant.root.scale=Vector3.ONE*clampf(0.55+sqrt(r.plants/30.0),0.5,1.55)
		for i in range(info.shells.size()): info.shells[i].visible=i<r.benthos*0.4
		for i in range(info.fish.size()):
			var animal=info.fish[i]; animal.visible=i<r.fish/2.0
			var angle=time*(0.45 if r.oxygen>30 else 0.20)+i*TAU/6
			animal.position=Vector3(cos(angle)*0.57,0.095,sin(angle)*0.42); animal.rotation.y=-angle
		info.station.visible=r.device; info.core.visible=not r.component.is_empty()
		if info.core.visible:
			var lab=builder.material_view.lab; var d=lab.data.designs[r.component.recipe]
			info.core.material_override=builder._mat(str(lab.data.materials[d.material].color))
		var running=r.device and r.enabled and r.gas>0 and not r.cooling
		info.light.material_override=builder._mat("ef826f" if r.cooling else ("a5efd1" if running else "8a9b9f"))
		for i in range(info.bubbles.size()):
			info.bubbles[i].visible=running
			info.bubbles[i].position=Vector3(0.45,0.06+fmod(time*0.4+i*0.25,0.5),0.3)
		info.screen.visible=r.screen; info.fill.scale.y=maxf(0.02,r.retained/float(rules.devices.screen_capacity))*3
		if not snapshot.paused and r.screen_energy>0 and r.retained<float(rules.devices.screen_capacity) and r.screen_enabled: info.rotor.rotation.y=time*4
		info.buffer.visible=r.buffer
		info.boat.visible=not r.harvest.is_empty()
		info.boat.position=Vector3(cos(time*0.7)*0.65,0.15,sin(time*0.7)*0.45); info.boat.rotation.y=-time*0.7
