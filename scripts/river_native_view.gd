extends Node3D
## v0.49 溪石部落 on screen: rigged people in hide-and-ochre clothes (the chief with a feather
## headband, the builder carrying timber while building), a woodpile by the village showing the
## stock, and a name sign. Their huts are ordinary blocks drawn by the construction view.
const G=preload("res://scripts/river_geometry.gd")
const Rig=preload("res://scripts/creature_rig.gd")
var material: Material
var terrain
var members={}
var pile: MeshInstance3D
var pile_seen=""
var paused=false
var clock=0.0

func _look(role: String) -> Dictionary:
	match role:
		"chief": return {"coat":"8a5a3c","pants":"5a4636","hair":"1f1a18","skin":"c99a70","hat":"straw","extra":""}
		"builder": return {"coat":"a8744a","pants":"4f4a3c","hair":"2a211c","skin":"c4936a","hat":"","extra":"apron"}
	return {"coat":"b88a5a","pants":"5c5040","hair":"33281f","skin":"cfa27a","hat":"","extra":"pack"}

func sync(natives,at: Vector2) -> void:
	var alive=[]
	if natives.enabled and natives.home!=Vector2.INF:
		for m in natives.members:
			var p=Vector2(float(m.x),float(m.z))
			if at.distance_to(p)>70.0: continue
			alive.append(int(m.id))
			var target=Vector3(p.x,terrain.ground(p),p.y)
			if not members.has(int(m.id)):
				var root=Node3D.new(); add_child(root); members[int(m.id)]=root; root.position=target
				root.add_child(Rig.person(_look(str(m.role)),material))
				var carry=MeshInstance3D.new(); var st=G.surface(material)
				for i in range(3): G.cube(st,Vector3(0,0.85+i*0.09,-0.32),Vector3(0.55,0.08,0.1),Color("8a6440"))
				carry.mesh=st.commit(); root.add_child(carry)
				var label=Label3D.new(); label.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); label.font_size=26; label.pixel_size=0.004; label.outline_size=3; label.position.y=1.95; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; root.add_child(label)
			var node: Node3D=members[int(m.id)]; node.set_meta("target",target)
			node.get_child(1).visible=str(m.task).begins_with("搬运")
			node.get_child(2).text="%s · %s\n%s" % [m.name,m.title,m.task]
			node.get_child(2).visible=at.distance_to(p)<6.0
			node.set_meta("working",m.task=="搭建")
	for id in members.keys():
		if id not in alive: members[id].queue_free(); members.erase(id)
	_pile(natives,at)

## The woodpile and stone heap grow and shrink with the tribe's stock.
func _pile(natives,at: Vector2) -> void:
	if not natives.enabled or natives.home==Vector2.INF:
		if pile!=null: pile.hide()
		return
	if pile==null:
		pile=MeshInstance3D.new(); add_child(pile)
		var sign=Label3D.new(); sign.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); sign.font_size=30; sign.pixel_size=0.006; sign.outline_size=4; sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED; pile.add_child(sign)
	var key=str([natives.home,natives.stock])
	pile.visible=at.distance_to(natives.home)<90.0
	if key==pile_seen: return
	pile_seen=key
	var spot=natives.home+Vector2(0,-4.5); var g=terrain.ground(spot); var st=G.surface(material)
	var logs=mini(12,int(natives.stock.get("timber",0))/3)
	for i in range(logs): G.cube(st,Vector3(spot.x-0.8+float(i%4)*0.42,g+0.12+float(i/4)*0.22,spot.y),Vector3(0.36,0.2,1.3),Color("8a6440").lightened(0.06*(i%2)))
	var stones=mini(8,int(natives.stock.get("stone",0))/2)
	for i in range(stones): G.cube(st,Vector3(spot.x+1.6+float(i%3)*0.3,g+0.12+float(i/3)*0.2,spot.y+0.2*float(i%2)),Vector3(0.28,0.2,0.28),Color("8d9497"))
	G.cube(st,Vector3(spot.x-2.4,g+0.9,spot.y),Vector3(0.12,1.8,0.12),Color("6a4a30"))
	pile.mesh=st.commit() if logs+stones>=0 else null
	pile.get_child(0).text=natives.rules.tribe.name; pile.get_child(0).position=Vector3(spot.x-2.4,g+2.1,spot.y)

func _process(dt: float) -> void:
	if not paused: clock+=dt
	for node in members.values():
		var target: Vector3=node.get_meta("target"); var delta=target-node.position
		if Vector2(delta.x,delta.z).length()>0.02: node.rotation.y=lerp_angle(node.rotation.y,atan2(-delta.x,-delta.z),minf(1,dt*7))
		node.position=node.position.lerp(target,minf(1,dt*3))
		var body: Node3D=node.get_child(0); var working=node.get_meta("working",false) and not paused
		body.rotation.x=sin(clock*5)*0.06 if working else 0.0
		Rig.animate(body,dt,Vector2(delta.x,delta.z).length()*minf(1,dt*3),clock)
