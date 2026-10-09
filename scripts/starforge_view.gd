extends Node3D
## v0.34 星锻岛 diorama: a floating gunmetal deck of 3 m plots on anti-gravity thrusters, with the
## Blender-made factories (assets/models/starforge/*.glb) on their plots. Display only.
const MODELS="res://assets/models/starforge/"
const COLUMNS=4
var camera: Camera3D
var deck: Node3D
var spinners: Array=[]
var seen=""
var yaw=0.6
var selected=-1
var marker: MeshInstance3D
var _scenes: Dictionary={}

func _ready() -> void:
	var env=Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=Color("0d1d2b")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("9fb4c8"); env.ambient_light_energy=0.9
	var world_env=WorldEnvironment.new(); world_env.environment=env; add_child(world_env)
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-52,-35,0); sun.light_energy=1.2; sun.light_color=Color("fff1d8"); add_child(sun)
	var rim=DirectionalLight3D.new(); rim.rotation_degrees=Vector3(-20,150,0); rim.light_energy=0.35; rim.light_color=Color("7fd8ff"); add_child(rim)
	camera=Camera3D.new(); camera.fov=40; add_child(camera); camera.current=true
	deck=Node3D.new(); add_child(deck)
	marker=MeshInstance3D.new(); var ring=TorusMesh.new(); ring.inner_radius=1.35; ring.outer_radius=1.5; ring.rings=32; ring.ring_segments=4; marker.mesh=ring
	var m=StandardMaterial3D.new(); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color=Color("35e0ff"); marker.material_override=m
	add_child(marker); marker.hide()

func _scene(name: String) -> PackedScene:
	if not _scenes.has(name): _scenes[name]=load(MODELS+name+".glb")
	return _scenes[name]

static func plot_center(i: int) -> Vector3:
	return Vector3((i%COLUMNS-1.5)*3.0,0,(i/COLUMNS-1.5)*3.0)

## Rebuilds only when the owned plots or the buildings change.
func sync(industry) -> void:
	var key=JSON.stringify([industry.unlocked,industry.plots,industry.buildings.keys(),industry.buildings.values().map(func(b): return [b.kind,b.level])])
	if key==seen: return
	seen=key; spinners=[]
	for c in deck.get_children(): c.queue_free()
	var max_plots=int(industry.rules().plots.max)
	for i in range(max_plots):
		var at=plot_center(i)
		if i<industry.plots:
			var tile: Node3D=_scene("deck_tile").instantiate(); tile.position=at; deck.add_child(tile)
		else:
			# Plots not yet built out: a faint hologram outline of the deck to come.
			var ghost=MeshInstance3D.new(); var box=BoxMesh.new(); box.size=Vector3(2.9,0.08,2.9); ghost.mesh=box
			var gm=StandardMaterial3D.new(); gm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; gm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			gm.albedo_color=Color(0.2,0.85,1.0,0.16 if i<int(industry.rules().plots.start) or industry.unlocked else 0.07); ghost.material_override=gm; ghost.position=at+Vector3(0,-0.1,0); deck.add_child(ghost)
	for key2 in industry.buildings:
		var b: Dictionary=industry.buildings[key2]; var spec: Dictionary=industry.rules().buildings[b.kind]
		var model: Node3D=_scene(str(spec.model)).instantiate(); model.position=plot_center(int(key2))
		model.scale=Vector3.ONE*(1.0+0.08*(int(b.level)-1)); deck.add_child(model)
		spinners.append(model)
	for corner in [Vector3(-4.5,-1.2,-4.5),Vector3(4.5,-1.2,-4.5),Vector3(-4.5,-1.2,4.5),Vector3(4.5,-1.2,4.5)]:
		var t: Node3D=_scene("thruster").instantiate(); t.position=corner; deck.add_child(t)
	var under=MeshInstance3D.new(); var prism=CylinderMesh.new(); prism.top_radius=6.9; prism.bottom_radius=2.2; prism.height=4.5; prism.radial_segments=6
	under.mesh=prism; var um=StandardMaterial3D.new(); um.albedo_color=Color("1f2630"); um.metallic=0.5; um.roughness=0.6; under.material_override=um
	under.position=Vector3(0,-2.6,0); under.rotation.y=PI/6; deck.add_child(under)

func _process(dt: float) -> void:
	if camera==null: return
	yaw+=dt*0.08
	var target=Vector3(0,0.6,0); var distance=22.0
	camera.position=target+Vector3(sin(yaw)*distance,distance*0.62,cos(yaw)*distance)
	camera.look_at(target)
	deck.position.y=sin(Time.get_ticks_msec()/1600.0)*0.18
	var t=Time.get_ticks_msec()/1000.0
	for i in range(spinners.size()):
		var n: Node3D=spinners[i]
		if is_instance_valid(n): n.rotation.y=sin(t*0.3+i)*0.05
	marker.visible=selected>=0
	if selected>=0: marker.position=plot_center(selected)+Vector3(0,0.3+deck.position.y,0); marker.rotation.y=t
