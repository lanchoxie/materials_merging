extends RefCounted
## v0.33 planet creatures: a merged body mesh with separate legs and a tail, so animals walk with a
## real gait instead of sliding. Display only; the population model never reads any of this.
## Front is -Z (the views turn nodes toward their movement with atan2(-dx,-dz)).
const G=preload("res://scripts/river_geometry.gd")
const Figure=preload("res://scripts/figure_geometry.gd")
static var _cache: Dictionary={}
## Whole-creature bounds (legs and tail included) for hitboxes and culling.
const BOUNDS={"meadow_herbivore":AABB(Vector3(-0.2,0,-0.56),Vector3(0.4,0.9,0.9)),"woodland_boar":AABB(Vector3(-0.28,0,-0.76),Vector3(0.56,0.78,1.16)),
	"marsh_fish":AABB(Vector3(-0.12,-0.1,-0.22),Vector3(0.24,0.25,0.62)),
	"mammoth":AABB(Vector3(-0.9,0,-2.0),Vector3(1.8,3.3,3.6)),"woolly_rhino":AABB(Vector3(-0.6,0,-1.9),Vector3(1.2,1.9,3.2)),"person":AABB(Vector3(-0.32,0,-0.26),Vector3(0.64,1.62,0.52)),
	"sand_scorpion":AABB(Vector3(-0.28,0,-0.4),Vector3(0.56,0.5,0.7)),
	"desert_lizard":AABB(Vector3(-0.18,0,-0.5),Vector3(0.36,0.38,0.9)),
	"frost_bear":AABB(Vector3(-0.45,0,-0.8),Vector3(0.9,1.5,1.4)),
	"ice_crawler":AABB(Vector3(-0.22,0,-0.35),Vector3(0.44,0.4,0.6))}

static func _key(kind: String,part: String,material: Material) -> String:
	return "%s:%s:%d" % [kind,part,material.get_instance_id()]

static func _mesh(kind: String,part: String,material: Material) -> ArrayMesh:
	var key=_key(kind,part,material)
	if _cache.has(key): return _cache[key]
	var st=G.surface(material); var ink=Color("2a2f33")
	match kind+":"+part:
		"meadow_herbivore:body":
			var coat=Color("c9925e")
			G.cube(st,Vector3(0,0.43,0),Vector3(0.3,0.27,0.56),coat)
			G.cube(st,Vector3(0,0.3,0),Vector3(0.24,0.03,0.44),Color("f0dcc0"))
			for p in [Vector3(-0.07,0,-0.12),Vector3(0.06,0,-0.02),Vector3(-0.05,0,0.1),Vector3(0.08,0,0.16),Vector3(0,0,0.04)]:
				G.cube(st,Vector3(p.x,0.566,p.z),Vector3(0.05,0.006,0.05),Color("f6ead5"))
			G.cube(st,Vector3(0,0.6,-0.25),Vector3(0.14,0.24,0.14),coat)
			G.cube(st,Vector3(0,0.56,-0.31),Vector3(0.1,0.12,0.04),Color("f0dcc0"))
			G.cube(st,Vector3(0,0.75,-0.33),Vector3(0.17,0.16,0.22),coat.lightened(0.04))
			G.cube(st,Vector3(0,0.72,-0.47),Vector3(0.1,0.09,0.1),Color("dcb68d"))
			G.cube(st,Vector3(0,0.745,-0.523),Vector3(0.05,0.03,0.012),ink)
			for side in [-1,1]:
				G.cube(st,Vector3(side*0.087,0.78,-0.37),Vector3(0.008,0.035,0.035),ink)
				G.cube(st,Vector3(side*0.0915,0.79,-0.38),Vector3(0.004,0.012,0.012),Color("ffffff"))
				G.cube(st,Vector3(side*0.135,0.84,-0.29),Vector3(0.12,0.05,0.07),coat.darkened(0.08))
				G.cube(st,Vector3(side*0.14,0.846,-0.29),Vector3(0.09,0.03,0.035),Color("e8b3a5"))
		"meadow_herbivore:leg":
			G.cube(st,Vector3(0,-0.13,0),Vector3(0.06,0.26,0.06),Color("b98454"))
			G.cube(st,Vector3(0,-0.275,0),Vector3(0.065,0.04,0.07),Color("3b2f28"))
		"meadow_herbivore:tail":
			G.cube(st,Vector3(0,-0.02,0.03),Vector3(0.07,0.09,0.06),Color("f6ead5"))
		"woodland_boar:body":
			var hide=Color("7f5e4b")
			G.cube(st,Vector3(0,0.42,0),Vector3(0.5,0.42,0.74),hide)
			G.cube(st,Vector3(0,0.3,0),Vector3(0.44,0.1,0.6),hide.darkened(0.12))
			G.cube(st,Vector3(0,0.65,-0.04),Vector3(0.14,0.08,0.62),Color("4e3a2e"))
			G.cube(st,Vector3(0,0.72,-0.22),Vector3(0.1,0.06,0.2),Color("4e3a2e"))
			G.cube(st,Vector3(0,0.42,-0.48),Vector3(0.36,0.32,0.26),hide.lightened(0.08))
			G.cube(st,Vector3(0,0.34,-0.66),Vector3(0.22,0.16,0.14),Color("b9897a"))
			G.cube(st,Vector3(0,0.34,-0.733),Vector3(0.16,0.11,0.01),Color("8e5f55"))
			for side in [-1,1]:
				G.cube(st,Vector3(side*0.04,0.35,-0.74),Vector3(0.03,0.04,0.006),ink)
				G.cube(st,Vector3(side*0.12,0.37,-0.66),Vector3(0.035,0.14,0.035),Color("f2e4c1"))
				G.cube(st,Vector3(side*0.12,0.45,-0.66),Vector3(0.03,0.04,0.03),Color("fff6e0"))
				G.cube(st,Vector3(side*0.16,0.64,-0.42),Vector3(0.1,0.16,0.06),Color("5e4535"))
				G.cube(st,Vector3(side*0.181,0.5,-0.56),Vector3(0.004,0.04,0.04),ink)
				G.cube(st,Vector3(side*0.183,0.51,-0.565),Vector3(0.003,0.014,0.014),Color("ffffff"))
		"woodland_boar:leg":
			G.cube(st,Vector3(0,-0.1,0),Vector3(0.1,0.2,0.11),Color("624d43"))
			G.cube(st,Vector3(0,-0.215,-0.01),Vector3(0.105,0.05,0.12),Color("2c2420"))
		"woodland_boar:tail":
			G.cube(st,Vector3(0,-0.07,0.02),Vector3(0.03,0.14,0.03),Color("5e4535"))
			G.cube(st,Vector3(0,-0.15,0.02),Vector3(0.05,0.04,0.05),Color("3d2c22"))
		# v0.39 冰河期. Mammoth: ~3 m at the shoulder, high domed head and back, small ears (less heat
		# loss), long shaggy coat, curved tusks and a trunk.
		"mammoth:body":
			var fur=Color("6b4a32"); var long=Color("54392a"); var ivory=Color("efe4c8")
			G.cube(st,Vector3(0,1.85,0.1),Vector3(1.5,1.5,2.3),fur)
			G.cube(st,Vector3(0,2.7,-0.35),Vector3(1.2,0.5,1.1),fur.lightened(0.05))
			G.cube(st,Vector3(0,1.05,0.1),Vector3(1.56,0.35,2.2),long)
			for side in [-1,1]: G.cube(st,Vector3(side*0.78,1.35,0.1),Vector3(0.06,0.9,2.2),long)
			G.cube(st,Vector3(0,2.55,-1.3),Vector3(0.95,1.05,0.75),fur.lightened(0.08))
			G.cube(st,Vector3(0,3.1,-1.25),Vector3(0.7,0.35,0.55),fur.lightened(0.12))
			G.cube(st,Vector3(0,2.1,-1.72),Vector3(0.34,0.5,0.3),fur.darkened(0.05))
			G.cube(st,Vector3(0,1.55,-1.85),Vector3(0.26,0.6,0.24),fur.darkened(0.1))
			G.cube(st,Vector3(0,1.08,-1.9),Vector3(0.2,0.4,0.2),fur.darkened(0.15))
			G.cube(st,Vector3(0,0.86,-1.86),Vector3(0.22,0.1,0.26),fur.darkened(0.2))
			for side in [-1,1]:
				G.cube(st,Vector3(side*0.3,2.0,-1.75),Vector3(0.14,0.14,0.45),ivory)
				G.cube(st,Vector3(side*0.38,1.75,-2.0),Vector3(0.13,0.35,0.13),ivory)
				G.cube(st,Vector3(side*0.32,1.6,-2.2),Vector3(0.12,0.12,0.35),ivory)
				G.cube(st,Vector3(side*0.24,1.72,-2.4),Vector3(0.1,0.25,0.1),ivory)
				G.cube(st,Vector3(side*0.48,2.75,-1.25),Vector3(0.1,0.3,0.24),long)
				G.cube(st,Vector3(side*0.43,2.62,-1.68),Vector3(0.02,0.07,0.07),ink)
		"mammoth:leg":
			G.cube(st,Vector3(0,-0.55,0),Vector3(0.42,1.1,0.42),Color("5e4130"))
			G.cube(st,Vector3(0,-0.32,0),Vector3(0.5,0.5,0.5),Color("54392a"))
			G.cube(st,Vector3(0,-1.07,0),Vector3(0.44,0.08,0.44),Color("3a2a21"))
		"mammoth:tail":
			G.cube(st,Vector3(0,-0.2,0.04),Vector3(0.1,0.4,0.1),Color("54392a"))
			G.cube(st,Vector3(0,-0.45,0.04),Vector3(0.16,0.14,0.16),Color("3a2a21"))
		# Woolly rhino: ~1.8 m, a shoulder hump, a long low head carrying two horns.
		"woolly_rhino:body":
			var coat=Color("8a6a45"); var horn=Color("4a3f36")
			G.cube(st,Vector3(0,1.1,0.1),Vector3(1.0,0.95,2.1),coat)
			G.cube(st,Vector3(0,1.62,-0.45),Vector3(0.8,0.35,0.7),coat.lightened(0.05))
			G.cube(st,Vector3(0,0.68,0.1),Vector3(1.04,0.18,2.0),coat.darkened(0.15))
			G.cube(st,Vector3(0,0.95,-1.15),Vector3(0.55,0.55,0.75),coat.lightened(0.06))
			G.cube(st,Vector3(0,0.78,-1.55),Vector3(0.42,0.38,0.35),coat.lightened(0.1))
			G.cube(st,Vector3(0,1.15,-1.72),Vector3(0.14,0.5,0.14),horn)
			G.cube(st,Vector3(0,1.45,-1.85),Vector3(0.1,0.25,0.1),horn.darkened(0.1))
			G.cube(st,Vector3(0,1.15,-1.38),Vector3(0.1,0.24,0.1),horn)
			for side in [-1,1]:
				G.cube(st,Vector3(side*0.2,1.28,-0.98),Vector3(0.09,0.14,0.08),coat.darkened(0.1))
				G.cube(st,Vector3(side*0.27,1.0,-1.36),Vector3(0.02,0.05,0.05),ink)
		"woolly_rhino:leg":
			G.cube(st,Vector3(0,-0.3,0),Vector3(0.24,0.6,0.26),Color("6f5538"))
			G.cube(st,Vector3(0,-0.62,0),Vector3(0.26,0.06,0.28),Color("3a2f25"))
		"woolly_rhino:tail":
			G.cube(st,Vector3(0,-0.12,0.02),Vector3(0.05,0.24,0.05),Color("6f5538"))
		"marsh_fish:body":
			G.cube(st,Vector3.ZERO,Vector3(0.2,0.15,0.42),Color("f2cb81"))
			G.cube(st,Vector3(0,0.07,0.01),Vector3(0.14,0.03,0.36),Color("d9944f"))
			G.cube(st,Vector3(0,-0.06,0),Vector3(0.15,0.03,0.32),Color("fbe9c4"))
			G.cube(st,Vector3(0,0.11,0.02),Vector3(0.02,0.07,0.16),Color("e0a761"))
			for side in [-1,1]:
				G.cube(st,Vector3(side*0.101,0.025,-0.14),Vector3(0.006,0.05,0.05),ink)
				G.cube(st,Vector3(side*0.104,0.035,-0.15),Vector3(0.004,0.018,0.018),Color("ffffff"))
				G.cube(st,Vector3(side*0.11,-0.03,-0.05),Vector3(0.03,0.02,0.08),Color("e0a761"))
		"marsh_fish:tail":
			G.cube(st,Vector3(0,0,0.05),Vector3(0.06,0.09,0.1),Color("e9b56e"))
			G.cube(st,Vector3(0,0,0.13),Vector3(0.025,0.18,0.1),Color("e0a761"))
		# v0.69 non-Earth creatures — reuse blocky geometry, planet-tinted.
		"sand_scorpion:body":
			G.cube(st,Vector3.ZERO,Vector3(0.36,0.18,0.6),Color("8a5028"))
			G.cube(st,Vector3(0,0.12,-0.25),Vector3(0.18,0.12,0.22),Color("a06535"))
			for side in [-1,1]: G.cube(st,Vector3(side*0.22,0.08,-0.2),Vector3(0.05,0.04,0.3),Color("6a3a1a"))
			G.cube(st,Vector3(0,0.16,0.28),Vector3(0.08,0.05,0.4),Color("8a5028"))
			G.cube(st,Vector3(0,0.2,0.55),Vector3(0.05,0.04,0.1),Color("d4a050"))
		"sand_scorpion:leg":
			G.cube(st,Vector3(0,-0.1,0),Vector3(0.04,0.2,0.05),Color("6a3a1a"))
		"sand_scorpion:tail":
			G.cube(st,Vector3(0,0,0.05),Vector3(0.06,0.06,0.25),Color("8a5028"))
			G.cube(st,Vector3(0,0.04,0.2),Vector3(0.04,0.04,0.06),Color("d4a050"))
		"desert_lizard:body":
			G.cube(st,Vector3.ZERO,Vector3(0.22,0.16,0.5),Color("c89048"))
			G.cube(st,Vector3(0,0.1,0.02),Vector3(0.14,0.06,0.4),Color("d8a458"))
			for side in [-1,1]: G.cube(st,Vector3(side*0.13,0.06,0.1),Vector3(0.02,0.03,0.06),Color("2a2a2a"))
		"desert_lizard:leg":
			G.cube(st,Vector3(0,-0.06,0),Vector3(0.06,0.12,0.06),Color("a87838"))
		"desert_lizard:tail":
			G.cube(st,Vector3(0,0,0.05),Vector3(0.05,0.05,0.3),Color("c89048"))
			G.cube(st,Vector3(0,0,0.3),Vector3(0.03,0.03,0.12),Color("a87838"))
		"frost_bear:body":
			G.cube(st,Vector3.ZERO,Vector3(0.6,0.7,1.1),Color("d8e0e8"))
			G.cube(st,Vector3(0,0.5,0.1),Vector3(0.5,0.25,0.9),Color("c0ccd8"))
			G.cube(st,Vector3(0,0.55,-0.55),Vector3(0.36,0.36,0.36),Color("e8eef4"))
			G.cube(st,Vector3(0,0.45,-0.7),Vector3(0.16,0.16,0.12),Color("2a2a3a"))
			for side in [-1,1]: G.cube(st,Vector3(side*0.1,0.5,-0.62),Vector3(0.04,0.03,0.03),Color("1a1a2a"))
		"frost_bear:leg":
			G.cube(st,Vector3(0,-0.3,0),Vector3(0.2,0.6,0.24),Color("c0ccd8"))
		"frost_bear:tail":
			G.cube(st,Vector3(0,0,0.1),Vector3(0.08,0.12,0.18),Color("d8e0e8"))
		"ice_crawler:body":
			G.cube(st,Vector3.ZERO,Vector3(0.3,0.2,0.4),Color("8acce0"))
			G.cube(st,Vector3(0,0.12,0),Vector3(0.2,0.08,0.3),Color("a8d8e8"))
			for side in [-1,1]: G.cube(st,Vector3(side*0.16,0.06,0.12),Vector3(0.02,0.04,0.04),Color("2a4a6a"))
		"ice_crawler:leg":
			G.cube(st,Vector3(0,-0.08,0),Vector3(0.05,0.16,0.05),Color("6ab8d0"))
		"ice_crawler:tail":
			G.cube(st,Vector3(0,0,0.05),Vector3(0.04,0.04,0.2),Color("8acce0"))
	var mesh: ArrayMesh=st.commit()
	if part=="body" and BOUNDS.has(kind): mesh.custom_aabb=BOUNDS[kind]
	_cache[key]=mesh
	return mesh

## A ready animal node: the body mesh on the node itself, legs and tail as pivoting children.
static func make(kind: String,material: Material) -> MeshInstance3D:
	var node=MeshInstance3D.new(); node.mesh=_mesh(kind,"body",material)
	var legs=[]
	var hips={"meadow_herbivore":[Vector3(-0.1,0.31,-0.2),Vector3(0.1,0.31,-0.2),Vector3(-0.1,0.31,0.2),Vector3(0.1,0.31,0.2)],
		"woodland_boar":[Vector3(-0.17,0.24,-0.24),Vector3(0.17,0.24,-0.24),Vector3(-0.17,0.24,0.24),Vector3(0.17,0.24,0.24)],
		"mammoth":[Vector3(-0.5,1.12,-0.65),Vector3(0.5,1.12,-0.65),Vector3(-0.5,1.12,0.8),Vector3(0.5,1.12,0.8)],
		"woolly_rhino":[Vector3(-0.32,0.65,-0.6),Vector3(0.32,0.65,-0.6),Vector3(-0.32,0.65,0.75),Vector3(0.32,0.65,0.75)],
		"sand_scorpion":[Vector3(-0.2,0.09,-0.16),Vector3(0.2,0.09,-0.16),Vector3(-0.2,0.09,0.1),Vector3(0.2,0.09,0.1),Vector3(-0.22,0.09,-0.06),Vector3(0.22,0.09,-0.06)],
		"desert_lizard":[Vector3(-0.16,0.08,-0.2),Vector3(0.16,0.08,-0.2),Vector3(-0.16,0.08,0.16),Vector3(0.16,0.08,0.16)],
		"frost_bear":[Vector3(-0.26,0.35,-0.32),Vector3(0.26,0.35,-0.32),Vector3(-0.26,0.35,0.36),Vector3(0.26,0.35,0.36)],
		"ice_crawler":[Vector3(-0.18,0.1,-0.14),Vector3(0.18,0.1,-0.14),Vector3(-0.18,0.1,0.06),Vector3(0.18,0.1,0.06),Vector3(-0.2,0.1,-0.05),Vector3(0.2,0.1,-0.05)]}
	for at in hips.get(kind,[]):
		var leg=MeshInstance3D.new(); leg.mesh=_mesh(kind,"leg",material); leg.position=at; node.add_child(leg); legs.append(leg)
	var tail=MeshInstance3D.new(); tail.mesh=_mesh(kind,"tail",material)
	tail.position={"meadow_herbivore":Vector3(0,0.53,0.29),"woodland_boar":Vector3(0,0.56,0.37),"marsh_fish":Vector3(0,0,0.2),"mammoth":Vector3(0,2.2,1.27),"woolly_rhino":Vector3(0,1.3,1.16),"sand_scorpion":Vector3(0,0.1,0.28),"desert_lizard":Vector3(0,0.08,0.22),"frost_bear":Vector3(0,0.4,0.5),"ice_crawler":Vector3(0,0.1,0.18)}.get(kind,Vector3.ZERO)
	node.add_child(tail)
	node.set_meta("legs",legs); node.set_meta("tail",tail); node.set_meta("gait",randf()*TAU); node.set_meta("kind",kind); node.set_meta("bounds",BOUNDS.get(kind,node.mesh.get_aabb()))
	return node

## Advance the gait by the distance actually travelled this frame; idle animals settle and flick.
static func animate(node: Node3D,dt: float,travelled: float,clock: float) -> void:
	if not node.has_meta("legs"): return
	var kind=str(node.get_meta("kind"))
	var speed=clampf(travelled/maxf(dt,0.0001),0.0,3.0)
	var gait=float(node.get_meta("gait"))+travelled*{"meadow_herbivore":9.0,"mammoth":2.6,"woolly_rhino":4.0}.get(kind,7.0)
	node.set_meta("gait",gait)
	var amount=clampf(speed*1.4,0.0,1.0)
	var legs: Array=node.get_meta("legs")
	for i in range(legs.size()):
		# Diagonal pairs move together (a trot): front-left with back-right.
		var phase=gait+(PI if i in [1,2] else 0.0)
		legs[i].rotation.x=lerpf(legs[i].rotation.x,sin(phase)*0.55*amount,minf(1,dt*12))
	if kind=="person":
		var arms: Array=node.get_meta("arms")
		for i in range(arms.size()):
			var swing=-sin(gait+(PI if i==1 else 0.0))*0.5*amount
			if i==1 and node.get_meta("working",false): swing=-0.9+sin(clock*6.0)*0.6
			arms[i].rotation.x=lerpf(arms[i].rotation.x,swing+sin(clock*1.6+gait)*0.04,minf(1,dt*12))
		return
	var tail: Node3D=node.get_meta("tail")
	if kind=="marsh_fish": tail.rotation.y=sin(clock*7.0+gait)*0.45
	else:
		tail.rotation.x=0.35+sin(clock*3.0+gait)*0.15
		tail.rotation.z=sin(clock*(9.0 if amount<0.2 else 4.0)+gait)*0.35

## Planet people (villagers and camp visitors), about 1.6 m tall, facing -Z. `look` keys: coat,
## pants, hair, hat ("straw", "cap" or ""), extra ("apron", "pack", "device" or "").
static func person_mesh(look: Dictionary,part: String,material: Material) -> ArrayMesh:
	var key="person:%s:%s:%d" % [str(look),part,material.get_instance_id()]
	if _cache.has(key): return _cache[key]
	var coat=Color(look.get("coat","bf9962")); var pants=Color(look.get("pants","546979")); var hair=Color(look.get("hair","4a3328"))
	var skin=Color(look.get("skin","e9c7a2")); var ink=Color("2b3a42")
	var st=G.surface(material)
	match part:
		"body":
			G.cube(st,Vector3(0,0.66,0),Vector3(0.36,0.12,0.22),pants)
			G.cube(st,Vector3(0,0.9,0),Vector3(0.4,0.42,0.24),coat)
			G.cube(st,Vector3(0,1.08,0),Vector3(0.46,0.08,0.25),coat.lightened(0.06))
			G.cube(st,Vector3(0,0.71,0),Vector3(0.41,0.05,0.25),Color("5b4433"))
			G.cube(st,Vector3(0,0.71,-0.127),Vector3(0.06,0.04,0.006),Color("d9b46a"))
			G.cube(st,Vector3(0,1.0,-0.121),Vector3(0.1,0.16,0.004),coat.lightened(0.25))
			G.cube(st,Vector3(0,1.15,0),Vector3(0.11,0.06,0.11),skin.darkened(0.08))
			Figure.ball(st,Vector3(0,1.32,0),0.17,skin)
			Figure.ball(st,Vector3(0,1.37,0.031),0.176,hair,Vector3(1.0,0.82,1.0))
			G.cube(st,Vector3(0,1.44,-0.1),Vector3(0.24,0.05,0.07),hair)
			for side in [-1,1]:
				Figure.ball(st,Vector3(side*0.06,1.327,-0.15),0.024,ink)
				Figure.ball(st,Vector3(side*0.053,1.337,-0.17),0.0085,Color("ffffff"))
				Figure.ball(st,Vector3(side*0.102,1.285,-0.13),0.023,Color("f2a99c"))
			G.cube(st,Vector3(0,1.27,-0.165),Vector3(0.045,0.013,0.014),Color("a25d52"))
			match str(look.get("hat","")):
				"straw":
					G.cube(st,Vector3(0,1.49,0),Vector3(0.58,0.025,0.54),Color("d8bd7c"))
					G.cube(st,Vector3(0,1.477,0),Vector3(0.6,0.012,0.56),Color("b99a5c"))
					Figure.ball(st,Vector3(0,1.52,0),0.16,Color("c9ab68"),Vector3(1.0,0.6,1.0))
					G.cube(st,Vector3(0,1.52,0),Vector3(0.29,0.035,0.29),Color("8b5a3c"))
				"cap":
					Figure.ball(st,Vector3(0,1.42,0.01),0.185,Color("3f8f86"),Vector3(1.0,0.6,1.0))
					G.cube(st,Vector3(0,1.43,-0.2),Vector3(0.22,0.02,0.12),Color("2f6f68"))
					G.cube(st,Vector3(0,1.47,-0.155),Vector3(0.05,0.03,0.01),Color("bff5e9"))
			match str(look.get("extra","")):
				"apron":
					G.cube(st,Vector3(0,0.83,-0.125),Vector3(0.32,0.46,0.012),Color("8a6748"))
					G.cube(st,Vector3(0,0.78,-0.133),Vector3(0.14,0.1,0.008),Color("6f5238"))
				"pack":
					G.cube(st,Vector3(0,0.92,0.19),Vector3(0.32,0.38,0.16),Color("66715c"))
					G.cube(st,Vector3(0,1.13,0.2),Vector3(0.34,0.06,0.17),Color("4f5947"))
					G.cube(st,Vector3(0,0.84,0.275),Vector3(0.2,0.12,0.02),Color("7d8a70"))
					G.cube(st,Vector3(0,1.15,0.2),Vector3(0.36,0.08,0.08),Color("b8564a"))
				"device":
					G.cube(st,Vector3(0.21,0.72,-0.06),Vector3(0.06,0.14,0.1),Color("41535c"))
					G.cube(st,Vector3(0.242,0.74,-0.06),Vector3(0.006,0.08,0.07),Color("7ee0c9"))
					G.cube(st,Vector3(0,1.02,-0.124),Vector3(0.12,0.012,0.004),Color("7ee0c9"))
		"arm":
			G.cube(st,Vector3(0,-0.19,0),Vector3(0.11,0.38,0.12),coat)
			G.cube(st,Vector3(0,-0.39,0),Vector3(0.115,0.04,0.125),coat.darkened(0.15))
			Figure.ball(st,Vector3(0,-0.45,0),0.055,skin)
		"leg":
			G.cube(st,Vector3(0,-0.27,0),Vector3(0.15,0.54,0.17),pants)
			G.cube(st,Vector3(0,-0.58,-0.03),Vector3(0.16,0.08,0.24),Color("3a2f2a"))
	var mesh: ArrayMesh=st.commit()
	if part=="body": mesh.custom_aabb=BOUNDS.person
	_cache[key]=mesh
	return mesh

## A person node: the body mesh on the node itself (hitboxes read it), arms and legs as children.
static func person(look: Dictionary,material: Material) -> MeshInstance3D:
	var node=MeshInstance3D.new(); node.mesh=person_mesh(look,"body",material)
	var legs=[]; var arms=[]
	for side in [-1,1]:
		var leg=MeshInstance3D.new(); leg.mesh=person_mesh(look,"leg",material); leg.position=Vector3(side*0.1,0.62,0); node.add_child(leg); legs.append(leg)
		var arm=MeshInstance3D.new(); arm.mesh=person_mesh(look,"arm",material); arm.position=Vector3(side*0.26,1.08,0); arm.rotation.z=side*0.06; node.add_child(arm); arms.append(arm)
	node.set_meta("legs",legs); node.set_meta("arms",arms); node.set_meta("gait",randf()*TAU); node.set_meta("kind","person"); node.set_meta("bounds",BOUNDS.person)
	return node

## Swap a person's outfit in place (an era change) without rebuilding the nodes.
static func dress(node: MeshInstance3D,look: Dictionary,material: Material) -> void:
	node.mesh=person_mesh(look,"body",material)
	for leg in node.get_meta("legs"): leg.mesh=person_mesh(look,"leg",material)
	for arm in node.get_meta("arms"): arm.mesh=person_mesh(look,"arm",material)

## Ambient birds (render-only, no population record): a body with two flapping wings.
static func bird(material: Material) -> Node3D:
	var key="bird:%d" % material.get_instance_id()
	if not _cache.has(key):
		var st=G.surface(material)
		G.cube(st,Vector3(0,0,0),Vector3(0.11,0.09,0.3),Color("3d4a57"))
		G.cube(st,Vector3(0,-0.035,-0.02),Vector3(0.09,0.03,0.22),Color("d9d4c6"))
		Figure.ball(st,Vector3(0,0.03,-0.17),0.06,Color("3d4a57"))
		G.cube(st,Vector3(0,0.02,-0.245),Vector3(0.03,0.025,0.05),Color("e2a23f"))
		G.cube(st,Vector3(0,0.01,0.19),Vector3(0.12,0.015,0.1),Color("2f3944"))
		var body: ArrayMesh=st.commit()
		var wing=G.surface(material)
		G.cube(wing,Vector3(0.18,0,0),Vector3(0.36,0.015,0.14),Color("4a5866"))
		G.cube(wing,Vector3(0.3,-0.003,0.035),Vector3(0.14,0.012,0.09),Color("2a333c"))
		_cache[key]=[body,wing.commit()]
	var node=MeshInstance3D.new(); node.mesh=_cache[key][0]; node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wings=[]
	for side in [-1,1]:
		var w=MeshInstance3D.new(); w.mesh=_cache[key][1]; w.scale.x=side; w.position.x=side*0.05; w.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; node.add_child(w); wings.append(w)
	node.set_meta("wings",wings)
	return node
