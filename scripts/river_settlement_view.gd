extends Node3D
const G=preload("res://scripts/river_geometry.gd")
var material: Material
var terrain
var members={}
var ranch
var construction
var depot_position=Vector2.ZERO
var depot_node
var facility_node
var stamp=""
var paused=false
var clock=0.0
var meshes={}

func _mesh(era: int,role: int=1) -> Mesh:
	var cache_key=era*10+role
	if meshes.has(cache_key): return meshes[cache_key]
	var st=G.surface(material); var coat=Color("bf9962") if role==1 else Color("638da4")
	G.cube(st,Vector3(0,0.85,0),Vector3(0.42,0.6,0.28),coat)
	G.cube(st,Vector3(0,1.3,0),Vector3(0.30,0.32,0.30),Color("e6c3a1"))
	G.cube(st,Vector3(0,1.50,0),Vector3(0.48,0.08,0.42),Color("c2a66b") if era==1 else Color("63bbaa"))
	for side in [-1,1]:
		G.cube(st,Vector3(side*0.12,0.28,0),Vector3(0.14,0.56,0.18),Color("546979"))
		G.cube(st,Vector3(side*0.29,0.83,0),Vector3(0.13,0.52,0.16),coat)
		G.cube(st,Vector3(side*0.08,1.32,-0.155),Vector3(0.04,0.035,0.01),Color("2c3f45"))
	if era>=2: G.cube(st,Vector3(0.28,0.71,-0.15),Vector3(0.18,0.25,0.04),Color("539bad"))
	meshes[cache_key]=st.commit(); return meshes[cache_key]

func sync(model,at: Vector2) -> void:
	_sync_depot(at)
	var alive=[]
	for person in model.people:
		if at.distance_to(Vector2(person.x,person.z))>70: continue
		alive.append(person.id)
		var target=Vector3(person.x,terrain.ground(Vector2(person.x,person.z)),person.z)
		if not members.has(person.id):
			var root=Node3D.new(); add_child(root); members[person.id]=root; root.position=target
			var mesh=MeshInstance3D.new(); mesh.mesh=_mesh(model.era,int(person.id)); root.add_child(mesh)
			var carry=MeshInstance3D.new(); var st=G.surface(material)
			G.cube(st,Vector3(0,0.8,-0.34),Vector3(0.45,0.3,0.3),Color("d4b06f")); carry.mesh=st.commit(); root.add_child(carry)
			var label=Label3D.new(); label.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); label.font_size=26; label.pixel_size=0.009; label.position.y=1.95; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; root.add_child(label)
		var node=members[person.id]; node.set_meta("target",target)
		var j=ranch.jobs.get(str(int(person.id)),{}) if ranch!=null else {}
		node.get_child(1).visible=not j.get("cargo",{}).is_empty()
		node.get_child(2).text=person.name+"\n"+("农夫" if int(person.id)==1 else "工匠")
		node.get_child(2).pixel_size=0.004; node.get_child(2).outline_size=3
		node.get_child(2).visible=at.distance_to(Vector2(person.x,person.z))<3.0
		node.set_meta("working",j.get("stage")=="work" and j.get("left",4)<4)
	for id in members.keys():
		if id not in alive: members[id].queue_free(); members.erase(id)

func _sync_depot(at: Vector2) -> void:
	if ranch==null: return
	if depot_node==null:
		depot_node=MeshInstance3D.new(); add_child(depot_node); var st=G.surface(material)
		var crate_at=depot_position+Vector2(0,-1.3)
		var p=Vector3(crate_at.x,terrain.ground(crate_at),crate_at.y)
		for x in [-0.6,0.6]:
			G.cube(st,p+Vector3(x,0.35,0),Vector3(0.9,0.7,0.65),Color("ad825a"))
			G.cube(st,p+Vector3(x,0.72,0),Vector3(0.94,0.07,0.69),Color("d0b17d"))
		G.cube(st,p+Vector3(0,1.25,0.15),Vector3(1.55,0.12,1),Color("657e70")); depot_node.mesh=st.commit()
		var label=Label3D.new(); label.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); label.font_size=24; label.outline_size=3; label.pixel_size=0.004; label.position=p+Vector3(0,1.6,0); label.text="公共仓库"; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; depot_node.add_child(label)
	depot_node.visible=at.distance_to(depot_position)<70
	depot_node.get_child(0).visible=at.distance_to(depot_position)<3.0
	if construction==null: return
	var next=str([ranch.facilities,construction.revision])
	if stamp==next: return
	stamp=next
	if facility_node==null: facility_node=MeshInstance3D.new(); add_child(facility_node)
	var st=G.surface(material); var count=0
	for key in ranch.facilities:
		var f=ranch.facilities[key]
		if f.stock<=0 or not construction.blocks.has(key): continue
		var b=construction.blocks[key]; var p=Vector3(b.x,b.y+0.2+float(f.stock)/6*0.65,b.z)
		G.cube(st,p,Vector3(0.76,0.06,0.76),Color("73c4d5") if f.kind=="trough" else Color("d5c279")); count+=1
	facility_node.visible=count>0
	if count>0: facility_node.mesh=st.commit()

func _process(dt: float) -> void:
	if not paused: clock+=dt
	for node in members.values():
		var target: Vector3=node.get_meta("target"); var delta=target-node.position
		if Vector2(delta.x,delta.z).length()>0.02: node.rotation.y=lerp_angle(node.rotation.y,atan2(-delta.x,-delta.z),minf(1,dt*7))
		node.position=node.position.lerp(target,minf(1,dt*7))
		var working=node.get_meta("working",false) and not paused
		node.get_child(0).rotation.x=sin(clock*5)*0.1 if working else 0.0
