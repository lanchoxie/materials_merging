extends Control
## v0.72.8: Cinematic rocket launch running inside the real planet scene.
## No separate SubViewport — terrain, water, trees and clouds stay visible.
signal sequence_done

## Set by main.gd before add_child().
var view          # planet_v2_view Node3D
var state         # lab_state

# ── 3D nodes parented into view ──────────────────────────────────────────────
var rocket_group: Node3D   # entire stack root (world-space)
var s1_root: Node3D        # stage 1 (separates first, falls back)
var s2_root: Node3D        # stage 2 (separates second)
var ship_root: Node3D      # capsule (remains until space_scene)
var solar_l: MeshInstance3D
var solar_r: MeshInstance3D
var thrust_main: CPUParticles3D  # 9-engine plume
var thrust_s2:   CPUParticles3D  # vacuum engine plume
var smoke_base:  CPUParticles3D  # ground smoke column
var clouds: Array = []

# ── Physics state ─────────────────────────────────────────────────────────────
var rocket_pos: Vector2 = Vector2.ZERO
var ground_y: float = 0.0
var rocket_y:  float = 0.0
var rocket_vy: float = 0.0
var s1_sep: bool = false; var s1_abs_y: float = 0.0; var s1_vy: float = 0.0
var s2_sep: bool = false; var s2_abs_y: float = 0.0; var s2_vy: float = 0.0
var solar_deploying: bool = false; var solar_t: float = 0.0
var shake: float = 0.0

# ── Camera ───────────────────────────────────────────────────────────────────
## 0 = side-track  1 = cockpit  2 = orbit
var cam_mode: int = 0
var orbit_yaw: float = 0.5; var orbit_pitch: float = 0.22; var orbit_dist: float = 32.0

# ── Phase ─────────────────────────────────────────────────────────────────────
var phase: int = 0
var phase_time: float = 0.0
var finished: bool = false

const PHASES = [
	{"name":"🔥 点火准备 · 3… 2… 1…","dur":2.8,"thrust":0.0},
	{"name":"🚀 主发动机点火！","dur":1.2,"thrust":0.4},
	{"name":"起飞！","dur":5.0,"thrust":1.0},
	{"name":"马赫 1 · 超音速","dur":3.0,"thrust":1.3},
	{"name":"一级分离 · 二级点火","dur":2.5,"thrust":1.5,"sep1":true},
	{"name":"穿越大气层","dur":3.0,"thrust":1.7},
	{"name":"进入轨道","dur":2.5,"thrust":1.2,"sep2":true,"cam_orbit":true},
	{"name":"舰船分离 · 太阳帆展开","dur":3.5,"thrust":0.0,"solar":true,"cam_cockpit":true},
	{"name":"进入深空","dur":1.8,"thrust":0.0},
]

# ── HUD nodes ─────────────────────────────────────────────────────────────────
var phase_label: Label
var hud_label:   Label
var hint_label:  Label
var veil:        ColorRect

## Drag input for orbit camera (mobile + mouse).
var drag_active: bool = false
var drag_last: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if view == null or state == null:
		push_error("launch_sequence: view/state not set before add_child"); return
	# Rocket starts at the saved rocket_at position.
	var ra = state.planet.v2.get("rocket_at")
	if ra is Dictionary and not ra.is_empty():
		rocket_pos = Vector2(float(ra.x), float(ra.z))
	else:
		rocket_pos = view.walker.position + Vector2(-sin(view.walker.yaw),-cos(view.walker.yaw))*12.0
	ground_y = view.terrain.ground(rocket_pos)
	rocket_y  = ground_y
	_build_rocket()
	_build_clouds()
	_build_hud()
	# Disable normal walker camera; we'll control the camera ourselves.
	view.set_meta("launching", true)

func _build_rocket() -> void:
	rocket_group = Node3D.new(); view.add_child(rocket_group)
	rocket_group.position = Vector3(rocket_pos.x, ground_y, rocket_pos.y)

	var mat = func(hex: String, metal: float = 0.6, emit: bool = false) -> StandardMaterial3D:
		var m = StandardMaterial3D.new()
		m.albedo_color = Color(hex); m.metallic = metal; m.roughness = 0.38
		if emit: m.emission_enabled = true; m.emission = Color(hex); m.emission_energy_multiplier = 2.0
		return m
	var add = func(parent: Node3D, mesh: Mesh, pos: Vector3,
			material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
		var n = MeshInstance3D.new(); n.mesh = mesh; n.position = pos
		n.rotation = rot; n.material_override = material; parent.add_child(n); return n

	# ── Stage 1 ──
	s1_root = Node3D.new(); rocket_group.add_child(s1_root)
	# Main barrel  (height 9, radius 1.5 → 1.3)
	var bm = CylinderMesh.new(); bm.bottom_radius=1.5; bm.top_radius=1.3; bm.height=9; bm.radial_segments=24
	add.call(s1_root, bm, Vector3(0,4.5,0), mat.call("dde4ea",0.55))
	# Black engine section ring
	var er = CylinderMesh.new(); er.bottom_radius=1.55; er.top_radius=1.55; er.height=0.7; er.radial_segments=24
	add.call(s1_root, er, Vector3(0,0.35,0), mat.call("1a1e22",0.4))
	# 9 Merlin-style nozzles (3×3 grid, flared)
	for row in range(3):
		for col in range(3):
			var nx = (col-1)*0.7; var nz = (row-1)*0.7
			var nzm = CylinderMesh.new(); nzm.bottom_radius=0.32; nzm.top_radius=0.18; nzm.height=0.9; nzm.radial_segments=12
			add.call(s1_root, nzm, Vector3(nx,-0.45,nz), mat.call("3a3e42",0.7))
	# Grid fins (4, retracted flat against hull)
	for k in range(4):
		var ang = k * PI/2
		var gfm = BoxMesh.new(); gfm.size = Vector3(0.12, 1.4, 1.2)
		var gf = add.call(s1_root, gfm, Vector3(cos(ang)*1.5,7.8,sin(ang)*1.5), mat.call("8898a8",0.5))
		gf.rotation.y = ang
	# Landing legs (4, folded flush)
	for k in range(4):
		var ang = k * PI/2
		var llm = BoxMesh.new(); llm.size = Vector3(0.12, 2.2, 0.22)
		var ll = add.call(s1_root, llm, Vector3(cos(ang)*1.5,1.1,sin(ang)*1.5), mat.call("c8d4dc",0.5))
		ll.rotation.y = ang; ll.set_meta("landing_leg", k)
	# Interstage (wider ring connecting S1 to S2)
	var ism = CylinderMesh.new(); ism.bottom_radius=1.32; ism.top_radius=1.12; ism.height=1.2; ism.radial_segments=24
	add.call(s1_root, ism, Vector3(0,9.6,0), mat.call("2a3038",0.5))

	# ── Stage 2 ──
	s2_root = Node3D.new(); rocket_group.add_child(s2_root)
	s2_root.position.y = 10.2
	var s2m = CylinderMesh.new(); s2m.bottom_radius=1.12; s2m.top_radius=1.0; s2m.height=5.5; s2m.radial_segments=24
	add.call(s2_root, s2m, Vector3(0,2.75,0), mat.call("eef2f5",0.5))
	# Vacuum bell (wide flared nozzle)
	var vbm = CylinderMesh.new(); vbm.bottom_radius=0.9; vbm.top_radius=0.28; vbm.height=1.5; vbm.radial_segments=20
	add.call(s2_root, vbm, Vector3(0,-0.75,0), mat.call("5a6268",0.7))

	# ── Capsule/Ship ──
	ship_root = Node3D.new(); rocket_group.add_child(ship_root)
	ship_root.position.y = 15.7
	# Trunk cylinder
	var trm = CylinderMesh.new(); trm.bottom_radius=1.0; trm.top_radius=0.98; trm.height=2.2; trm.radial_segments=24
	add.call(ship_root, trm, Vector3(0,-1.1,0), mat.call("7c8d98",0.5))
	# Crew capsule (tapered cone)
	var csm = CylinderMesh.new(); csm.bottom_radius=0.96; csm.top_radius=0.18; csm.height=3.2; csm.radial_segments=24
	add.call(ship_root, csm, Vector3(0,1.6,0), mat.call("dde4ea",0.55))
	# Nose cap
	var ncm = SphereMesh.new(); ncm.radius=0.22; ncm.height=0.36
	add.call(ship_root, ncm, Vector3(0,3.3,0), mat.call("aabbcc",0.4))
	# Windows strip
	var wsm = CylinderMesh.new(); wsm.bottom_radius=0.86; wsm.top_radius=0.86; wsm.height=0.28; wsm.radial_segments=24
	add.call(ship_root, wsm, Vector3(0,1.4,0), mat.call("7fd8ff",0.05))
	# Solar panels (folded, will deploy)
	solar_l = MeshInstance3D.new(); var slm = BoxMesh.new(); slm.size = Vector3(0.05, 2.4, 0.9)
	solar_l.mesh = slm; solar_l.material_override = mat.call("1a3a8c",0.3)
	solar_l.position = Vector3(-1.05, -0.5, 0); ship_root.add_child(solar_l)
	solar_r = MeshInstance3D.new(); solar_r.mesh = slm; solar_r.material_override = mat.call("1a3a8c",0.3)
	solar_r.position = Vector3(1.05, -0.5, 0); ship_root.add_child(solar_r)

	# ── Particles ──
	thrust_main = CPUParticles3D.new()
	thrust_main.amount = 140; thrust_main.lifetime = 0.9; thrust_main.emitting = false
	thrust_main.direction = Vector3(0,-1,0); thrust_main.spread = 14.0
	thrust_main.initial_velocity_min = 22; thrust_main.initial_velocity_max = 38
	thrust_main.gravity = Vector3(0,-4,0); thrust_main.scale_amount_min = 0.7; thrust_main.scale_amount_max = 1.4
	thrust_main.color = Color(1.0,0.55,0.15,0.9)
	s1_root.add_child(thrust_main); thrust_main.position = Vector3(0,-0.9,0)

	thrust_s2 = CPUParticles3D.new()
	thrust_s2.amount = 60; thrust_s2.lifetime = 1.1; thrust_s2.emitting = false
	thrust_s2.direction = Vector3(0,-1,0); thrust_s2.spread = 8.0
	thrust_s2.initial_velocity_min = 18; thrust_s2.initial_velocity_max = 30
	thrust_s2.color = Color(0.9,0.96,1.0,0.8)
	s2_root.add_child(thrust_s2); thrust_s2.position = Vector3(0,-1.5,0)

	smoke_base = CPUParticles3D.new()
	smoke_base.amount = 90; smoke_base.lifetime = 3.5; smoke_base.emitting = false
	smoke_base.direction = Vector3(0,1,0); smoke_base.spread = 55.0
	smoke_base.initial_velocity_min = 3; smoke_base.initial_velocity_max = 7
	smoke_base.gravity = Vector3(0.5,0.2,0); smoke_base.color = Color(0.85,0.82,0.78,0.7)
	smoke_base.scale_amount_min = 1.5; smoke_base.scale_amount_max = 3.2
	view.add_child(smoke_base); smoke_base.position = Vector3(rocket_pos.x, ground_y+0.5, rocket_pos.y)

func _build_clouds() -> void:
	# Simple low-poly billboard cloud puffs around the launch site.
	var rng = RandomNumberGenerator.new(); rng.seed = 9911
	var cmat = StandardMaterial3D.new(); cmat.albedo_color = Color(1,1,1,0.72)
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	for i in range(14):
		var cm = SphereMesh.new()
		cm.radius = rng.randf_range(12,30); cm.height = cm.radius*0.55
		cm.radial_segments = 8; cm.rings = 4
		var c = MeshInstance3D.new(); c.mesh = cm; c.material_override = cmat
		var ang = rng.randf_range(0, TAU)
		var dist = rng.randf_range(60, 180)
		c.position = Vector3(rocket_pos.x + cos(ang)*dist,
				ground_y + rng.randf_range(55, 110),
				rocket_pos.y + sin(ang)*dist)
		view.add_child(c); clouds.append(c)

func _build_hud() -> void:
	var vy = get_viewport().get_visible_rect().size.y
	var vx = get_viewport().get_visible_rect().size.x
	phase_label = Label.new()
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 30)
	phase_label.add_theme_color_override("font_color", Color("ffffff"))
	phase_label.add_theme_color_override("font_outline_color", Color(0,0,0,0.8))
	phase_label.add_theme_constant_override("outline_size", 6)
	phase_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phase_label.offset_bottom = -vy*0.12; add_child(phase_label)

	hud_label = Label.new()
	hud_label.position = Vector2(24, 24); hud_label.size = Vector2(340, 60)
	hud_label.add_theme_font_size_override("font_size", 15)
	hud_label.add_theme_color_override("font_color", Color("aaccdd"))
	hud_label.add_theme_color_override("font_outline_color", Color(0,0,0,0.8))
	hud_label.add_theme_constant_override("outline_size", 5)
	add_child(hud_label)

	hint_label = Label.new()
	hint_label.text = "V 切换视角 · 第三人称可拖动转视角 · ESC 跳过"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color("667788"))
	hint_label.add_theme_color_override("font_outline_color", Color(0,0,0,0.8))
	hint_label.add_theme_constant_override("outline_size", 4)
	hint_label.position = Vector2(0, vy - 28); hint_label.size = Vector2(vx, 24)
	add_child(hint_label)

	veil = ColorRect.new(); veil.color = Color(0,0,0,0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(veil)

	# Mobile: view toggle button.
	var vbtn = preload("res://scripts/ui.gd").button("视角 V", func(): _cycle_cam())
	vbtn.position = Vector2(vx - 130, 24); vbtn.size = Vector2(110, 40); add_child(vbtn)
	var skip_btn = preload("res://scripts/ui.gd").button("跳过", _skip)
	skip_btn.position = Vector2(vx - 130, 72); skip_btn.size = Vector2(110, 40); add_child(skip_btn)

func _cycle_cam() -> void:
	cam_mode = (cam_mode + 1) % 3

func _skip() -> void:
	if not finished: _finish()

func _get_camera() -> Camera3D:
	if view == null: return null
	return view.get("camera")

func _process(dt: float) -> void:
	if finished or view == null: return
	if phase >= PHASES.size(): return
	phase_time += dt
	var ph = PHASES[phase]
	var thrust = float(ph.get("thrust", 0.0))

	# ── Ignite smoke / thrust ──────────────────────────────────────────────
	if thrust > 0.0:
		thrust_main.emitting = not s1_sep
		if not s1_sep:
			thrust_main.scale_amount_min = 0.5 + thrust*0.6
			thrust_main.scale_amount_max = 1.0 + thrust*1.1
	else:
		thrust_main.emitting = false
	thrust_s2.emitting = s1_sep and not s2_sep and thrust > 0.0
	if phase <= 2: smoke_base.emitting = thrust > 0.0

	# ── Rocket physics ────────────────────────────────────────────────────
	if thrust > 0.0 and not s2_sep:
		rocket_vy = minf(rocket_vy + thrust * 18.0 * dt, 160.0)
	elif s2_sep:
		rocket_vy = minf(rocket_vy + 4.0 * dt, 60.0)
	rocket_y += rocket_vy * dt
	rocket_group.position.y = rocket_y

	# ── Stage separations ─────────────────────────────────────────────────
	if ph.get("sep1", false) and not s1_sep:
		s1_sep = true
		s1_abs_y = rocket_y; s1_vy = rocket_vy * 0.35
		# Detach s1_root into view so it can fall independently.
		rocket_group.remove_child(s1_root)
		view.add_child(s1_root)
		s1_root.global_position = Vector3(rocket_pos.x, s1_abs_y, rocket_pos.y)
	if s1_sep:
		s1_vy -= 14.0 * dt
		s1_abs_y += s1_vy * dt
		if is_instance_valid(s1_root):
			s1_root.global_position.y = s1_abs_y
			s1_root.rotation.z += 0.4 * dt  # tumble

	if ph.get("sep2", false) and not s2_sep:
		s2_sep = true
		s2_abs_y = rocket_y; s2_vy = rocket_vy * 0.2
		rocket_group.remove_child(s2_root)
		view.add_child(s2_root)
		s2_root.global_position = Vector3(rocket_pos.x, s2_abs_y, rocket_pos.y)
	if s2_sep:
		s2_vy -= 8.0 * dt
		s2_abs_y += s2_vy * dt
		if is_instance_valid(s2_root):
			s2_root.global_position.y = s2_abs_y
			s2_root.rotation.z += 0.2 * dt

	# ── Solar panel deploy ─────────────────────────────────────────────────
	if ph.get("solar", false) and not solar_deploying:
		solar_deploying = true; solar_t = 0.0
	if solar_deploying:
		solar_t = minf(solar_t + dt * 0.6, 1.0)
		var spread = lerpf(0.0, 3.2, solar_t)
		if is_instance_valid(solar_l): solar_l.position.x = -1.05 - spread
		if is_instance_valid(solar_r): solar_r.position.x =  1.05 + spread

	# ── Sky fade ──────────────────────────────────────────────────────────
	var height_frac = clampf((rocket_y - ground_y) / 400.0, 0.0, 1.0)
	if view.get("env") is Environment:
		view.env.background_color = Color(0.18,0.32,0.55).lerp(Color(0.005,0.006,0.015), height_frac)
		if view.sky_material is ProceduralSkyMaterial:
			view.sky_material.sky_top_color = Color("2255aa").lerp(Color("000810"), height_frac)
			view.sky_material.sky_horizon_color = Color("88ccee").lerp(Color("001422"), height_frac)

	# ── Camera modes ──────────────────────────────────────────────────────
	# Phase hints.
	if ph.get("cam_orbit", false) and cam_mode == 0: cam_mode = 2
	if ph.get("cam_cockpit", false) and cam_mode == 2: cam_mode = 1
	var cam = _get_camera()
	if is_instance_valid(cam):
		var ship_wp = Vector3(rocket_pos.x, rocket_y + 17.0, rocket_pos.y)
		match cam_mode:
			0:  # Side-tracking shot (camera pans up keeping rocket in frame)
				var side_d = lerpf(30.0, 20.0, minf(1.0, (rocket_y - ground_y)/80.0))
				cam.position = Vector3(rocket_pos.x + side_d, rocket_y + 8.0 + shake * 0.25, rocket_pos.y + side_d * 0.4)
				cam.look_at(ship_wp - Vector3(0, 4.0, 0))
			1:  # Cockpit: inside the capsule looking forward-up through porthole
				var porthole_dir = Vector3(0.0, 0.95, -0.31).normalized()
				cam.position = ship_wp + Vector3(0, -0.4, 0)
				cam.look_at(ship_wp + porthole_dir * 40.0)
			2:  # Orbit: user can drag to spin around the rocket
				var op = ship_wp + Vector3(
					sin(orbit_yaw) * cos(orbit_pitch),
					sin(orbit_pitch),
					cos(orbit_yaw) * cos(orbit_pitch)) * orbit_dist
				cam.position = cam.position.lerp(op, minf(1.0, dt * 4.5))
				cam.look_at(ship_wp)

	# ── Shake ─────────────────────────────────────────────────────────────
	shake = clampf(rocket_vy / 120.0, 0.0, 1.4) if thrust > 0.0 else maxf(0.0, shake - dt * 2.0)
	if shake > 0.0 and is_instance_valid(cam):
		cam.position += Vector3(
			sin(Time.get_ticks_msec() * 0.07) * shake * 0.12,
			cos(Time.get_ticks_msec() * 0.11) * shake * 0.06, 0)

	# ── HUD ───────────────────────────────────────────────────────────────
	phase_label.text = ph.name
	hud_label.text = "高度 %.0f m · 速度 %.0f m/s\n%s" % [
		maxf(0.0, rocket_y - ground_y), rocket_vy,
		["追踪视角","座舱视角","环绕视角"][cam_mode]]

	# ── Phase advance ─────────────────────────────────────────────────────
	if phase_time >= float(ph.get("dur", 2.0)):
		phase += 1; phase_time = 0.0
		if phase >= PHASES.size(): _finish()

func _finish() -> void:
	if finished: return
	finished = true
	smoke_base.emitting = false
	thrust_main.emitting = false
	thrust_s2.emitting = false
	var tw = create_tween(); tw.tween_property(veil, "color:a", 1.0, 0.9)
	await tw.finished
	_cleanup()
	sequence_done.emit()

func _cleanup() -> void:
	if view != null: view.remove_meta("launching")
	# Remove particles and extra nodes we added to view.
	if is_instance_valid(smoke_base): smoke_base.queue_free()
	if is_instance_valid(s1_root) and not s1_root.get_parent() == rocket_group: s1_root.queue_free()
	if is_instance_valid(s2_root) and not s2_root.get_parent() == rocket_group: s2_root.queue_free()
	for c in clouds: if is_instance_valid(c): c.queue_free()
	if is_instance_valid(rocket_group): rocket_group.queue_free()

func _input(event: InputEvent) -> void:
	if finished: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_V: _cycle_cam()
		if event.physical_keycode == KEY_ESCAPE: _skip()
	# Orbit drag (mouse + touch)
	if cam_mode == 2:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				drag_active = event.pressed; drag_last = event.position
		elif event is InputEventScreenTouch:
			drag_active = event.pressed; drag_last = event.position
		elif event is InputEventMouseMotion and drag_active:
			var d = event.position - drag_last; drag_last = event.position
			orbit_yaw   += d.x * 0.008
			orbit_pitch  = clampf(orbit_pitch - d.y * 0.006, -0.3, 1.1)
		elif event is InputEventScreenDrag:
			orbit_yaw   += event.relative.x * 0.008
			orbit_pitch  = clampf(orbit_pitch - event.relative.y * 0.006, -0.3, 1.1)
