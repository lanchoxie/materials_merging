extends Node3D
## Camera-local procedural hands: animation never grants items or deals damage.
const G=preload("res://scripts/river_geometry.gd")
var arm: MeshInstance3D
var held: MeshInstance3D
var clock=0.0
var swing_left=0.0
var moving=0.0
var tool="collect"
var material: StandardMaterial3D

func _ready() -> void:
	material=StandardMaterial3D.new(); material.vertex_color_use_as_albedo=true; material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test=true
	var st=G.surface(material)
	G.cube(st,Vector3(0,-0.10,0.06),Vector3(0.16,0.28,0.18),Color("466b76"))
	G.cube(st,Vector3(0,0.075,0),Vector3(0.17,0.15,0.2),Color("edc9a0"))
	G.cube(st,Vector3(-0.085,0.04,-0.07),Vector3(0.06,0.09,0.08),Color("dcb78f"))
	arm=MeshInstance3D.new(); arm.mesh=st.commit(); add_child(arm)
	held=MeshInstance3D.new(); arm.add_child(held); set_tool(tool)

func set_tool(kind: String) -> void:
	if held==null: tool=kind; return
	if tool==kind and held.mesh!=null: return
	tool=kind; var st=G.surface(material)
	held.visible=kind not in ["collect","strike",""]
	if not held.visible: return
	if kind in ["axe","dig","remove"]:
		G.cube(st,Vector3(0,0.20,-0.1),Vector3(0.055,0.44,0.06),Color("b99063"))
		G.cube(st,Vector3(-0.08 if kind=="axe" else 0,0.40,-0.1),Vector3(0.24,0.13 if kind!="dig" else 0.25,0.08),Color("add8d5"))
	elif kind in ["plant","tree_plant"]:
		G.cube(st,Vector3(0,0.18,-0.09),Vector3(0.05,0.24,0.05),Color("92714d"))
		G.cube(st,Vector3(0,0.3,-0.09),Vector3(0.23,0.12,0.12),Color("8ec975"))
	elif kind=="organic_solution":
		G.cube(st,Vector3(0,0.22,-0.14),Vector3(0.18,0.28,0.18),Color("8bd5d7"))
		G.cube(st,Vector3(0,0.39,-0.14),Vector3(0.10,0.08,0.10),Color("dac389"))
		G.cube(st,Vector3(0,0.23,-0.235),Vector3(0.13,0.11,0.015),Color("f6e9bf"))
		G.cube(st,Vector3(0,0.23,-0.245),Vector3(0.065,0.05,0.012),Color("5ca879"))
	elif kind=="organic_sample":
		G.cube(st,Vector3(0,0.22,-0.14),Vector3(0.22,0.24,0.19),Color("f3eee0"))
		G.cube(st,Vector3(0,0.25,-0.242),Vector3(0.14,0.07,0.02),Color("6cbea6"))
	else:
		G.cube(st,Vector3(0,0.22,-0.14),Vector3(0.25,0.24,0.25),Color("69cdbb") if kind.begins_with("mini") else Color("cfa974"))
		G.cube(st,Vector3(0,0.23,-0.27),Vector3(0.13,0.12,0.015),Color("f3dfba"))
	held.mesh=st.commit()

func swing() -> void:
	if swing_left<=0: swing_left=0.38

func _process(dt: float) -> void:
	clock+=dt; swing_left=maxf(0,swing_left-dt)
	var strike=sin((1-swing_left/0.38)*PI) if swing_left>0 else 0.0
	position=Vector3(0.38-strike*0.14,-0.3+sin(clock*9)*0.015*moving,-0.64-strike*0.2)
	rotation=Vector3(-0.25-strike*0.9,0.12+strike*0.25,-0.1-strike*0.5)
