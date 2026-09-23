extends Node3D
## Nearby render instances of persistent population records. No spawning logic.
const G=preload("res://scripts/river_geometry.gd")
var terrain
var material: Material
var animal_mesh: Mesh
var people_meshes=[]
var scenery={}
var moving={}
var paused=false
var clock=0.0
var barriers: Array=[]
var mature=0.9
var era=0

func _ready() -> void:
	for color in [Color("c69a64"),Color("79a5a3"),Color("c0a2bb")]:
		var st=G.surface(material)
		G.cube(st,Vector3(0,0.8,0),Vector3(0.4,0.55,0.25),color)
		G.cube(st,Vector3(0,1.25,0),Vector3(0.30,0.32,0.28),Color("e7c8a3"))
		G.cube(st,Vector3(0,1.43,0),Vector3(0.4,0.1,0.36),Color("826845"))
		G.cube(st,Vector3(0,0.9,0.2),Vector3(0.3,0.38,0.18),Color("66715c"))
		for side in [-1,1]:
			G.cube(st,Vector3(side*0.12,0.27,0),Vector3(0.14,0.52,0.17),Color("526170"))
			G.cube(st,Vector3(side*0.27,0.8,0),Vector3(0.12,0.5,0.15),color.darkened(0.1))
		people_meshes.append(st.commit())

func sync(population,at: Vector2,is_paused: bool) -> void:
	paused=is_paused; mature=float(population.rules.harvest_maturity)
	var keep=[]; var alive=[]; barriers=[]
	for s in population.visible_sites(at):
		var id=str(s.id); keep.append(id)
		var center=Vector2(s.x,s.z); var version=str([int(s.flora*12),s.flora>=mature,era if s.home else 0])
		if s.camp:
			barriers.append(Rect2(center+Vector2(-4,-2.9),Vector2(2,1.8)))
			barriers.append(Rect2(center+Vector2(0.35,1.6),Vector2(1.3,0.8)))
		if not scenery.has(id):
			var n=MeshInstance3D.new(); add_child(n); scenery[id]=n
		if scenery[id].get_meta("version","")!=version:
			scenery[id].mesh=_scenery(s); scenery[id].set_meta("version",version)
		for a in s.animals:
			var key=id+"/animal/"+str(int(a.id)); alive.append(key)
			_entity(key,animal_mesh,center+Vector2(a.x,a.z))
		for v in s.visitors:
			var key=id+"/visitor/"+str(int(v.id)); alive.append(key)
			_entity(key,people_meshes[int(v.id)%people_meshes.size()],center+Vector2(v.x,v.z))
	for id in scenery.keys():
		if id not in keep: scenery[id].queue_free(); scenery.erase(id)
	for key in moving.keys():
		if key not in alive: moving[key].queue_free(); moving.erase(key)

func _entity(key: String,mesh: Mesh,p: Vector2) -> void:
	var target=Vector3(p.x,terrain.ground(p),p.y)
	if not moving.has(key):
		var n=MeshInstance3D.new(); n.mesh=mesh; n.position=target; add_child(n); moving[key]=n
	moving[key].set_meta("target",target)

func _scenery(s: Dictionary) -> Mesh:
	var st=G.surface(material); var c=Vector2(s.x,s.z)
	for i in range(6):
		var p=c+Vector2(3.4+float(i%3)*0.45,-2+float(i/3)*0.65); var h=terrain.ground(p)
		var size=0.12+float(s.flora)*0.5
		G.cube(st,Vector3(p.x,h+size/2,p.y),Vector3(0.3,size,0.32),Color("95b970"))
		if s.flora>=mature: G.cube(st,Vector3(p.x,h+size,p.y),Vector3(0.13,0.1,0.13),Color("e5b367"))
	if s.camp:
		var p=c+Vector2(-3,-2); var h=terrain.ground(p)
		var style=era if s.home else 0
		G.cube(st,Vector3(p.x,h+0.7,p.y),Vector3(2,1.4,1.8),Color("d6e4dc") if style>=2 else Color("c6b28c"))
		if style>=2:
			G.cube(st,Vector3(p.x,h+1.5,p.y),Vector3(2.4,0.15,2.1),Color("527c86"))
			G.cube(st,Vector3(p.x+0.6,h+0.85,p.y+0.91),Vector3(0.6,0.4,0.03),Color("77c8d3"))
			G.cube(st,Vector3(p.x-0.7,h+2.0,p.y),Vector3(0.06,0.9,0.06),Color("bce3de"))
		else:
			for i in range(4): G.cube(st,Vector3(p.x,h+1.48+i*0.18,p.y),Vector3(2.4-i*0.5,0.18,2.1),Color("b77955") if style==1 else Color("678f85"))
		G.cube(st,Vector3(p.x,h+0.55,p.y+0.91),Vector3(0.65,1.1,0.03),Color("3c514e"))
		p=c+Vector2(1,2); h=terrain.ground(p)
		G.cube(st,Vector3(p.x,h+0.65,p.y),Vector3(1.3,0.12,0.8),Color("b18c67"))
		for side in [-1,1]: G.cube(st,Vector3(p.x+side*0.45,h+0.3,p.y),Vector3(0.12,0.6,0.5),Color("8b7156"))
	return st.commit()

func _process(dt: float) -> void:
	if not paused: clock+=dt
	for n in moving.values():
		var target: Vector3=n.get_meta("target"); var delta=target-n.position
		if Vector2(delta.x,delta.z).length()>0.03:
			n.rotation.y=lerp_angle(n.rotation.y,atan2(-delta.x,-delta.z),minf(1,dt*7))
		n.position=n.position.lerp(target,minf(1,dt*7))
