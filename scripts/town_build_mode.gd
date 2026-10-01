extends RefCounted
## v0.27 build mode: a ghost that follows the pointer tile by tile, a green/red footprint and the
## tile grid. Tapping commits through lab_state's town API, so the model stays the only truth.
## Path, fence and plant items marked "paint" keep painting while the pointer drags.
## v0.31: tiles are global, so footprints may cross plot edges; the item belongs to the plot under
## its anchor (buildings keep theirs in their own plot). An eraser sends paths and decor to the
## toolbox, and every step can be undone (lab_state.town_journal).
const Town=preload("res://scripts/island_town.gd")
const TownDecor=preload("res://scripts/town_decor.gd")
const UI=preload("res://scripts/ui.gd")
## Orthographic camera height while building: one plot fills about a third of the view.
const ZOOM=9.0
var game
var active=false
var kind=""
var rot=0
## Eraser: drag over paths and decorations to put them in the toolbox.
var erasing=false
## Moving an existing item: its plot and uid (0 = the plot's main building). -1 when placing new.
var source_plot=-1
var uid=-1
var plot=-1
var at=Vector2i(-1,-1)
## Global tile under the pointer (the eraser works tile by tile).
var cell=Vector2i.ZERO
var error=""
var painting=false
var placed=0
var _painted: Dictionary={}
var ghost: Node3D
var marker: MeshInstance3D
var grid: MeshInstance3D
var hud: PanelContainer
var hud_label: Label
var undo_button: Button
var paths_button: Button
## Second tap within this mode confirms the island-wide path recycle.
var _paths_armed=false
## Undo or recycle changed the town without placing anything; finish() still saves.
var _dirty=false
## Camera size before build mode zoomed in on the plot; restored when the mode ends.
var _camera_size=0.0

func setup(owner_game) -> void: game=owner_game

func start_place(item_kind: String) -> void:
	_begin(item_kind,-1,-1)
	game._toast("点选空格摆放，可以跨过地块边缘 · %s" % ("按住拖动可以连续铺设" if paints() else "可以旋转后再放"))

func start_move(from_plot: int, item_uid: int) -> void:
	var p: Dictionary=game.state.plots[from_plot]
	var item_kind=str(p.kind) if item_uid==0 else str(game.state.town_item(from_plot,item_uid).get("kind",""))
	if item_kind.is_empty(): return
	_begin(item_kind,from_plot,item_uid)
	rot=0 if item_uid==0 else int(game.state.town_item(from_plot,item_uid).get("rot",0))
	if is_instance_valid(ghost): ghost.rotation.y=-rot*PI/2
	_hide_original(true)
	game._toast("点选新位置 · 建筑的落脚格留在本地块，可以跨出边缘；装饰可以搬到别的地块")

func start_erase() -> void:
	_begin("",-1,-1,true)
	game._toast("擦除：点或拖过小路和装饰，它们会收进工具箱 · 可以撤销")

func paints() -> bool:
	return erasing or (uid<0 and bool(Town.info(kind).get("paint",false)))

func rotatable() -> bool:
	return not erasing and not Town.is_building(kind)

func _begin(item_kind: String, from_plot: int, item_uid: int, erase: bool=false) -> void:
	cancel()
	game._close_modal()
	active=true; kind=item_kind; erasing=erase; source_plot=from_plot; uid=item_uid; rot=0; placed=0
	plot=-1; at=Vector2i(-1,-1); error=""; _paths_armed=false; _dirty=false
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

## Tile lines over the hovered plot and its neighbours; plot edges are drawn twice as bright.
func _grid_mesh() -> ImmediateMesh:
	var lines=ImmediateMesh.new(); lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var t=Town.tile(); var n=Town.grid()*3
	var start=-4.5
	for i in range(n+1):
		var repeat=2 if i%Town.grid()==0 else 1
		for k in range(repeat):
			var lift=0.004*k
			lines.surface_add_vertex(Vector3(start+i*t,lift,start)); lines.surface_add_vertex(Vector3(start+i*t,lift,start+n*t))
			lines.surface_add_vertex(Vector3(start,lift,start+i*t)); lines.surface_add_vertex(Vector3(start+n*t,lift,start+i*t))
	lines.surface_end()
	return lines

func _build_ghost() -> void:
	if is_instance_valid(ghost): ghost.queue_free()
	ghost=Node3D.new(); ghost.name="TownGhost"; game.world.add_child(ghost)
	if erasing: ghost.hide(); return
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
	hud=UI.box(game,Rect2(236,138,880,58),Color("20393f"))
	var row=UI.row(hud,8)
	hud_label=UI.label("",15,UI.TEXT); hud_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hud_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	row.add_child(hud_label)
	if rotatable(): row.add_child(UI.button("↻ 旋转",rotate))
	undo_button=UI.button("↶ 撤销",undo); row.add_child(undo_button)
	if uid<0:
		if erasing: row.add_child(UI.button("改为摆放",func(): finish(); game._show_town_shop()))
		else: row.add_child(UI.button("擦除",start_erase))
		paths_button=UI.button("回收全岛小路",recycle_paths); row.add_child(paths_button)
	row.add_child(UI.button("完成" if uid<0 else "取消",finish,true))
	_update_hud()

func _update_hud() -> void:
	if not is_instance_valid(hud_label): return
	var text=""
	if erasing:
		text="擦除 · 拖过的小路和装饰收进工具箱"
	else:
		var name=game.state.town_name(kind)
		var price=game.state.town_price(kind)
		var stored=int(game.state.storage.decorations.get(kind,0))
		text="挪动 · %s" % name if uid>=0 else "摆放 · %s   %s" % [name,"工具箱里还有%d件" % stored if stored>0 else "%d 金币" % price]
	if placed>0: text+="   %s%d件" % ["已收" if erasing else "已放",placed]
	if not error.is_empty() and plot>=0: text+="   ·  "+error
	hud_label.text=text
	hud_label.modulate=Color("ffb4a8") if (not error.is_empty() and plot>=0) else Color.WHITE
	if is_instance_valid(undo_button):
		var last=game.state.town_undo_text()
		undo_button.disabled=last.is_empty()
		undo_button.tooltip_text="撤销：" + last if not last.is_empty() else "还没有可以撤销的操作"
	if is_instance_valid(paths_button):
		var count=game.state.town_recyclable(-1).size()
		paths_button.text="再点一次：回收%d块小路" % count if _paths_armed else "回收全岛小路"
		paths_button.disabled=count==0

func rotate() -> void:
	if not rotatable(): return
	rot=posmod(rot+1,4)
	if is_instance_valid(ghost): ghost.rotation.y=-rot*PI/2
	_evaluate(); _show_target()

## Undo the newest town edit (also bound to Ctrl+Z). Build mode stays open.
func undo() -> void:
	var message=game.state.town_undo()
	_paths_armed=false; _dirty=true
	_refresh(message)

func recycle_paths() -> void:
	if not _paths_armed:
		_paths_armed=true; _update_hud(); return
	_paths_armed=false; _dirty=true
	_refresh(game.state.town_recycle(-1))

func _refresh(message: String) -> void:
	game._sync_world(); game._update_labels()
	_evaluate(); _show_target()
	game._toast(message)

func _screen(pos: Vector2) -> Vector2:
	return pos*Vector2(game.world_viewport.size)/game.world_box.size

## Pointer hover or drag: snap the ghost to the tile under the pointer.
func hover(pos: Vector2) -> void:
	if not active: return
	var point=game.world.screen_point(_screen(pos))
	if point==null or game.world.plot_at_point(point)<0: plot=-1; _show_target(); return
	var state=game.state
	cell=Town.global_at(point)
	var footprint=Town.size(kind,rot) if not erasing else Vector2i.ONE
	var anchor=cell-Vector2i(footprint.x/2,footprint.y/2)
	if Town.is_building(kind) and source_plot>=0:
		# A moved building keeps its anchor (and residents) in its own plot.
		plot=source_plot
		var local=anchor-Town.to_global(state.plots[plot],Vector2i.ZERO)
		at=Vector2i(clampi(local.x,0,Town.grid()-1),clampi(local.y,0,Town.grid()-1))
	else:
		plot=int(Town.coord_lookup(state.plots).get(Town.plot_of(anchor),-1))
		if plot>=0: at=anchor-Town.to_global(state.plots[plot],Vector2i.ZERO)
	_evaluate()
	_show_target()
	if painting and error.is_empty(): _commit(false)

func press(pos: Vector2) -> void:
	if not active: return
	_paths_armed=false
	hover(pos)
	painting=paints()
	_painted.clear()
	if painting:
		game.state.town_group_begin()
		if error.is_empty(): _commit(false)

func release(pos: Vector2, dragged: bool) -> void:
	if not active: return
	var was_painting=painting
	painting=false
	hover(pos)
	if was_painting:
		game.state.town_group_end()
		if placed==0 and not error.is_empty(): game._toast(error)
		_update_hud()
		return
	if dragged and uid<0: return
	if not error.is_empty(): game._toast(error); return
	_commit(true)

## What the eraser would collect on the hovered tile: [plot, uid] or [] (with error set).
func _erase_target() -> Array:
	var hit: Dictionary=game.state.town_at(cell)
	if hit.is_empty() or not str(hit.id).is_valid_int(): error="这里没有小路或装饰"; return []
	var item: Dictionary=game.state.town_item(int(hit.plot),int(hit.id))
	if item.is_empty() or Town.is_building(str(item.kind)): error="建筑不能擦除，请在侧栏出售"; return []
	return [int(hit.plot),int(hit.id)]

func _evaluate() -> void:
	error=""
	if plot<0: error="请点在已开拓的地块上"; return
	var state=game.state
	if erasing:
		_erase_target(); return
	error=state._town_plot_error(plot)
	if not error.is_empty(): return
	var ignore: Array=[]
	if uid==0: ignore.append("%d:p" % source_plot)
	elif uid>0: ignore.append("%d:%d" % [source_plot,uid])
	error=state.town_fits(plot,kind,at,rot,ignore)
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
	var t=Town.tile()
	var footprint=Town.size(kind,rot) if not erasing else Vector2i.ONE
	var origin=cell if erasing else Town.to_global(p,at)
	var center=Vector3((origin.x+footprint.x*0.5)*t-1.5,0,(origin.y+footprint.y*0.5)*t-1.5)
	(marker.mesh as BoxMesh).size=Vector3(footprint.x*t-0.02,0.03,footprint.y*t-0.02)
	marker.position=center+Vector3(0,0.13,0)
	var good=Color(0.95,0.72,0.42,0.62) if erasing else Color(0.52,0.86,0.76,0.62)
	marker.material_override.albedo_color=good if error.is_empty() else Color(0.91,0.45,0.45,0.62)
	ghost.position=center+Vector3(0,0.06 if error.is_empty() else 0.18,0)
	grid.position=Vector3(float(p.x)*3,0.125,float(p.z)*3)
	marker.show(); grid.show()
	ghost.visible=not erasing

func _commit(finish_after: bool) -> void:
	var state=game.state
	var key=Vector3i(cell.x,cell.y,-1) if erasing else Vector3i(plot,at.x,at.y)
	if painting and _painted.has(key): return
	var message=""
	if erasing:
		var target=_erase_target()
		if target.is_empty(): return
		message=state.town_store(int(target[0]),int(target[1]))
	elif uid<0: message=state.town_place(plot,kind,at.x,at.y,rot)
	else: message=state.town_move(source_plot,uid,plot,at.x,at.y,rot)
	var ok=message.contains("已摆放") or message.contains("落成") or message.contains("已挪到") or message.contains("已收入")
	if not ok: game._toast(message); return
	_painted[key]=true
	placed+=1
	var done=not erasing and (uid>=0 or Town.is_building(kind) or (finish_after and state.coins<state.town_price(kind) and int(state.storage.decorations.get(kind,0))<=0))
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
	var dirty=placed>0 or _dirty
	cancel()
	if dirty and not game.snapshot_mode and not game.visual_test: game.state.save_game()
	game._rebuild_sidebar()

func cancel() -> void:
	if not active: return
	_hide_original(false)
	if painting: game.state.town_group_end()
	active=false; painting=false; erasing=false
	if game!=null and is_instance_valid(game.world):
		game.world.interaction_lock=false
		if _camera_size>0.0 and not is_equal_approx(game.world.camera.size,_camera_size): game.world.zoom_view(_camera_size/game.world.camera.size)
	for node in [ghost,marker,grid,hud]:
		if is_instance_valid(node): node.queue_free()
	ghost=null; marker=null; grid=null; hud=null; hud_label=null; undo_button=null; paths_button=null
	kind=""; uid=-1; source_plot=-1; plot=-1
