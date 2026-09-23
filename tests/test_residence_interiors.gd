extends SceneTree
const Layout=preload("res://scripts/residence_layout.gd")
const Surface=preload("res://scripts/residence_surface.gd")
const Interior=preload("res://scripts/residence_interior.gd")
var checks=0
var failures=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/residence_interiors.json"))
	for kind in ["engineer_house","doctor_dorm","professor_apartment","academician_villa"]:
		var max_level=int(data.types[kind].max_level)
		var previous=0
		for level in range(1,max_level+1):
			var plot={"kind":kind,"building_level":level}
			var layout=Layout.new(); layout.setup(plot,1)
			check(layout.kind==kind and layout.level==level,"%s level %d reads the campus level" % [kind,level])
			check(layout.fixtures.size()>previous,"%s level %d adds a usable interior fixture" % [kind,level])
			previous=layout.fixtures.size()
			var surface=Surface.new(); surface.setup(layout)
			var start=surface.spawn("")
			check(not surface.blocked(start),"%s level %d entry is clear" % [kind,level])
			check(surface.blocked(Vector2(0,layout.depth/2-0.03)),"%s level %d closed door collides" % [kind,level])
			surface.door_angle=PI/2
			check(not surface.blocked(Vector2(0,layout.depth/2-0.03)),"%s level %d open door is traversable" % [kind,level])
			var node=Interior.new(); root.add_child(node); node.setup(layout,surface)
			check(node.geometry!=null and node.door!=null and node.get_child_count()>3,"%s level %d builds a door and furniture scene" % [kind,level])
			# Every bed/chair/sofa/lift must be reachable from the entrance without crossing furniture.
			var reachable={Vector2i.ZERO:surface.spawn("")}; var queue=[Vector2i.ZERO]; var cursor=0
			while cursor<queue.size():
				var key=queue[cursor]; cursor+=1
				for delta in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var next=key+delta; var at=surface.spawn("")+Vector2(next)*0.25
					if reachable.has(next) or surface.blocked(at): continue
					reachable[next]=at; queue.append(next)
			for item in layout.fixtures:
				if item.type not in ["chair","sofa","bed","lift"]: continue
				var can_reach=false; var destination=item.box.get_center()+Vector3(0,0.12,0)
				for at in reachable.values():
					var eye=Vector3(at.x,1.67,at.y)
					if eye.distance_to(destination)>2.0: continue
					var found=node.query(eye,(destination-eye).normalized())
					if found.get("index",-1)==int(item.id): can_reach=true; break
				check(can_reach,"%s %d %s reachable and not occluded" % [kind,level,item.title])
			check(node.toggle_door(surface.spawn("")) and node.door_open,"door opens from clear standing position")
			node._process(1.0)
			check(not node.toggle_door(Vector2(0,layout.depth/2-0.1)) and node.door_open,"closing door cannot trap observer")
			check(node.toggle_door(surface.spawn("")),"door can close from a safe distance")
			node._process(0.18)
			check(surface.door_angle>0 and surface.door_angle<PI/2 and is_equal_approx(node.door.rotation.y,surface.door_angle),"animated door shares collision angle")
			node.queue_free()
	print("RESIDENCE INTERIORS: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
