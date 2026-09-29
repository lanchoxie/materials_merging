extends RefCounted
## Small procedural furniture kit. Static pieces are baked once per visited floor.
const FONT=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
var materials={}
var wood=Color("997253")
var accent=Color("569c91")
var fabric=Color("cd875e")
var cream=Color("f2e9d5")
var dark=Color("374d53")
var gold=Color("d5b470")

func material(c: Color) -> StandardMaterial3D:
	var key=c.to_html()
	if not materials.has(key):
		var m=StandardMaterial3D.new(); m.albedo_color=c; m.roughness=1.0; materials[key]=m
	return materials[key]

func box(p: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh=BoxMesh.new(); mesh.size=size
	var n=MeshInstance3D.new(); n.mesh=mesh; n.position=at; n.material_override=material(color); p.add_child(n); return n

func ball(p: Node3D, radius: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh=SphereMesh.new(); mesh.radius=radius; mesh.height=radius*2; mesh.radial_segments=12; mesh.rings=6
	var n=MeshInstance3D.new(); n.mesh=mesh; n.position=at; n.material_override=material(color); p.add_child(n); return n

func label(p: Node3D,text: String,at: Vector3,size: float=0.0035) -> Label3D:
	var n=Label3D.new(); n.text=text; n.font=FONT; n.font_size=48; n.pixel_size=size; n.modulate=cream; n.outline_size=0; n.position=at; p.add_child(n); return n

func door(p: Node3D,width: float,height: float) -> Node3D:
	var hinge=Node3D.new(); p.add_child(hinge)
	box(hinge,Vector3(width,height,0.08),Vector3(width/2,height/2,0),accent)
	for y in [height*0.28,height*0.72]:
		box(hinge,Vector3(width*0.75,height*0.32,0.02),Vector3(width/2,y,0.05),accent.lightened(0.13))
	ball(hinge,0.045,Vector3(width-0.13,height*0.45,0.10),gold)
	ball(hinge,0.045,Vector3(width-0.13,height*0.45,-0.10),gold)
	return hinge

func shell(p: Node3D,plan) -> void:
	wood=Color(plan.spec.wood); accent=Color(plan.spec.accent); fabric=Color(plan.spec.fabric)
	var w=plan.width; var d=plan.depth; var wall=Color(plan.spec.wall)
	box(p,Vector3(w+0.15,0.24,d+0.15),Vector3(0,0,0),wood)
	for i in range(ceili(w/0.6)):
		var x=-w/2+0.3+i*0.6
		box(p,Vector3(minf(0.58,w/2-x+0.3),0.015,d),Vector3(x,0.13,0),wood.lightened(0.12 if i%2 else 0.05))
	box(p,Vector3(w,0.12,d),Vector3(0,3.18,0),cream)
	box(p,Vector3(w,3.1,0.16),Vector3(0,1.65,-d/2),wall)
	# Front wall has a real opening. Side windows are inset sky views rather than blank walls.
	for side in [-1,1]:
		box(p,Vector3((w-1.2)/2,3.1,0.16),Vector3(side*(w/4+0.3),1.65,d/2),wall)
		box(p,Vector3(0.16,3.1,d),Vector3(side*w/2,1.65,0),wall)
		box(p,Vector3(0.20,0.18,d),Vector3(side*(w/2-0.03),0.24,0),wood)
		box(p,Vector3(0.22,0.12,d),Vector3(side*(w/2-0.05),2.9,0),wood)
		window(p,Vector3(side*(w/2-0.12),1.9,-0.6),side)
	box(p,Vector3(1.3,0.85,0.16),Vector3(0,2.75,d/2),wall)
	for x in [-0.66,0.66]: box(p,Vector3(0.12,2.25,0.25),Vector3(x,1.23,d/2),wood)
	box(p,Vector3(1.45,0.14,0.25),Vector3(0,2.37,d/2),wood)
	box(p,Vector3(1.2,0.08,1.2),Vector3(0,0.08,d/2+0.6),wood)
	box(p,Vector3(1.18,2.2,0.05),Vector3(0,1.22,d/2+1.0),Color("9bbfbe"))
	box(p,Vector3(2.5,0.022,1.6),Vector3(0,0.15,d/2-1.8),accent.darkened(0.12))
	for x in [-1.15,1.15]: box(p,Vector3(0.035,0.01,1.4),Vector3(x,0.17,d/2-1.8),gold)
	# Paired pendant lamps and warm ceiling beams.
	for z in [-d/4,d/4]:
		box(p,Vector3(0.025,0.3,0.025),Vector3(0,2.98,z),dark)
		box(p,Vector3(0.65,0.12,0.48),Vector3(0,2.78,z),gold)
		box(p,Vector3(0.5,0.03,0.35),Vector3(0,2.69,z),Color("fff1c3"))
	if plan.kind=="academician_villa":
		for x in [-w/2+0.5,w/2-0.5]: box(p,Vector3(0.19,3.0,0.19),Vector3(x,1.62,0),gold)
	# Framed molecular wall art at the end of the room.
	box(p,Vector3(1.35,0.8,0.07),Vector3(0,2.53,-d/2+0.12),wood)
	box(p,Vector3(1.18,0.65,0.025),Vector3(0,2.53,-d/2+0.165),dark)
	for i in range(4): ball(p,0.10,Vector3((i-1.5)*0.26,2.53+sin(i*2)*0.16,-d/2+0.21),[accent,cream,gold,fabric][i])
	box(p,Vector3(1.15,0.025,0.02),Vector3(0,2.53,-d/2+0.19),cream)

func window(p: Node3D,at: Vector3,side: int) -> void:
	var frame=Node3D.new(); p.add_child(frame); frame.position=at; frame.rotation.y=-side*PI/2
	box(frame,Vector3(2.1,1.55,0.09),Vector3.ZERO,wood)
	box(frame,Vector3(1.91,1.35,0.05),Vector3(0,0,0.06),Color("aed8d8"))
	box(frame,Vector3(1.88,0.32,0.04),Vector3(0,-0.5,0.10),Color("8fb6a0"))
	for x in [-0.75,-0.2,0.42]:
		ball(frame,0.17,Vector3(x,0.35,0.11),cream).scale=Vector3(1.7,0.5,0.3)
	for x in [-0.95,0,0.95]: box(frame,Vector3(0.055,1.42,0.14),Vector3(x,0,0.12),cream)
	box(frame,Vector3(2.3,0.09,0.35),Vector3(0,-0.79,0.13),wood)
	for x in [-1.13,1.13]: box(frame,Vector3(0.22,1.65,0.14),Vector3(x,-0.07,0.11),fabric)

func furniture(p: Node3D,item: Dictionary,plan) -> void:
	var n=Node3D.new(); n.name=item.type+"_"+item.id; p.add_child(n); n.position=item.at+Vector3(0,0.12,0)
	match item.type:
		"bed":
			box(n,Vector3(1.25,0.3,2.1),Vector3(0,0.3,0),wood)
			box(n,Vector3(1.2,0.18,2.0),Vector3(0,0.54,0),cream)
			box(n,Vector3(1.21,0.06,1.35),Vector3(0,0.665,0.29),fabric)
			box(n,Vector3(0.86,0.12,0.36),Vector3(0,0.68,-0.69),cream.lightened(0.1))
			box(n,Vector3(1.3,0.82,0.08),Vector3(0,0.43,-1),wood)
			for x in [-0.5,0.5]: box(n,Vector3(0.05,0.025,1.3),Vector3(x,0.71,0.3),gold)
		"chair":
			legs(n,Vector2(0.5,0.5),0.48)
			box(n,Vector3(0.65,0.13,0.65),Vector3(0,0.53,0),fabric)
			box(n,Vector3(0.65,0.52,0.1),Vector3(0,0.81,0.26),wood)
			box(n,Vector3(0.52,0.32,0.06),Vector3(0,0.84,0.19),fabric)
		"sofa":
			box(n,Vector3(1.9,0.36,0.85),Vector3(0,0.37,0),wood)
			box(n,Vector3(1.7,0.18,0.70),Vector3(0,0.58,0),fabric)
			box(n,Vector3(1.9,0.68,0.14),Vector3(0,0.67,-0.36),fabric)
			for x in [-0.89,0.89]: box(n,Vector3(0.18,0.32,0.85),Vector3(x,0.72,0),fabric.lightened(0.15))
			for x in [-0.55,0.55]: box(n,Vector3(0.33,0.3,0.14),Vector3(x,0.81,-0.2),cream)
		"desk","tea":
			var high=0.86 if item.type=="desk" else 0.43
			legs(n,Vector2(item.size.x-0.2,item.size.z-0.2),high)
			box(n,Vector3(item.size.x,0.08,item.size.z),Vector3(0,high,0),wood if item.type=="desk" else cream)
			box(n,Vector3(0.38,0.04,0.27),Vector3(-0.24,high+0.06,0.1),accent)
			box(n,Vector3(0.19,0.19,0.19),Vector3(0.43,high+0.13,0),cream)
			if item.type=="desk":
				box(n,Vector3(0.45,0.3,0.05),Vector3(0.15,high+0.25,-0.20),dark)
				box(n,Vector3(0.37,0.23,0.012),Vector3(0.15,high+0.25,-0.164),accent.lightened(0.45))
				if plan.kind=="professor_apartment" and plan.level>=2:
					box(n,Vector3(0.16,0.04,0.16),Vector3(-0.6,high+0.06,-0.12),gold)
					box(n,Vector3(0.035,0.4,0.035),Vector3(-0.6,high+0.28,-0.12),gold)
					box(n,Vector3(0.25,0.1,0.18),Vector3(-0.55,high+0.5,-0.12),accent)
		"shelf":
			box(n,Vector3(1.9,2.35,0.06),Vector3(0,1.18,-0.21),wood.darkened(0.12))
			for x in [-0.92,0.92]: box(n,Vector3(0.06,2.4,0.48),Vector3(x,1.2,0),wood)
			for row in range(5):
				box(n,Vector3(1.9,0.07,0.48),Vector3(0,row*0.48+0.08,0),wood)
				for col in range(8): box(n,Vector3(0.10+0.015*(col%3),0.24+0.04*(col%3),0.27),Vector3(-0.72+col*0.2,row*0.48+0.26,0.025),[accent,fabric,gold,cream][(col+row+plan.floor_number)%4])
		"cabinet":
			box(n,Vector3(1.15,1.7,0.65),Vector3(0,0.85,0),wood)
			for x in [-0.29,0.29]:
				box(n,Vector3(0.51,1.53,0.04),Vector3(x,0.86,0.34),accent)
				box(n,Vector3(0.04,0.20,0.04),Vector3(x*0.3,0.86,0.38),gold)
		"snack":
			box(n,Vector3(1.2,0.85,0.65),Vector3(0,0.43,0),wood)
			box(n,Vector3(0.4,0.48,0.35),Vector3(-0.25,1.1,0),accent)
			ball(n,0.13,Vector3(-0.25,1.42,0),Color("9fced7"))
			for x in [0.2,0.43]: box(n,Vector3(0.15,0.2,0.15),Vector3(x,0.96,0),fabric)
		"display":
			box(n,Vector3(0.9,0.82,0.6),Vector3(0,0.42,0),wood)
			box(n,Vector3(0.95,0.08,0.65),Vector3(0,0.87,0),gold)
			var crystal=box(n,Vector3(0.31,0.4,0.31),Vector3(0,1.19,0),accent.lightened(0.28)); crystal.rotation=Vector3(0.2,0.6,0.3)
			for x in [-0.32,0.32]: ball(n,0.09,Vector3(x,1.02,0),gold)
		"garden":
			box(n,Vector3(2.5,0.23,2.0),Vector3(0,0.13,0),wood)
			box(n,Vector3(2.28,0.08,1.8),Vector3(0,0.27,0),Color("86b8ab"))
			for i in range(3):
				box(n,Vector3(0.09,1.45,0.09),Vector3((i-1)*0.6,0.85,-0.15),wood)
				ball(n,0.42,Vector3((i-1)*0.6,1.65+0.15*(i%2),-0.15),accent).scale=Vector3(0.75,1.2,0.75)
		"plant":
			box(n,Vector3(0.4,0.4,0.4),Vector3(0,0.2,0),cream)
			box(n,Vector3(0.06,0.4,0.06),Vector3(0,0.6,0),wood)
			ball(n,0.28,Vector3(0,0.88,0),accent).scale=Vector3(0.8,1.4,0.8)
		"divider":
			for i in range(7): box(n,Vector3(0.12,2.65,0.1),Vector3(0,1.33,-1.08+i*0.36),wood)
			box(n,Vector3(0.12,0.1,2.3),Vector3(0,2.6,0),gold)
		"lift":
			box(n,Vector3(0.45,1.6,0.25),Vector3(0,0.8,0),wood)
			box(n,Vector3(0.36,0.4,0.04),Vector3(0,1.25,0.15),accent)
			label(n,"%dF" % plan.floor_number,Vector3(0,1.25,0.18),0.003)
			ball(n,0.065,Vector3(0,0.9,0.18),gold)

func legs(p: Node3D,size: Vector2,height: float) -> void:
	for x in [-size.x/2,size.x/2]:
		for z in [-size.y/2,size.y/2]: box(p,Vector3(0.07,height,0.07),Vector3(x,height/2,z),wood)
