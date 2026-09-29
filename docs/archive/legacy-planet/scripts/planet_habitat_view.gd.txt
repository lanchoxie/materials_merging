extends Node3D
## Bounded procedural representatives; positions and actions come from the model.
var builder
var model=preload("res://scripts/planet_habitat.gd").new()
var sites={}
var regions={}
var crossings={}
var animals=[]
var rain=[]
var snapshot={}
var time=0.0

func _pos(id: String) -> Vector3:
	var p=model.rules.regions[id].position; return Vector3(float(p[0]),0.05,float(p[1]))

func setup(host) -> void:
	builder=host
	var scenery=Node3D.new(); add_child(scenery)
	var island=builder._sphere(scenery,3.25,Vector3(0,-0.62,0),"596e5b"); island.scale=Vector3(1.1,0.19,0.82)
	var cliff=builder._sphere(scenery,3.20,Vector3(0,-0.92,0),"435d59"); cliff.scale=Vector3(1.08,0.19,0.82)
	for id in model.rules.regions:
		var root=Node3D.new(); root.position=_pos(id); add_child(root)
		var land=builder._cylinder(scenery,1.08,0.10,_pos(id)-Vector3(0,0.045,0),"82926a" if id!="ridge" else "ad9b75"); land.scale.z=0.9
		var bowl=builder._cylinder(root,0.38,0.04,Vector3(0,0.01,0),"aa9b77")
		var water=builder._cylinder(root,0.35,0.02,Vector3(0,0.04,0),"6cbfc5")
		var marker=builder._ring(root,0.40,0.44,Vector3(0,0.06,0),"a5efd1"); marker.hide()
		sites["habitat_"+str(id)]={"root":root,"marker":marker}
		var plants=[]
		for i in range(12):
			var angle=i*TAU/12; var fern=Node3D.new(); fern.position=Vector3(cos(angle)*0.82,0,sin(angle)*0.68); root.add_child(fern)
			for j in range(5):
				var leaf=builder._box(fern,Vector3(0.055,0.035,0.30),Vector3(0,0.10,0),"477c62" if i%2 else "8cbd79"); leaf.rotation=Vector3(-0.45,j*TAU/5,0)
			preload("res://scripts/static_geometry.gd").bake(fern); plants.append(fern)
		var canopy=Node3D.new(); root.add_child(canopy)
		for x in [-0.44,0.44]:
			for z in [-0.34,0.34]: builder._cylinder(canopy,0.022,0.60,Vector3(x,0.3,z),"dac8a3")
		var top=builder._box(canopy,Vector3(0.96,0.045,0.82),Vector3(0,0.62,0),"d9c3a0"); top.rotation.z=0.10
		preload("res://scripts/static_geometry.gd").bake(canopy)
		regions[id]={"water":water,"plants":plants,"canopy":canopy}
		for i in range(3):
			var at=_pos(id)+Vector3(-0.77+i*0.44,0,-0.75)
			builder._cylinder(scenery,0.045,0.64,at+Vector3(0,0.32,0),"9a8462")
			for j in range(5):
				var leaf=builder._sphere(scenery,0.18,at+Vector3(sin(j*TAU/5)*0.22,0.66,cos(j*TAU/5)*0.22),"4e8065"); leaf.scale=Vector3(1.2,0.3,0.75)
	for id in model.rules.edges:
		var e=model.rules.edges[id]; var a=_pos(e.a); var b=_pos(e.b); var center=(a+b)*0.5
		var root=Node3D.new(); root.position=center; add_child(root)
		var path=builder._box(root,Vector3(0.26,0.035,a.distance_to(b)*0.78),Vector3(0,-0.005,0),"baa483"); path.look_at(to_global(b))
		var bridge=Node3D.new(); root.add_child(bridge); bridge.look_at(to_global(b))
		for i in range(9): builder._box(bridge,Vector3(0.40,0.06,0.10),Vector3(0,0.07,-0.50+i*0.125),"d7be8d")
		for x in [-0.23,0.23]:
			builder._box(bridge,Vector3(0.035,0.035,1.15),Vector3(x,0.28,0),"b88f60")
			for z in [-0.48,0.48]: builder._box(bridge,Vector3(0.035,0.3,0.035),Vector3(x,0.14,z),"b88f60")
		preload("res://scripts/static_geometry.gd").bake(bridge)
		var gate=builder._box(root,Vector3(0.40,0.05,0.06),Vector3(0,0.22,0),"dba47f"); gate.rotation.y=path.rotation.y
		var marker=builder._ring(root,0.19,0.23,Vector3(0,0.09,0),"ffd18c")
		crossings[id]={"path":path,"bridge":bridge,"gate":gate,"marker":marker}
		sites["crossing_"+str(id)]={"root":root,"marker":marker}
	for i in range(model.rules.animals.size()): _animal(i)
	for i in range(18): rain.append(builder._box(self,Vector3(0.014,0.10,0.014),Vector3.ZERO,"a3d8df"))
	preload("res://scripts/static_geometry.gd").bake(scenery)

func _animal(i: int) -> void:
	var species=str(model.rules.animals[i][0]); var color=str(model.rules.species[species].color); var predator=species=="tyrannosaurus"
	var root=Node3D.new(); add_child(root)
	var body=Node3D.new(); root.add_child(body)
	var torso=builder._sphere(body,0.19,Vector3(0,0.38 if predator else 0.26,0),color); torso.scale=Vector3(0.82,1.15 if predator else 0.95,1.7); torso.rotation.x=-0.22 if predator else 0.0
	var tail=builder._sphere(body,0.12,Vector3(0,0.40 if predator else 0.27,-0.39),color); tail.scale=Vector3(0.64,0.6,2.7); tail.rotation.x=-0.20
	var neck=builder._sphere(body,0.10,Vector3(0,0.49 if predator else 0.34,0.25),color); neck.scale=Vector3(0.75,1.8,1); neck.rotation.x=0.3
	var head=Node3D.new(); head.position=Vector3(0,0.63 if predator else 0.31,0.35); root.add_child(head)
	var skull=builder._sphere(head,0.11,Vector3.ZERO,color); skull.scale=Vector3(0.85,0.85,1.4 if predator else 1.1)
	for x in [-0.084,0.084]:
		builder._sphere(head,0.025,Vector3(x,0.028,0.052),"ecdfb4")
		builder._sphere(head,0.012,Vector3(x*1.2,0.028,0.062),"273b38")
	if species=="triceratops":
		var frill=builder._sphere(head,0.16,Vector3(0,0.02,-0.085),"d1b67c"); frill.scale=Vector3(1.12,1.0,0.25); frill.rotation.x=-0.4
		for x in [-0.067,0.067,0.0]:
			var horn=CylinderMesh.new(); horn.top_radius=0; horn.bottom_radius=0.022; horn.height=0.18 if x!=0 else 0.10; horn.radial_segments=8
			var mesh=builder._mesh(head,horn,Vector3(x,0.08,0.11 if x!=0 else 0.17),"f3e6c2"); mesh.rotation.x=0.9
	elif predator:
		builder._box(head,Vector3(0.17,0.07,0.20),Vector3(0,-0.043,0.065),"d2aa84")
		for x in [-0.07,0.07]: builder._box(head,Vector3(0.02,0.028,0.11),Vector3(x,-0.018,0.08),"f6e4b7")
		for x in [-0.13,0.13]: builder._box(body,Vector3(0.03,0.07,0.055),Vector3(x,0.42,0.19),color)
	else:
		builder._box(head,Vector3(0.13,0.045,0.15),Vector3(0,-0.022,0.10),"bdd0a3")
		for j in range(5): builder._sphere(body,0.045,Vector3(0,0.44,-0.18+j*0.085),"55775c")
	preload("res://scripts/static_geometry.gd").bake(body); preload("res://scripts/static_geometry.gd").bake(head)
	var legs=[]
	for j in range(2 if predator else 4):
		var x=0.12 if j%2 else -0.12; var z=-0.07 if predator else (-0.16 if j<2 else 0.16)
		var leg=builder._box(root,Vector3(0.065,0.3 if predator else 0.18,0.08),Vector3(x,0.16 if predator else 0.11,z),color); legs.append(leg)
	var needs=builder._sphere(root,0.045,Vector3(0,0.86 if predator else 0.64,0),"e9b476")
	var lost=Node3D.new(); root.add_child(lost)
	for j in range(3): builder._box(lost,Vector3(0.20,0.035,0.04),Vector3(0,0.04,-0.08+j*0.08),"d8cdb6")
	preload("res://scripts/static_geometry.gd").bake(lost)
	animals.append({"root":root,"body":body,"head":head,"legs":legs,"needs":needs,"lost":lost})

func _location(p: Dictionary) -> Vector3:
	var at=_pos(p.at)
	if not p.to.is_empty(): at=at.lerp(_pos(p.to),float(p.progress))
	var angle=int(p.id)*2.399
	return at+Vector3(cos(angle)*0.52,0.01,sin(angle)*0.45)

func sync(world: Dictionary) -> void:
	var changed=snapshot.get("id","")!=world.id or int(snapshot.get("seconds",0))>int(world.seconds)
	var w={}
	for key in world.habitat:
		if key!="history": w[key]=world.habitat[key]
	snapshot={"id":world.id,"seconds":world.seconds,"paused":world.paused,"habitat":w.duplicate(true)}
	if changed:
		for i in range(animals.size()): animals[i].root.position=_location(w.animals[i])

func _process(dt: float) -> void:
	if not visible or snapshot.is_empty(): return
	var w=snapshot.habitat
	if not snapshot.paused and w.enabled: time+=dt
	for id in regions:
		var r=w.regions[id]; var visual=regions[id]; var radius=sqrt(clampf(r.water/120.0,0.02,1))
		visual.water.visible=r.water>0.1; visual.water.scale=Vector3(radius,1,radius); visual.canopy.visible=r.shade
		for i in range(visual.plants.size()): visual.plants[i].scale=Vector3.ONE*clampf(r.plants/120.0,0.05,1.1)
	for id in crossings:
		var visual=crossings[id]; var edge=w.edges[id]
		visual.path.visible=model.rules.edges[id].built; visual.bridge.visible=edge.built and not model.rules.edges[id].built; visual.gate.visible=edge.built and not edge.open
		visual.marker.visible=not edge.built or builder.highlighted=="crossing_"+str(id)
	for i in range(animals.size()):
		var p=w.animals[i]; var v=animals[i]; var target=_location(p); var offset=target-v.root.position
		v.root.visible=w.enabled; v.root.position=v.root.position.lerp(target,minf(1,dt*12))
		if offset.length()>0.01: v.root.rotation.y=lerp_angle(v.root.rotation.y,atan2(offset.x,offset.z),minf(1,dt*8))
		v.body.visible=p.alive; v.head.visible=p.alive; v.lost.visible=not p.alive
		var moving=p.action=="walk" and not snapshot.paused
		for j in range(v.legs.size()):
			v.legs[j].visible=p.alive; v.legs[j].rotation.x=sin(time*7+j*PI)*0.40 if moving else 0
		v.head.rotation.x=0.35+sin(time*4+i)*0.12 if p.action in ["graze","drink","scavenge"] and not snapshot.paused else 0
		v.needs.visible=p.alive and (p.thirst>65 or p.hunger>65)
		v.needs.material_override=builder._mat("7bc7e2" if p.thirst>p.hunger else "e7c477")
	for i in range(rain.size()):
		rain[i].visible=w.enabled and model.wet(w)
		rain[i].position=Vector3(sin(i*7.6)*2.8,0.2+fposmod(2.0-time*2+i*0.27,2.0),cos(i*5.2)*1.8)
