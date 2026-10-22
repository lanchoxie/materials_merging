extends Control
## v0.71: 3D space flight scene — player pilots the ship in real 3D space.
## Planets are solid spheres; the sun is an OmniLight3D; the ship flies
## with WASD + mouse look. Approach a planet to enter orbit and land.
signal landed(planet_id: String)
signal dismissed

const Shape=preload("res://scripts/planet_shape.gd")
const UI=preload("res://scripts/ui.gd")

var viewport: SubViewport
var camera: Camera3D
var ship: Node3D
var planets: Dictionary={}   # id → {node, pos, radius, info}
var ship_pos: Vector3=Vector3.ZERO
var ship_vel: Vector3=Vector3.ZERO
var ship_yaw: float=0.0
var ship_pitch: float=0.0
var ship_roll: float=0.0
var cockpit_mode: bool=false
var speed: float=80.0  # always moving forward; Shift boosts, Space slows
var here: String=""
var state
## v0.71: orbital approach state machine.
## "free" = normal flight, "approach" = auto-decelerating toward planet, "landing" = done
var flight_state: String="free"
var approach_target: String=""
var approach_timer: float=0.0
var hud: Label
var aim_label: Label
var close_btn: Button
var view_btn: Button
## v0.71: key state tracking (SubViewportContainer blocks Input.is_key_pressed)
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
	var bmat=StandardMaterial3D.new(); bmat.albedo_color=Color("aaccdd"); bmat.metallic=0.7; bmat.roughness=0.3
	var wmat=StandardMaterial3D.new(); wmat.albedo_color=Color("223344"); wmat.metallic=0.5
	var engmat=StandardMaterial3D.new(); engmat.albedo_color=Color("224466"); engmat.emission_enabled=true
	engmat.emission=Color("2244aa"); engmat.emission_energy_multiplier=1.2
	# Main hull — horizontal saucer-ish box
	var hull=MeshInstance3D.new(); var hm=BoxMesh.new(); hm.size=Vector3(6,1.2,10)
	hull.mesh=hm; hull.material_override=bmat; s.add_child(hull)
	# Raised bridge on top
	var bridge=MeshInstance3D.new(); var brm=BoxMesh.new(); brm.size=Vector3(2.5,1.0,3.5)
	bridge.mesh=brm; bridge.material_override=bmat; bridge.position=Vector3(0,1.1,-1.0); s.add_child(bridge)
	# Left / right engine pods
	for side in [-1,1]:
		var pod=MeshInstance3D.new(); var pm=BoxMesh.new(); pm.size=Vector3(1.0,0.8,4.0)
		pod.mesh=pm; pod.material_override=bmat; pod.position=Vector3(side*3.8,0,1.0); s.add_child(pod)
		# Engine glow at rear of each pod
		var glow=MeshInstance3D.new(); var gm=CylinderMesh.new()
		gm.bottom_radius=0.4; gm.top_radius=0.4; gm.height=0.3
		glow.mesh=gm; glow.material_override=engmat; glow.position=Vector3(side*3.8,0,3.2); glow.rotation.x=PI/2; s.add_child(glow)
	# Centre rear engine
	var ceng=MeshInstance3D.new(); var cem=CylinderMesh.new()
	cem.bottom_radius=0.6; cem.top_radius=0.6; cem.height=0.4
	ceng.mesh=cem; ceng.material_override=engmat; ceng.position=Vector3(0,0,5.2); ceng.rotation.x=PI/2; s.add_child(ceng)
	# Cockpit windows
	var win=MeshInstance3D.new(); var wm=BoxMesh.new(); wm.size=Vector3(1.8,0.4,0.2)
	win.mesh=wm; win.material_override=wmat; win.position=Vector3(0,1.6,-2.6); s.add_child(win)
	# Small white point light (no colored glow)
	var eng_light=OmniLight3D.new(); eng_light.light_color=Color("aaccff"); eng_light.light_energy=0.8; eng_light.omni_range=20
	eng_light.position=Vector3(0,0,5); s.add_child(eng_light)
	return s

func _build_hud() -> void:
	hud=Label.new(); hud.add_theme_font_size_override("font_size",16)
	hud.add_theme_color_override("font_color",Color("aaccdd"))
	hud.position=Vector2(20,20); hud.size=Vector2(400,60); add_child(hud)
	aim_label=Label.new(); aim_label.add_theme_font_size_override("font_size",18)
	aim_label.add_theme_color_override("font_color",Color("88ffcc"))
	aim_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	aim_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aim_label.offset_top=get_viewport().get_visible_rect().size.y-80; add_child(aim_label)
	close_btn=UI.button("返回地面",func(): dismissed.emit(); queue_free())
	close_btn.position=Vector2(20,get_viewport().get_visible_rect().size.y-50); close_btn.size=Vector2(120,36); add_child(close_btn)
	view_btn=UI.button("视角 V",func(): cockpit_mode=not cockpit_mode)
	view_btn.position=Vector2(150,get_viewport().get_visible_rect().size.y-50); view_btn.size=Vector2(100,36); add_child(view_btn)

func _process(dt: float) -> void:
	if ship==null or camera==null: return
	var fwd=Vector3.FORWARD.rotated(Vector3.UP,ship_yaw).rotated(Vector3.RIGHT.rotated(Vector3.UP,ship_yaw),ship_pitch)
	# Throttle
	if keys_held.get(KEY_SHIFT,false): speed=minf(speed+80*dt,400)
	elif keys_held.get(KEY_SPACE,false): speed=maxf(speed-80*dt,0)
	# Yaw/pitch from WASD
	if keys_held.get(KEY_A,false): ship_yaw+=1.2*dt
	if keys_held.get(KEY_D,false): ship_yaw-=1.2*dt
	if keys_held.get(KEY_W,false): ship_pitch-=0.8*dt
	if keys_held.get(KEY_S,false): ship_pitch+=0.8*dt
	ship_pitch=clampf(ship_pitch,-1.2,1.2)
	# Apply velocity
	ship_vel=fwd*speed
	ship_pos+=ship_vel*dt
	ship.position=ship_pos
	ship.rotation=Vector3(ship_pitch,ship_yaw,0)
	# Camera
	if cockpit_mode:
		camera.position=ship_pos+Vector3(0,0.5,-2)
		camera.rotation=Vector3(ship_pitch,ship_yaw,0)
	else:
		var cam_back=fwd*25+Vector3(0,5,0)
		camera.position=ship_pos-cam_back
		camera.look_at(ship_pos)
	# Check planet proximity and orbital approach state machine
	var nearest=""; var nearest_dist=1e9
	for pid in planets:
		var p=planets[pid]; var d=ship_pos.distance_to(p.pos as Vector3)-float(p.radius)
		if d<nearest_dist: nearest_dist=d; nearest=pid
	if flight_state=="free":
		if nearest_dist<600 and nearest!="" and nearest!=here:
			flight_state="approach"; approach_target=nearest; approach_timer=0.0
			aim_label.text="进入 %s 轨道 · 自动减速中…" % str(planets[nearest].info.name)
		elif nearest_dist<300 and nearest==here:
			aim_label.text="你在 %s 轨道 · 按 L 起飞到另一轨道" % str(planets[nearest].info.name)
		elif nearest!="" and nearest_dist<1200:
			aim_label.text="接近 %s · %d km" % [str(planets[nearest].info.name),roundi(nearest_dist/100)]
		else:
			aim_label.text="WASD 转向 · Shift 加速 · Space 减速 · V 切视角 · L 降落"
	elif flight_state=="approach":
		approach_timer+=dt
		# Auto-decelerate and steer toward planet
		var target_p=planets[approach_target].pos as Vector3
		var toward=(target_p-ship_pos).normalized()
		ship_yaw=lerpf(ship_yaw,atan2(-toward.x,-toward.z),minf(1.0,dt*0.8))
		ship_pitch=lerpf(ship_pitch,atan2(-toward.y,Vector2(toward.x,toward.z).length()),minf(1.0,dt*0.8))
		speed=lerpf(speed,15.0,minf(1.0,dt*0.6))
		aim_label.text="减速进入轨道 · %d m/s · %.0f km" % [roundi(speed),nearest_dist/100]
		if nearest_dist<float(planets[approach_target].radius)+80.0 or approach_timer>12.0:
			flight_state="landing"
			aim_label.text="即将降落 %s…" % str(planets[approach_target].info.name)
	elif flight_state=="landing":
		approach_timer+=dt
		if approach_timer>2.0:
			landed.emit(approach_target); queue_free(); return
	hud.text="速度 %d m/s · %s" % [roundi(speed), "座舱视角" if cockpit_mode else "追踪视角"]

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if event.pressed: keys_held[code]=true
		else: keys_held.erase(code)
		if event.pressed and not event.echo:
			if code==KEY_V: cockpit_mode=not cockpit_mode
			if code==KEY_L:
				var nearest=""; var nearest_dist=1e9
				for pid in planets:
					var p=planets[pid]; var d=ship_pos.distance_to(p.pos as Vector3)-float(p.radius)
					if d<nearest_dist: nearest_dist=d; nearest=pid
				if nearest_dist<500 and nearest!="": landed.emit(nearest); queue_free()
			if code==KEY_ESCAPE: dismissed.emit(); queue_free()
