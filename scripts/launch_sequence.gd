extends Control
## v0.71: 3D rocket launch cinematics — ignition, liftoff, stage separation,
## atmospheric entry, ship separation. Then hands off to space flight.
signal sequence_done

var viewport: SubViewport
var camera: Camera3D
var root: Node3D
var rocket: Node3D
var stage1: Node3D
var stage2: Node3D
var ship_capsule: Node3D
var phase: int=0
var phase_time: float=0.0
var rocket_y: float=0.0
var rocket_vy: float=0.0
var camera_dist: float=30.0
var camera_angle: float=0.3
var label: Label
var sub_label: Label
var veil: ColorRect

const PHASES=[
	{"name":"倒计时 3… 2… 1…","dur":2.0,"thrust":false},
	{"name":"🚀 点火！","dur":1.5,"thrust":true},
	{"name":"升空中…","dur":2.5,"thrust":true},
	{"name":"一级分离","dur":1.5,"thrust":true,"separate1":true},
	{"name":"二级推进","dur":2.0,"thrust":true},
	{"name":"穿越大气层","dur":2.0,"thrust":true},
	{"name":"进入亚轨道","dur":1.5,"thrust":true,"separate2":true},
	{"name":"舰船分离","dur":1.5,"thrust":false,"separate_ship":true},
	{"name":"进入太空","dur":1.0,"thrust":false},
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var svc=SubViewportContainer.new(); svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); svc.stretch=true; add_child(svc)
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,720); viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; svc.add_child(viewport)
	root=Node3D.new(); viewport.add_child(root)
	var env=Environment.new(); env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0.15,0.25,0.45); env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(0.3,0.4,0.5); env.ambient_light_energy=0.5
	var we=WorldEnvironment.new(); we.environment=env; root.add_child(we)
	camera=Camera3D.new(); camera.fov=60; camera.far=20000; root.add_child(camera)
	# Ground plane
	var ground=MeshInstance3D.new(); var gm=BoxMesh.new(); gm.size=Vector3(200,1,200)
	ground.mesh=gm; var gmat=StandardMaterial3D.new(); gmat.albedo_color=Color("4a5a3a")
	ground.material_override=gmat; ground.position=Vector3(0,-0.5,0); root.add_child(ground)
	# Directional light (sun)
	var sun=DirectionalLight3D.new(); sun.position=Vector3(50,80,50); sun.look_at(Vector3.ZERO)
	sun.light_energy=1.2; root.add_child(sun)
	# Build the rocket stack
	rocket=_build_rocket(); root.add_child(rocket)
	# HUD
	label=Label.new(); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",28); label.add_theme_color_override("font_color",Color("ffffff"))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(label)
	sub_label=Label.new(); sub_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size",16); sub_label.add_theme_color_override("font_color",Color("aaccee"))
	sub_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); sub_label.offset_top=60; add_child(sub_label)
	veil=ColorRect.new(); veil.color=Color(0,0,0,0); veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(veil)

func _build_rocket() -> Node3D:
	var r=Node3D.new()
	var mat_steel=StandardMaterial3D.new(); mat_steel.albedo_color=Color("c8d0d8"); mat_steel.metallic=0.8
	var mat_ship=StandardMaterial3D.new(); mat_ship.albedo_color=Color("e0e8f0"); mat_ship.metallic=0.6
	# Stage 1
	stage1=Node3D.new(); r.add_child(stage1)
	var s1=MeshInstance3D.new(); var s1m=CylinderMesh.new()
	s1m.bottom_radius=1.4; s1m.top_radius=1.2; s1m.height=7.0
	s1.mesh=s1m; s1.material_override=mat_steel; s1.position=Vector3(0,3.5,0); stage1.add_child(s1)
	for k in range(3):
		var ang=k*TAU/3; var noz=MeshInstance3D.new(); var nzm=CylinderMesh.new()
		nzm.bottom_radius=0.35; nzm.top_radius=0.2; nzm.height=1.2
		noz.mesh=nzm; noz.material_override=StandardMaterial3D.new(); noz.material_override.albedo_color=Color("333333")
		noz.position=Vector3(cos(ang)*0.7,-0.6,sin(ang)*0.7); stage1.add_child(noz)
	# Fins
	for k in range(4):
		var ang=k*PI/2; var fin=MeshInstance3D.new(); var fm=BoxMesh.new(); fm.size=Vector3(0.15,2.5,1.4)
		fin.mesh=fm; fin.material_override=mat_steel
		fin.position=Vector3(cos(ang)*1.5,1.25,sin(ang)*1.5); fin.rotation.y=ang; stage1.add_child(fin)
	# Stage 2
	stage2=Node3D.new(); r.add_child(stage2)
	var s2=MeshInstance3D.new(); var s2m=CylinderMesh.new()
	s2m.bottom_radius=1.0; s2m.top_radius=0.9; s2m.height=3.5
	s2.mesh=s2m; s2.material_override=mat_steel; s2.position=Vector3(0,8.75,0); stage2.add_child(s2)
	# Ship capsule
	ship_capsule=Node3D.new(); r.add_child(ship_capsule)
	var ship=MeshInstance3D.new(); var shm=CylinderMesh.new()
	shm.bottom_radius=0.8; shm.top_radius=0.15; shm.height=3.0
	ship.mesh=shm; ship.material_override=mat_ship; ship.position=Vector3(0,12.0,0); ship_capsule.add_child(ship)
	return r

func _process(dt: float) -> void:
	if root==null: return
	phase_time+=dt
	var ph=PHASES[phase]
	label.text=ph.name
	# Physics: thrust accelerates the rocket upward
	if ph.get("thrust",false):
		rocket_vy+=25.0*dt
		rocket_vy=minf(rocket_vy,120.0)
		rocket_y+=rocket_vy*dt
	# Stage 1 separation: drop stage1 behind
	if ph.get("separate1",false) and phase_time<0.3:
		if stage1!=null:
			var drop=Node3D.new(); drop.add_child(stage1)
			stage1.position=Vector3(0,-rocket_y,0)
			root.add_child(stage1)
			stage1=stage1  # keep reference but it now falls
	if ph.get("separate2",false) and phase_time<0.3:
		if stage2!=null:
			root.add_child(stage2); stage2.position=Vector3(0,rocket_y-1,0)
	# Ship separation: capsule flies free
	if ph.get("separate_ship",false) and phase_time<0.3:
		if ship_capsule!=null:
			root.add_child(ship_capsule); ship_capsule.position=Vector3(0,rocket_y+3,0)
	rocket.position=Vector3(0,rocket_y,0)
	# Camera follows from the side, pulling back as rocket rises
	camera_dist=lerpf(camera_dist,30.0+rocket_y*0.3,minf(1.0,dt*2.0))
	camera.position=Vector3(cos(camera_angle)*camera_dist,rocket_y+5,sin(camera_angle)*camera_dist)
	camera.look_at(Vector3(0,rocket_y+5,0))
	# Background fades to space as altitude increases
	var sky_t=clampf(rocket_y/300.0,0.0,1.0)
	if viewport.get_child(0)!=null:
		var env_node=viewport.get_child(0).get_node_or_null("WorldEnvironment")
		if env_node and env_node.environment:
			env_node.environment.background_color=Color(0.15,0.25,0.45).lerp(Color(0.005,0.006,0.015),sky_t)
	# Advance phase
	if phase_time>=float(ph.dur):
		phase+=1; phase_time=0.0
		if phase>=PHASES.size():
			# Fade out and signal done
			var tw=create_tween(); tw.tween_property(veil,"color:a",1.0,0.8)
			await tw.finished
			sequence_done.emit(); queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		sequence_done.emit(); queue_free()
