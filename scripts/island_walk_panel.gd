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

func setup(model) -> void:
	state=model; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var title=UI.label("浮岛漫步",28,UI.MINT); title.position=Vector2(28,22); add_child(title)
	var sub=UI.label("从反应釜旁走过，看看自己带回来的作品。",16,UI.MUTED); sub.position=Vector2(210,31); add_child(sub)
	var close=UI.button("回到经营视角",_close); close.position=Vector2(1210,21); close.size=Vector2(202,48); add_child(close)
	var box=SubViewportContainer.new(); box.position=Vector2(28,90); box.size=Vector2(1384,690); box.stretch=true; box.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(box)
	viewport=SubViewport.new(); viewport.size=Vector2i(1384,690); viewport.own_world_3d=true; box.add_child(viewport)
	world=preload("res://scripts/world_view.gd").new(); world.campus_life_enabled=true; world.detail_budget=20; viewport.add_child(world); world.setup(state)
	campus=preload("res://scripts/campus_view.gd").new(); campus.setup(state,world)
	portal=preload("res://scripts/island_light_bridge.gd").new(); portal.setup(world,state)
	miniatures=preload("res://scripts/island_miniature_view.gd").new(); world.add_child(miniatures); miniatures.sync(state)
	terrain.setup(state,portal); walker.enter("island")
	hands=preload("res://scripts/first_person_hands.gd").new(); world.camera.add_child(hands); hands.set_tool("collect")
	input=preload("res://scripts/river_exploration_input.gd").new(); input.view=self; input.position=box.position; input.size=box.size; add_child(input); input.set_walking(true)
	input.primary_requested.connect(_interact); input.collect_requested.connect(_interact)
	caption=UI.label("",18,UI.GOLD); caption.position=Vector2(280,795); caption.size=Vector2(880,40); caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; add_child(caption)
	var actions=UI.row(self,10); actions.position=Vector2(500,845)
	for item in [["互动 E",_interact],["跳跃",func(): walker.jump()],["作品展台",func(): requested.emit("miniatures",-1)]]:
		var b=UI.button(item[0],item[1]); b.focus_mode=Control.FOCUS_NONE; actions.add_child(b)
	var help=UI.label("WASD移动 · 按住拖动看向四周 · 手机左摇杆移动、右侧拖动转头",14,UI.MUTED); help.position=Vector2(32,852); help.size=Vector2(440,45); help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(help)
	_camera()

func _camera() -> void:
	world.camera.projection=Camera3D.PROJECTION_PERSPECTIVE; world.camera.fov=75; world.camera.near=0.05; world.camera.far=150
	world.camera.position=walker.eye(); world.camera.rotation=Vector3(walker.pitch,walker.yaw,0)
	world._selection.visible=false

func _aim() -> Dictionary:
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

func _interact() -> void:
	hands.swing(); target=_aim()
	if target.is_empty(): caption.text="走近反应釜或建筑再互动；光桥尽头通往河湾。"; return
	requested.emit(str(target.kind),int(target.index))

func _process(dt: float) -> void:
	if world==null or input==null: return
	walker.step(dt); _camera(); hands.moving=walker.movement.length(); clock+=dt
	if clock<0.25: return
	clock=0; world._camera_target=walker.eye(); world._commit_camera_details(); campus.sync(); miniatures.sync(state); _camera()
	target=_aim()
	caption.text="沿着小路，走进自己的原子工坊" if target.is_empty() else ("E · 走过光桥，前往河湾" if target.kind=="planet" else ("E · 打开反应釜工作台" if target.kind=="reactor" else "E · 查看这座建筑"))

func _close() -> void:
	input.clear_input(); dismissed.emit(); queue_free()
