extends RefCounted
## v0.27 courtyard decorations. Pure mesh builders on the campus view's box/ball helpers; each
## item is built around its footprint centre, already rotated by the caller. Sizes are metres.
const Town=preload("res://scripts/island_town.gd")

## links: which of the four sides (Vector2i offsets) has a joining neighbour, in item-local axes.
static func build(v, node: Node3D, kind: String, links: Array, detail: bool) -> void:
	var spec: Dictionary=Town.info(kind)
	var color=Color(str(spec.get("color","cccccc")))
	var s: Vector2i=Town.size(kind)
	var w=s.x*Town.tile(); var d=s.y*Town.tile()
	match kind:
		"stone_path","wood_path","crystal_path": _path(v,node,kind,color,w,d,detail)
		"wood_fence","picket_fence": _fence(v,node,kind,color,links)
		"stone_wall": _wall(v,node,color,links)
		"hedge": _hedge(v,node,color,links)
		"gate": _gate(v,node,color)
		"flower_bed":
			v.box(node,Vector3(w-0.04,0.08,d-0.04),Vector3(0,0.14,0),Color("a88a6a"))
			v.box(node,Vector3(w-0.10,0.03,d-0.10),Vector3(0,0.19,0),Color("6e5140"))
			var colors=[Color("ef8fa6"),Color("f4d06f"),Color("b7a3ea"),Color("f7f1e6")]
			for i in range(9 if detail else 4):
				var at=Vector3((i%3-1)*0.13,0.25,(int(i/3)%3-1)*0.13)
				v.ball(node,0.045,at,colors[i%colors.size()])
		"sunflower":
			v.box(node,Vector3(0.025,0.34,0.025),Vector3(0,0.27,0),Color("5f9a55"))
			v.ball(node,0.07,Vector3(0,0.46,0.02),color)
			v.ball(node,0.035,Vector3(0,0.46,0.07),Color("6b4b2e"))
		"bush": v.ball(node,0.12,Vector3(0,0.2,0),color)
		"young_tree":
			v.box(node,Vector3(0.07,0.42,0.07),Vector3(0,0.31,0),Color("9b7654"))
			v.ball(node,0.2,Vector3(0,0.62,0),color)
			v.ball(node,0.14,Vector3(0.1,0.78,0.03),color.lightened(0.1))
		"blossom_tree":
			v.box(node,Vector3(0.1,0.6,0.1),Vector3(0,0.4,0),Color("8d6a55"))
			for at in [Vector3(0,0.86,0),Vector3(0.18,0.78,0.08),Vector3(-0.16,0.8,-0.06),Vector3(0.02,1.02,-0.1)]:
				v.ball(node,0.2,at,color)
			if detail: v.box(node,Vector3(0.6,0.012,0.6),Vector3(0,0.106,0),Color("f6d3dd"))
		"bench":
			v.box(node,Vector3(0.44,0.035,0.16),Vector3(0,0.24,0),color)
			v.box(node,Vector3(0.44,0.12,0.025),Vector3(0,0.33,-0.07),color)
			for x in [-0.18,0.18]: v.box(node,Vector3(0.03,0.14,0.14),Vector3(x,0.16,0),Color("5c5a58"))
		"sf_chair":
			v.box(node,Vector3(0.05,0.02,0.05),Vector3(0,0.11,0),Color("5c6670"))
			v.box(node,Vector3(0.025,0.14,0.025),Vector3(0,0.19,0),Color("8b95a3"))
			v.ball(node,0.11,Vector3(0,0.3,0),color)
			v.box(node,Vector3(0.2,0.12,0.03),Vector3(0,0.37,-0.09),color.darkened(0.1))
			v.box(node,Vector3(0.18,0.012,0.012),Vector3(0,0.33,0.08),Color("35e0ff"))
		"sf_desk":
			v.box(node,Vector3(w*0.92,0.035,d*0.7),Vector3(0,0.32,0),color)
			for x in [-w*0.4,w*0.4]: v.box(node,Vector3(0.025,0.2,d*0.6),Vector3(x,0.2,0),Color("8b95a3"))
			v.box(node,Vector3(0.12,0.08,0.01),Vector3(0.05,0.38,-0.05),Color("35e0ff"))
		"sf_sofa":
			v.box(node,Vector3(w*0.9,0.08,d*0.7),Vector3(0,0.18,0),Color("3b3b3b"))
			v.box(node,Vector3(w*0.9,0.07,d*0.66),Vector3(0,0.255,0.01),color)
			v.box(node,Vector3(w*0.9,0.16,0.05),Vector3(0,0.34,-d*0.3),color.darkened(0.08))
			for x in [-w*0.45,w*0.45]: v.box(node,Vector3(0.04,0.12,d*0.66),Vector3(x,0.3,0),color.darkened(0.15))
			v.box(node,Vector3(w*0.8,0.01,0.012),Vector3(0,0.13,d*0.33),Color("ff8a7a").lightened(0.3))
		"sf_kitchen":
			v.box(node,Vector3(w*0.92,0.22,d*0.7),Vector3(0,0.21,0),Color("c8d0da"))
			v.box(node,Vector3(w*0.94,0.02,d*0.74),Vector3(0,0.33,0),Color("eef2f5"))
			var pan=v.ball(node,0.06,Vector3(-0.08,0.36,0),Color("2b2b2b")); pan.scale=Vector3(1,0.3,1)
			v.box(node,Vector3(0.1,0.01,0.015),Vector3(0.02,0.36,0),Color("2b2b2b"))
			v.ball(node,0.025,Vector3(0.14,0.36,0.02),Color("ff7a2e"))
		"street_lamp":
			v.box(node,Vector3(0.1,0.04,0.1),Vector3(0,0.11,0),Color("386270"))
			v.box(node,Vector3(0.03,0.62,0.03),Vector3(0,0.42,0),Color("386270"))
			v.ball(node,0.07,Vector3(0,0.76,0),color)
		"signpost":
			v.box(node,Vector3(0.035,0.46,0.035),Vector3(0,0.31,0),Color("8c6b4d"))
			var sign=v.box(node,Vector3(0.22,0.08,0.02),Vector3(0.06,0.46,0),color); sign.rotation.y=0.2
		"flag":
			v.box(node,Vector3(0.025,0.8,0.025),Vector3(0,0.5,0),Color("e8e8e0"))
			v.box(node,Vector3(0.22,0.13,0.012),Vector3(0.12,0.82,0),color)
		"swing":
			for x in [-w*0.44,w*0.44]:
				for z in [-0.08,0.08]: v.box(node,Vector3(0.03,0.62,0.03),Vector3(x,0.42,z),color)
			v.box(node,Vector3(w*0.92,0.035,0.035),Vector3(0,0.72,0),color)
			for x in [-0.12,0.12]:
				for side in [-0.07,0.07]: v.box(node,Vector3(0.008,0.42,0.008),Vector3(x+side,0.5,0),Color("e8dcc6"))
				v.box(node,Vector3(0.18,0.025,0.1),Vector3(x,0.29,0),Color("c4744e"))
		"pond":
			v.box(node,Vector3(w-0.02,0.05,d-0.02),Vector3(0,0.11,0),Color("b9b3a6"))
			v.box(node,Vector3(w-0.12,0.03,d-0.12),Vector3(0,0.135,0),color)
			if detail:
				v.ball(node,0.05,Vector3(-w*0.2,0.15,0.05),Color("7fbf7a"))
				v.ball(node,0.05,Vector3(w*0.25,0.15,-0.08),Color("7fbf7a"))
				v.ball(node,0.035,Vector3(w*0.25,0.18,-0.08),Color("f3b8cb"))
		"fountain":
			v.box(node,Vector3(w-0.04,0.12,d-0.04),Vector3(0,0.15,0),Color("e7ded0"))
			v.box(node,Vector3(w-0.16,0.04,d-0.16),Vector3(0,0.2,0),color)
			v.box(node,Vector3(0.16,0.42,0.16),Vector3(0,0.35,0),Color("e7ded0"))
			v.box(node,Vector3(0.42,0.05,0.42),Vector3(0,0.56,0),Color("e7ded0"))
			v.ball(node,0.1,Vector3(0,0.66,0),color.lightened(0.2))
		"windmill":
			v.box(node,Vector3(0.4,0.8,0.4),Vector3(0,0.5,0),color)
			v.box(node,Vector3(0.46,0.1,0.46),Vector3(0,0.94,0),Color("b0584e"))
			var hub=Node3D.new(); hub.position=Vector3(0,0.8,0.23); hub.set_meta("dynamic_geometry",true); hub.set_meta("spin",Vector3(0,0,1.4)); node.add_child(hub)
			for i in range(4):
				var arm=Node3D.new(); hub.add_child(arm); arm.rotation.z=i*PI/2
				v.box(arm,Vector3(0.06,0.34,0.012),Vector3(0,0.17,0),Color("f2ead8"))
			v.spinners.append(hub)
		"stone_pedestal":
			v.box(node,Vector3(0.38,0.28,0.38),Vector3(0,0.24,0),color)
			v.box(node,Vector3(0.44,0.04,0.44),Vector3(0,0.40,0),color.lightened(0.12))
		"plinth":
			v.box(node,Vector3(0.6,0.32,0.6),Vector3(0,0.26,0),color)
			v.box(node,Vector3(0.66,0.04,0.66),Vector3(0,0.44,0),Color("d3af63"))
		"turntable":
			v.box(node,Vector3(0.36,0.22,0.36),Vector3(0,0.21,0),color)
			var disk=Node3D.new(); disk.position=Vector3(0,0.34,0); disk.set_meta("dynamic_geometry",true); disk.set_meta("spin",Vector3(0,0.6,0)); disk.name="Spin"; node.add_child(disk)
			v.box(disk,Vector3(0.42,0.04,0.42),Vector3.ZERO,Color("d3af63"))
			v.spinners.append(disk)
		"glass_case":
			v.box(node,Vector3(0.42,0.26,0.42),Vector3(0,0.23,0),Color("7b6b5c"))
			v.box(node,Vector3(0.46,0.03,0.46),Vector3(0,0.37,0),Color("d3af63"))
			var glass=v.box(node,Vector3(0.4,0.34,0.4),Vector3(0,0.55,0),color)
			glass.material_override=v.glass(); glass.set_meta("dynamic_geometry",true)

## Height where an exhibit sits on each pedestal.
static func display_top(kind: String) -> float:
	return {"stone_pedestal":0.42,"plinth":0.46,"turntable":0.36,"glass_case":0.39}.get(kind,0.42)

static func _path(v, node: Node3D, kind: String, color: Color, w: float, d: float, detail: bool) -> void:
	v.box(node,Vector3(w,0.02,d),Vector3(0,0.105,0),color)
	if not detail: return
	match kind:
		"stone_path":
			for at in [Vector3(-0.12,0.118,-0.11),Vector3(0.1,0.118,-0.06),Vector3(-0.05,0.118,0.12),Vector3(0.13,0.118,0.13)]:
				v.box(node,Vector3(0.13,0.012,0.11),at,color.lightened(0.14))
		"wood_path":
			for i in range(4): v.box(node,Vector3(w,0.008,0.01),Vector3(0,0.117,-d*0.5+d*(i+0.5)/4.0),color.darkened(0.25))
		"crystal_path":
			for at in [Vector3(-0.1,0.13,0.08),Vector3(0.12,0.13,-0.1)]: v.ball(node,0.022,at,Color("e8fbff"))

static func _fence(v, node: Node3D, kind: String, color: Color, links: Array) -> void:
	var thin=0.022 if kind=="picket_fence" else 0.03
	v.box(node,Vector3(0.045,0.32,0.045),Vector3(0,0.25,0),color.lightened(0.08))
	var sides=links if not links.is_empty() else [Vector2i(1,0),Vector2i(-1,0)]
	for side in sides:
		var half=Vector3(side.x,0,side.y)*0.0625
		var length=Vector3(0.125 if side.x!=0 else thin,0.028,0.125 if side.y!=0 else thin)
		for h in [0.19,0.31]: v.box(node,length,half+Vector3(0,h,0),color)
		if kind=="picket_fence": v.box(node,Vector3(thin,0.26,thin),half*1.6+Vector3(0,0.22,0),color)

static func _wall(v, node: Node3D, color: Color, links: Array) -> void:
	v.box(node,Vector3(0.12,0.22,0.12),Vector3(0,0.2,0),color)
	for side in links:
		v.box(node,Vector3(0.125 if side.x!=0 else 0.1,0.2,0.125 if side.y!=0 else 0.1),Vector3(side.x,0,side.y)*0.0625+Vector3(0,0.19,0),color.darkened(0.06))

static func _hedge(v, node: Node3D, color: Color, links: Array) -> void:
	v.box(node,Vector3(0.18,0.24,0.18),Vector3(0,0.21,0),color)
	for side in links:
		v.box(node,Vector3(0.125 if side.x!=0 else 0.17,0.23,0.125 if side.y!=0 else 0.17),Vector3(side.x,0,side.y)*0.0625+Vector3(0,0.2,0),color.darkened(0.05))

static func _gate(v, node: Node3D, color: Color) -> void:
	for x in [-0.11,0.11]: v.box(node,Vector3(0.04,0.38,0.04),Vector3(x,0.28,0),color.lightened(0.08))
	v.box(node,Vector3(0.18,0.2,0.02),Vector3(0,0.24,0),color)
	v.box(node,Vector3(0.2,0.025,0.03),Vector3(0,0.42,0),Color("d3af63"))
