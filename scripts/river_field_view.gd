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

func _ready() -> void:
	resource_mesh=MeshInstance3D.new(); add_child(resource_mesh)
	crops_mesh=MeshInstance3D.new(); add_child(crops_mesh)
	pulse=MeshInstance3D.new(); var mesh=SphereMesh.new(); mesh.radius=0.10; mesh.height=0.2; pulse.mesh=mesh
	var m=StandardMaterial3D.new(); m.albedo_color=Color("ffe2a1"); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; pulse.material_override=m; add_child(pulse); pulse.hide()

func feedback(at: Vector3) -> void:
	pulse.position=at; pulse_time=0.45; pulse.show()

func _process(dt: float) -> void:
	if pulse_time<=0: return
	pulse_time-=dt; pulse.position.y+=dt*0.7; pulse.scale=Vector3.ONE*(0.5+pulse_time*3)
	if pulse_time<=0: pulse.hide()

func sync(field,c,at: Vector2,now: int,organics=null) -> void:
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
