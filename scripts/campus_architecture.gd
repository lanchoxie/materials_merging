extends RefCounted
## Distinct silhouettes with shared palette; upgrades add wings, balconies or floors.
## v0.27: every building also has three visual tiers across its levels (plot.tier, 1..3):
## wood planks → brick with trim → white walls, glass and solar panels.
const WALLS=[Color("dcc39c"),Color("c9806a"),Color("eef2ef")]
const TRIM=[Color("9a7652"),Color("f1e3c8"),Color("8fd3dc")]

static func build(v, parent: Node3D, plot: Dictionary, detail: bool) -> void:
	var level: int = int(plot.get("building_level",1))
	var tier: int = clampi(int(plot.get("tier",1)),1,3)
	var kind: String = plot.kind
	if kind == "house": kind = "engineer_house"
	if kind == "garden": kind = "park"
	parent.set_meta("architecture",kind)
	parent.set_meta("tier",tier)
	match kind:
		"engineer_house": _cottage(v,parent,tier,detail)
		"academician_villa": _villa(v,parent,level,tier,detail)
		"professor_apartment": _professor(v,parent,level,tier,detail)
		"park": _park(v,parent,tier,detail)
		_: _public(v,parent,kind,level,tier,detail)

## Front-face details shared by all houses. front: z of the facade, y0/y1: wall band.
static func _facade(v, p: Node3D, tier: int, width: float, y0: float, y1: float, front: float, detail: bool) -> void:
	if not detail: return
	match tier:
		1:
			var y=y0+0.12
			while y<y1-0.05:
				v.box(p,Vector3(width,0.018,0.02),Vector3(0,y,front+0.012),TRIM[0]); y+=0.16
		2:
			for x in [-width*0.5+0.03,width*0.5-0.03]: v.box(p,Vector3(0.07,y1-y0,0.03),Vector3(x,(y0+y1)*0.5,front+0.012),TRIM[1])
			v.box(p,Vector3(width+0.04,0.05,0.035),Vector3(0,y1-0.02,front+0.014),TRIM[1])
			for x in [-width*0.28,width*0.28]:
				v.box(p,Vector3(0.26,0.07,0.09),Vector3(x,y0+0.24,front+0.05),Color("8f6146"))
				for dx in [-0.07,0.0,0.07]: v.ball(p,0.035,Vector3(x+dx,y0+0.30,front+0.05),Color("ef8fa6") if dx==0.0 else Color("f4d06f"))
		3:
			v.box(p,Vector3(width*0.86,(y1-y0)*0.62,0.025),Vector3(0,(y0+y1)*0.5+0.04,front+0.013),TRIM[2])
			for x in [-width*0.29,0.0,width*0.29]: v.box(p,Vector3(0.025,(y1-y0)*0.62,0.035),Vector3(x,(y0+y1)*0.5+0.04,front+0.02),Color("f7faf8"))

## Roof extras: a chimney for brick, solar panels and a flag for glass.
static func _roof(v, p: Node3D, tier: int, top: float, width: float, depth: float, detail: bool) -> void:
	if tier==2:
		v.box(p,Vector3(0.18,0.34,0.18),Vector3(width*0.28,top+0.14,-depth*0.22),Color("a8574a"))
		v.box(p,Vector3(0.22,0.05,0.22),Vector3(width*0.28,top+0.32,-depth*0.22),Color("5d4a44"))
	elif tier==3:
		for x in [-width*0.22,width*0.12]:
			var panel=v.box(p,Vector3(width*0.3,0.03,depth*0.42),Vector3(x,top+0.10,-depth*0.08),Color("2f4f7a")); panel.rotation.x=-0.35
		if detail:
			v.box(p,Vector3(0.025,0.55,0.025),Vector3(width*0.42,top+0.30,depth*0.3),Color("e8e8e0"))
			v.box(p,Vector3(0.20,0.12,0.012),Vector3(width*0.42+0.11,top+0.50,depth*0.3),Color("e7776d"))

static func _cottage(v, p: Node3D, tier: int, detail: bool) -> void:
	var wall=WALLS[tier-1]
	v.box(p,Vector3(1.89,0.14,1.74),Vector3(0,0.16,0),Color("dfcfb1"))
	v.box(p,Vector3(1.52,1.03,1.27),Vector3(0,0.73,-0.12),wall)
	v.box(p,Vector3(1.55,0.15,1.30),Vector3(0,0.27,-0.12),Color("9ccfb9") if tier<3 else Color("dfe8e4"))
	var roof_color=[Color("a0764f"),Color("db947b"),Color("5f8f9a")][tier-1]
	for side in [-1.0,1.0]:
		var roof=v.box(p,Vector3(0.99,0.15,1.61),Vector3(side*0.40,1.42,-0.12),roof_color)
		roof.rotation_degrees.z=side*-31.0
	v.box(p,Vector3(0.34,0.69,0.045),Vector3(-0.23,0.60,0.537),Color("4f8c8a"))
	v.box(p,Vector3(0.38,0.37,0.05),Vector3(0.40,0.85,0.55),Color("4f8c8a"))
	v.box(p,Vector3(0.29,0.27,0.028),Vector3(0.40,0.85,0.59),Color("cae9dc"))
	v.box(p,Vector3(0.58,0.1,0.35),Vector3(-0.23,0.26,0.70),Color("d4d8ba"))
	_facade(v,p,tier,1.52,0.34,1.22,0.51,detail)
	if tier==2: v.box(p,Vector3(0.20,0.40,0.20),Vector3(0.42,1.62,-0.48),Color("a8574a"))
	if tier==3:
		for x in [-0.42,0.42]:
			var panel=v.box(p,Vector3(0.62,0.03,0.9),Vector3(x*0.98,1.47,-0.18),Color("2f4f7a")); panel.rotation_degrees.z=-31.0 if x>0 else 31.0; panel.position.y+=0.07
	if detail:
		v.ball(p,0.26,Vector3(0.73,0.30,0.80),Color("84c4a1"))
		if tier==1: v.box(p,Vector3(0.30,0.22,0.22),Vector3(-0.75,0.30,0.72),Color("b48a5e"))

static func _villa(v, p: Node3D, level: int, tier: int, detail: bool) -> void:
	# Low, asymmetric courtyard villa; a second level is an annex, never a tower.
	var wall=[Color("e9d6b4"),Color("d99a80"),Color("f4f1ea")][tier-1]
	v.box(p,Vector3(2.14,0.10,2.05),Vector3(0,0.16,0),Color("e6d6b8"))
	v.box(p,Vector3(1.12,1.14,1.2),Vector3(-0.43,0.78,-0.28),wall)
	v.box(p,Vector3(0.85,0.73,1.12),Vector3(0.52,0.58,-0.32),wall.darkened(0.08))
	v.box(p,Vector3(1.34,0.14,1.46),Vector3(-0.43,1.42,-0.28),Color("455d69"))
	v.box(p,Vector3(1.04,0.13,1.35),Vector3(0.52,1.02,-0.32),Color("637a7e"))
	v.box(p,Vector3(0.95,0.67,0.025),Vector3(-0.44,0.8,0.334),Color("73b4bd"))
	v.box(p,Vector3(0.90,0.06,0.48),Vector3(-0.43,0.32,0.59),Color("ccac7e"))
	# Pool, pergola and two slim cypress trees distinguish this from the cottage.
	v.box(p,Vector3(0.79,0.07,0.59),Vector3(0.57,0.23,0.67),Color("68c9cf"))
	v.box(p,Vector3(0.90,0.06,0.63),Vector3(-0.5,1.09,0.67),Color("c2a574"))
	for x in [-0.90,-0.11]: v.box(p,Vector3(0.055,0.81,0.055),Vector3(x,0.66,0.92),Color("d3ba8b"))
	if detail:
		for x in [-0.94,0.96]:
			var tree = v.ball(p,0.17,Vector3(x,0.64,-0.95),Color("679580")); tree.scale.y=2.3
		for x in [-0.67,-0.25]: v.box(p,Vector3(0.035,0.68,0.05),Vector3(x,0.8,0.35),Color("d0ac76"))
	if level>1:
		v.box(p,Vector3(0.69,0.27,0.73),Vector3(0.52,1.20,-0.33),Color("a9d4cf"))
		v.box(p,Vector3(0.78,0.06,0.81),Vector3(0.52,1.36,-0.33),Color("e4d8b9"))
	_roof(v,p,tier,1.49,1.2,1.2,detail)

static func _professor(v,p: Node3D,level: int,tier: int,detail: bool) -> void:
	var wall=[Color("e1cfae"),Color("cf8a70"),Color("eef2ef")][tier-1]
	v.box(p,Vector3(1.82,0.17,1.67),Vector3(0,0.20,0),Color("7c899a"))
	for floor_index in range(level):
		var y=0.52+float(floor_index)*0.48
		var offset=0.12 if floor_index%2==0 else -0.12
		v.box(p,Vector3(1.60,0.46,1.28),Vector3(offset,y,-0.13),wall)
		v.box(p,Vector3(1.72,0.065,1.51),Vector3(offset,y-0.23,-0.02),Color("a79bb4"))
		v.box(p,Vector3(1.39,0.22,0.04),Vector3(offset,y,0.535),TRIM[2] if tier==3 else Color("7caeb7"))
		if detail:
			v.box(p,Vector3(1.64,0.06,0.38),Vector3(offset,y-0.15,0.67),Color("f1e8d4"))
			v.box(p,Vector3(1.62,0.16,0.045),Vector3(offset,y-0.02,0.85),Color("aec9ca"))
			v.box(p,Vector3(0.20,0.16,0.18),Vector3(offset+0.52,y,0.75),Color("799b85"))
	var top=0.34+0.48*level
	v.box(p,Vector3(1.96,0.13,1.64),Vector3(0,top+0.10,-0.06),Color("686d88"))
	v.box(p,Vector3(0.57,0.17,0.55),Vector3(-0.46,top+0.22,-0.37),Color("8fba99"))
	v.box(p,Vector3(0.34,0.35,0.08),Vector3(0,0.45,0.65),Color("416a79"))
	_roof(v,p,tier,top+0.16,1.8,1.5,detail)

static func _park(v,p: Node3D,tier: int,detail: bool) -> void:
	v.box(p,Vector3(2.12,0.09,2.0),Vector3(0,0.17,0),Color("83b597"))
	var paving=[Color("e0d4b0"),Color("d7b39a"),Color("e9ecea")][tier-1]
	for z in [-0.55,0.15,0.65]: v.box(p,Vector3(0.55,0.035,0.39),Vector3(-0.15,0.23,z),paving)
	v.box(p,Vector3(0.65,0.075,0.65),Vector3(0.50,0.25,-0.25),Color("82d6d6"))
	for point in [Vector3(-0.73,0,-0.63),Vector3(0.76,0,-0.65)]:
		v.box(p,Vector3(0.11,0.57,0.11),point+Vector3(0,0.53,0),Color("ad8967"))
		v.ball(p,0.39,point+Vector3(0,1.0,0),Color("84c4a1") if tier<3 else Color("f3b8cb"))
	v.box(p,Vector3(0.64,0.10,0.22),Vector3(0.59,0.42,0.57),Color("ddb992"))
	v.box(p,Vector3(0.64,0.30,0.07),Vector3(0.59,0.55,0.66),Color("bd9976"))
	if tier>=2:
		# A small fountain in the pond, and flower beds along the paving.
		v.box(p,Vector3(0.14,0.30,0.14),Vector3(0.50,0.38,-0.25),Color("e7ded0"))
		v.ball(p,0.10,Vector3(0.50,0.58,-0.25),Color("bfeaf0"))
		if detail:
			for z in [-0.55,0.15]: v.ball(p,0.09,Vector3(-0.62,0.28,z),Color("ef8fa6"))
	if tier==3 and detail:
		v.box(p,Vector3(0.05,0.9,0.05),Vector3(-0.9,0.62,0.8),Color("386270"))
		v.ball(p,0.11,Vector3(-0.9,1.1,0.8),Color("ffe0a7"))
	if detail:
		for x in [-0.8,-0.58]: v.ball(p,0.11,Vector3(x,0.32,0.68),Color("d9b0cc"))

static func _public(v,p: Node3D,kind: String,level: int,tier: int,detail: bool) -> void:
	var height=0.58+0.38*level
	var roof=Color({"doctor_dorm":"658eae","institute":"58a79e","canteen":"d3926c"}.get(kind,"759798"))
	var wall=[Color("e2cfab"),Color("cf8a70"),Color("eef2ef")][tier-1]
	v.box(p,Vector3(1.76,height,1.5),Vector3(0,height/2+0.16,0),wall)
	v.box(p,Vector3(1.96,0.13,1.7),Vector3(0,height+0.21,0),roof)
	v.box(p,Vector3(0.3,0.55,0.035),Vector3(0,0.43,0.77),Color("40646c"))
	if detail:
		for floor_index in range(level):
			for x in [-0.58,-0.28,0.28,0.58]: v.box(p,Vector3(0.19,0.20,0.035),Vector3(x,0.61+floor_index*0.38,0.77),Color("95c9c6"))
	_facade(v,p,tier,1.76,0.16,height+0.16,0.75,detail and tier!=3)
	if tier==3 and detail:
		v.box(p,Vector3(0.05,height,0.04),Vector3(-0.86,height/2+0.16,0.77),TRIM[2])
		v.box(p,Vector3(0.05,height,0.04),Vector3(0.86,height/2+0.16,0.77),TRIM[2])
	_roof(v,p,tier,height+0.28,1.9,1.6,detail)
	if kind=="institute":
		v.ball(p,0.38,Vector3(0,height+0.42,0),Color("8bd2cd"))
		v.box(p,Vector3(0.25,height,0.15),Vector3(-0.72,height/2+0.16,0.84),roof)
	if kind=="canteen":
		v.box(p,Vector3(1.96,0.10,0.62),Vector3(0,0.80,0.85),roof)
		for x in [-0.80,0.80]: v.box(p,Vector3(0.055,0.63,0.055),Vector3(x,0.48,1.02),Color("eadbbb"))
	if kind=="workshop":
		v.box(p,Vector3(0.9,0.6,0.06),Vector3(0,0.45,0.81),Color("668b91"))
		for x in [-0.65,0.1]:
			var light=v.box(p,Vector3(0.48,0.13,1.25),Vector3(x,height+0.32,0),Color("a1c6c5")); light.rotation.z=0.22
		v.box(p,Vector3(0.42,0.32,0.36),Vector3(0.8,0.26,0.95),Color("c19d6b"))
