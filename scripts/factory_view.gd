extends Node3D
## Independent material/workshop display: no world simulation dependencies.
var materials={}
var player_view
var material_view
var crate: Node3D
var camera: Camera3D
var product_body: Node3D
var displayed_recipe=""

func _ready() -> void:
	var environment=WorldEnvironment.new(); var env=Environment.new()
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("142c3c")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("c7dfdf"); env.ambient_light_energy=0.8
	environment.environment=env; add_child(environment)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-40,-30,0); light.light_energy=1.5; add_child(light)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=7.8
	camera.position=Vector3(5,4.7,8); add_child(camera); camera.look_at(Vector3(0,0.5,0)); camera.current=true
	player_view=preload("res://scripts/player_material_view.gd").new(); add_child(player_view); player_view.setup(self)
	material_view=preload("res://scripts/material_lab_view.gd").new(); add_child(material_view); material_view.setup(self)
	crate=Node3D.new(); add_child(crate)
	_cylinder(crate,2.7,0.2,Vector3(0,-0.6,0),"274855")
	product_body=Node3D.new(); crate.add_child(product_body); show_product("standard_water_crate")
	set_mode("workshop")

func show_product(id: String) -> void:
	if product_body==null or displayed_recipe==id: return
	displayed_recipe=id
	for child in product_body.get_children(): child.free()
	if id.begins_with("field_"):
		var c=preload("res://scripts/river_construction.gd").new()
		var kind=str(c.rules.recipes[id].kind)
		var m=StandardMaterial3D.new(); m.vertex_color_use_as_albedo=true
		var st=preload("res://scripts/river_geometry.gd").surface(m)
		preload("res://scripts/river_component_geometry.gd").draw(st,Vector3(0,0.15,0),kind,Color(c.rules.kinds[kind].color))
		var n=MeshInstance3D.new(); n.mesh=st.commit(); n.scale=Vector3.ONE*1.7; product_body.add_child(n)
	elif id=="frame_bundle":
		for layer in range(4):
			for side in [-1,1]: _box(product_body,Vector3(2.1,0.24,0.48),Vector3(0,-0.32+layer*0.3,side*0.34),"bd9267")
		for x in [-0.65,0.65]: _box(product_body,Vector3(0.1,1.25,1.25),Vector3(x,0.17,0),"5c736b")
	elif id in ["modern_silicon","modern_perovskite"]:
		for x in [-0.7,0.7]: _box(product_body,Vector3(0.08,0.85,0.12),Vector3(x,-0.05,0),"a2b8b5")
		var panel=Node3D.new(); panel.position.y=0.65; panel.rotation.x=-0.28; product_body.add_child(panel)
		_box(panel,Vector3(2.25,0.12,1.7),Vector3.ZERO,"bbcfcf")
		for x in range(4):
			for z in range(3): _box(panel,Vector3(0.5,0.035,0.48),Vector3(-0.81+x*0.54,0.08,-0.52+z*0.52),"324f84" if id=="modern_silicon" else "73548e")
	else:
		_box(product_body,Vector3(2,1.8,1.6),Vector3(0,0.45,0),"c6dcd3")
		_box(product_body,Vector3(2.1,0.18,1.7),Vector3(0,1.42,0),"4eaaa5")
		_box(product_body,Vector3(0.6,0.55,0.05),Vector3(0,0.45,0.82),"67bcb9")
		for x in [-0.8,0.8]: _box(product_body,Vector3(0.18,1.85,1.72),Vector3(x,0.45,0),"76958d")

func set_mode(mode: String) -> void:
	player_view.visible=mode=="dossiers"
	material_view.visible=mode=="materials"
	crate.visible=mode not in ["dossiers","materials"]

func rotate_display(delta: float) -> void:
	for item in [player_view,material_view,crate]: item.rotation.y+=delta

func _mat(hex: String,metal: float=0.0) -> StandardMaterial3D:
	if materials.has(hex): return materials[hex]
	var mat=StandardMaterial3D.new(); mat.albedo_color=Color(hex); mat.roughness=0.67; mat.metallic=metal
	materials[hex]=mat; return mat

func _mesh(parent: Node,mesh: Mesh,pos: Vector3,color: String) -> MeshInstance3D:
	var node=MeshInstance3D.new(); node.mesh=mesh; node.position=pos; node.material_override=_mat(color); parent.add_child(node); return node

func _sphere(parent: Node,r: float,pos: Vector3,color: String) -> MeshInstance3D:
	var shape=SphereMesh.new(); shape.radius=r; shape.height=r*2; shape.radial_segments=16; shape.rings=8
	return _mesh(parent,shape,pos,color)

func _box(parent: Node,size: Vector3,pos: Vector3,color: String) -> MeshInstance3D:
	var shape=BoxMesh.new(); shape.size=size; return _mesh(parent,shape,pos,color)

func _cylinder(parent: Node,r: float,height: float,pos: Vector3,color: String) -> MeshInstance3D:
	var shape=CylinderMesh.new(); shape.top_radius=r; shape.bottom_radius=r; shape.height=height; shape.radial_segments=32
	return _mesh(parent,shape,pos,color)

func _ring(parent: Node,inner: float,outer: float,pos: Vector3,color: String) -> MeshInstance3D:
	var shape=TorusMesh.new(); shape.inner_radius=inner; shape.outer_radius=outer; shape.rings=48; shape.ring_segments=8
	return _mesh(parent,shape,pos,color)

