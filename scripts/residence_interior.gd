extends Node3D
## Presentation of one residential floor. State stays in the campus plot and is never duplicated.
const Geometry=preload("res://scripts/residence_geometry.gd")
var layout
var surface
var door
var door_open=false
var geometry
var door_target=0.0
var observer

func setup(plan,room_surface) -> void:
	layout=plan; surface=room_surface; name="ResidenceInterior"
	geometry=Geometry.new()
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.free()
	door_open=false; door_target=0; surface.door_angle=0
	geometry.shell(self,layout)
	# The actual door is a hinged mesh. Opening it also updates the collision surface.
	door=geometry.door(self,1.2,2.2); door.position=Vector3(-0.6,0.12,layout.depth/2)
	door.set_meta("dynamic_geometry",true)
	var plaque=geometry.label(self,"%s  ·  %dF" % [layout.spec.name,layout.floor_number],Vector3(0,2.48,layout.depth/2+0.22),0.004)
	plaque.rotation.y=PI
	for item in layout.fixtures: geometry.furniture(self,item,layout)
	preload("res://scripts/static_geometry.gd").bake(self)

func toggle_door(player: Vector2) -> bool:
	if not surface.can_close(player): return false
	door_open=not door_open
	door_target=PI/2 if door_open else 0.0
	return true

func _process(dt: float) -> void:
	# Picking, collision and the rendered leaf use the same animated angle.
	var next=move_toward(surface.door_angle,door_target,dt*PI/2/float(layout.rules.door_seconds))
	if observer!=null and surface.door_blocks(observer.position,next): return
	surface.door_angle=next
	door.rotation.y=surface.door_angle

func query(eye: Vector3,dir: Vector3) -> Dictionary:
	var best={}; var distance=float(layout.rules.interaction_distance)
	var transform=surface.door_transform(); var inverse=transform.affine_inverse()
	var hit=AABB(Vector3(0,0,-0.08),Vector3(1.2,2.2,0.16)).intersects_ray(inverse*eye,inverse.basis*dir)
	if hit!=null and eye.distance_to(transform*hit)<distance:
		distance=eye.distance_to(transform*hit); best={"kind":"door","index":-1}
	for item in layout.fixtures:
		var area: AABB=item.box; area.position.y+=0.12
		hit=area.intersects_ray(eye,dir)
		if hit==null or eye.distance_to(hit)>=distance: continue
		distance=eye.distance_to(hit)
		# Non-interactive furniture still occludes an object behind it.
		best={"kind":item.type,"index":int(item.id),"title":item.title}
	return best

func rebuild(plan) -> void:
	layout=plan; _rebuild()
