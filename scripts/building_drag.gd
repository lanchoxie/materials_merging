extends RefCounted
## Gesture owns a visual preview only. The state transaction happens exactly once on release.
const HOLD_SECONDS=0.46
const SLOP=10.0
var game
var source=-1
var target=-1
var elapsed=0.0
var armed=false
var active=false
var origin: Vector2
var ghost: Node3D
var original: Node3D
var marker: MeshInstance3D

func setup(owner_game) -> void: game=owner_game

func pick(pos: Vector2) -> int:
	if not Rect2(Vector2.ZERO,game.world_box.size).has_point(pos): return -1
	return game.world.screen_pick(pos*Vector2(game.world_viewport.size)/game.world_box.size)

func begin(pos: Vector2) -> void:
	cancel()
	origin=pos; source=pick(pos); elapsed=0.0
	if source<0: return
	var plot: Dictionary=game.state.plots[source]
	armed=plot.unlocked and plot.kind not in ["empty","plaza"]

func tick(dt: float) -> void:
	if not armed or active: return
	elapsed+=dt
	if elapsed<HOLD_SECONDS: return
	var campus=game.campus_view.scenery.get_node_or_null("Plot_%d/Building" % source)
	original=campus if campus!=null else game.world._content.get_node_or_null("Plot_%d" % source)
	if original==null: cancel(); return
	ghost=original.duplicate() as Node3D
	game.world.add_child(ghost)
	ghost.global_transform=original.global_transform
	original.hide()
	ghost.position.y+=0.48
	marker=MeshInstance3D.new()
	var shape=BoxMesh.new(); shape.size=Vector3(2.77,0.05,2.77); marker.mesh=shape
	var mat=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override=mat; game.world.add_child(marker)
	active=true; armed=false
	game.world.interaction_lock=true
	game._toast("建筑已拿起 · 拖到空地松手放置 · 移出地图取消")
	move(origin)

func valid_target(index: int) -> bool:
	if index<0 or index>=game.state.plots.size(): return false
	var p: Dictionary=game.state.plots[index]
	return p.unlocked and (p.kind=="empty" or index==source)

func move(pos: Vector2) -> bool:
	if not active:
		if pos.distance_to(origin)>SLOP: armed=false
		return false
	target=pick(pos)
	if target>=0:
		var p: Dictionary=game.state.plots[target]
		ghost.position=Vector3(float(p.x)*3,0.48,float(p.z)*3)
		marker.position=Vector3(float(p.x)*3,0.13,float(p.z)*3)
	marker.material_override.albedo_color=Color("84dcc2") if valid_target(target) else Color("e98888")
	return true

func release(pos: Vector2) -> bool:
	if not active: armed=false; return false
	move(pos)
	var destination=target
	var start=source
	var okay=valid_target(target)
	cancel()
	if okay and destination!=start:
		game._action(game.state.move_building(start,destination))
		game._select_plot(destination)
	elif not okay: game._toast("此处不能放置，建筑已回到原位")
	return true

func cancel() -> void:
	if game!=null and is_instance_valid(game.world): game.world.interaction_lock=false
	if is_instance_valid(original): original.show()
	if is_instance_valid(ghost): ghost.queue_free()
	if is_instance_valid(marker): marker.queue_free()
	ghost=null; marker=null; original=null
	armed=false; active=false; source=-1; target=-1
