extends Node3D
## Camera-local procedural hands: animation never grants items or deals damage.
## v0.33: a shaded, gloved hand with curled fingers, a suit sleeve with a glowing cuff and a wrist
## analyser; tools have real heads, grip wraps and lit screens. The rig lags a little behind camera
## turns so looking around feels physical.
const G=preload("res://scripts/river_geometry.gd")
const VIEWMODEL=preload("res://assets/shaders/viewmodel.gdshader")
const SKIN=Color("e9c39a")
const SKIN_DARK=Color("d2a77d")
const GLOVE=Color("39545e")
const SUIT=Color("2f4a55")
const ACCENT=Color("7ee0c9")
const METAL=Color("b8cfd3")
const WOOD=Color("a37a50")
var arm: MeshInstance3D
var held: MeshInstance3D
var clock=0.0
var swing_left=0.0
var moving=0.0
var tool="collect"
var material: ShaderMaterial
var glow: ShaderMaterial
var sway=Vector2.ZERO
var last_basis=Basis()

func _ready() -> void:
	material=ShaderMaterial.new(); material.shader=VIEWMODEL
	glow=ShaderMaterial.new(); glow.shader=VIEWMODEL; glow.set_shader_parameter("glow",1.0)
	arm=MeshInstance3D.new(); arm.mesh=_arm(); arm.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(arm)
	held=MeshInstance3D.new(); held.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; arm.add_child(held); set_tool(tool)

## Forearm in a suit sleeve, a glowing cuff, the wrist analyser and a loosely closed hand.
func _arm() -> ArrayMesh:
	var st=G.surface(material)
	G.cube(st,Vector3(0,-0.17,0.08),Vector3(0.17,0.2,0.19),SUIT)
	G.cube(st,Vector3(0,-0.055,0.055),Vector3(0.18,0.05,0.2),SUIT.lightened(0.12))
	G.cube(st,Vector3(0,0.0,0.03),Vector3(0.13,0.08,0.14),GLOVE)
	G.cube(st,Vector3(0.0,0.0,-0.045),Vector3(0.07,0.045,0.03),Color("1f2b31"))
	# palm and back of the hand
	G.cube(st,Vector3(0,0.085,0.0),Vector3(0.15,0.11,0.15),SKIN)
	G.cube(st,Vector3(0,0.085,0.078),Vector3(0.13,0.09,0.012),SKIN_DARK)
	# four curled fingers: knuckle row on top, finger tips folded toward the palm
	for i in range(4):
		var x=-0.054+i*0.036; var drop=absf(i-1.3)*0.006
		G.cube(st,Vector3(x,0.152-drop,-0.02),Vector3(0.032,0.035,0.11),SKIN)
		G.cube(st,Vector3(x,0.168-drop,-0.02),Vector3(0.026,0.006,0.07),SKIN.lightened(0.08))
		G.cube(st,Vector3(x,0.12-drop,-0.083),Vector3(0.03,0.06,0.034),SKIN_DARK)
	# thumb wrapping across the front
	G.cube(st,Vector3(-0.088,0.07,-0.03),Vector3(0.04,0.06,0.07),SKIN_DARK)
	G.cube(st,Vector3(-0.06,0.1,-0.074),Vector3(0.06,0.035,0.035),SKIN)
	var mesh: ArrayMesh=st.commit()
	var lit=G.surface(glow)
	G.cube(lit,Vector3(0,-0.055,-0.047),Vector3(0.181,0.012,0.11),ACCENT)
	G.cube(lit,Vector3(0.0,0.0,-0.062),Vector3(0.05,0.03,0.006),ACCENT)
	return lit.commit(mesh)

func set_tool(kind: String) -> void:
	if held==null: tool=kind; return
	if tool==kind and held.mesh!=null: return
	tool=kind
	held.visible=kind not in ["collect","strike",""]
	if not held.visible: return
	var st=G.surface(material); var lit=G.surface(glow); var bright=false
	if kind in ["axe","dig","remove"]:
		G.cube(st,Vector3(0,0.21,-0.1),Vector3(0.045,0.46,0.05),WOOD)
		for y in [0.05,0.1,0.15]: G.cube(st,Vector3(0,y,-0.1),Vector3(0.052,0.03,0.057),Color("3e4a4f"))
		G.cube(st,Vector3(0,0.42,-0.1),Vector3(0.06,0.06,0.065),Color("6d7f86"))
		if kind=="axe":
			G.cube(st,Vector3(-0.07,0.42,-0.1),Vector3(0.1,0.12,0.03),METAL)
			G.cube(st,Vector3(-0.13,0.42,-0.1),Vector3(0.03,0.17,0.022),Color("e3f1f2"))
			G.cube(st,Vector3(0.05,0.42,-0.1),Vector3(0.05,0.05,0.05),Color("6d7f86"))
		elif kind=="dig":
			for k in range(4):
				var w=0.07-k*0.014
				G.cube(st,Vector3(-0.06-k*0.05,0.415-k*0.012,-0.1),Vector3(0.05,w,w),METAL.darkened(k*0.04))
				G.cube(st,Vector3(0.06+k*0.05,0.415-k*0.012,-0.1),Vector3(0.05,w,w),METAL.darkened(k*0.04))
		else:
			G.cube(st,Vector3(0,0.42,-0.1),Vector3(0.22,0.1,0.1),METAL)
			G.cube(st,Vector3(0.115,0.42,-0.1),Vector3(0.012,0.11,0.11),Color("e3f1f2"))
			G.cube(st,Vector3(-0.115,0.42,-0.1),Vector3(0.012,0.11,0.11),Color("e3f1f2"))
			G.cube(lit,Vector3(0,0.42,-0.151),Vector3(0.12,0.02,0.004),ACCENT); bright=true
	elif kind in ["plant","tree_plant"]:
		G.cube(st,Vector3(0,0.2,-0.1),Vector3(0.13,0.08,0.13),Color("6b4f36"))
		G.cube(st,Vector3(0,0.245,-0.1),Vector3(0.1,0.02,0.1),Color("8a6748"))
		G.cube(st,Vector3(0,0.3,-0.1),Vector3(0.016,0.11,0.016),Color("6e9a4e"))
		for side in [-1,1]:
			G.cube(st,Vector3(side*0.035,0.33+side*0.012,-0.1),Vector3(0.06,0.012,0.035),Color("8ec975"))
			G.cube(st,Vector3(side*0.02,0.37,-0.1+side*0.02),Vector3(0.03,0.01,0.05),Color("a5db84"))
	elif kind=="organic_solution":
		G.cube(st,Vector3(0,0.22,-0.14),Vector3(0.16,0.24,0.16),Color("a8e3e2"))
		G.cube(st,Vector3(0,0.37,-0.14),Vector3(0.07,0.06,0.07),Color("cde9e9"))
		G.cube(st,Vector3(0,0.415,-0.14),Vector3(0.085,0.035,0.085),Color("c9a35f"))
		G.cube(st,Vector3(0,0.22,-0.222),Vector3(0.12,0.1,0.006),Color("f6e9bf"))
		G.cube(lit,Vector3(0,0.19,-0.14),Vector3(0.145,0.15,0.145),Color("5fd0a2")); bright=true
		G.cube(st,Vector3(0,0.22,-0.226),Vector3(0.06,0.045,0.004),Color("3f8f62"))
	elif kind=="scan":
		G.cube(st,Vector3(0,0.2,-0.12),Vector3(0.17,0.27,0.07),Color("2e3c44"))
		G.cube(st,Vector3(0,0.2,-0.1585),Vector3(0.15,0.25,0.004),Color("1d272c"))
		G.cube(st,Vector3(0.075,0.22,-0.12),Vector3(0.025,0.2,0.075),Color("445963"))
		G.cube(st,Vector3(0,0.37,-0.12),Vector3(0.016,0.09,0.016),Color("8aa1a8"))
		G.cube(lit,Vector3(0,0.245,-0.162),Vector3(0.12,0.12,0.004),Color("7ee0c9"))
		G.cube(lit,Vector3(0,0.245,-0.1645),Vector3(0.09,0.012,0.002),Color("e6fffa"))
		G.cube(lit,Vector3(-0.035,0.135,-0.162),Vector3(0.025,0.025,0.004),Color("f1c96a"))
		G.cube(lit,Vector3(0.025,0.135,-0.162),Vector3(0.025,0.025,0.004),Color("ff8a7a"))
		G.cube(lit,Vector3(0,0.425,-0.12),Vector3(0.03,0.03,0.03),Color("f1c96a")); bright=true
	elif kind.begins_with("place_rock"):
		var c=Color(kind.get_slice(":",1)) if kind.contains(":") else Color("a0948f")
		G.cube(st,Vector3(0,0.22,-0.14),Vector3(0.22,0.2,0.22),c)
		G.cube(st,Vector3(0.03,0.33,-0.12),Vector3(0.14,0.04,0.15),c.lightened(0.1))
		G.cube(st,Vector3(-0.05,0.2,-0.255),Vector3(0.09,0.08,0.02),c.darkened(0.12))
	elif kind=="organic_sample":
		G.cube(st,Vector3(0,0.22,-0.14),Vector3(0.2,0.22,0.17),Color("f3eee0"))
		G.cube(st,Vector3(0,0.34,-0.14),Vector3(0.21,0.025,0.18),Color("cfc6b0"))
		G.cube(st,Vector3(0,0.24,-0.227),Vector3(0.14,0.07,0.006),Color("6cbea6"))
	else:
		var body=Color("69cdbb") if kind.begins_with("mini") else Color("cfa974")
		G.cube(st,Vector3(0,0.22,-0.14),Vector3(0.24,0.23,0.24),body)
		for x in [-0.115,0.115]: G.cube(st,Vector3(x,0.22,-0.14),Vector3(0.02,0.235,0.245),body.darkened(0.18))
		G.cube(st,Vector3(0,0.34,-0.14),Vector3(0.25,0.02,0.07),body.darkened(0.25))
		G.cube(st,Vector3(0,0.23,-0.264),Vector3(0.13,0.11,0.006),Color("f3dfba"))
	var mesh: ArrayMesh=st.commit()
	held.mesh=lit.commit(mesh) if bright else mesh

func swing() -> void:
	if swing_left<=0: swing_left=0.38

func _process(dt: float) -> void:
	clock+=dt; swing_left=maxf(0,swing_left-dt)
	var strike=sin((1-swing_left/0.38)*PI) if swing_left>0 else 0.0
	# Lag behind camera turns, then settle back.
	var b: Basis=get_parent().global_transform.basis if get_parent() is Node3D else Basis()
	if dt>0:
		var turn=Vector2(last_basis.z.cross(b.z).y,b.z.y-last_basis.z.y)
		sway=sway.lerp(Vector2(clampf(turn.x*6.0,-0.08,0.08),clampf(turn.y*6.0,-0.06,0.06)),minf(1,dt*10))
	sway=sway.lerp(Vector2.ZERO,minf(1,dt*5)); last_basis=b
	var breathe=sin(clock*1.7)*0.004
	var bob=sin(clock*9)*0.015*moving; var side=cos(clock*4.5)*0.01*moving
	position=Vector3(0.38-strike*0.14+side+sway.x,-0.27+bob+breathe-sway.y,-0.64-strike*0.2)
	rotation=Vector3(-0.25-strike*0.9,0.12+strike*0.25,-0.1-strike*0.5+sway.x*1.5)
