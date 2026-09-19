extends Node3D
## Visual representatives only. Work, routes and cargo come from the village model.
var builder
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_village.json"))
var sites: Dictionary={}
var snapshot: Dictionary={}
var time=0.0
var paths=[]
var people=[]
var buildings={}
var scaffolds={}
var wheel: Node3D
var field=[]
var goods=[]
var river_fish=[]
var gate: Node3D

func setup(host) -> void:
	builder=host
	var ground=builder._sphere(self,3.25,Vector3(0,-0.51,0),"607755"); ground.scale=Vector3(1.2,0.14,0.85)
	var cliff=builder._sphere(self,3.2,Vector3(0,-0.77,0),"485d56"); cliff.scale=Vector3(1.21,0.17,0.86)
	builder._box(self,Vector3(0.62,0.045,4.2),Vector3(0.75,0.003,0),"5ca7b8")
	builder._box(self,Vector3(0.80,0.055,0.20),Vector3(1.40,0.008,-1.25),"77bac3")
	gate=builder._box(self,Vector3(0.63,0.23,0.1),Vector3(0.75,0.01,-1.0),"926f4d")
	for i in range(4): river_fish.append(builder._sphere(self,0.055,Vector3(0.8,0.045,i-1.5),"f8d18a"))
	for edge in rules.edges:
		var a=_pos(edge[0]); var b=_pos(edge[1]); var road=builder._box(self,Vector3(0.19,0.02,a.distance_to(b)),(a+b)*0.5-Vector3(0,0.025,0),"a28d65")
		road.look_at(b); paths.append(road)
	for id in rules.nodes:
		var node=Node3D.new(); node.position=_pos(id); add_child(node)
		var marker=builder._ring(node,0.5,0.55,Vector3(0,0.05,0),"a5efd1"); marker.hide()
		sites[id]={"root":node,"marker":marker}
	_house(sites.home.root,Vector3(0.75,0.58,0.63),"bda482",true)
	_house(sites.depot.root,Vector3(0.7,0.47,0.54),"b1a693",false)
	for i in range(5):
		var crate=builder._box(sites.depot.root,Vector3(0.13,0.13,0.14),Vector3(-0.22+i*0.12,0.09,0.44),"c5a168"); goods.append(crate)
	builder._cylinder(sites.well.root,0.27,0.20,Vector3(0,0.10,0),"a7a59a")
	builder._cylinder(sites.well.root,0.21,0.01,Vector3(0,0.21,0),"66b6c1")
	builder._box(sites.field.root,Vector3(1.15,0.045,0.75),Vector3(0,0.0,0),"795747")
	for row in range(3):
		for col in range(7): field.append(builder._box(sites.field.root,Vector3(0.045,0.24,0.045),Vector3(-0.46+col*0.15,0.12,-0.23+row*0.22),"c7b763"))
	for id in rules.projects:
		var base=sites[str(rules.projects[id].node)].root
		var structure=Node3D.new(); base.add_child(structure); buildings[id]=structure
		var scaffold=Node3D.new(); base.add_child(scaffold); scaffolds[id]=scaffold
		for x in [-0.44,0.44]:
			for z in [-0.36,0.36]: builder._box(scaffold,Vector3(0.035,0.85,0.035),Vector3(x,0.4,z),"d8bb84")
		builder._box(scaffold,Vector3(0.92,0.05,0.13),Vector3(0,0.5,-0.36),"c2a476")
		match id:
			"road":
				for i in range(9): builder._box(structure,Vector3(0.13,0.05,0.34),Vector3(i*0.15,0.035,0),"d8c398")
				for z in [-0.20,0.20]: builder._box(structure,Vector3(1.37,0.025,0.035),Vector3(0.6,0.26,z),"9c7957")
			"cistern":
				for x in [-0.35,0.35]: builder._box(structure,Vector3(0.065,0.6,0.065),Vector3(x,0.3,0),"815f49")
				_roof(structure,0.9,0.67,0.66,"879070")
			"mill":
				_house(structure,Vector3(0.8,0.85,0.67),"c4b395",false)
				wheel=Node3D.new(); wheel.name="Building"; wheel.position=Vector3(-0.57,0.32,0); structure.add_child(wheel)
				builder._cylinder(wheel,0.34,0.07,Vector3.ZERO,"8b684a").rotation_degrees.z=90
				for i in range(10):
					var angle=i*TAU/10; var paddle=builder._box(wheel,Vector3(0.23,0.06,0.15),Vector3(0,sin(angle)*0.35,cos(angle)*0.35),"c7a575"); paddle.rotation.x=-angle
			"market":
				for x in [-0.4,0.4]:
					for z in [-0.27,0.27]: builder._box(structure,Vector3(0.045,0.7,0.045),Vector3(x,0.35,z),"846449")
				builder._box(structure,Vector3(0.84,0.1,0.46),Vector3(0,0.34,0),"b78c5b")
				_roof(structure,0.98,0.75,0.65,"b57858")
	for id in buildings:
		preload("res://scripts/static_geometry.gd").bake(buildings[id])
		preload("res://scripts/static_geometry.gd").bake(scaffolds[id])
	for i in range(rules.people.size()): _person(i)
	for at in [Vector3(-3,0,1.2),Vector3(2.8,0,-1.7),Vector3(2.8,0,1.9)]:
		builder._cylinder(self,0.07,0.7,at+Vector3(0,0.25,0),"937553")
		var crown=builder._sphere(self,0.35,at+Vector3(0,0.68,0),"75985f"); crown.scale.y=1.25

func _roof(parent: Node3D,width: float,y: float,depth: float,color: String) -> void:
	for sign in [-1,1]:
		var roof=builder._box(parent,Vector3(width*0.62,0.07,depth),Vector3(sign*width*0.23,y,0),color); roof.rotation.z=sign*-0.45

func _house(parent: Node3D,size: Vector3,color: String,hearth: bool) -> void:
	var shell=Node3D.new(); parent.add_child(shell); parent=shell
	builder._box(parent,size,Vector3(0,size.y*0.5,0),color)
	for x in [-size.x*0.46,0,size.x*0.46]: builder._box(parent,Vector3(0.045,size.y,0.025),Vector3(x,size.y*0.5,size.z*0.51),"604d42")
	for y in [0.1,size.y*0.88]: builder._box(parent,Vector3(size.x,0.04,0.025),Vector3(0,y,size.z*0.51),"604d42")
	builder._box(parent,Vector3(0.15,size.y*0.52,0.04),Vector3(-size.x*0.19,size.y*0.26,size.z*0.52),"564a41")
	builder._box(parent,Vector3(0.12,0.15,0.035),Vector3(size.x*0.22,size.y*0.6,size.z*0.52),"dbb877")
	_roof(parent,size.x*1.17,size.y+0.1,size.z*1.2,"817657" if hearth else "8e6958")
	preload("res://scripts/static_geometry.gd").bake(shell)

func _person(i: int) -> void:
	var root=Node3D.new(); add_child(root)
	var colors=["b6a467","789d9d","dfbb89","9e7967","b67b69","779164"]
	builder._cylinder(root,0.058,0.16,Vector3(0,0.17,0),colors[i])
	builder._sphere(root,0.060,Vector3(0,0.30,0),"eacbb0")
	builder._cylinder(root,0.07,0.023,Vector3(0,0.35,0),"756c59")
	var legs=[]; var arms=[]
	for sign in [-1,1]:
		legs.append(builder._box(root,Vector3(0.038,0.12,0.042),Vector3(sign*0.037,0.06,0),"63594f"))
		arms.append(builder._box(root,Vector3(0.032,0.12,0.035),Vector3(sign*0.083,0.18,0),colors[i]))
	var cargo=builder._box(root,Vector3(0.15,0.12,0.10),Vector3(0,0.18,0.11),"c9aa77")
	people.append({"root":root,"legs":legs,"arms":arms,"cargo":cargo})

func _pos(id: String) -> Vector3:
	var a=rules.nodes[id]; return Vector3(float(a[0]),0.03,float(a[1]))

func sync(world: Dictionary) -> void:
	var changed=snapshot.get("id","")!=world.id or int(snapshot.get("seconds",0))>int(world.seconds)
	var state={}
	for key in world.village:
		if key!="history": state[key]=world.village[key]
	snapshot={"id":world.id,"village":state.duplicate(true),"paused":world.paused,"seconds":world.seconds}
	if changed:
		for i in range(people.size()): people[i].root.position=_location(snapshot.village.people[i])

func _location(p: Dictionary) -> Vector3:
	var location=_pos(str(p.route[0])).lerp(_pos(str(p.route[1])),float(p.fraction)) if p.route.size()>1 else _pos(str(p.at))
	return location+Vector3((int(p.id)%3-1)*0.13,0,0.48+floorf(float(p.id)/3)*0.13)

func _process(dt: float) -> void:
	if not visible or snapshot.is_empty(): return
	var w=snapshot.village
	if not snapshot.paused and w.enabled: time+=dt
	for i in range(people.size()):
		var p=w.people[i]; var visual=people[i]; var target=_location(p); var offset=target-visual.root.position
		visual.root.visible=w.enabled; visual.root.position=visual.root.position.lerp(target,minf(1,dt*10))
		if offset.length()>0.025: visual.root.rotation.y=atan2(offset.x,offset.z)
		var moving=p.route.size()>1 and not snapshot.paused
		for j in range(2):
			visual.legs[j].rotation.x=sin(time*8+j*PI)*0.48 if moving else 0
			visual.arms[j].rotation.x=sin(time*7+j*PI)*0.65 if moving or (not snapshot.paused and p.stage=="work" and p.task!="rest") else 0
		visual.cargo.visible=not p.cargo.is_empty() or (p.stage=="work" and not p.load.is_empty())
		visual.cargo.material_override=builder._mat("75afbe" if p.task in ["drink","fetch"] else "d1b37c")
	for road in paths: road.material_override=builder._mat("c4b999" if w.projects.road.complete else "a28d65")
	for id in buildings:
		buildings[id].visible=w.projects[id].complete
		scaffolds[id].visible=w.projects[id].committed and not w.projects[id].complete
		if scaffolds[id].visible: scaffolds[id].scale.y=0.35+0.65*w.projects[id].progress/float(rules.projects[id].work)
	if not snapshot.paused and w.mill_running: wheel.rotation.x+=dt*1.6*w.diversion
	gate.visible=w.projects.mill.complete; gate.scale.y=maxf(0.05,w.diversion)
	for i in range(river_fish.size()):
		river_fish[i].visible=i<w.passage/25; river_fish[i].position.z=fmod(time*0.22+i,3.8)-1.9
	for i in range(goods.size()): goods[i].visible=i<float(w.stock.goods)/2
	var growing=false
	for p in w.people:
		if p.task=="farm" and p.stage=="work": growing=true
	for sprout in field: sprout.scale.y=0.7+0.25*sin(time*0.6) if growing else 0.7
