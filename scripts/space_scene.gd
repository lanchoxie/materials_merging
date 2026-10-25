extends Control
## v0.73: 3D space flight — Dragon capsule, orbital approach with nav arrows, drag camera.
signal landed(planet_id: String)
signal dismissed

const Shape=preload("res://scripts/planet_shape.gd")
const UI=preload("res://scripts/ui.gd")

var viewport: SubViewport
var camera: Camera3D
var ship: Node3D
var planets: Dictionary={}
var ship_pos: Vector3=Vector3.ZERO
var ship_yaw: float=0.0
var ship_pitch: float=0.0
var cockpit_mode: bool=false
var speed: float=80.0
var here: String=""
var state

## Orbital approach state machine
var flight_state: String="free"  # free / approach_window / approach_commit / landing
var approach_target: String=""
var approach_timer: float=0.0
var approach_window_good: bool=false  # is the approach angle acceptable?

## Camera drag (third-person orbit)
var cam_yaw_offset: float=0.0    # added to ship_yaw for orbit
var cam_pitch_offset: float=0.18
var cam_dist: float=28.0
var drag_active: bool=false
var drag_last: Vector2=Vector2.ZERO

var hud: Label
var aim_label: Label
var nav_label: Label  # navigation arrow + distance info
var view_btn: Button
var keys_held: Dictionary={}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	# --- 3D viewport via SubViewportContainer ---
	var svc=SubViewportContainer.new(); svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch=true; add_child(svc)
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,720)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; svc.add_child(viewport)
	var root=Node3D.new(); viewport.add_child(root)
	# World environment
	var env=Environment.new(); env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0.005,0.006,0.015); env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color(0.05,0.06,0.08); env.ambient_light_energy=0.2
	var we=WorldEnvironment.new(); we.environment=env; root.add_child(we)
	camera=Camera3D.new(); camera.fov=70; camera.far=50000; root.add_child(camera)
	# --- Starfield (visible emissive spheres via MultiMesh) ---
	var rng=RandomNumberGenerator.new(); rng.seed=7777
	var mm=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D
	var star_sphere=SphereMesh.new(); star_sphere.radius=40; star_sphere.height=80; star_sphere.radial_segments=6; star_sphere.rings=4
	mm.mesh=star_sphere; mm.instance_count=500
	var star_mat=StandardMaterial3D.new(); star_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color=Color(1,1,1,1); star_mat.emission_enabled=true
	star_mat.emission=Color(1,1,1); star_mat.emission_energy_multiplier=2.0
	star_sphere.surface_set_material(0,star_mat)
	for i in range(500):
		var dir=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		var t=Transform3D(); t.origin=dir*rng.randf_range(6000,12000)
		# Random scale variation
		var s=rng.randf_range(0.3,1.5); t=t.scaled(Vector3(s,s,s))
		mm.set_instance_transform(i,t)
	var stars=MultiMeshInstance3D.new(); stars.multimesh=mm; root.add_child(stars)
	# --- Sun ---
	var sun=MeshInstance3D.new(); var sun_m=SphereMesh.new(); sun_m.radius=120; sun_m.height=240; sun.mesh=sun_m
	var sun_mat=StandardMaterial3D.new(); sun_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_mat.albedo_color=Color(1.0,0.92,0.55); sun_mat.emission=Color(1.0,0.85,0.4); sun_mat.emission_energy_multiplier=3
	sun.material_override=sun_mat; sun.position=Vector3.ZERO; root.add_child(sun)
	var sun_light=OmniLight3D.new(); sun_light.light_color=Color(1,0.95,0.8); sun_light.light_energy=2.5
	sun_light.omni_range=20000; root.add_child(sun_light)
	# --- Planets ---
	var order=Shape.planets().order
	for i in order.size():
		var pid=order[i]; var info=Shape.profile_of(pid)
		var angle=TAU*float(i)/float(order.size())
		var dist=2500.0+i*1800.0
		var ppos=Vector3(cos(angle)*dist,0,sin(angle)*dist)
		var pmesh=MeshInstance3D.new(); var sm=SphereMesh.new()
		var pradius=180.0 if pid=="earth" else 140.0
		sm.radius=pradius; sm.height=pradius*2; pmesh.mesh=sm
		var tint=Color(info.get("globe_tint","4488bb")) if str(info.get("globe_tint",""))!="" else Color("4488bb")
		var pmat=StandardMaterial3D.new(); pmat.albedo_color=tint; pmat.roughness=0.85
		pmesh.material_override=pmat; pmesh.position=ppos; root.add_child(pmesh)
		# Planet label in 3D (Label3D)
		var plabel=Label3D.new(); plabel.text=str(info.name); plabel.position=ppos+Vector3(0,pradius+30,0)
		plabel.font_size=40; plabel.modulate=Color("c0e0ff"); root.add_child(plabel)
		planets[pid]={"node":pmesh,"pos":ppos,"radius":pradius,"info":info,"label":plabel}
	# --- Ship ---
	ship=_build_ship(); root.add_child(ship)
	# Start near the current planet
	here=str(state.planet.v2.planet)
	var hp=planets.get(here,{});
	if hp: ship_pos=hp.pos+Vector3(0,hp.radius+50,400) as Vector3
	else: ship_pos=Vector3(0,200,800)
	ship.position=ship_pos
	# --- HUD overlay ---
	_build_hud()

func _build_ship() -> Node3D:
	var s=Node3D.new()
	var mat=func(hex:String,metal:float=0.4,emit:bool=false):
		var m=StandardMaterial3D.new(); m.albedo_color=Color(hex); m.metallic=metal; m.roughness=0.35
		if emit: m.emission_enabled=true; m.emission=Color(hex); m.emission_energy_multiplier=1.8
		return m
	var add=func(mesh:Mesh,at:Vector3,material:Material,rot:Vector3=Vector3.ZERO):
		var n=MeshInstance3D.new(); n.mesh=mesh; n.position=at; n.rotation=rot; n.material_override=material; s.add_child(n); return n
	# Trunk
	var trm=CylinderMesh.new(); trm.bottom_radius=1.0;trm.top_radius=0.98;trm.height=2.4;trm.radial_segments=24
	add.call(trm,Vector3(0,-1.2,0),mat.call("7a8b96",0.5))
	# Solar panels (deployed wide)
	for side in [-1,1]:
		var slm=BoxMesh.new(); slm.size=Vector3(0.07,2.4,0.95)
		add.call(slm,Vector3(side*3.5,-0.5,0),mat.call("1a3a8c",0.4))
		# Solar cell grid lines
		var glm=BoxMesh.new(); glm.size=Vector3(0.08,2.4,0.05)
		for gi in range(4): add.call(glm,Vector3(side*3.5,-0.5,-0.36+gi*0.24),mat.call("0a1e5c",0.3))
	# Capsule body
	var csm=CylinderMesh.new(); csm.bottom_radius=0.95;csm.top_radius=0.16;csm.height=3.4;csm.radial_segments=28
	add.call(csm,Vector3(0,1.7,0),mat.call("edf2f6",0.4))
	# Heat shield
	var hsd=CylinderMesh.new(); hsd.bottom_radius=0.97;hsd.top_radius=0.97;hsd.height=0.28;hsd.radial_segments=24
	add.call(hsd,Vector3(0,0.12,0),mat.call("181c20",0.2))
	# Windows
	var wsm=CylinderMesh.new(); wsm.bottom_radius=0.88;wsm.top_radius=0.88;wsm.height=0.3;wsm.radial_segments=24
	add.call(wsm,Vector3(0,1.5,0),mat.call("7fcce8",0.05))
	# Nose cap
	var ncm=SphereMesh.new(); ncm.radius=0.16;ncm.height=0.26
	add.call(ncm,Vector3(0,3.3,0),mat.call("c0ccd4",0.4))
	# Engine glow (rear thrusters)
	for side in [-1,1]:
		var gm=CylinderMesh.new(); gm.bottom_radius=0.25;gm.top_radius=0.25;gm.height=0.18;gm.radial_segments=12
		add.call(gm,Vector3(side*0.6,-2.45,0),mat.call("9eeeff",0.05,true))
	# Nav light
	var eng_light=OmniLight3D.new(); eng_light.light_color=Color("aaddff"); eng_light.light_energy=1.0; eng_light.omni_range=22
	eng_light.position=Vector3(0,-2.5,0); s.add_child(eng_light)
	return s

func _build_hud() -> void:
	hud=Label.new(); hud.add_theme_font_size_override("font_size",16)
	hud.add_theme_color_override("font_color",Color("aaccdd"))
	hud.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	hud.add_theme_constant_override("outline_size",4)
	hud.position=Vector2(20,20); hud.size=Vector2(460,80); add_child(hud)
	aim_label=Label.new(); aim_label.add_theme_font_size_override("font_size",18)
	aim_label.add_theme_color_override("font_color",Color("88ffcc"))
	aim_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	aim_label.add_theme_constant_override("outline_size",5)
	aim_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	aim_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aim_label.offset_top=get_viewport().get_visible_rect().size.y-100; add_child(aim_label)
	# Navigation label (top centre)
	nav_label=Label.new(); nav_label.add_theme_font_size_override("font_size",15)
	nav_label.add_theme_color_override("font_color",Color("ffdd88"))
	nav_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	nav_label.add_theme_constant_override("outline_size",4)
	nav_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	nav_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nav_label.offset_bottom=-get_viewport().get_visible_rect().size.y*0.85; add_child(nav_label)
	var vy=get_viewport().get_visible_rect().size.y
	# NO "返回地面" button — player must fly to a planet to land
	view_btn=UI.button("视角 V",func(): cockpit_mode=not cockpit_mode)
	view_btn.position=Vector2(20,vy-50); view_btn.size=Vector2(100,36); add_child(view_btn)
	# Mobile flight buttons
	var vx=get_viewport().get_visible_rect().size.x
	var mb_up=UI.button("↑",func(): keys_held[KEY_W]=true; keys_held.erase(KEY_S))
	mb_up.position=Vector2(vx-170,vy-180); mb_up.size=Vector2(70,50); add_child(mb_up)
	var mb_down=UI.button("↓",func(): keys_held[KEY_S]=true; keys_held.erase(KEY_W))
	mb_down.position=Vector2(vx-170,vy-120); mb_down.size=Vector2(70,50); add_child(mb_down)
	var mb_left=UI.button("←",func(): keys_held[KEY_A]=true; keys_held.erase(KEY_D))
	mb_left.position=Vector2(vx-250,vy-120); mb_left.size=Vector2(70,50); add_child(mb_left)
	var mb_right=UI.button("→",func(): keys_held[KEY_D]=true; keys_held.erase(KEY_A))
	mb_right.position=Vector2(vx-90,vy-120); mb_right.size=Vector2(70,50); add_child(mb_right)
	var mb_acc=UI.button("加速",func(): keys_held[KEY_SHIFT]=true; keys_held.erase(KEY_SPACE))
	mb_acc.position=Vector2(vx-250,vy-180); mb_acc.size=Vector2(80,44); add_child(mb_acc)
	var mb_dec=UI.button("减速",func(): keys_held[KEY_SPACE]=true; keys_held.erase(KEY_SHIFT))
	mb_dec.position=Vector2(vx-330,vy-180); mb_dec.size=Vector2(80,44); add_child(mb_dec)

func _process(dt: float) -> void:
	if ship==null or camera==null: return
	var fwd=Vector3.FORWARD.rotated(Vector3.UP,ship_yaw).rotated(Vector3.RIGHT.rotated(Vector3.UP,ship_yaw),ship_pitch)
	# Throttle
	if keys_held.get(KEY_SHIFT,false): speed=minf(speed+80*dt,600)
	elif keys_held.get(KEY_SPACE,false): speed=maxf(speed-120*dt,0)
	# Yaw/pitch
	if keys_held.get(KEY_A,false): ship_yaw+=1.2*dt
	if keys_held.get(KEY_D,false): ship_yaw-=1.2*dt
	if keys_held.get(KEY_W,false): ship_pitch-=0.8*dt
	if keys_held.get(KEY_S,false): ship_pitch+=0.8*dt
	ship_pitch=clampf(ship_pitch,-1.2,1.2)
	ship_pos+=fwd*speed*dt
	ship.position=ship_pos
	ship.rotation=Vector3(ship_pitch,ship_yaw,0)

	# ── Camera ─────────────────────────────────────────────────────────────
	if cockpit_mode:
		# Inside capsule: camera sits at capsule nose, looks forward
		camera.position=ship_pos+Vector3(0,2.0,0)+Vector3(-sin(ship_yaw)*0.5,0,-cos(ship_yaw)*0.5)
		camera.rotation=Vector3(ship_pitch,ship_yaw,0)
	else:
		# Third-person orbit: drag offsets cam_yaw_offset / cam_pitch_offset
		var total_yaw=ship_yaw+cam_yaw_offset
		var cp=clampf(cam_pitch_offset,-0.3,1.1)
		var cam_offset=Vector3(
			sin(total_yaw)*cos(cp),
			sin(cp),
			cos(total_yaw)*cos(cp))*cam_dist
		camera.position=ship_pos-cam_offset+Vector3(0,2,0)
		camera.look_at(ship_pos+Vector3(0,1,0))

	# ── Find nearest planet ────────────────────────────────────────────────
	var nearest=""; var nearest_dist=1e9
	for pid in planets:
		var p=planets[pid]
		var d=ship_pos.distance_to(p.pos as Vector3)-float(p.radius)
		if d<nearest_dist: nearest_dist=d; nearest=pid

	# ── Navigation HUD: direction arrow to nearest non-here planet ─────────
	var nav_target=""
	var nav_dist=1e9
	for pid in planets:
		if pid==here: continue
		var d=ship_pos.distance_to(planets[pid].pos as Vector3)-float(planets[pid].radius)
		if d<nav_dist: nav_dist=d; nav_target=pid
	if nav_target!="":
		var toward=(planets[nav_target].pos as Vector3 - ship_pos).normalized()
		var dot_fwd=toward.dot(fwd)
		var dot_right=toward.dot(Vector3.RIGHT.rotated(Vector3.UP,ship_yaw))
		var dot_up=toward.dot(Vector3.UP)
		var arrow="→"
		if dot_fwd>0.7: arrow="↑ 前方"
		elif dot_fwd<-0.7: arrow="↓ 后方"
		elif dot_right>0.4: arrow="→ 右转"
		elif dot_right<-0.4: arrow="← 左转"
		elif dot_up>0.3: arrow="↑ 上方"
		else: arrow="↓ 下方"
		var km=roundi(nav_dist/100)
		nav_label.text="导航 %s → %s %d km" % [str(planets[nav_target].info.name),arrow,km]

	# ── Approach state machine ─────────────────────────────────────────────
	match flight_state:
		"free":
			if nearest_dist<600 and nearest!="" and nearest!=here:
				# Check approach angle: must be flying roughly toward the planet
				var target_p=planets[nearest].pos as Vector3
				var toward_planet=(target_p-ship_pos).normalized()
				var approach_dot=fwd.dot(toward_planet)
				approach_window_good=(approach_dot>0.65 and speed>20.0)
				if approach_window_good:
					flight_state="approach_window"
					aim_label.text="📡 进入 %s 降落窗口 · 保持航向 · 自动接管…" % str(planets[nearest].info.name)
					approach_target=nearest; approach_timer=0.0
				else:
					var angle_deg=roundi(rad_to_deg(acos(clampf(approach_dot,-1,1))))
					aim_label.text="接近 %s · %d km · 航向偏差 %d° (需 <40°)" % [str(planets[nearest].info.name),roundi(nearest_dist/100),angle_deg]
			elif nearest_dist<300 and nearest==here:
				aim_label.text="在 %s 轨道 · 飞向其他星球" % str(planets[nearest].info.name)
			elif nearest!="" and nearest_dist<2000:
				aim_label.text="接近 %s · %d km · WASD转向" % [str(planets[nearest].info.name),roundi(nearest_dist/100)]
			else:
				aim_label.text="WASD转向 · Shift加速 · Space减速 · V切视角 · 拖动转视角"
		"approach_window":
			approach_timer+=dt
			var target_p=planets[approach_target].pos as Vector3
			var toward=(target_p-ship_pos).normalized()
			# Auto-steer + decelerate
			ship_yaw=lerpf(ship_yaw,atan2(-toward.x,-toward.z),minf(1.0,dt*1.2))
			ship_pitch=lerpf(ship_pitch,atan2(-toward.y,Vector2(toward.x,toward.z).length()),minf(1.0,dt*1.0))
			speed=lerpf(speed,8.0,minf(1.0,dt*0.9))
			var orbit_h=roundi(ship_pos.distance_to(planets[approach_target].pos as Vector3)-float(planets[approach_target].radius))
			aim_label.text="🛸 降落轨道 %s · 高度 %d km · %d m/s · 自动对准…" % [str(planets[approach_target].info.name),roundi(orbit_h/100),roundi(speed)]
			if orbit_h<int(planets[approach_target].radius)+90 or approach_timer>18.0:
				flight_state="landing"
				aim_label.text="🌍 进入 %s 大气层…" % str(planets[approach_target].info.name)
		"landing":
			approach_timer+=dt
			if approach_timer>2.5:
				landed.emit(approach_target); queue_free(); return

	hud.text="速度 %d m/s · 高度 %d km\n%s" % [
		roundi(speed),
		roundi(ship_pos.length()/100) if here=="" else roundi((ship_pos.distance_to(planets.get(here,{}).get("pos",Vector3.ZERO))-float(planets.get(here,{}).get("radius",0)))/100),
		"座舱" if cockpit_mode else "追踪视角"]

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if event.pressed: keys_held[code]=true
		else: keys_held.erase(code)
		if event.pressed and not event.echo:
			if code==KEY_V: cockpit_mode=not cockpit_mode
	# Third-person camera drag
	if not cockpit_mode:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
			drag_active=event.pressed; drag_last=event.position
		elif event is InputEventScreenTouch:
			drag_active=event.pressed; drag_last=event.position
		if event is InputEventMouseMotion and drag_active:
			var d=event.position-drag_last; drag_last=event.position
			cam_yaw_offset+=d.x*0.01
			cam_pitch_offset=clampf(cam_pitch_offset-d.y*0.008,-0.3,1.1)
		elif event is InputEventScreenDrag:
			cam_yaw_offset+=event.relative.x*0.01
			cam_pitch_offset=clampf(cam_pitch_offset-event.relative.y*0.008,-0.3,1.1)
			cam_pitch_offset=clampf(cam_pitch_offset-event.relative.y*0.007,-0.3,1.1)
