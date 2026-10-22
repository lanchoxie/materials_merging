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
var speed: float=0.0
var here: String=""
var state
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
	# --- Starfield (small cubes via MultiMesh) ---
	var rng=RandomNumberGenerator.new(); rng.seed=7777
	var mm=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D
	var star_cube=BoxMesh.new(); star_cube.size=Vector3(8,8,8); mm.mesh=star_cube
	mm.instance_count=600
	var star_mat=StandardMaterial3D.new(); star_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.albedo_color=Color(1,1,1,0.9)
	star_cube.surface_set_material(0,star_mat)
	for i in range(600):
		var dir=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		var t=Transform3D(); t.origin=dir*rng.randf_range(8000,14000)
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
	var body=MeshInstance3D.new(); var bm=BoxMesh.new(); bm.size=Vector3(3,3,8)
	body.mesh=bm; var bmat=StandardMaterial3D.new(); bmat.albedo_color=Color("aaccdd"); bmat.metallic=0.7
	body.material_override=bmat; s.add_child(body)
	var nose=MeshInstance3D.new(); var nm=CylinderMesh.new(); nm.bottom_radius=1.5; nm.top_radius=0.05; nm.height=4
	nose.mesh=nm; nose.position=Vector3(0,0,-6); nose.material_override=bmat; s.add_child(nose)
	# Engine glow
	var eng=OmniLight3D.new(); eng.light_color=Color("4488ff"); eng.light_energy=1.5; eng.omni_range=30
	eng.position=Vector3(0,0,5); s.add_child(eng)
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
	# Check planet proximity
	var nearest=""; var nearest_dist=1e9
	for pid in planets:
		var p=planets[pid]; var d=ship_pos.distance_to(p.pos)-p.radius
		if d<nearest_dist: nearest_dist=d; nearest=pid
	if nearest_dist<300 and nearest!="":
		var pinfo=planets[nearest].info
		aim_label.text="靠近 %s · 按 L 降落" % str(pinfo.name)
		if Input.is_key_pressed(KEY_L):
			landed.emit(nearest); queue_free(); return
	elif nearest_dist<800 and nearest!="":
		aim_label.text="接近 %s 轨道" % str(planets[nearest].info.name)
	else:
		aim_label.text=""
	hud.text="速度 %d m/s · 坐标 (%.0f, %.0f, %.0f)" % [roundi(speed),ship_pos.x,ship_pos.y,ship_pos.z]

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
