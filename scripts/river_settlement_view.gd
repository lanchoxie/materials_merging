extends Node3D
const G=preload("res://scripts/river_geometry.gd")
var material: Material
var terrain
var members={}
var meshes={}

func _mesh(era: int) -> Mesh:
	if meshes.has(era): return meshes[era]
	var st=G.surface(material); var coat=Color("bf9962") if era==1 else Color("d2e7dc")
	G.cube(st,Vector3(0,0.85,0),Vector3(0.42,0.6,0.28),coat)
	G.cube(st,Vector3(0,1.3,0),Vector3(0.30,0.32,0.30),Color("e6c3a1"))
	G.cube(st,Vector3(0,1.50,0),Vector3(0.48,0.08,0.42),Color("c2a66b") if era==1 else Color("63bbaa"))
	for side in [-1,1]:
		G.cube(st,Vector3(side*0.12,0.28,0),Vector3(0.14,0.56,0.18),Color("546979"))
		G.cube(st,Vector3(side*0.29,0.83,0),Vector3(0.13,0.52,0.16),coat)
		G.cube(st,Vector3(side*0.08,1.32,-0.155),Vector3(0.04,0.035,0.01),Color("2c3f45"))
	if era>=2: G.cube(st,Vector3(0.28,0.71,-0.15),Vector3(0.18,0.25,0.04),Color("539bad"))
	meshes[era]=st.commit(); return meshes[era]

func sync(model,at: Vector2) -> void:
	var alive=[]
	for person in model.people:
		if at.distance_to(Vector2(person.x,person.z))>70: continue
		alive.append(person.id)
		if not members.has(person.id): members[person.id]=MeshInstance3D.new(); add_child(members[person.id])
		var node: MeshInstance3D=members[person.id]; node.mesh=_mesh(model.era)
		node.position=Vector3(person.x,terrain.ground(Vector2(person.x,person.z)),person.z)
	for id in members.keys():
		if id not in alive: members[id].queue_free(); members.erase(id)
