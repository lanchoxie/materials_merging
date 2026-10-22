extends Control
## v0.72: 3D rocket launch — ground launch, staged separation, earth receding.
signal sequence_done

var viewport: SubViewport
var camera: Camera3D
var root: Node3D
var rocket_root: Node3D   # entire stack (moves up)
var s1_node: Node3D       # stage 1 body (separates and falls)
var s2_node: Node3D       # stage 2 body (separates later)
var cap_node: Node3D      # ship capsule (stays)
var earth_node: Node3D    # planet sphere far below
var s1_sep: bool=false; var s1_vel: float=0.0; var s1_y: float=0.0
var s2_sep: bool=false; var s2_vel: float=0.0; var s2_y: float=0.0
var rocket_y: float=0.0
var rocket_vy: float=0.0
var phase: int=0
var phase_time: float=0.0
var cockpit_mode: bool=false
var cockpit_overlay: Control=null
var label: Label
var veil: ColorRect
var world_env: WorldEnvironment

const PHASES=[
	{"name":"倒计时 3… 2… 1…","dur":2.2,"thrust":false},
	{"name":"🚀 点火！","dur":1.2,"thrust":true},
	{"name":"升空…","dur":3.0,"thrust":true},
	{"name":"一级分离","dur":2.0,"thrust":true,"sep1":true},
	{"name":"二级点火","dur":3.0,"thrust":true},
	{"name":"穿越大气层","dur":2.5,"thrust":true},
	{"name":"进入轨道","dur":2.0,"thrust":true,"sep2":true},
	{"name":"舰船分离","dur":1.5,"thrust":false},
	{"name":"进入深空","dur":1.0,"thrust":false},
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var svc=SubViewportContainer.new(); svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch=true; add_child(svc)
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,720)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; svc.add_child(viewport)
	root=Node3D.new(); viewport.add_child(root)
	# Environment
	var env=Environment.new(); env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0.18,0.32,0.55)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(0.4,0.5,0.6); env.ambient_light_energy=0.6
	world_env=WorldEnvironment.new(); world_env.environment=env; root.add_child(world_env)
	camera=Camera3D.new(); camera.fov=55; camera.far=80000; root.add_child(camera)
	# Sun
	var sun=DirectionalLight3D.new(); sun.position=Vector3(300,400,200)
	root.add_child(sun); sun.look_at(Vector3.ZERO); sun.light_energy=1.4
	# Ground
	var gnd=MeshInstance3D.new(); var gm=BoxMesh.new(); gm.size=Vector3(600,2,600)
	gnd.mesh=gm; var gmat=StandardMaterial3D.new(); gmat.albedo_color=Color("3a4a2a")
	gnd.material_override=gmat; gnd.position=Vector3(0,-1,0); root.add_child(gnd)
	# Launch pad
	var pad=MeshInstance3D.new(); var pm=CylinderMesh.new(); pm.bottom_radius=8; pm.top_radius=8; pm.height=0.5
	pad.mesh=pm; var pmat=StandardMaterial3D.new(); pmat.albedo_color=Color("888888")
	pad.material_override=pmat; root.add_child(pad)
	# Earth sphere (large, far below horizon — visible as rocket climbs)
	earth_node=MeshInstance3D.new(); var em=SphereMesh.new(); em.radius=6200; em.height=12400; em.radial_segments=32; em.rings=16
	earth_node.mesh=em; var emat=StandardMaterial3D.new(); emat.albedo_color=Color("2255aa"); emat.roughness=0.9
	earth_node.material_override=emat; earth_node.position=Vector3(0,-6400,0); root.add_child(earth_node)
	# Build rocket stack
	rocket_root=Node3D.new(); root.add_child(rocket_root)
	_build_stack()
	# HUD
	label=Label.new(); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",28); label.add_theme_color_override("font_color",Color("ffffff"))
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); label.offset_bottom=-200; add_child(label)
	veil=ColorRect.new(); veil.color=Color(0,0,0,0); veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(veil)
	cockpit_overlay=_build_cockpit(); add_child(cockpit_overlay); cockpit_overlay.hide()
	var hint=Label.new(); hint.text="V 键切换座舱/第三人称 · ESC 跳过"
	hint.add_theme_font_size_override("font_size",13); hint.add_theme_color_override("font_color",Color("667788"))
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.offset_top=get_viewport().get_visible_rect().size.y-32; add_child(hint)

func _build_stack() -> void:
	var mat_w=StandardMaterial3D.new(); mat_w.albedo_color=Color("e8eef0"); mat_w.metallic=0.6; mat_w.roughness=0.35
	var mat_g=StandardMaterial3D.new(); mat_g.albedo_color=Color("c8d4dc"); mat_g.metallic=0.8; mat_g.roughness=0.3
	var mat_d=StandardMaterial3D.new(); mat_d.albedo_color=Color("333840"); mat_d.metallic=0.7; mat_d.roughness=0.5
	var mat_n=StandardMaterial3D.new(); mat_n.albedo_color=Color("1a1a20"); mat_n.metallic=0.5
	# Stage 1 (lowest): 8m tall, wide body + fins + 3 nozzles
	s1_node=Node3D.new(); rocket_root.add_child(s1_node)
	var s1b=MeshInstance3D.new(); var s1m=CylinderMesh.new(); s1m.bottom_radius=1.6; s1m.top_radius=1.3; s1m.height=8
	s1b.mesh=s1m; s1b.material_override=mat_g; s1b.position=Vector3(0,4,0); s1_node.add_child(s1b)
	# Engine band
	var s1band=MeshInstance3D.new(); var s1bm=CylinderMesh.new(); s1bm.bottom_radius=1.7; s1bm.top_radius=1.6; s1bm.height=0.6
	s1band.mesh=s1bm; s1band.material_override=mat_d; s1band.position=Vector3(0,0.3,0); s1_node.add_child(s1band)
	# 3 nozzles
	for k in range(3):
		var ang=k*TAU/3; var nz=MeshInstance3D.new(); var nzm=CylinderMesh.new()
		nzm.bottom_radius=0.45; nzm.top_radius=0.25; nzm.height=1.2; nz.mesh=nzm; nz.material_override=mat_n
		nz.position=Vector3(cos(ang)*0.7,-0.4,sin(ang)*0.7); s1_node.add_child(nz)
	# Fins
	for k in range(4):
		var ang=k*PI/2; var fin=MeshInstance3D.new(); var fm=BoxMesh.new(); fm.size=Vector3(0.18,3.0,1.8)
		fin.mesh=fm; fin.material_override=mat_g
		fin.position=Vector3(cos(ang)*1.6,1.5,sin(ang)*1.6); fin.rotation.y=ang; s1_node.add_child(fin)
	# Stage 2: 4m tall, narrower
	s2_node=Node3D.new(); rocket_root.add_child(s2_node); s2_node.position.y=8.0
	var s2b=MeshInstance3D.new(); var s2m=CylinderMesh.new(); s2m.bottom_radius=1.1; s2m.top_radius=0.95; s2m.height=4
	s2b.mesh=s2m; s2b.material_override=mat_w; s2b.position=Vector3(0,2,0); s2_node.add_child(s2b)
	# Interstage ring
	var s2ring=MeshInstance3D.new(); var s2rm=CylinderMesh.new(); s2rm.bottom_radius=1.15; s2rm.top_radius=1.15; s2rm.height=0.3
	s2ring.mesh=s2rm; s2ring.material_override=mat_d; s2ring.position=Vector3(0,-0.15,0); s2_node.add_child(s2ring)
	# Ship capsule: sits on top, 3m, conical
	cap_node=Node3D.new(); rocket_root.add_child(cap_node); cap_node.position.y=12.0
	var capb=MeshInstance3D.new(); var cm=CylinderMesh.new(); cm.bottom_radius=0.9; cm.top_radius=0.12; cm.height=3.2
	capb.mesh=cm; capb.material_override=mat_w; capb.position=Vector3(0,1.6,0); cap_node.add_child(capb)
	# Window strip on capsule
	var win=MeshInstance3D.new(); var wm=CylinderMesh.new(); wm.bottom_radius=0.85; wm.top_radius=0.85; wm.height=0.3
	win.mesh=wm; win.material_override=mat_n; win.position=Vector3(0,1.5,0); cap_node.add_child(win)
	# Solar panel wings on capsule
	for side in [-1,1]:
		var pw=MeshInstance3D.new(); var pwm=BoxMesh.new(); pwm.size=Vector3(3.0,0.05,1.2)
		pw.mesh=pwm; var pmat=StandardMaterial3D.new(); pmat.albedo_color=Color("224488"); pmat.metallic=0.6
		pw.material_override=pmat; pw.position=Vector3(side*2.2,1.5,0); cap_node.add_child(pw)

func _build_cockpit() -> Control:
	var vw=get_viewport().get_visible_rect().size
	var ov=Control.new(); ov.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var cabin=ColorRect.new(); cabin.color=Color(0.04,0.06,0.09); cabin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cabin.mouse_filter=Control.MOUSE_FILTER_IGNORE; ov.add_child(cabin)
	# Seat + belts
	var seat=ColorRect.new(); seat.color=Color(0.10,0.12,0.16); seat.position=Vector2(0,vw.y*0.68); seat.size=Vector2(vw.x,vw.y*0.32)
	seat.mouse_filter=Control.MOUSE_FILTER_IGNORE; ov.add_child(seat)
	for dx in [-200,200]:
		var belt=ColorRect.new(); belt.color=Color(0.50,0.40,0.20); belt.size=Vector2(24,vw.y*0.36)
		belt.position=Vector2(vw.x*0.5+dx-12,vw.y*0.52); belt.rotation=0.36*(1 if dx>0 else -1)
		belt.mouse_filter=Control.MOUSE_FILTER_IGNORE; ov.add_child(belt)
	# Porthole
	var pr=Rect2(vw*0.5-Vector2(170,120),Vector2(340,240))
	var pbg=ColorRect.new(); pbg.color=Color(0.02,0.04,0.08); pbg.position=pr.position; pbg.size=pr.size
	pbg.mouse_filter=Control.MOUSE_FILTER_IGNORE; ov.add_child(pbg)
	var pg=ColorRect.new(); pg.color=Color(0.12,0.28,0.55,0.6); pg.position=pr.position+Vector2(16,16); pg.size=Vector2(308,208)
	pg.mouse_filter=Control.MOUSE_FILTER_IGNORE; ov.add_child(pg); ov.set_meta("pg",pg)
	# Frame
	for bar in [[Vector2(0,0),Vector2(340,14)],[Vector2(0,226),Vector2(340,14)],[Vector2(0,0),Vector2(14,240)],[Vector2(326,0),Vector2(14,240)],[Vector2(0,112),Vector2(340,10)]]:
		var fr=ColorRect.new(); fr.color=Color(0.16,0.18,0.20); fr.position=pr.position+bar[0]; fr.size=bar[1]
		fr.mouse_filter=Control.MOUSE_FILTER_IGNORE; ov.add_child(fr)
	return ov

func _process(dt: float) -> void:
	if root==null or phase>=PHASES.size(): return
	phase_time+=dt
	var ph=PHASES[phase]; label.text=ph.name
	# Thrust
	if ph.get("thrust",false):
		rocket_vy=minf(rocket_vy+30*dt,150)
		rocket_y+=rocket_vy*dt
	# Stage 1 separation: detach and fall
	if ph.get("sep1",false) and not s1_sep:
		s1_sep=true; s1_y=rocket_y; s1_vel=rocket_vy
		root.add_child(s1_node); s1_node.position=Vector3(0,s1_y,0)
	# Stage 2 separation
	if ph.get("sep2",false) and not s2_sep:
		s2_sep=true; s2_y=rocket_y; s2_vel=rocket_vy
		root.add_child(s2_node); s2_node.position=Vector3(0,s2_y,0)
	# Animate separated stages (gravity pulls them down relative to camera)
	if s1_sep:
		s1_vel-=8*dt; s1_y+=s1_vel*dt; s1_node.position.y=s1_y
	if s2_sep:
		s2_vel-=5*dt; s2_y+=s2_vel*dt; s2_node.position.y=s2_y
	# Main rocket (remaining capsule) rises
	rocket_root.position.y=rocket_y
	# Sky fade
	var sky_t=clampf(rocket_y/600,0,1)
	world_env.environment.background_color=Color(0.18,0.32,0.55).lerp(Color(0.005,0.006,0.015),sky_t)
	# Camera
	if cockpit_mode and is_instance_valid(cockpit_overlay):
		cockpit_overlay.show()
		camera.position=Vector3(0,rocket_y+13.5,0.5)
		camera.rotation=Vector3(deg_to_rad(85),0,0)
		var pg=cockpit_overlay.get_meta("pg") as ColorRect
		if pg: pg.color=Color(0.12,0.28,0.55,0.6).lerp(Color(0.005,0.006,0.015,0.9),sky_t)
	else:
		if is_instance_valid(cockpit_overlay): cockpit_overlay.hide()
		var cam_d=lerpf(35,25+rocket_y*0.08,minf(1,dt*1.5))
		camera.position=Vector3(cam_d*0.7,rocket_y+6,cam_d*0.7)
		camera.look_at(Vector3(0,rocket_y+6,0))
	# Advance phase
	if phase_time>=float(ph.dur):
		phase+=1; phase_time=0
		if phase>=PHASES.size():
			var tw=create_tween(); tw.tween_property(veil,"color:a",1.0,0.8)
			await tw.finished
			sequence_done.emit(); queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_V: cockpit_mode=not cockpit_mode
		if event.physical_keycode==KEY_ESCAPE: sequence_done.emit(); queue_free()
