extends Control
signal dismissed
signal requested(kind: String,index: int)
const UI=preload("res://scripts/ui.gd")
const CENTERS={}
var state
var world
var terrain=preload("res://scripts/island_walk_surface.gd").new()
var walker=preload("res://scripts/river_walker.gd").new(terrain)
var campus
var portal
var miniatures
var input
var hands
var viewport
var caption
var clock=0.0
var target={}
var editor_open=false
var interior_mode=false
var interior_world
var interior_camera
var interior_surface
var interior_layout
var interior
var island_terrain
var island_position=Vector2.ZERO
var island_feet_y=0.0
var island_yaw=0.0
var island_pitch=0.0
var island_hands
var island_walker
var room_box
var room_viewport
var title_label
var subtitle
var showcase_button
var residence_index=-1
var exit_residence_button

func setup(model) -> void:
	state=model; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	title_label=UI.label("浮岛漫步",28,UI.MINT); title_label.position=Vector2(28,22); add_child(title_label)
	subtitle=UI.label("从反应釜旁走过，看看自己带回来的作品。",16,UI.MUTED); subtitle.position=Vector2(260,31); add_child(subtitle)
	var close=UI.button("回到经营视角",_close); close.position=Vector2(1210,21); close.size=Vector2(202,48); add_child(close)
	var box=SubViewportContainer.new(); box.position=Vector2(28,90); box.size=Vector2(1384,690); box.stretch=true; box.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(box)
	viewport=SubViewport.new(); viewport.size=Vector2i(1384,690); viewport.own_world_3d=true; box.add_child(viewport)
	world=preload("res://scripts/world_view.gd").new(); world.campus_life_enabled=true; world.detail_budget=20; viewport.add_child(world); world.setup(state)
	campus=preload("res://scripts/campus_view.gd").new(); campus.setup(state,world)
	portal=preload("res://scripts/island_light_bridge.gd").new(); portal.setup(world,state)
	miniatures=preload("res://scripts/island_miniature_view.gd").new(); world.add_child(miniatures); miniatures.sync(state)
	terrain.setup(state,portal); walker.enter("island")
	hands=preload("res://scripts/first_person_hands.gd").new(); world.camera.add_child(hands); hands.set_tool("collect")
	island_hands=hands
	input=preload("res://scripts/river_exploration_input.gd").new(); input.view=self; input.position=box.position; input.size=box.size; add_child(input); input.set_walking(true)
	input.primary_requested.connect(_interact); input.collect_requested.connect(_interact)
	caption=UI.label("",18,UI.GOLD); caption.position=Vector2(280,795); caption.size=Vector2(880,40); caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; add_child(caption)
	var actions=UI.row(self,10); actions.position=Vector2(500,845)
	for item in [["互动 E",_interact],["跳跃",_jump],["作品展台",func(): requested.emit("miniatures",-1)]]:
		var b=UI.button(item[0],item[1]); b.focus_mode=Control.FOCUS_NONE; actions.add_child(b)
		if item[0]=="作品展台": showcase_button=b
	exit_residence_button=UI.button("离开住宅",_exit_residence); exit_residence_button.focus_mode=Control.FOCUS_NONE; exit_residence_button.visible=false; actions.add_child(exit_residence_button)
	var help=UI.label("WASD移动 · 按住拖动看向四周 · 手机左摇杆移动、右侧拖动转头",14,UI.MUTED); help.position=Vector2(32,852); help.size=Vector2(440,45); help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(help)
	_camera()

func _camera() -> void:
	if interior_mode and is_instance_valid(interior_camera):
		interior_camera.projection=Camera3D.PROJECTION_PERSPECTIVE; interior_camera.fov=75; interior_camera.near=0.03; interior_camera.far=80
		interior_camera.position=walker.eye(); interior_camera.rotation=Vector3(walker.pitch,walker.yaw,0); interior_camera.current=true
		return
	world.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; world.camera.fov=75; world.camera.near=0.05; world.camera.far=150
	world.camera.position=walker.eye(); world.camera.rotation=Vector3(walker.pitch,walker.yaw,0); world.camera.current=true
	world._selection.visible=false

func _aim() -> Dictionary:
	if interior_mode: return _aim_interior()
	var eye=walker.eye(); var dir=-world.camera.global_transform.basis.z; var best={}; var distance=3.0
	for i in range(state.plots.size()):
		var p=state.plots[i]
		if not p.unlocked: continue
		var area=AABB(Vector3(p.x*3-0.97,0.12,p.z*3-0.97),Vector3(1.94,2.8,1.94))
		if p.kind in ["empty","road","plaza","park","garden","fence","sculpture"]: continue
		var hit=area.intersects_ray(eye,dir)
		if hit==null or eye.distance_to(hit)>=distance: continue
		distance=eye.distance_to(hit); best={"kind":p.kind,"index":i}
	var gate=portal.plaza+portal.tip+Vector3(0,0.8,0)
	if eye.distance_to(gate)<2.3 and dir.dot((gate-eye).normalized())>0.5: best={"kind":"planet","index":-1}
	return best

func _aim_interior() -> Dictionary:
	return interior.query(interior_camera.position,-interior_camera.transform.basis.z)

func _interact() -> void:
	if editor_open: return
	hands.swing(); target=_aim()
	if interior_mode:
		if not walker.resting.is_empty(): _stand_up(); return
		if target.is_empty(): caption.text="靠近门、椅子或床再互动。"; return
		match target.kind:
			"door":
				if not interior.toggle_door(walker.position): caption.text="先离开门扇范围，再开关门"
			"chair","sofa": _sit_down()
			"bed": _lie_down()
			"lift": _change_floor()
			_: caption.text=str(target.get("title",""))
		return
	if target.is_empty(): caption.text="走近反应釜或建筑再互动；光桥尽头通往河湾。"; return
	requested.emit(str(target.kind),int(target.index))

func _jump() -> void:
	if interior_mode and not walker.resting.is_empty(): _stand_up(); return
	walker.jump()

func enter_residence(index: int) -> bool:
	if interior_mode or index<0 or index>=state.plots.size(): return false
	var plot=state.plots[index]
	if not plot.unlocked or not preload("res://scripts/residence_layout.gd").accepts(str(plot.kind)): return false
	input.clear_input(); island_walker=walker; island_terrain=terrain; residence_index=index
	island_position=walker.position; island_feet_y=walker.feet_y; island_yaw=walker.yaw; island_pitch=walker.pitch
	interior_layout=preload("res://scripts/residence_layout.gd").new(); interior_layout.setup(plot,1)
	interior_surface=preload("res://scripts/residence_surface.gd").new(); interior_surface.setup(interior_layout)
	# The visited room owns a separate World3D. The island's lights and actors stay asleep.
	room_box=SubViewportContainer.new(); room_box.position=input.position; room_box.size=input.size; room_box.stretch=true; room_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(room_box); move_child(room_box,input.get_index())
	room_viewport=SubViewport.new(); room_viewport.size=Vector2i(input.size); room_viewport.own_world_3d=true; room_box.add_child(room_viewport)
	interior_world=Node3D.new(); interior_world.name="InteriorWorld"; room_viewport.add_child(interior_world)
	interior=preload("res://scripts/residence_interior.gd").new(); interior_world.add_child(interior); interior.setup(interior_layout,interior_surface)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-55,-25,0); light.light_energy=0.50; light.light_color=Color("fff1d0"); interior_world.add_child(light)
	var fill=OmniLight3D.new(); fill.position=Vector3(0,2.3,0); fill.omni_range=13; fill.light_energy=0.48; fill.light_color=Color("ffe4bd"); interior_world.add_child(fill)
	var env=WorldEnvironment.new(); var environment=Environment.new(); environment.background_mode=Environment.BG_COLOR; environment.background_color=Color("9bbfbe"); environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; environment.ambient_light_color=Color("d2d8d0"); environment.ambient_light_energy=0.56; env.environment=environment; interior_world.add_child(env)
	interior_camera=Camera3D.new(); interior_world.add_child(interior_camera)
	interior_mode=true; island_hands=hands; viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; world.process_mode=Node.PROCESS_MODE_DISABLED
	hands=preload("res://scripts/first_person_hands.gd").new(); interior_camera.add_child(hands); hands.set_tool("")
	terrain=interior_surface; walker=preload("res://scripts/residence_walker.gd").new(terrain); walker.enter("residence"); walker.yaw=0
	interior.observer=walker
	input.set_walking(true); exit_residence_button.visible=true; showcase_button.visible=false; _room_title(); _camera(); _update_caption(); return true

func _room_title() -> void:
	title_label.text=str(interior_layout.spec.name)
	subtitle.text="Lv.%d · %d/%d层 · %s" % [interior_layout.level,interior_layout.floor_number,interior_layout.floors,interior_layout.description()]

func _exit_residence() -> void:
	if not interior_mode: return
	input.clear_input(); interior_mode=false; terrain=island_terrain; walker=island_walker
	room_box.hide(); room_box.queue_free(); room_box=null
	world.process_mode=Node.PROCESS_MODE_INHERIT; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	hands=island_hands; exit_residence_button.visible=false; showcase_button.visible=true
	title_label.text="浮岛漫步"; subtitle.text="从反应釜旁走过，看看自己带回来的作品。"
	world.setup(state); portal.sync(state); terrain.setup(state,portal); campus.sync(); miniatures.sync(state)
	_camera(); input.set_walking(true); caption.text="已回到门外"

func _stand_up() -> void:
	input.clear_input(); walker.stand(); hands.visible=true; _camera(); _update_caption()

func _sit_down() -> void:
	_rest()

func _lie_down() -> void:
	_rest()

func _rest() -> void:
	input.clear_input(); walker.rest(interior_layout.fixtures[int(target.index)]); hands.hide(); _camera(); _update_caption()

func _change_floor() -> void:
	if interior_layout.floors<=1: caption.text="升级住宅后开放更多楼层"; return
	var next=1 if interior_layout.floor_number>=interior_layout.floors else interior_layout.floor_number+1
	input.clear_input(); walker.stand()
	interior_layout.setup(state.plots[residence_index],next); interior_surface.setup(interior_layout); interior.rebuild(interior_layout)
	walker.enter("residence"); walker.yaw=0; _room_title(); _camera(); _update_caption()

func handle_back() -> bool:
	if not interior_mode: return false
	if not walker.resting.is_empty(): _stand_up()
	else: _exit_residence()
	return true

func set_editor_open(open: bool) -> void:
	editor_open=open
	input.set_walking(not open)
	process_mode=Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if open else SubViewport.UPDATE_ALWAYS
	if not open:
		# Refresh edited reactor geometry without recreating the observer or its position.
		world.setup(state); campus.sync(); miniatures.sync(state); _camera()
		input.grab_focus()

func _process(dt: float) -> void:
	if world==null or input==null: return
	walker.step(dt)
	if interior_mode:
		hands.visible=walker.resting.is_empty()
		if walker.position.y>interior_layout.depth/2+0.35 and interior.door_open:
			_exit_residence(); return
	_camera(); hands.moving=walker.movement.length(); clock+=dt
	if clock<0.15: return
	clock=0
	if not interior_mode:
		world._camera_target=walker.eye(); world._commit_camera_details(); campus.sync(); miniatures.sync(state); _camera()
	_update_caption()

func _update_caption() -> void:
	target=_aim()
	if interior_mode:
		if not walker.resting.is_empty():
			caption.text="%s · 可转头欣赏房间 · E / 空格 / 跳跃 起身" % ("躺在床上" if walker.resting=="bed" else "坐在座位上")
		elif target.is_empty(): caption.text="室内漫步 · 对准家具按 E · 打开门，走出去回到浮岛"
		else:
			match target.kind:
				"door": caption.text="E · %s" % ("关门" if interior.door_open else "开门 · 门外通往浮岛")
				"chair","sofa": caption.text="E · 坐下 · %s" % target.title
				"bed": caption.text="E · 躺下 · %s" % target.title
				"lift": caption.text="E · 前往下一层（%d层已开放）" % interior_layout.floors if interior_layout.floors>1 else "楼层台 · 升级住宅后开放新楼层"
				_: caption.text=str(target.get("title","室内装饰"))
	else:
		caption.text="沿着小路，走进自己的原子工坊" if target.is_empty() else ("E · 走过光桥，前往河湾" if target.kind=="planet" else ("E · 打开反应釜工作台" if target.kind=="reactor" else ("E · 进入住宅" if preload("res://scripts/residence_layout.gd").accepts(str(target.kind)) else "E · 查看这座建筑")))

func _close() -> void:
	if interior_mode: _exit_residence()
	input.clear_input(); dismissed.emit(); queue_free()
