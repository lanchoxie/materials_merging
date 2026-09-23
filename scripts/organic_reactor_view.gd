extends Node3D
## Preview reads the selected real reactor. It never produces or installs a specimen.
var atoms: Node3D
var seen=""
var active=false

func _ready() -> void:
	var environment=WorldEnvironment.new(); var env=Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=Color("102c35"); env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("c4e9df"); env.ambient_light_energy=0.8; environment.environment=env; add_child(environment)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-30,-25,0); add_child(light)
	var camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=6.2; camera.position=Vector3(3,2,6); add_child(camera); camera.look_at(Vector3.ZERO); camera.current=true
	for y in [-1.6,1.6]:
		var lid=CylinderMesh.new(); lid.top_radius=1.6; lid.bottom_radius=1.6; lid.height=0.22; lid.radial_segments=32
		var node=MeshInstance3D.new(); node.mesh=lid; node.position.y=y; node.material_override=_material(Color("5cac9e")); add_child(node)
		var ring=TorusMesh.new(); ring.inner_radius=1.45; ring.outer_radius=1.55; ring.rings=32; ring.ring_segments=8
		var rim=MeshInstance3D.new(); rim.mesh=ring; rim.position.y=y+0.13; rim.material_override=_material(Color("dfbd71")); add_child(rim)
	var glass=CylinderMesh.new(); glass.top_radius=1.5; glass.bottom_radius=1.5; glass.height=3.1; glass.radial_segments=32
	var shell=MeshInstance3D.new(); shell.mesh=glass; var m=_material(Color(0.5,0.9,0.88,0.10)); m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; shell.material_override=m; add_child(shell)
	atoms=Node3D.new(); add_child(atoms)

func _material(color: Color) -> StandardMaterial3D:
	var material=StandardMaterial3D.new(); material.albedo_color=color; material.roughness=0.38; return material

func sync(state,r: Dictionary,phase: String) -> void:
	active=phase in ["producing","ready"] and int(r.pending)<state.reactor_capacity(r)
	var stamp=state.signature(r)
	if stamp==seen: return
	seen=stamp
	for child in atoms.get_children(): child.queue_free()
	var work=state.reactor_work(r); var center=Vector3.ZERO; var points=[]
	for p in work.positions: center+=Vector3(p[0],p[1],p[2])
	center/=maxi(1,work.positions.size()); var extent=1.0
	for p in work.positions: extent=maxf(extent,(Vector3(p[0],p[1],p[2])-center).length())
	var scale_factor=1.1/extent
	for i in range(work.atoms.size()):
		var p=work.positions[i]; var point=(Vector3(p[0],p[1],p[2])-center)*scale_factor; points.append(point)
		var sphere=SphereMesh.new(); sphere.radius=0.13 if work.atoms[i]=="H" else 0.21; sphere.height=sphere.radius*2; sphere.radial_segments=16; sphere.rings=8
		var node=MeshInstance3D.new(); node.mesh=sphere; node.position=point; node.material_override=_material(Color(state.elements[work.atoms[i]].color)); atoms.add_child(node)
	for bond in work.bonds:
		var a: Vector3=points[int(bond[0])]; var b: Vector3=points[int(bond[1])]; var delta=b-a
		if delta.length()<0.001: continue
		var cylinder=CylinderMesh.new(); cylinder.top_radius=0.035; cylinder.bottom_radius=0.035; cylinder.height=delta.length(); cylinder.radial_segments=8
		var node=MeshInstance3D.new(); node.mesh=cylinder; node.position=(a+b)/2; node.quaternion=Quaternion(Vector3.UP,delta.normalized()); node.material_override=_material(Color("bcd1d1")); atoms.add_child(node)

func _process(dt: float) -> void:
	if active and atoms!=null: atoms.rotation.y+=dt*0.18
