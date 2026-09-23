extends RefCounted
## Distinct silhouettes with shared palette; upgrades add wings, balconies or floors.
static func build(v, parent: Node3D, plot: Dictionary, detail: bool) -> void:
	var level: int = int(plot.get("building_level",1))
	var kind: String = plot.kind
	if kind == "house": kind = "engineer_house"
	if kind == "garden": kind = "park"
	parent.set_meta("architecture",kind)
	match kind:
		"engineer_house":
			if v.world.has_method("_build_house"): v.world._build_house(parent)
			else: v.box(parent,Vector3(1.4,0.8,1.3),Vector3(0,0.5,0),Color("dec9a1"))
		"academician_villa": _villa(v,parent,level,detail)
		"professor_apartment": _professor(v,parent,level,detail)
		"park": _park(v,parent,detail)
		_: _public(v,parent,kind,level,detail)

static func _villa(v, p: Node3D, level: int, detail: bool) -> void:
	# Low, asymmetric courtyard villa; a second level is an annex, never a tower.
	v.box(p,Vector3(2.14,0.10,2.05),Vector3(0,0.16,0),Color("e6d6b8"))
	v.box(p,Vector3(1.12,1.14,1.2),Vector3(-0.43,0.78,-0.28),Color("f4ead3"))
	v.box(p,Vector3(0.85,0.73,1.12),Vector3(0.52,0.58,-0.32),Color("d6c3a2"))
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

static func _professor(v,p: Node3D,level: int,detail: bool) -> void:
	v.box(p,Vector3(1.82,0.17,1.67),Vector3(0,0.20,0),Color("7c899a"))
	for floor_index in range(level):
		var y=0.52+float(floor_index)*0.48
		var offset=0.12 if floor_index%2==0 else -0.12
		v.box(p,Vector3(1.60,0.46,1.28),Vector3(offset,y,-0.13),Color("e6e1dd"))
		v.box(p,Vector3(1.72,0.065,1.51),Vector3(offset,y-0.23,-0.02),Color("a79bb4"))
		v.box(p,Vector3(1.39,0.22,0.04),Vector3(offset,y,0.535),Color("7caeb7"))
		if detail:
			v.box(p,Vector3(1.64,0.06,0.38),Vector3(offset,y-0.15,0.67),Color("f1e8d4"))
			v.box(p,Vector3(1.62,0.16,0.045),Vector3(offset,y-0.02,0.85),Color("aec9ca"))
			v.box(p,Vector3(0.20,0.16,0.18),Vector3(offset+0.52,y,0.75),Color("799b85"))
	var top=0.34+0.48*level
	v.box(p,Vector3(1.96,0.13,1.64),Vector3(0,top+0.10,-0.06),Color("686d88"))
	v.box(p,Vector3(0.57,0.17,0.55),Vector3(-0.46,top+0.22,-0.37),Color("8fba99"))
	v.box(p,Vector3(0.34,0.35,0.08),Vector3(0,0.45,0.65),Color("416a79"))

static func _park(v,p: Node3D,detail: bool) -> void:
	v.box(p,Vector3(2.12,0.09,2.0),Vector3(0,0.17,0),Color("83b597"))
	for z in [-0.55,0.15,0.65]: v.box(p,Vector3(0.55,0.035,0.39),Vector3(-0.15,0.23,z),Color("e0d4b0"))
	v.box(p,Vector3(0.65,0.075,0.65),Vector3(0.50,0.25,-0.25),Color("82d6d6"))
	for point in [Vector3(-0.73,0,-0.63),Vector3(0.76,0,-0.65)]:
		v.box(p,Vector3(0.11,0.57,0.11),point+Vector3(0,0.53,0),Color("ad8967"))
		v.ball(p,0.39,point+Vector3(0,1.0,0),Color("84c4a1"))
	v.box(p,Vector3(0.64,0.10,0.22),Vector3(0.59,0.42,0.57),Color("ddb992"))
	v.box(p,Vector3(0.64,0.30,0.07),Vector3(0.59,0.55,0.66),Color("bd9976"))
	if detail:
		for x in [-0.8,-0.58]: v.ball(p,0.11,Vector3(x,0.32,0.68),Color("d9b0cc"))

static func _public(v,p: Node3D,kind: String,level: int,detail: bool) -> void:
	var height=0.58+0.38*level
	var roof=Color({"doctor_dorm":"658eae","institute":"58a79e","canteen":"d3926c"}.get(kind,"759798"))
	v.box(p,Vector3(1.76,height,1.5),Vector3(0,height/2+0.16,0),Color("e3e4d4"))
	v.box(p,Vector3(1.96,0.13,1.7),Vector3(0,height+0.21,0),roof)
	v.box(p,Vector3(0.3,0.55,0.035),Vector3(0,0.43,0.77),Color("40646c"))
	if detail:
		for floor_index in range(level):
			for x in [-0.58,-0.28,0.28,0.58]: v.box(p,Vector3(0.19,0.20,0.035),Vector3(x,0.61+floor_index*0.38,0.77),Color("95c9c6"))
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
