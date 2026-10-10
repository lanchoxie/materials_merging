extends Control
## v0.43 星锻岛漫步: walk island Ⅱ in first person (user: 「第二个浮岛……可以第一人称进入」).
## The world is the same diorama as the management screen (starforge_view.gd in walk mode).
## E on a factory opens its management, E on 星锻公寓 walks inside, E on a decoration puts it back
## in the toolbox; pick a decoration below, aim at the deck (a green tile ghost) and press E to set it
## down, 旋转 turns it. Staff walk between their factory, the lounge and home as they tire and rest.
signal dismissed
signal requested(kind: String,index: int)
const UI=preload("res://scripts/ui.gd")
const Town=preload("res://scripts/island_town.gd")
const Surface=preload("res://scripts/starforge_walk_surface.gd")
## The shared exploration input asks the view for region centres (island walks have none).
const CENTERS={}
var state
var view
var viewport
var terrain=Surface.new()
var walker
var input
var hands
var caption: Label
var title_label: Label
var subtitle: Label
var decor_bar: HFlowContainer
var ghost: MeshInstance3D
var holding=""            # decoration kind in hand ("" = none)
var rot=0
var target={}
var clock=0.0
var editor_open=false
# Inside 星锻公寓 (the island-Ⅰ residence interior, in its own World3D).
var interior_mode=false
var interior
var interior_layout
var interior_camera
var room_box
var deck_walker
var deck_terrain
var deck_hands
var exit_button: Button

func pilot():
	return walker

func return_title() -> String:
	return "星锻岛漫步"

func setup(model) -> void:
	state=model; set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); theme=UI.make_theme()
	var bg=ColorRect.new(); bg.color=UI.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	title_label=UI.label("星锻岛漫步",28,UI.MINT); title_label.position=Vector2(28,22); add_child(title_label)
	subtitle=UI.label("在工厂之间走走，看看员工在忙什么。",16,UI.MUTED); subtitle.position=Vector2(250,31); add_child(subtitle)
	var close=UI.button("回到管理视角",_close); close.position=Vector2(1210,21); close.size=Vector2(202,48); add_child(close)
	var box=SubViewportContainer.new(); box.position=Vector2(28,90); box.size=Vector2(1384,640); box.stretch=true; box.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(box)
	viewport=SubViewport.new(); viewport.size=Vector2i(1384,640); viewport.own_world_3d=true; box.add_child(viewport)
	view=preload("res://scripts/starforge_view.gd").new(); view.walk_mode=true; viewport.add_child(view); view.sync(state.industry)
	terrain.setup(state.industry)
	walker=preload("res://scripts/river_walker.gd").new(terrain); walker.enter("deck"); _unstick()
	hands=preload("res://scripts/first_person_hands.gd").new(); view.camera.add_child(hands); hands.set_tool("collect")
	ghost=MeshInstance3D.new(); var gm=StandardMaterial3D.new(); gm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; gm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; ghost.material_override=gm
	view.add_child(ghost); ghost.hide()
	input=preload("res://scripts/river_exploration_input.gd").new(); input.view=self; input.position=box.position; input.size=box.size; add_child(input); input.set_walking(true)
	input.primary_requested.connect(_interact); input.collect_requested.connect(_interact)
	caption=UI.label("",18,UI.GOLD); caption.position=Vector2(240,738); caption.size=Vector2(960,36); caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; add_child(caption)
	decor_bar=HFlowContainer.new(); decor_bar.position=Vector2(28,780); decor_bar.size=Vector2(1100,110); decor_bar.add_theme_constant_override("h_separation",6); add_child(decor_bar)
	var actions=UI.row(self,8); actions.position=Vector2(1140,786)
	for item in [["互动 E",_interact],["旋转",_rotate],["跳跃",func(): walker.jump()]]:
		var b=UI.button(item[0],item[1]); b.focus_mode=Control.FOCUS_NONE; actions.add_child(b)
	exit_button=UI.button("离开公寓",_exit_apartment); exit_button.focus_mode=Control.FOCUS_NONE; exit_button.position=Vector2(1140,840); exit_button.hide(); add_child(exit_button)
	_decor_bar(); _camera(); _update_caption()

## If the start point is taken (a decoration stands there), step out to the nearest free spot.
func _unstick() -> void:
	if not terrain.blocked(walker.position): return
	for r in range(1,40):
		for k in range(12):
			var p=walker.position+Vector2.from_angle(k*TAU/12)*r*0.1
			if not terrain.blocked(p): walker.position=p; walker.reset_height(); return

## The toolbox decorations, one button each; the held one is highlighted.
func _decor_bar() -> void:
	for c in decor_bar.get_children(): c.queue_free()
	var hand=UI.button("空手",func(): _hold(""))
	hand.focus_mode=Control.FOCUS_NONE; hand.modulate=UI.MINT if holding=="" else Color.WHITE; decor_bar.add_child(hand)
	var kinds=[]
	for kind in state.storage.decorations:
		if int(state.storage.decorations[kind])>0 and Town.is_decor(str(kind)) and not Town.is_building(str(kind)): kinds.append(str(kind))
	kinds.sort()
	for kind in kinds:
		var b=UI.button("%s ×%d" % [state.town_name(kind),int(state.storage.decorations[kind])],_hold.bind(kind))
		b.focus_mode=Control.FOCUS_NONE; b.add_theme_font_size_override("font_size",14); b.modulate=UI.MINT if kind==holding else Color.WHITE; decor_bar.add_child(b)
	if kinds.is_empty(): decor_bar.add_child(UI.label("工具箱里没有装饰：在浮岛 Ⅰ 的布置庭院里收起或买一些，或让家居工坊做家具送回。",14,UI.MUTED))

func _hold(kind: String) -> void:
	holding=kind if int(state.storage.decorations.get(kind,0))>0 else ""
	_decor_bar(); input.grab_focus(); _update_caption()

func _rotate() -> void:
	rot=posmod(rot+1,4); _update_caption()

func _camera() -> void:
	if interior_mode:
		interior_camera.position=walker.eye(); interior_camera.rotation=Vector3(walker.pitch,walker.yaw,0); interior_camera.current=true
		return
	view.camera.fov=75; view.camera.near=0.02; view.camera.far=150
	view.camera.position=walker.eye(); view.camera.rotation=Vector3(walker.pitch,walker.yaw,0); view.camera.current=true

## What the crosshair is on: a staff member, a building, a decoration, or a deck tile within reach.
func aim() -> Dictionary:
	if interior_mode: return interior.query(interior_camera.position,-interior_camera.transform.basis.z)
	var ind=state.industry; var eye=walker.eye(); var dir=-view.camera.global_transform.basis.z
	var best={}; var reach=2.6
	for id in view.figures:
		var f: Node3D=view.figures[id]
		var hit=AABB(f.position+Vector3(-0.16,0,-0.16),Vector3(0.32,0.8,0.32)).intersects_ray(eye,dir)
		if hit!=null and eye.distance_to(hit)<reach: reach=eye.distance_to(hit); best={"kind":"staff","id":int(id)}
	for key in ind.buildings:
		var at: Vector3=ind.plot_center(int(key))
		var hit=AABB(at+Vector3(-Surface.PLINTH,0,-Surface.PLINTH),Vector3(Surface.PLINTH*2,2.6,Surface.PLINTH*2)).intersects_ray(eye,dir)
		if hit!=null and eye.distance_to(hit)<reach: reach=eye.distance_to(hit); best={"kind":"building","index":int(key),"building":str(ind.buildings[key].kind)}
	for row in ind.decorations():
		var at: Vector3=ind.plot_center(int(row.plot)); var r=Surface.tile_rect(Vector2(at.x,at.z),Town.item_rect(row.item)).grow(0.05)   # picking is a bit generous
		var hit=AABB(Vector3(r.position.x,0,r.position.y),Vector3(r.size.x,0.6,r.size.y)).intersects_ray(eye,dir)
		if hit!=null and eye.distance_to(hit)<reach: reach=eye.distance_to(hit); best={"kind":"decor","plot":int(row.plot),"uid":int(row.item.uid),"item":row.item}
	if best.is_empty() and dir.y<-0.05:
		var t=-eye.y/dir.y; var p=eye+dir*t
		if t<3.2 and terrain.inside(Vector2(p.x,p.z)): best={"kind":"ground","point":Vector2(p.x,p.z)}
	return best

## Where the held decoration would go: plot index and the footprint's anchor tile (centred on aim).
func placement(point: Vector2) -> Dictionary:
	var ind=state.industry; var plot=ind.plot_at(Surface.cell_of(point))
	var n=Town.size(holding,rot); var tile=Surface.tile_of(point)-Vector2i(n.x/2,n.y/2)
	tile=Vector2i(clampi(tile.x,0,Town.usable()-n.x),clampi(tile.y,0,Town.usable()-n.y))
	return {"plot":plot,"at":tile,"error":ind.decor_error(state,plot,holding,tile,rot) if plot>=0 else "这里不是甲板"}

func _interact() -> void:
	if editor_open: return
	hands.swing(); target=aim()
	if interior_mode:
		if not walker.resting.is_empty(): walker.stand(); hands.visible=true; _update_caption(); return
		match str(target.get("kind","")):
			"door":
				if not interior.toggle_door(walker.position): caption.text="先离开门扇范围，再开关门"
			"chair","sofa","bed": walker.rest(interior_layout.fixtures[int(target.index)]); hands.hide()
			"": caption.text="靠近门、床或沙发再互动。"
			_: caption.text=str(target.get("title",""))
		return
	var ind=state.industry
	if holding!="" and target.get("kind","")=="ground":
		var spot=placement(target.point)
		caption.text=spot.error if not spot.error.is_empty() else ind.place_decor(state,int(spot.plot),holding,spot.at,rot)
		if spot.error.is_empty():
			if int(state.storage.decorations.get(holding,0))<=0: holding=""
			_refresh()
		return
	match str(target.get("kind","")):
		"decor":
			caption.text=ind.store_decor(state,int(target.plot),int(target.uid)); _refresh()
		"building":
			if target.building=="staff_housing": enter_apartment(int(target.index))
			else: requested.emit("manage",int(target.index))
		"staff":
			caption.text=_staff_line(int(target.id))
		_:
			caption.text="走近工厂或公寓再互动；选一件装饰，对准空甲板按 E 摆放。"

func _staff_line(id: int) -> String:
	var ind=state.industry
	for s in ind.staff:
		if int(s.id)==id: return "%s · %s · 体力 %d%% · %s" % [s.name,ind.rules().staff.roles[s.role].name,int(float(s.get("energy",100.0))),ind.status_of(s)]
	return ""

func _refresh() -> void:
	view.sync(state.industry); terrain.setup(state.industry); _decor_bar()

# --- Inside 星锻公寓 ------------------------------------------------------------------------------
func enter_apartment(index: int) -> bool:
	var ind=state.industry; var b: Dictionary=ind.buildings.get(str(index),{})
	if interior_mode or b.get("kind","")!="staff_housing": return false
	input.clear_input(); deck_walker=walker; deck_terrain=terrain; deck_hands=hands
	interior_layout=preload("res://scripts/residence_layout.gd").new()
	interior_layout.setup({"kind":"staff_housing","building_level":int(b.level),"furnished":int(ind.furnished.get(str(index),0))},1)
	var surface=preload("res://scripts/residence_surface.gd").new(); surface.setup(interior_layout)
	room_box=SubViewportContainer.new(); room_box.position=input.position; room_box.size=input.size; room_box.stretch=true; room_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(room_box); move_child(room_box,input.get_index())
	var room_viewport=SubViewport.new(); room_viewport.size=Vector2i(input.size); room_viewport.own_world_3d=true; room_box.add_child(room_viewport)
	var room=Node3D.new(); room_viewport.add_child(room)
	interior=preload("res://scripts/residence_interior.gd").new(); room.add_child(interior); interior.setup(interior_layout,surface)
	var light=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-55,-25,0); light.light_energy=0.5; light.light_color=Color("fff1d0"); room.add_child(light)
	var fill=OmniLight3D.new(); fill.position=Vector3(0,2.3,0); fill.omni_range=13; fill.light_energy=0.48; fill.light_color=Color("ffe4bd"); room.add_child(fill)
	var env=WorldEnvironment.new(); var e=Environment.new(); e.background_mode=Environment.BG_COLOR; e.background_color=Color("0d1d2b"); e.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color=Color("d2d8d0"); e.ambient_light_energy=0.56; env.environment=e; room.add_child(env)
	interior_camera=Camera3D.new(); interior_camera.fov=75; interior_camera.near=0.03; interior_camera.far=80; room.add_child(interior_camera)
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; view.process_mode=Node.PROCESS_MODE_DISABLED
	hands=preload("res://scripts/first_person_hands.gd").new(); interior_camera.add_child(hands); hands.set_tool("")
	terrain=surface; walker=preload("res://scripts/residence_walker.gd").new(terrain); walker.enter("residence"); walker.yaw=0
	interior.observer=walker; interior_mode=true
	title_label.text=str(interior_layout.spec.name); subtitle.text="Lv.%d · %s" % [interior_layout.level,interior_layout.description()]
	decor_bar.hide(); exit_button.show(); input.set_walking(true); _camera(); _update_caption()
	return true

func _exit_apartment() -> void:
	if not interior_mode: return
	input.clear_input(); interior_mode=false
	room_box.queue_free(); room_box=null; interior=null
	terrain=deck_terrain; walker=deck_walker; hands=deck_hands
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; view.process_mode=Node.PROCESS_MODE_INHERIT
	title_label.text="星锻岛漫步"; subtitle.text="在工厂之间走走，看看员工在忙什么。"
	decor_bar.show(); exit_button.hide(); input.set_walking(true); _camera(); caption.text="回到了甲板上"

func handle_back() -> bool:
	if not interior_mode: return false
	if not walker.resting.is_empty(): walker.stand(); hands.visible=true
	else: _exit_apartment()
	return true

## Main suspends this screen (keeps the walker where it is) while the management panel is open.
func set_editor_open(open: bool) -> void:
	editor_open=open
	input.set_walking(not open)
	process_mode=Node.PROCESS_MODE_DISABLED if open else Node.PROCESS_MODE_INHERIT
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if open or interior_mode else SubViewport.UPDATE_ALWAYS
	if not open:
		_refresh(); _camera(); input.grab_focus()

func _process(dt: float) -> void:
	if view==null or input==null: return
	walker.step(dt)
	if interior_mode:
		hands.visible=walker.resting.is_empty()
		if walker.position.y>interior_layout.depth/2+0.35 and interior.door_open: _exit_apartment(); return
	_camera(); hands.moving=walker.movement.length(); clock+=dt
	if not interior_mode: _ghost()
	if clock<0.2: return
	clock=0
	if not interior_mode: view.sync(state.industry)
	_update_caption()

## The held decoration's footprint on the aimed tiles: green fits, red does not.
func _ghost() -> void:
	if holding=="": ghost.hide(); return
	var t=aim()
	if t.get("kind","")!="ground": ghost.hide(); return
	var spot=placement(t.point)
	if int(spot.plot)<0: ghost.hide(); return
	var n=Town.size(holding,rot); var center=state.industry.plot_center(int(spot.plot))+Town.center(spot.at,n)
	var b=BoxMesh.new(); b.size=Vector3(n.x*Town.tile()-0.02,0.05,n.y*Town.tile()-0.02); ghost.mesh=b
	ghost.position=center+Vector3(0,0.04,0); ghost.show()
	ghost.material_override.albedo_color=Color(0.3,1.0,0.55,0.45) if spot.error.is_empty() else Color(1.0,0.35,0.3,0.45)

func _update_caption() -> void:
	target=aim()
	if interior_mode:
		if not walker.resting.is_empty(): caption.text="%s · E / 跳跃 起身" % ("躺在床上" if walker.resting=="bed" else "坐在沙发上")
		elif target.is_empty(): caption.text="星锻公寓 · 对准床或沙发按 E · 打开门，走出去回到甲板"
		elif target.kind=="door": caption.text="E · %s" % ("关门" if interior.door_open else "开门 · 门外是甲板")
		elif target.kind in ["bed","sofa","chair"]: caption.text="E · %s · %s" % ["躺下" if target.kind=="bed" else "坐下",target.title]
		else: caption.text=str(target.get("title",""))
		return
	var ind=state.industry
	match str(target.get("kind","")):
		"staff": caption.text=_staff_line(int(target.id))
		"building":
			var spec: Dictionary=ind.rules().buildings[target.building]
			caption.text="%s Lv.%d · E %s" % [spec.name,int(ind.buildings[str(target.index)].level),"走进公寓" if target.building=="staff_housing" else "打开管理"]
		"decor": caption.text="%s · E 收回工具箱" % state.town_name(str(target.item.kind))
		"ground":
			if holding!="":
				var spot=placement(target.point)
				caption.text=("E · 摆放%s（旋转 %d°）" % [state.town_name(holding),rot*90]) if spot.error.is_empty() else spot.error
			else: caption.text="空甲板 · 选一件装饰后对准这里按 E"
		_: caption.text="WASD 走动 · 拖动转头 · 对准工厂按 E 管理，对准星锻公寓按 E 进去"

func _close() -> void:
	if interior_mode: _exit_apartment()
	input.clear_input(); dismissed.emit(); queue_free()
