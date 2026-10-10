extends Node3D
## Nearby, batched gather scenery and quantized local crop growth; no inventory writes.
const G=preload("res://scripts/river_geometry.gd")
var material: Material
var resource_mesh: MeshInstance3D
var crops_mesh: MeshInstance3D
var seen=""
var crops_seen=""
var pulse_time=0.0
var pulse: MeshInstance3D
## v0.46: farm robot bodies (one per robot nearby), driving between their dock and the planter they work.
var bots: Dictionary={}
var bot_clock=0.0

func _ready() -> void:
	resource_mesh=MeshInstance3D.new(); add_child(resource_mesh)
	crops_mesh=MeshInstance3D.new(); add_child(crops_mesh)
	pulse=MeshInstance3D.new(); var mesh=SphereMesh.new(); mesh.radius=0.10; mesh.height=0.2; pulse.mesh=mesh
	var m=StandardMaterial3D.new(); m.albedo_color=Color("ffe2a1"); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; pulse.material_override=m; add_child(pulse); pulse.hide()

func feedback(at: Vector3) -> void:
	pulse.position=at; pulse_time=0.45; pulse.show()

func _process(dt: float) -> void:
	bot_clock+=dt
	for key in bots:
		var n: Node3D=bots[key]; var goal: Vector3=n.get_meta("goal",n.position); var step=goal-n.position
		var flat=Vector3(step.x,0,step.z)
		if flat.length()>0.03:
			n.position+=flat.limit_length(dt*1.6); n.rotation.y=lerp_angle(n.rotation.y,atan2(-flat.x,-flat.z),minf(1.0,dt*8.0))
		n.position.y=lerpf(n.position.y,goal.y,minf(1.0,dt*6.0))
		var arm: Node3D=n.get_meta("arm")
		arm.rotation.x=sin(bot_clock*6.0)*0.6 if flat.length()<=0.03 and str(n.get_meta("action",""))!="待命" else 0.0
		n.get_meta("spray").emitting=str(n.get_meta("action",""))=="浇水" and flat.length()<=0.03
	if pulse_time<=0: return
	pulse_time-=dt; pulse.position.y+=dt*0.7; pulse.scale=Vector3.ONE*(0.5+pulse_time*3)
	if pulse_time<=0: pulse.hide()

## Robots near the player: at their dock when idle, beside the planter they are tending otherwise.
func sync_robots(field,c,at: Vector2,now: int) -> void:
	var wanted={}
	for key in c.blocks:
		var b: Dictionary=c.blocks[key]
		if b.kind!="farm_robot" or Vector2(float(b.x),float(b.z)).distance_to(at)>70.0: continue
		wanted[key]=true
		if not bots.has(key):
			bots[key]=_robot(); add_child(bots[key]); bots[key].position=Vector3(float(b.x),_floor(c,float(b.x),float(b.z),float(b.y))+0.14,float(b.z))
		var work: Dictionary=field.robot_work.get(key,{}); var goal=Vector3(float(b.x),_floor(c,float(b.x),float(b.z),float(b.y))+0.14,float(b.z))
		var period=int(field.rules.robots.period)
		var target: Dictionary=c.blocks.get(str(work.get("target","")),{})
		if not target.is_empty() and now-int(work.get("at",-99))<period:
			var p=Vector3(float(target.x),float(target.y),float(target.z)); var away=(goal-p); away.y=0
			goal=p+(away.normalized()*0.85 if away.length()>0.01 else Vector3(0.85,0,0)); goal.y=_floor(c,goal.x,goal.z,float(target.y))+0.02
		bots[key].set_meta("goal",goal); bots[key].set_meta("action",str(work.get("action","待命")) if not target.is_empty() else "待命")
	for key in bots.keys():
		if not wanted.has(key): bots[key].queue_free(); bots.erase(key)

## The surface a robot rolls on: natural ground can be a half cell above the block's cell.
func _floor(c,x: float,z: float,cell_y: float) -> float:
	return maxf(cell_y,c.terrain.ground(Vector2(x,z)))

func _robot() -> Node3D:
	var root=Node3D.new()
	var paint=func(hex: String):
		var m=StandardMaterial3D.new(); m.albedo_color=Color(hex); m.roughness=0.6; return m
	var part=func(parent: Node3D,size: Vector3,at: Vector3,hex: String) -> MeshInstance3D:
		var n=MeshInstance3D.new(); var b=BoxMesh.new(); b.size=size; n.mesh=b; n.position=at; n.material_override=paint.call(hex); parent.add_child(n); return n
	part.call(root,Vector3(0.46,0.22,0.56),Vector3(0,0.2,0),"6fd38f")
	part.call(root,Vector3(0.36,0.18,0.3),Vector3(0,0.4,0.06),"e8eef2")
	part.call(root,Vector3(0.22,0.06,0.04),Vector3(0,0.42,-0.1),"233c70")
	for x in [-0.27,0.27]:
		for z in [-0.18,0.18]: part.call(root,Vector3(0.08,0.16,0.16),Vector3(x,0.08,z),"2f3a42")
	var arm=Node3D.new(); arm.position=Vector3(0,0.36,-0.22); root.add_child(arm)
	part.call(arm,Vector3(0.06,0.06,0.3),Vector3(0,0,-0.15),"d9b45a")
	part.call(arm,Vector3(0.12,0.08,0.08),Vector3(0,-0.02,-0.32),"5b6670")
	var spray=CPUParticles3D.new(); spray.position=Vector3(0,0.4,-0.5); spray.amount=24; spray.lifetime=0.7; spray.direction=Vector3(0,0.3,-1); spray.spread=25.0
	spray.initial_velocity_min=1.0; spray.initial_velocity_max=1.6; spray.gravity=Vector3(0,-4,0); spray.emitting=false
	var drop=BoxMesh.new(); drop.size=Vector3.ONE*0.05; var dm=StandardMaterial3D.new(); dm.albedo_color=Color("8fd8ff"); dm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; drop.material=dm; spray.mesh=drop
	root.add_child(spray)
	root.set_meta("arm",arm); root.set_meta("spray",spray)
	return root

func sync(field,c,at: Vector2,now: int,organics=null) -> void:
	sync_robots(field,c,at,now)
	var cell=Vector2i(floori(at.x/8),floori(at.y/8)); var key=str([cell,field.revision])
	if key!=seen:
		seen=key; var st=G.surface(material); var count=0
		for n in field.nodes(Vector2(cell)*8,44):
			var p=Vector3(n.x,n.y,n.z); var depleted=field.remaining(n.id,now)>0
			var color=Color(field.rules.resources[n.kind].color)
			G.cube(st,p+Vector3(0,0.015,0),Vector3(1.2,0.03,1.2),Color("6d7550")); count+=1
			if n.kind=="timber":
				for i in range(1 if depleted else 4): G.cube(st,p+Vector3((i%2)*0.32-0.16,0.08+(i/2)*0.16,0),Vector3(0.18,0.15,0.85),color.darkened(0.2) if depleted else color)
			elif n.kind=="stone":
				for i in range(2 if depleted else 5): G.cube(st,p+Vector3(sin(i*4)*0.32,0.08+(i/3)*0.2,cos(i*4)*0.32),Vector3.ONE*(0.13 if depleted else 0.34),color)
			else:
				for i in range(4):
					var offset=Vector3(sin(i*3)*0.3,0,cos(i*3)*0.3); var height=0.15 if depleted else 0.65
					G.cube(st,p+offset+Vector3(0,height/2,0),Vector3(0.13,height,0.13),Color("75a85c"))
					if not depleted: G.cube(st,p+offset+Vector3(0,height,0),Vector3.ONE*(0.20 if n.kind=="fruit" else 0.12),color)
		resource_mesh.mesh=st.commit() if count>0 else null
	var signature=[]
	for id in field.gardens:
		var g=field.gardens[id]; signature.append([id,int(g.growth*12),int(g.moisture*8),int(organics.injury(id)*8) if organics!=null else 0])
	key=str([cell,signature])
	if key==crops_seen: return
	crops_seen=key; var st=G.surface(material); var count=0
	for id in field.gardens:
		var b=c.blocks[id]; var plot=field.gardens[id]; var p=Vector3(b.x,b.y+1.01,b.z)
		if Vector2(b.x,b.z).distance_to(at)>65: continue
		count+=1; G.cube(st,p,Vector3(0.80,0.02,0.8),Color("aa8a5b").lerp(Color("4e4033"),plot.moisture))
		for i in range(4):
			var h=0.06+plot.growth*0.65; var stem=p+Vector3((i%2)*0.4-0.2,h/2,(i/2)*0.4-0.2)
			G.cube(st,stem,Vector3(0.10,h,0.10),(Color("dec567") if plot.growth>=1 else Color("8bca68")).lerp(Color("a57445"),organics.injury(id) if organics!=null else 0))
			if organics!=null and organics.injury(id)>0.15: G.cube(st,stem+Vector3(0.1,h*0.3,0),Vector3(0.22,0.07,0.14),Color("b38342"))
			if plot.growth>0.55: G.cube(st,stem+Vector3(0,h/2,0),Vector3(0.18,0.15,0.18),Color("ead386"))
	crops_mesh.mesh=st.commit() if count>0 else null
