extends RefCounted
const G=preload("res://scripts/river_geometry.gd")
static func draw(st: SurfaceTool,p: Vector3,kind: String,color: Color) -> void:
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
