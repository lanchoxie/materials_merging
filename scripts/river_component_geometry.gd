extends RefCounted
const G=preload("res://scripts/river_geometry.gd")
static func draw(st: SurfaceTool,p: Vector3,kind: String,color: Color) -> void:
	if kind in ["sprinkler","oxygen_tower","co2_tower","fertilizer_spreader"]: _machine(st,p+Vector3(0,-0.5,0),kind,color); return
	if kind=="campfire":
		# v0.39: a ring of stones, crossed logs and a stepped flame (the view adds sparks and light).
		var base=p+Vector3(0,-0.5,0)
		for a in range(8):
			var ang=a*TAU/8; G.cube(st,base+Vector3(cos(ang)*0.38,0.08,sin(ang)*0.38),Vector3(0.2,0.16,0.2),Color("8d9497").darkened(0.08*(a%2)))
		for a in range(3):
			var ang=a*PI/3; var dir=Vector3(cos(ang),0,sin(ang))
			G.cube(st,base+Vector3(0,0.14,0),Vector3(0.62*absf(dir.x)+0.1,0.09,0.62*absf(dir.z)+0.1),Color("6a4a30"))
		G.cube(st,base+Vector3(0,0.3,0),Vector3(0.3,0.26,0.3),Color("ff8a3d"))
		G.cube(st,base+Vector3(0,0.5,0),Vector3(0.18,0.22,0.18),Color("ffc35a"))
		G.cube(st,base+Vector3(0,0.66,0),Vector3(0.08,0.14,0.08),Color("fff0a8"))
		return
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

# --- v0.44 building materials -------------------------------------------------------------------
## One shaped piece: slab, brick wall, door (2 cells, open or shut), window (glass on `glass_st`)
## or roof slope, in wood / stone / plastic / metal. `rot` turns it to face the way it was built.
static func piece(st: SurfaceTool, glass_st: SurfaceTool, b: Dictionary, rules: Dictionary) -> void:
	var kind: Dictionary=rules.kinds[b.kind]; var mat: Dictionary=rules.materials[str(kind.material)]
	var color=Color(str(mat.color)); var trim=Color(str(mat.trim)); var m=str(kind.material)
	var base=Vector3(float(b.x),float(b.y),float(b.z)); var r=int(b.get("rot",0))
	match str(kind.shape):
		"slab":
			_box(st,base,Vector3(0,0.25,0),Vector3(1,0.5,1),r,color)
			_surface_marks(st,base,0.5,m,color,trim,r)
		"brick":
			_box(st,base,Vector3(0,0.5,0),Vector3(1,1,1),r,color)
			if m=="metal":
				for x in [-0.3,0.0,0.3]: _box(st,base,Vector3(x,0.5,0),Vector3(0.05,1.0,1.012),r,trim)
				for x in [-0.3,0.0,0.3]: _box(st,base,Vector3(0,0.5,x),Vector3(1.012,1.0,0.05),r,trim)
			elif m=="plastic":
				_box(st,base,Vector3(0,0.06,0),Vector3(1.01,0.1,1.01),r,trim)
				_box(st,base,Vector3(0,0.94,0),Vector3(1.01,0.1,1.01),r,trim)
			else:
				# Courses of bricks (or logs): mortar lines, joints staggered row by row.
				var mortar=trim if m=="stone" else color.darkened(0.3)
				for y in [0.25,0.5,0.75]: _box(st,base,Vector3(0,y,0),Vector3(1.008,0.025,1.008),r,mortar)
				for row in range(4):
					var y=0.125+row*0.25; var offsets=[-0.25,0.25] if row%2==0 else [0.0]
					for o in offsets:
						_box(st,base,Vector3(o,y,0),Vector3(0.025,0.22,1.008),r,mortar)
						_box(st,base,Vector3(0,y,o),Vector3(1.008,0.22,0.025),r,mortar)
		"door":
			# Frame posts and lintel; the leaf shut in the middle, or swung back on its left hinge.
			for x in [-0.46,0.46]: _box(st,base,Vector3(x,1.0,0),Vector3(0.08,2.0,0.2),r,trim)
			_box(st,base,Vector3(0,1.96,0),Vector3(1.0,0.08,0.2),r,trim)
			var shut=not b.get("open",false)
			var leaf_at=Vector3(0,0.96,0) if shut else Vector3(-0.38,0.96,-0.42)
			var leaf_size=Vector3(0.84,1.9,0.08) if shut else Vector3(0.08,1.9,0.84)
			_box(st,base,leaf_at,leaf_size,r,color)
			if shut:
				for y in [0.5,1.4]: _box(st,base,Vector3(0,y,0),Vector3(0.7,0.5,0.1),r,color.lightened(0.08) if m!="metal" else trim.lightened(0.2))
				_box(st,base,Vector3(0.3,0.95,0),Vector3(0.06,0.06,0.16),r,Color("d9b45a"))
			else:
				_box(st,base,Vector3(-0.38,0.95,-0.12),Vector3(0.16,0.06,0.06),r,Color("d9b45a"))
		"window":
			for y in [0.06,0.94]: _box(st,base,Vector3(0,y,0),Vector3(1.0,0.12,0.22),r,trim)
			for x in [-0.44,0.44]: _box(st,base,Vector3(x,0.5,0),Vector3(0.12,1.0,0.22),r,trim)
			_box(st,base,Vector3(0,0.5,0),Vector3(0.05,0.8,0.08),r,trim)
			_box(st,base,Vector3(0,0.5,0),Vector3(0.8,0.05,0.08),r,trim)
			_box(st,base,Vector3(0,0.02,0.16),Vector3(1.0,0.04,0.12),r,color)
			var pane=Color(0.72,0.9,0.98,0.32)
			_box(glass_st if glass_st!=null else st,base,Vector3(0,0.5,0),Vector3(0.78,0.78,0.03),r,pane)
		"slope":
			_wedge(st,base,r,color)
			# Tile or seam lines across the roof face.
			for t in [0.25,0.5,0.75]:
				var y=0.05+0.95*t; var z=0.5-t
				_box(st,base,Vector3(0,y+0.015,z),Vector3(1.0,0.03,0.05),r,trim if m!="wood" else color.darkened(0.25))

## Seams on a slab's top: planks for wood, flagstones for stone, a rim for plastic, rivets for metal.
static func _surface_marks(st: SurfaceTool,base: Vector3,top: float,m: String,color: Color,trim: Color,r: int) -> void:
	match m:
		"wood":
			for x in [-0.25,0.0,0.25]: _box(st,base,Vector3(x,top,0),Vector3(0.02,0.012,1.002),r,color.darkened(0.3))
		"stone":
			_box(st,base,Vector3(0,top,0),Vector3(1.002,0.012,0.025),r,trim)
			_box(st,base,Vector3(0,top,0),Vector3(0.025,0.012,1.002),r,trim)
		"plastic":
			for z in [-0.47,0.47]: _box(st,base,Vector3(0,top,z),Vector3(1.0,0.012,0.06),r,trim)
		"metal":
			for x in [-0.4,0.4]:
				for z in [-0.4,0.4]: _box(st,base,Vector3(x,top,z),Vector3(0.05,0.03,0.05),r,trim.lightened(0.3))

## Turn a local offset by the piece's rotation (0 faces −z, then +x, +z, −x).
static func _turn(v: Vector3,r: int) -> Vector3:
	match posmod(r,4):
		1: return Vector3(-v.z,v.y,v.x)
		2: return Vector3(-v.x,v.y,-v.z)
		3: return Vector3(v.z,v.y,-v.x)
	return v

## An axis-aligned box given in the piece's local frame (base = the cell's floor centre).
static func _box(st: SurfaceTool,base: Vector3,at: Vector3,size: Vector3,r: int,color: Color) -> void:
	var s=size if posmod(r,2)==0 else Vector3(size.z,size.y,size.x)
	G.cube(st,base+_turn(at,r),s,color)

## A roof wedge: high (1 m) at the far side (local −z), low at the near side.
static func _wedge(st: SurfaceTool,base: Vector3,r: int,color: Color) -> void:
	var low=0.05
	var pts={"a":Vector3(-0.5,0,0.5),"b":Vector3(0.5,0,0.5),"c":Vector3(0.5,0,-0.5),"d":Vector3(-0.5,0,-0.5),
		"e":Vector3(-0.5,low,0.5),"f":Vector3(0.5,low,0.5),"g":Vector3(0.5,1,-0.5),"h":Vector3(-0.5,1,-0.5)}
	for k in pts: pts[k]=base+_turn(pts[k],r)
	var mid=base+Vector3(0,0.35,0)
	for f in [["e","f","g","h"],["d","c","b","a"],["c","d","h","g"],["a","b","f","e"],["b","c","g","f"],["d","a","e","h"]]:
		_outward(st,[pts[f[0]],pts[f[1]],pts[f[2]],pts[f[3]]],color,mid)

## Draws a quad facing away from `inside`, whatever order its corners were given in.
static func _outward(st: SurfaceTool,q: Array,color: Color,inside: Vector3) -> void:
	var normal=(q[2]-q[0]).cross(q[1]-q[0])
	var centre=(q[0]+q[1]+q[2]+q[3])*0.25
	if normal.dot(centre-inside)<0.0: q=[q[3],q[2],q[1],q[0]]
	G.face(st,q,color)

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
