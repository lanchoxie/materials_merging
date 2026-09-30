extends RefCounted
## v0.27 build mode: a ghost that follows the pointer tile by tile, a green/red footprint and the
## plot's tile grid. Tapping commits through lab_state's town API, so the model stays the only truth.
## Path, fence and plant items marked "paint" keep painting while the pointer drags.
const Town=preload("res://scripts/island_town.gd")
const TownDecor=preload("res://scripts/town_decor.gd")
const UI=preload("res://scripts/ui.gd")
## Orthographic camera height while building: one plot fills about a third of the view.
const ZOOM=9.0
var game
var active=false
var kind=""
var rot=0
## Moving an existing item: its plot and uid (0 = the plot's main building). -1 when placing new.
var source_plot=-1
var uid=-1
var plot=-1
var at=Vector2i(-1,-1)
var error=""
var painting=false
var placed=0
var _painted: Dictionary={}
var ghost: Node3D
var marker: MeshInstance3D
var grid: MeshInstance3D
var hud: PanelContainer
var hud_label: Label
## Camera size before build mode zoomed in on the plot; restored when the mode ends.
var _camera_size=0.0

func setup(owner_game) -> void: game=owner_game

func start_place(item_kind: String) -> void:
	_begin(item_kind,-1,-1)
	game._toast("点选地块上的空格摆放 · %s" % ("按住拖动可以连续铺设" if paints() else "可以旋转后再放"))

func start_move(from_plot: int, item_uid: int) -> void:
	var p: Dictionary=game.state.plots[from_plot]
	var item_kind=str(p.kind) if item_uid==0 else str(game.state.town_item(from_plot,item_uid).get("kind",""))
	if item_kind.is_empty(): return
	_begin(item_kind,from_plot,item_uid)
	rot=0 if item_uid==0 else int(game.state.town_item(from_plot,item_uid).get("rot",0))
	if is_instance_valid(ghost): ghost.rotation.y=-rot*PI/2
	_hide_original(true)
	game._toast("点选新位置 · 建筑只在本地块内挪动，装饰可以搬到别的地块")

func paints() -> bool:
	return uid<0 and bool(Town.info(kind).get("paint",false))

func rotatable() -> bool:
	return not Town.is_building(kind)

func _begin(item_kind: String, from_plot: int, item_uid: int) -> void:
	cancel()
	game._close_modal()
	active=true; kind=item_kind; source_plot=from_plot; uid=item_uid; rot=0; placed=0
	plot=-1; at=Vector2i(-1,-1); error=""
	game.world.interaction_lock=true
	var camera: Camera3D=game.world.camera
	_camera_size=camera.size
	if camera.size>ZOOM: game.world.zoom_view(ZOOM/camera.size)
	var focus=from_plot if from_plot>=0 else game.selected_plot
	if focus>=0 and focus<game.state.plots.size() and game.state.plots[focus].unlocked: game.world.focus_plot(focus)
	marker=MeshInstance3D.new(); marker.mesh=BoxMesh.new()
	var mat=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override=mat; game.world.add_child(marker)
	grid=MeshInstance3D.new()
	var line=StandardMaterial3D.new(); line.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; line.albedo_color=Color(1,1,1,0.35); line.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	grid.material_override=line; grid.mesh=_grid_mesh(); game.world.add_child(grid); grid.hide()
	_build_ghost()
	_build_hud()
	_show_target()

func _grid_mesh() -> ImmediateMesh:
	var lines=ImmediateMesh.new(); lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var t=Town.tile(); var n=Town.usable()
	for i in range(n+1):
		lines.surface_add_vertex(Vector3(-1.5+i*t,0,-1.5)); lines.surface_add_vertex(Vector3(-1.5+i*t,0,-1.5+n*t))
		lines.surface_add_vertex(Vector3(-1.5,0,-1.5+i*t)); lines.surface_add_vertex(Vector3(-1.5+n*t,0,-1.5+i*t))
	lines.surface_end()
	return lines

func _build_ghost() -> void:
	if is_instance_valid(ghost): ghost.queue_free()
	ghost=Node3D.new(); ghost.name="TownGhost"; game.world.add_child(ghost)
	var body=Node3D.new(); ghost.add_child(body)
	var view=game.campus_view
	if Town.is_building(kind):
		var level=int(game.state.plots[source_plot].get("building_level",1)) if uid==0 else int(game.state.town_item(source_plot,uid).get("level",1)) if uid>0 else 1
		var s=Town.size(kind).x*Town.tile()/view.NATIVE_WIDTH
		body.scale=Vector3(s,s,s)
		view._building(body,{"kind":kind,"building_level":level,"tier":Town.tier(level,int(game.state.layout.building_info(kind).get("max_level",1)))},false)
	else:
		var saved=view.spinners.size()
		TownDecor.build(view,body,kind,[],true)
		view.spinners.resize(saved)
	ghost.hide()

func _build_hud() -> void:
	hud=UI.box(game,Rect2(236,138,822,58),Color("20393f"))
	var row=UI.row(hud,10)
	hud_label=UI.label("",15,UI.TEXT); hud_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(hud_label)
	if rotatable(): row.add_child(UI.button("↻ 旋转",rotate))
	row.add_child(UI.button("完成" if uid<0 else "取消",finish,true))
	_update_hud()

func _update_hud() -> void:
	if not is_instance_valid(hud_label): return
	var name=game.state.town_name(kind)
	var price=game.state.town_price(kind)
	var stored=int(game.state.storage.decorations.get(kind,0))
	var text="挪动 · %s" % name if uid>=0 else "摆放 · %s   %s" % [name,"工具箱里还有%d件" % stored if stored>0 else "%d 金币" % price]
	if placed>0: text+="   已放%d件" % placed
	if not error.is_empty() and plot>=0: text+="   ·  "+error
	hud_label.text=text
	hud_label.modulate=Color("ffb4a8") if (not error.is_empty() and plot>=0) else Color.WHITE

func rotate() -> void:
	rot=posmod(rot+1,4)
	if is_instance_valid(ghost): ghost.rotation.y=-rot*PI/2
	_evaluate(); _show_target()

func _screen(pos: Vector2) -> Vector2:
	return pos*Vector2(game.world_viewport.size)/game.world_box.size

## Pointer hover or drag: snap the ghost to the tile under the pointer.
func hover(pos: Vector2) -> void:
	if not active: return
	var point=game.world.screen_point(_screen(pos))
	if point==null: plot=-1; _show_target(); return
	var index: int=game.world.plot_at_point(point)
	plot=index
	if index>=0:
		var p: Dictionary=game.state.plots[index]
		var local: Vector3=point-Vector3(float(p.x)*3,0,float(p.z)*3)
		var footprint=Town.size(kind,rot)
		var cell=Town.tile_at(local)
		at=Vector2i(clampi(cell.x-footprint.x/2,0,maxi(0,Town.usable()-footprint.x)),clampi(cell.y-footprint.y/2,0,maxi(0,Town.usable()-footprint.y)))
	_evaluate()
	_show_target()
	if painting and error.is_empty(): _commit(false)

func press(pos: Vector2) -> void:
	if not active: return
	hover(pos)
	painting=paints()
	_painted.clear()
	if painting and error.is_empty(): _commit(false)

func release(pos: Vector2, dragged: bool) -> void:
	if not active: return
	var was_painting=painting
	painting=false
	hover(pos)
	if was_painting:
		if placed==0 and not error.is_empty(): game._toast(error)
		return
	if dragged and uid<0: return
	if not error.is_empty(): game._toast(error); return
	_commit(true)

func _evaluate() -> void:
	error=""
	if plot<0: error="请点在已开拓的地块上"; return
	var state=game.state
	error=state._town_plot_error(plot)
	if not error.is_empty(): return
	var p: Dictionary=state.plots[plot]
	if Town.is_building(kind):
		if uid>=0 and plot!=source_plot: error="建筑只在本地块内挪动"; return
		if p.kind=="reactor": error="反应炉地块只能摆放装饰"; return
	var ignore_uid=uid if (uid>0 and plot==source_plot) else -1
	error=Town.fits(p,kind,at,rot,ignore_uid,uid==0)
	if not error.is_empty(): return
	if uid<0:
		var stored=int(state.storage.decorations.get(kind,0))
		if Town.is_building(kind) or stored<=0:
			var locked=state.town_locked(kind) if not Town.is_building(kind) else ""
			if not locked.is_empty(): error=locked; return
			if state.coins<state.town_price(kind): error="金币不足"; return

func _show_target() -> void:
	_update_hud()
	if not is_instance_valid(marker): return
	if plot<0:
		marker.hide(); ghost.hide(); grid.hide(); return
	var p: Dictionary=game.state.plots[plot]
	var base=Vector3(float(p.x)*3,0,float(p.z)*3)
	var footprint=Town.size(kind,rot)
	var center=base+Town.center(at,footprint)
	(marker.mesh as BoxMesh).size=Vector3(footprint.x*Town.tile()-0.02,0.03,footprint.y*Town.tile()-0.02)
	marker.position=center+Vector3(0,0.13,0)
	marker.material_override.albedo_color=Color(0.52,0.86,0.76,0.62) if error.is_empty() else Color(0.91,0.45,0.45,0.62)
	ghost.position=center+Vector3(0,0.06 if error.is_empty() else 0.18,0)
	grid.position=base+Vector3(0,0.125,0)
	marker.show(); ghost.show(); grid.show()

func _commit(finish_after: bool) -> void:
	var state=game.state
	var key=Vector3i(plot,at.x,at.y)
	if painting and _painted.has(key): return
	var message=""
	if uid<0: message=state.town_place(plot,kind,at.x,at.y,rot)
	else: message=state.town_move(source_plot,uid,plot,at.x,at.y,rot)
	var ok=message.contains("已摆放") or message.contains("落成") or message.contains("已挪到")
	if not ok: game._toast(message); return
	_painted[key]=true
	placed+=1
	var done=uid>=0 or Town.is_building(kind) or (finish_after and state.coins<state.town_price(kind) and int(state.storage.decorations.get(kind,0))<=0)
	if done:
		var target=plot
		cancel(); game.selected_plot=target; game._action(message); game._select_plot(target); return
	# Painting a row saves once at the end instead of on every tile.
	game.feedback.react(game,message)
	game._sync_world(); game._update_labels()
	_evaluate(); _show_target()
	if not painting: game._toast(message)

func _hide_original(hidden: bool) -> void:
	if source_plot<0 or game.campus_view==null or not is_instance_valid(game.campus_view.scenery): return
	var path="Plot_%d/Building" % source_plot if uid==0 else "Plot_%d/Item_%d" % [source_plot,uid]
	var node: Node3D=game.campus_view.scenery.get_node_or_null(path)
	if node!=null: node.visible=not hidden

func finish() -> void:
	var dirty=placed>0
	cancel()
	if dirty and not game.snapshot_mode and not game.visual_test: game.state.save_game()
	game._rebuild_sidebar()

func cancel() -> void:
	if not active: return
	_hide_original(false)
	active=false; painting=false
	if game!=null and is_instance_valid(game.world):
		game.world.interaction_lock=false
		if _camera_size>0.0 and not is_equal_approx(game.world.camera.size,_camera_size): game.world.zoom_view(_camera_size/game.world.camera.size)
	for node in [ghost,marker,grid,hud]:
		if is_instance_valid(node): node.queue_free()
	ghost=null; marker=null; grid=null; hud=null; hud_label=null
	kind=""; uid=-1; source_plot=-1; plot=-1
