extends Control
## v0.73.0: Cinematic rocket launch inside the real planet scene.
## Fairing splits two halves, ship (space_scene model) separates, solar panels unfold.
signal sequence_done

var view   # planet_v2_view  (set before add_child)
var state  # lab_state

# 3D nodes added to view
var rocket_group: Node3D
var s1_root: Node3D        # stage 1
var s2_root: Node3D        # stage 2 + fairing + ship
var fairing_l: Node3D      # left fairing half
var fairing_r: Node3D      # right fairing half
var ship_root: Node3D      # the actual ship (matches space_scene model)
var solar_l: MeshInstance3D
var solar_r: MeshInstance3D
var thrust_main: CPUParticles3D
var thrust_s2:   CPUParticles3D
var smoke_base:  CPUParticles3D
var sep_flash: OmniLight3D
var clouds: Array = []

# Physics
var rocket_pos: Vector2 = Vector2.ZERO
var ground_y: float = 0.0
var rocket_y: float = 0.0; var rocket_vy: float = 0.0
var s1_sep: bool=false; var s1_abs_y: float=0.0; var s1_vy: float=0.0; var s1_spin: float=0.0
var s2_sep: bool=false; var s2_abs_y: float=0.0; var s2_vy: float=0.0
var fairing_sep: bool=false; var fl_x: float=0.0; var fr_x: float=0.0; var fl_vy: float=0.0; var fr_vy: float=0.0
var ship_sep: bool=false; var ship_abs_y: float=0.0; var ship_vy: float=0.0
var solar_t: float=0.0; var solar_deploying: bool=false
var sep_flash_t: float=0.0

# Shake (only for side/orbit cameras, never cockpit)
var shake: float=0.0

# Camera  0=side-track  1=cockpit  2=orbit
var cam_mode: int=0
var orbit_yaw: float=0.7; var orbit_pitch: float=0.25; var orbit_dist: float=22.0
var cockpit_yaw: float=0.0; var cockpit_pitch: float=0.0
var drag_active: bool=false; var drag_last: Vector2=Vector2.ZERO
var cam_target_pos: Vector3=Vector3.ZERO  # smoothed target for tracking shot

# Phase
var phase: int=0; var phase_time: float=0.0; var finished: bool=false

const PHASES = [
	{"name":"点火准备 · 3… 2… 1…","dur":2.8,"thrust":0.0},
	{"name":"🔥 主发动机点火！","dur":1.0,"thrust":0.4},
	{"name":"🚀 升空！","dur":5.0,"thrust":1.0},
	{"name":"突破音障","dur":3.0,"thrust":1.3},
	{"name":"一级分离 · 二级点火","dur":3.0,"thrust":1.5,"sep1":true},
	{"name":"穿越大气层","dur":4.0,"thrust":1.8,"fairing":true},
	{"name":"进入轨道","dur":3.0,"thrust":1.2,"sep2":true},
	{"name":"舰船分离 · 太阳帆展开","dur":4.0,"thrust":0.0,"ship_sep":true,"solar":true},
	{"name":"深空启航","dur":2.0,"thrust":0.0},
]

# HUD
var phase_label: Label; var hud_label: Label; var veil: ColorRect

# ──────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if view == null or state == null:
		push_error("launch_sequence: view/state not set"); return
	var ra = state.planet.v2.get("rocket_at")
	if ra is Dictionary and not ra.is_empty():
		rocket_pos = Vector2(float(ra.x), float(ra.z))
	else:
		rocket_pos = view.walker.position + Vector2(-sin(view.walker.yaw),-cos(view.walker.yaw))*12.0
	ground_y = view.terrain.ground(rocket_pos)
	rocket_y  = ground_y
	# Pre-initialise cam target so tracking camera starts in the right place.
	cam_target_pos = Vector3(rocket_pos.x, ground_y + 15.0, rocket_pos.y)
	_build_rocket()
	_build_clouds()
	_build_hud()
	view.set_meta("launching", true)
	if is_instance_valid(view.get("hands")): view.hands.hide()
	# Hide the standing rocket_node on the ground — CG builds its own
	if is_instance_valid(view.get("rocket_node")): view.rocket_node.hide()

# ── Build rocket (Falcon-9 style + Dragon capsule) ────────────────────────────

func _mat(hex: String, metal: float=0.55, rough: float=0.35, emit: bool=false) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color=Color(hex); m.metallic=metal; m.roughness=rough
	if emit: m.emission_enabled=true; m.emission=Color(hex); m.emission_energy_multiplier=2.2
	return m

func _cyl(parent:Node3D, br:float, tr:float, h:float, pos:Vector3, material:Material,
		seg:int=24, rot:Vector3=Vector3.ZERO) -> MeshInstance3D:
	var n=MeshInstance3D.new(); var m=CylinderMesh.new()
	m.bottom_radius=br; m.top_radius=tr; m.height=h; m.radial_segments=seg
	n.mesh=m; n.position=pos; n.rotation=rot; n.material_override=material; parent.add_child(n); return n

func _box(parent:Node3D, size:Vector3, pos:Vector3, material:Material,
		rot:Vector3=Vector3.ZERO) -> MeshInstance3D:
	var n=MeshInstance3D.new(); var m=BoxMesh.new(); m.size=size
	n.mesh=m; n.position=pos; n.rotation=rot; n.material_override=material; parent.add_child(n); return n

func _build_rocket() -> void:
	rocket_group = Node3D.new(); view.add_child(rocket_group)
	rocket_group.position = Vector3(rocket_pos.x, ground_y, rocket_pos.y)

	var white  = _mat("f0f3f6",0.35,0.40)
	var orange = _mat("e8621a",0.25,0.50)
	var dark   = _mat("242c34",0.70,0.35)
	var grey   = _mat("6a7882",0.65,0.40)
	var black  = _mat("181c20",0.30,0.55)
	var glow_o = _mat("ff7700",0.1,0.3,true)
	var glow_b = _mat("9eeeff",0.1,0.3,true)
	var glass  = _mat("7fcce8",0.05,0.1)
	var blue_p = _mat("1a3a8c",0.4,0.3)

	# ── Stage 1 ──────────────────────────────────────────────────────────
	s1_root = Node3D.new(); rocket_group.add_child(s1_root)
	# Main barrel (tapered white cylinder)
	_cyl(s1_root,1.5,1.32,9.0,Vector3(0,4.5,0),white,32)
	# LOX stripe (orange band)
	_cyl(s1_root,1.34,1.34,0.6,Vector3(0,7.6,0),orange,32)
	# Engine section ring
	_cyl(s1_root,1.58,1.58,0.7,Vector3(0,0.35,0),dark,32)
	# 9 Merlin nozzles (3×3 grid)
	for row in range(3):
		for col in range(3):
			var nx=(col-1)*0.72; var nz=(row-1)*0.72
			_cyl(s1_root,0.29,0.15,0.9,Vector3(nx,-0.45,nz),dark,10)
			# inner glow dot
			_cyl(s1_root,0.10,0.10,0.06,Vector3(nx,-0.92,nz),glow_o,8)
	# 4 grid fins (folded flat — thin dark plates)
	for k in range(4):
		var ang=k*PI/2; var gfn=_box(s1_root,Vector3(0.12,1.9,1.5),
			Vector3(cos(ang)*1.54,7.2,sin(ang)*1.54),grey); gfn.rotation.y=ang; gfn.set_meta("gf",k)
	# 4 landing legs (folded flush)
	for k in range(4):
		var ang=k*PI/2
		var ll=_box(s1_root,Vector3(0.10,2.5,0.18),Vector3(cos(ang)*1.54,1.25,sin(ang)*1.54),grey)
		ll.rotation.y=ang
	# Interstage adapter
	_cyl(s1_root,1.32,1.13,1.0,Vector3(0,9.5,0),dark,32)

	# ── Stage 2 + fairing stack ───────────────────────────────────────────
	s2_root = Node3D.new(); rocket_group.add_child(s2_root); s2_root.position.y=10.0
	_cyl(s2_root,1.12,1.0,6.0,Vector3(0,3.0,0),white,32)
	_cyl(s2_root,1.01,1.01,0.4,Vector3(0,5.0,0),orange,32)
	# Vacuum bell
	_cyl(s2_root,0.94,0.26,1.8,Vector3(0,-0.9,0),grey,20)
	# Stage 2 → fairing transition ring
	_cyl(s2_root,1.0,1.0,0.3,Vector3(0,6.15,0),dark,32)

	# ── Fairing (two half-shells on s2_root) ──────────────────────────────
	# Each half is a tapered cap (clamshell style, left and right)
	fairing_l = Node3D.new(); s2_root.add_child(fairing_l); fairing_l.position.y=6.3
	fairing_r = Node3D.new(); s2_root.add_child(fairing_r); fairing_r.position.y=6.3
	for side_node in [fairing_l, fairing_r]:
		var sign = 1 if side_node==fairing_l else -1
		# Main shell — half-cylinder (approximated as scaled full cyl)
		var hn=_cyl(side_node,1.0,0.18,4.2,Vector3(sign*0.5,2.1,0),white,16)
		hn.scale.x=0.5; hn.rotation.z=sign*0.08
		# Nose ogive cap
		var nc=_cyl(side_node,0.18,0.0,0.6,Vector3(sign*0.09,4.5,0),white,12)
		nc.rotation.z=sign*0.08
		# Separation line (dark stripe)
		_box(side_node,Vector3(0.04,4.8,2.05),Vector3(0,2.1,0),dark)

	# ── Ship (Dragon-style crew capsule — matches space_scene hull proportions) ──
	# sits atop fairing inside, will be revealed when fairing opens
	ship_root = Node3D.new(); s2_root.add_child(ship_root); ship_root.position.y=6.3
	# Trunk cylinder
	_cyl(ship_root,0.85,0.84,2.0,Vector3(0,-1.0,0),grey,24)
	# Capsule cone
	_cyl(ship_root,0.82,0.12,2.8,Vector3(0,1.4,0),white,28)
	# Heat shield
	_cyl(ship_root,0.84,0.84,0.22,Vector3(0,0.12,0),black,24)
	# Windows band
	_cyl(ship_root,0.74,0.74,0.26,Vector3(0,1.3,0),glass,24)
	# Nose cap
	var nsm=SphereMesh.new(); nsm.radius=0.14; nsm.height=0.22; var nc2=MeshInstance3D.new()
	nc2.mesh=nsm; nc2.position=Vector3(0,2.96,0); nc2.material_override=white; ship_root.add_child(nc2)
	# Abort tower
	_cyl(ship_root,0.04,0.04,1.4,Vector3(0,3.6,0),_mat("cc2020",0.2),6)
	_cyl(ship_root,0.18,0.04,0.35,Vector3(0,4.4,0),_mat("cc2020",0.2),6)
	# Solar panels (folded vertical against trunk, will deploy horizontally)
	# Each panel: a boom + panel face, initially folded up (rotation x = PI/2)
	solar_l=MeshInstance3D.new(); var sl=BoxMesh.new(); sl.size=Vector3(0.06,2.8,1.05)
	solar_l.mesh=sl; solar_l.material_override=blue_p
	solar_l.position=Vector3(-1.0,-0.5,0)  # starts at hull side
	solar_l.rotation.z=PI*0.5             # folded up
	ship_root.add_child(solar_l)
	solar_r=MeshInstance3D.new(); solar_r.mesh=sl; solar_r.material_override=blue_p
	solar_r.position=Vector3(1.0,-0.5,0)
	solar_r.rotation.z=-PI*0.5
	ship_root.add_child(solar_r)
	# Booms (thin struts connecting panel to hull)
	var boom_mat=_mat("5a6570",0.6)
	var bm_l=MeshInstance3D.new(); var bms=BoxMesh.new(); bms.size=Vector3(0.08,0.08,1.1)
	bm_l.mesh=bms; bm_l.material_override=boom_mat; bm_l.position=Vector3(-1.0,-0.5,0); ship_root.add_child(bm_l)
	var bm_r=MeshInstance3D.new(); bm_r.mesh=bms; bm_r.material_override=boom_mat
	bm_r.position=Vector3(1.0,-0.5,0); ship_root.add_child(bm_r)

	# ── Particles ────────────────────────────────────────────────────────
	thrust_main=CPUParticles3D.new(); thrust_main.amount=180; thrust_main.lifetime=0.80
	thrust_main.emitting=false; thrust_main.direction=Vector3(0,-1,0); thrust_main.spread=11.0
	thrust_main.initial_velocity_min=30; thrust_main.initial_velocity_max=48
	thrust_main.gravity=Vector3(0,-6,0); thrust_main.scale_amount_min=0.55; thrust_main.scale_amount_max=1.2
	thrust_main.color=Color(1.0,0.50,0.10,0.95)
	s1_root.add_child(thrust_main); thrust_main.position=Vector3(0,-0.9,0)

	thrust_s2=CPUParticles3D.new(); thrust_s2.amount=70; thrust_s2.lifetime=1.1
	thrust_s2.emitting=false; thrust_s2.direction=Vector3(0,-1,0); thrust_s2.spread=6.0
	thrust_s2.initial_velocity_min=22; thrust_s2.initial_velocity_max=35
	thrust_s2.color=Color(0.85,0.94,1.0,0.82)
	s2_root.add_child(thrust_s2); thrust_s2.position=Vector3(0,-1.8,0)

	smoke_base=CPUParticles3D.new(); smoke_base.amount=110; smoke_base.lifetime=4.5
	smoke_base.emitting=false; smoke_base.direction=Vector3(0,1,0); smoke_base.spread=62.0
	smoke_base.initial_velocity_min=4; smoke_base.initial_velocity_max=10
	smoke_base.gravity=Vector3(0.7,0.2,0); smoke_base.color=Color(0.80,0.76,0.72,0.62)
	smoke_base.scale_amount_min=2.5; smoke_base.scale_amount_max=5.0
	view.add_child(smoke_base); smoke_base.position=Vector3(rocket_pos.x,ground_y+0.5,rocket_pos.y)

	sep_flash=OmniLight3D.new(); sep_flash.light_color=Color(1.0,0.72,0.28)
	sep_flash.light_energy=0.0; sep_flash.omni_range=100
	rocket_group.add_child(sep_flash)

# ── Clouds ────────────────────────────────────────────────────────────────────

func _build_clouds() -> void:
	var rng=RandomNumberGenerator.new(); rng.seed=9911
	var cmat=StandardMaterial3D.new(); cmat.albedo_color=Color(1,1,1,0.70)
	cmat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
	for i in range(16):
		var cm=SphereMesh.new(); cm.radius=rng.randf_range(14,32); cm.height=cm.radius*0.52; cm.radial_segments=8; cm.rings=4
		var c=MeshInstance3D.new(); c.mesh=cm; c.material_override=cmat
		var ang=rng.randf_range(0,TAU); var dist=rng.randf_range(70,200)
		c.position=Vector3(rocket_pos.x+cos(ang)*dist, ground_y+rng.randf_range(60,120), rocket_pos.y+sin(ang)*dist)
		view.add_child(c); clouds.append(c)

# ── HUD ───────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var vy=get_viewport().get_visible_rect().size.y
	var vx=get_viewport().get_visible_rect().size.x
	phase_label=Label.new(); phase_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size",28)
	phase_label.add_theme_color_override("font_color",Color("ffffff"))
	phase_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.85))
	phase_label.add_theme_constant_override("outline_size",7)
	phase_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phase_label.offset_bottom=-vy*0.10; add_child(phase_label)

	hud_label=Label.new(); hud_label.position=Vector2(20,20); hud_label.size=Vector2(320,64)
	hud_label.add_theme_font_size_override("font_size",15)
	hud_label.add_theme_color_override("font_color",Color("aaccdd"))
	hud_label.add_theme_color_override("font_outline_color",Color(0,0,0,0.85))
	hud_label.add_theme_constant_override("outline_size",5); add_child(hud_label)

	var hint=Label.new(); hint.text="V 切换视角 · 第三人称/环绕拖动旋转 · ESC 跳过"
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color("556677"))
	hint.add_theme_color_override("font_outline_color",Color(0,0,0,0.7))
	hint.add_theme_constant_override("outline_size",4)
	hint.position=Vector2(0,vy-26); hint.size=Vector2(vx,22); add_child(hint)

	veil=ColorRect.new(); veil.color=Color(0,0,0,0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(veil)

	var vbtn=preload("res://scripts/ui.gd").button("👁 视角 V",func(): _cycle_cam())
	vbtn.position=Vector2(vx-130,20); vbtn.size=Vector2(118,40); add_child(vbtn)
	var skip_btn=preload("res://scripts/ui.gd").button("跳过",_skip)
	skip_btn.position=Vector2(vx-130,68); skip_btn.size=Vector2(118,40); add_child(skip_btn)

	# ── Cockpit 2D overlay (dark cabin frame + porthole) — shown in cam_mode==1 ──
	var cockpit_ui=Control.new(); cockpit_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cockpit_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE; cockpit_ui.name="cockpit_ui"; add_child(cockpit_ui)
	# Dark cabin interior (sides + bottom)
	var cabin_bg=ColorRect.new(); cabin_bg.color=Color(0.05,0.07,0.10,0.92)
	cabin_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); cabin_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE; cockpit_ui.add_child(cabin_bg)
	# Central porthole cutout — punch a clear rectangle in the centre
	var port_size=Vector2(minf(vx*0.55,580),minf(vy*0.50,380))
	var port_pos=Vector2((vx-port_size.x)*0.5,(vy-port_size.y)*0.42)
	var clear=ColorRect.new(); clear.color=Color(0,0,0,0); clear.position=port_pos; clear.size=port_size
	clear.mouse_filter=Control.MOUSE_FILTER_IGNORE; cockpit_ui.add_child(clear)
	# Porthole frame bars
	var fc=Color(0.14,0.16,0.18,0.95)
	var bars2=[
		Rect2(port_pos-Vector2(12,12),Vector2(port_size.x+24,12)),       # top
		Rect2(port_pos+Vector2(0,port_size.y),Vector2(port_size.x+24,12)), # bottom
		Rect2(port_pos-Vector2(12,12),Vector2(12,port_size.y+24)),       # left
		Rect2(port_pos+Vector2(port_size.x,-12),Vector2(12,port_size.y+24)), # right
		Rect2(port_pos+Vector2(port_size.x*0.5-6,0),Vector2(12,port_size.y)), # centre strut
	]
	for r2 in bars2:
		var fr2=ColorRect.new(); fr2.color=fc; fr2.position=r2.position; fr2.size=r2.size
		fr2.mouse_filter=Control.MOUSE_FILTER_IGNORE; cockpit_ui.add_child(fr2)
	# Seat panel strip at bottom
	var seat2=ColorRect.new(); seat2.color=Color(0.10,0.13,0.16,0.96)
	seat2.position=Vector2(0,vy*0.75); seat2.size=Vector2(vx,vy*0.25); seat2.mouse_filter=Control.MOUSE_FILTER_IGNORE; cockpit_ui.add_child(seat2)
	# Belt straps
	for dx2 in [-200,200]:
		var belt2=ColorRect.new(); belt2.color=Color(0.55,0.45,0.22,0.9); belt2.size=Vector2(22,vy*0.32)
		belt2.position=Vector2(vx*0.5+dx2-11,vy*0.56); belt2.rotation=0.36*(1 if dx2>0 else -1)
		belt2.mouse_filter=Control.MOUSE_FILTER_IGNORE; cockpit_ui.add_child(belt2)
	cockpit_ui.visible=false

# ── Helpers ───────────────────────────────────────────────────────────────────

func _cycle_cam() -> void:
	cam_mode=(cam_mode+1)%3

func _skip() -> void:
	if not finished: _finish()

func _get_camera() -> Camera3D:
	if view==null: return null
	return view.get("camera")

# ── Process ───────────────────────────────────────────────────────────────────

func _process(dt: float) -> void:
	if finished or view==null: return
	if phase>=PHASES.size(): return
	phase_time+=dt
	var ph=PHASES[phase]
	var thrust=float(ph.get("thrust",0.0))

	# Particles
	if thrust>0.0 and not s1_sep:
		thrust_main.emitting=true
		thrust_main.scale_amount_min=0.5+thrust*0.5
		thrust_main.scale_amount_max=1.0+thrust*0.9
	else: thrust_main.emitting=false
	thrust_s2.emitting=(s1_sep and not s2_sep and thrust>0.0)
	if phase<=2: smoke_base.emitting=(thrust>0.0)

	sep_flash_t=maxf(0.0,sep_flash_t-dt*3.0); sep_flash.light_energy=sep_flash_t*9.0

	# Physics
	if thrust>0.0 and not s2_sep:
		rocket_vy=minf(rocket_vy+thrust*20.0*dt,170.0)
	rocket_y+=rocket_vy*dt
	rocket_group.position.y=rocket_y

	# Stage 1 separation
	if ph.get("sep1",false) and not s1_sep:
		s1_sep=true; sep_flash_t=1.0
		s1_abs_y=rocket_y; s1_vy=rocket_vy*0.30
		rocket_group.remove_child(s1_root); view.add_child(s1_root)
		s1_root.global_position=Vector3(rocket_pos.x,s1_abs_y,rocket_pos.y)
		for child in s1_root.get_children():
			if child.has_meta("gf"):
				child.rotation.z=sign(child.position.x+0.01)*PI*0.4
	if s1_sep and is_instance_valid(s1_root):
		s1_vy-=18.0*dt; s1_abs_y+=s1_vy*dt; s1_spin+=0.6*dt
		s1_root.global_position.y=s1_abs_y
		s1_root.rotation=Vector3(s1_spin*0.25,0.0,s1_spin)

	# Fairing clamshell open
	if ph.get("fairing",false) and not fairing_sep:
		fairing_sep=true; sep_flash_t=0.6; fl_x=0.0; fr_x=0.0; fl_vy=0.0; fr_vy=0.0
	if fairing_sep and is_instance_valid(fairing_l) and is_instance_valid(fairing_r):
		fl_x-=6.0*dt; fl_vy-=2.0*dt; fairing_l.position.x=fl_x; fairing_l.position.y+=fl_vy*dt
		fr_x+=6.0*dt; fr_vy-=2.0*dt; fairing_r.position.x=fr_x; fairing_r.position.y+=fr_vy*dt
		fairing_l.rotation.z-=1.8*dt; fairing_r.rotation.z+=1.8*dt

	# Stage 2 separation
	if ph.get("sep2",false) and not s2_sep:
		s2_sep=true; sep_flash_t=1.0
		s2_abs_y=rocket_y; s2_vy=rocket_vy*0.15
		rocket_group.remove_child(s2_root); view.add_child(s2_root)
		s2_root.global_position=Vector3(rocket_pos.x,s2_abs_y,rocket_pos.y)
	if s2_sep and is_instance_valid(s2_root):
		s2_vy-=10.0*dt; s2_abs_y+=s2_vy*dt
		s2_root.global_position.y=s2_abs_y; s2_root.rotation.z+=0.18*dt

	# Ship separation
	if ph.get("ship_sep",false) and not ship_sep:
		ship_sep=true; sep_flash_t=0.8
		var sp=ship_root.get_parent()
		if is_instance_valid(sp): sp.remove_child(ship_root)
		view.add_child(ship_root)
		ship_abs_y=(s2_root.global_position.y if s2_sep else rocket_y)+6.3+1.5
		ship_root.global_position=Vector3(rocket_pos.x,ship_abs_y,rocket_pos.y)
		ship_vy=rocket_vy*1.05
	if ship_sep and is_instance_valid(ship_root):
		ship_abs_y+=ship_vy*dt
		ship_root.global_position.y=ship_abs_y

	# Solar deploy
	if ph.get("solar",false) and not solar_deploying:
		solar_deploying=true; solar_t=0.0
	if solar_deploying and is_instance_valid(solar_l) and is_instance_valid(solar_r):
		solar_t=minf(solar_t+dt*0.45,1.0)
		# Deploy: rotate from folded (PI/2) to flat (0), then extend outward
		var fold_angle=lerpf(PI*0.5,0.0,solar_t)
		var extend=lerpf(0.0,2.2,solar_t)
		solar_l.rotation.z=fold_angle; solar_l.position.x=-1.0-extend
		solar_r.rotation.z=-fold_angle; solar_r.position.x=1.0+extend

	# Sky fade
	var hfrac=clampf((rocket_y-ground_y)/360.0,0.0,1.0)
	if view.get("env") is Environment:
		view.env.background_color=Color(0.18,0.32,0.55).lerp(Color(0.004,0.006,0.014),hfrac)
	if view.sky_material is ProceduralSkyMaterial:
		view.sky_material.sky_top_color=Color("1a3d7a").lerp(Color("000810"),hfrac)
		view.sky_material.sky_horizon_color=Color("80bce0").lerp(Color("001020"),hfrac)
		view.sky_material.ground_horizon_color=view.sky_material.sky_horizon_color

	# Camera target — track the highest visible element
	var track_y: float
	if ship_sep:
		track_y = ship_abs_y
	elif s2_sep:
		track_y = s2_abs_y
	else:
		track_y = rocket_y
	cam_target_pos = Vector3(rocket_pos.x, track_y + 25.0, rocket_pos.y)

	# Show/hide cockpit 2D overlay
	var cockpit_ui=get_node_or_null("cockpit_ui")
	if is_instance_valid(cockpit_ui): cockpit_ui.visible=(cam_mode==1)

	var cam=_get_camera()
	if is_instance_valid(cam):
		match cam_mode:
			0:  # Side-tracking: snap to correct position immediately
				var progress=clampf((rocket_y-ground_y)/300.0,0.0,1.0)
				var side_d=lerpf(36.0,24.0,progress)
				var pitch_angle=lerpf(-0.12,0.65,progress)  # goes higher as rocket climbs
				var look_from=Vector3(
					rocket_pos.x+cos(pitch_angle)*side_d,
					cam_target_pos.y-sin(pitch_angle)*side_d*0.5,
					rocket_pos.y+side_d*0.35)
				cam.position=look_from
				cam.look_at(cam_target_pos)
			1:  # Cockpit — camera sits just outside the capsule nose, NOT inside geometry
				# We use a 2D cockpit overlay (built in _build_hud) + camera from outside at a distance
				var ship_front: Vector3
				if ship_sep and is_instance_valid(ship_root):
					ship_front=ship_root.global_position+Vector3(0,-0.5,0)
				else:
					ship_front=Vector3(rocket_pos.x,rocket_y+17.5,rocket_pos.y)
				# Camera placed 1m in front of capsule nose looking slightly downward toward horizon
				cam.position=ship_front+Vector3(sin(cockpit_yaw)*3.5,1.2,cos(cockpit_yaw)*3.5)
				cam.look_at(ship_front+Vector3(sin(cockpit_yaw+PI)*20.0,-3.0,cos(cockpit_yaw+PI)*20.0))
			2:  # Orbit
				var op=cam_target_pos+Vector3(
					sin(orbit_yaw)*cos(orbit_pitch),
					sin(orbit_pitch),
					cos(orbit_yaw)*cos(orbit_pitch))*orbit_dist
				cam.position=cam.position.lerp(op,minf(1.0,dt*6.0))
				cam.look_at(cam_target_pos)

	# Shake — tiny, zero in cockpit
	shake=clampf(rocket_vy/700.0,0.0,0.28) if thrust>0.0 else maxf(0.0,shake-dt*3.0)
	if shake>0.0 and is_instance_valid(cam) and cam_mode!=1:
		cam.position+=Vector3(
			sin(Time.get_ticks_msec()*0.07)*shake*0.07,
			cos(Time.get_ticks_msec()*0.11)*shake*0.035,0.0)

	phase_label.text=ph.name
	hud_label.text="高度 %.0f m · 速度 %.0f m/s\n%s" % [
		maxf(0.0,rocket_y-ground_y),rocket_vy,
		["追踪视角","座舱视角","环绕视角"][cam_mode]]

	if phase_time>=float(ph.get("dur",2.0)):
		phase+=1; phase_time=0.0
		if phase>=PHASES.size(): _finish()


# ── Finish ────────────────────────────────────────────────────────────────────

func _finish() -> void:
	if finished: return
	finished=true
	if is_instance_valid(smoke_base): smoke_base.emitting=false
	if is_instance_valid(thrust_main): thrust_main.emitting=false
	if is_instance_valid(thrust_s2): thrust_s2.emitting=false
	var tw=create_tween(); tw.tween_property(veil,"color:a",1.0,0.9)
	await tw.finished
	_cleanup()
	sequence_done.emit()

func _cleanup() -> void:
	if view!=null:
		view.remove_meta("launching")
		# Clear the standing rocket model from the ground
		if is_instance_valid(view.get("rocket_node")): view.rocket_node.queue_free(); view.rocket_node=null
		# Clear rocket_at so it doesn't re-appear on return
		if state!=null: state.planet.v2.rocket_at={}
		# Restore sky + hands
		if view.sky_material is ProceduralSkyMaterial:
			view.sky_material.sky_top_color=Color("1a2c4c")
			view.sky_material.sky_horizon_color=Color("d9906a")
		if is_instance_valid(view.get("hands")): view.hands.visible=view.first_person
	if is_instance_valid(smoke_base): smoke_base.queue_free()
	if is_instance_valid(s1_root) and s1_root.get_parent()!=rocket_group: s1_root.queue_free()
	if is_instance_valid(s2_root) and s2_root.get_parent()!=rocket_group: s2_root.queue_free()
	if is_instance_valid(ship_root) and ship_root.get_parent()!=rocket_group and ship_root.get_parent()!=s2_root: ship_root.queue_free()
	for c in clouds: if is_instance_valid(c): c.queue_free()
	if is_instance_valid(rocket_group): rocket_group.queue_free()

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if finished: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_V: _cycle_cam()
		if event.physical_keycode==KEY_ESCAPE: _skip()
	# Orbit + cockpit drag (mouse & touch)
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			drag_active=event.pressed; drag_last=event.position
	elif event is InputEventScreenTouch:
		drag_active=event.pressed; drag_last=event.position
	elif event is InputEventMouseMotion and drag_active:
		var d=event.position-drag_last; drag_last=event.position
		if cam_mode==2:
			orbit_yaw+=d.x*0.009; orbit_pitch=clampf(orbit_pitch-d.y*0.007,-0.3,1.15)
		elif cam_mode==1:
			cockpit_yaw+=d.x*0.012
	elif event is InputEventScreenDrag:
		if cam_mode==2:
			orbit_yaw+=event.relative.x*0.009; orbit_pitch=clampf(orbit_pitch-event.relative.y*0.007,-0.3,1.15)
		elif cam_mode==1:
			cockpit_yaw+=event.relative.x*0.012
