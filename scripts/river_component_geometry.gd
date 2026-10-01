extends RefCounted
const G=preload("res://scripts/river_geometry.gd")
static func draw(st: SurfaceTool,p: Vector3,kind: String,color: Color) -> void:
	if kind in ["sprinkler","oxygen_tower","co2_tower","fertilizer_spreader"]: _machine(st,p+Vector3(0,-0.5,0),kind,color); return
	if kind=="mixing_tank":
		G.cube(st,p+Vector3(0,-0.40,0),Vector3(0.88,0.18,0.88),Color("426969"))
		for x in [-0.36,0.36]:
			for z in [-0.36,0.36]: G.cube(st,p+Vector3(x,0.03,z),Vector3(0.085,0.82,0.085),color)
		for y in [-0.30,0.38]:
			for z in [-0.38,0.38]: G.cube(st,p+Vector3(0,y,z),Vector3(0.85,0.07,0.07),color)
			for x in [-0.38,0.38]: G.cube(st,p+Vector3(x,y,0),Vector3(0.07,0.07,0.85),color)
		G.cube(st,p+Vector3(0.44,-0.15,0),Vector3(0.12,0.12,0.18),Color("d5ac66"))
		G.cube(st,p+Vector3(0.47,-0.02,0),Vector3(0.06,0.16,0.06),Color("d5ac66"))
		for y in [-0.15,0.0,0.15]: G.cube(st,p+Vector3(-0.27,y,0.402),Vector3(0.12,0.025,0.025),Color("f6e1ad"))
		return
	if kind in ["trough","feeder"]:
		G.cube(st,p+Vector3(0,-0.42,0),Vector3(1,0.16,1),color.darkened(0.15))
		for x in [-0.44,0.44]: G.cube(st,p+Vector3(x,0,0),Vector3(0.12,1,1),color)
		for z in [-0.44,0.44]: G.cube(st,p+Vector3(0,0,z),Vector3(1,1,0.12),color)
		if kind=="feeder":
			for x in [-0.27,0,0.27]: G.cube(st,p+Vector3(x,0.3,-0.505),Vector3(0.07,0.6,0.03),color.lightened(0.3))
		return
	if kind=="fence":
		for x in [-0.4,0.4]: G.cube(st,p+Vector3(x,0,0),Vector3(0.18,1,0.9),color)
		for y in [-0.25,0.25]: G.cube(st,p+Vector3(0,y,0),Vector3(1,0.14,0.16),color.lightened(0.12))
		return
	G.cube(st,p,Vector3.ONE,color)
	match kind:
		"solar":
			G.cube(st,p+Vector3(0,0.505,0),Vector3(0.90,0.025,0.90),Color("233c70"))
			for x in [-0.3,0.0,0.3]: G.cube(st,p+Vector3(x,0.523,0),Vector3(0.012,0.01,0.88),Color("88cbd9"))
		"planter":
			G.cube(st,p+Vector3(0,0.505,0),Vector3(0.80,0.01,0.80),Color("967a50"))
			for z in [-0.45,0.45]: G.cube(st,p+Vector3(0,0.5,z),Vector3(1.02,0.12,0.12),color.lightened(0.2))
			for x in [-0.45,0.45]: G.cube(st,p+Vector3(x,0.5,0),Vector3(0.12,0.12,1.02),color.lightened(0.2))
		"roof":
			for x in [-0.4,-0.2,0,0.2,0.4]: G.cube(st,p+Vector3(x,0.51,0),Vector3(0.12,0.06,1.03),color.lightened(0.15))
			for z in [-0.3,0.3]: G.cube(st,p+Vector3(0,0.56,z),Vector3(1,0.025,0.035),Color("795c3b"))
		"floor":
			G.cube(st,p+Vector3(0,0.505,0),Vector3(1.002,0.015,0.025),color.darkened(0.25))
			for x in [-0.24,0.24]: G.cube(st,p+Vector3(x,0.505,0),Vector3(0.025,0.015,1.002),color.darkened(0.25))
		_:
			for y in [-0.25,0.25]: G.cube(st,p+Vector3(0,y,0),Vector3(1.004,0.015,1.004),Color("97704e"))

## v0.32 Earth machines: one 1 m footprint each, tall silhouettes that read from far away.
## p is the ground point of the block. Animated sprays and smoke are added by the view.
static func _machine(st: SurfaceTool,p: Vector3,kind: String,color: Color) -> void:
	var steel=Color("5b6670"); var dark=Color("2f3a42"); var glow=Color("9ff3ff")
	G.cube(st,p+Vector3(0,0.08,0),Vector3(1.0,0.16,1.0),dark)
	G.cube(st,p+Vector3(0,0.17,0),Vector3(0.86,0.04,0.86),Color("d9b45a"))
	match kind:
		"sprinkler":
			for a in range(8):
				var ang=a*TAU/8; G.cube(st,p+Vector3(cos(ang)*0.3,0.55,sin(ang)*0.3),Vector3(0.22,0.7,0.22),color.darkened(0.1 if a%2==0 else 0.0))
			G.cube(st,p+Vector3(0,0.92,0),Vector3(0.7,0.06,0.7),glow.darkened(0.2))
			G.cube(st,p+Vector3(0,1.6,0),Vector3(0.12,1.3,0.12),steel)
			for y in [1.2,1.7]: G.cube(st,p+Vector3(0,y,0),Vector3(0.2,0.05,0.2),Color("d9b45a"))
			for a in range(4):
				var ang=a*TAU/4+0.4; var dir=Vector3(cos(ang),0,sin(ang))
				G.cube(st,p+Vector3(0,2.25,0)+dir*0.38,Vector3(0.76 if a%2==0 else 0.08,0.06,0.08 if a%2==0 else 0.76),steel.lightened(0.2))
				G.cube(st,p+Vector3(0,2.22,0)+dir*0.74,Vector3(0.12,0.12,0.12),glow)
			G.cube(st,p+Vector3(0,2.32,0),Vector3(0.22,0.14,0.22),color.lightened(0.3))
		"oxygen_tower":
			G.cube(st,p+Vector3(0,1.5,0),Vector3(0.42,2.7,0.42),Color("e8eef2"))
			for y in [0.6,1.2,1.8,2.4]:
				G.cube(st,p+Vector3(0,y,0),Vector3(0.62,0.08,0.62),glow)
				G.cube(st,p+Vector3(0,y+0.06,0),Vector3(0.5,0.04,0.5),color.darkened(0.3))
			for side in [-1,1]:
				G.cube(st,p+Vector3(side*0.36,0.6,0.18),Vector3(0.2,0.8,0.2),steel); G.cube(st,p+Vector3(side*0.36,1.02,0.18),Vector3(0.24,0.06,0.24),glow.darkened(0.3))
			G.cube(st,p+Vector3(0,2.95,0),Vector3(0.16,0.3,0.16),steel)
			G.cube(st,p+Vector3(0,3.15,0),Vector3(0.22,0.12,0.22),Color("ffffff"))
		"co2_tower":
			G.cube(st,p+Vector3(-0.18,0.5,0.2),Vector3(0.5,0.62,0.5),steel)
			G.cube(st,p+Vector3(-0.18,0.84,0.2),Vector3(0.4,0.06,0.4),Color("e0a548"))
			for z in [-0.3,0.08]: G.cube(st,p+Vector3(0.3,0.55,z),Vector3(0.28,0.7,0.28),color)
			G.cube(st,p+Vector3(0.12,1.6,-0.15),Vector3(0.34,2.6,0.34),Color("6b6158"))
			for y in [1.0,1.9,2.7]: G.cube(st,p+Vector3(0.12,y,-0.15),Vector3(0.4,0.1,0.4),Color("c94f3d") if y>2.5 else Color("e0a548"))
			G.cube(st,p+Vector3(0.12,2.95,-0.15),Vector3(0.44,0.08,0.44),dark)
		"fertilizer_spreader":
			for x in [-0.32,0.32]:
				for z in [-0.32,0.32]: G.cube(st,p+Vector3(x,0.6,z),Vector3(0.08,0.9,0.08),steel)
			for i in range(5):
				var w=0.3+i*0.16; G.cube(st,p+Vector3(0,1.0+i*0.17,0),Vector3(w,0.17,w),color.darkened(0.05*(i%2)))
			G.cube(st,p+Vector3(0,1.9,0),Vector3(1.0,0.06,1.0),color.lightened(0.25))
			G.cube(st,p+Vector3(0,0.82,0),Vector3(0.08,0.2,0.08),dark)
			G.cube(st,p+Vector3(0,0.7,0),Vector3(0.8,0.04,0.12),steel.lightened(0.25)); G.cube(st,p+Vector3(0,0.7,0),Vector3(0.12,0.04,0.8),steel.lightened(0.25))
			G.cube(st,p+Vector3(0.3,1.5,0.51),Vector3(0.3,0.18,0.02),Color("f4f0e6"))
			G.cube(st,p+Vector3(0.3,1.5,0.525),Vector3(0.16,0.06,0.01),Color("3f7a3c"))
