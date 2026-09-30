extends RefCounted
## Scripted input for self-tests. Events are written in canvas (1440×900 design) coordinates;
## the root window maps real window coordinates back through its stretch transform, so we map
## forward first. Headless runs have a 0×0 window (64×64 root, ~0.044 scale), which made every
## positional test event miss its target. With a real 1440×900 window the transform is identity.

static func to_window(event: InputEvent) -> InputEvent:
	var tree = Engine.get_main_loop()
	if not tree is SceneTree or tree.root == null: return event
	var t: Transform2D = tree.root.get_final_transform()
	if t == Transform2D.IDENTITY: return event
	var e: InputEvent = event.duplicate()
	if e is InputEventMouse:
		e.position = t * e.position
		e.global_position = t * e.global_position
	if e is InputEventMouseMotion:
		e.relative = t.basis_xform(e.relative); e.velocity = t.basis_xform(e.velocity)
	if e is InputEventScreenTouch:
		e.position = t * e.position
	if e is InputEventScreenDrag:
		e.position = t * e.position
		e.relative = t.basis_xform(e.relative); e.velocity = t.basis_xform(e.velocity)
	return e

static func send(event: InputEvent) -> void:
	Input.parse_input_event(to_window(event))
