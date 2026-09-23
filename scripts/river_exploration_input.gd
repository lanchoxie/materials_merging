extends Control
## One owner per touch. Releases and focus loss clear movement even outside the map.
signal terrain_clicked(at: Vector2)
signal zoomed(amount: float)
signal journey_requested
signal collect_requested
signal build_requested
signal primary_requested
signal slot_requested(index: int)
signal slot_cycled(direction: int)
var view
var walking=false
var keys={}
var move_touch=-1
var look_touch=-1
var stick_origin=Vector2.ZERO
var stick=Vector2.ZERO
var mouse_look=false
var mouse_stick=false
var primary_down=false
var primary_started=0
var primary_motion=0.0

func _ready() -> void:
	focus_mode=Control.FOCUS_ALL; mouse_filter=Control.MOUSE_FILTER_STOP
	gui_input.connect(_map_input)
	focus_exited.connect(clear_input)

func set_walking(enabled: bool) -> void:
	walking=enabled; clear_input()
	if enabled: grab_focus()
	queue_redraw()

func clear_input() -> void:
	keys.clear(); move_touch=-1; look_touch=-1; stick=Vector2.ZERO; mouse_look=false; mouse_stick=false
	primary_down=false
	if view!=null: view.walker.stop()
	queue_redraw()

func joystick_center() -> Vector2:
	return Vector2(96,size.y-95)

func _map_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		if not walking: terrain_clicked.emit(event.position); accept_event(); return
		grab_focus()
		if event.position.x<size.x*0.4 and event.position.distance_to(joystick_center())<115 and move_touch<0:
			move_touch=event.index; stick_origin=joystick_center(); _stick(event.position)
		elif look_touch<0: look_touch=event.index
		accept_event()
	elif event is InputEventMouseButton:
		if event.device==-1 and (move_touch>=0 or look_touch>=0): return
		if not walking and event.pressed:
			if event.button_index==MOUSE_BUTTON_WHEEL_UP: zoomed.emit(-0.1)
			elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoomed.emit(0.1)
			elif event.button_index==MOUSE_BUTTON_LEFT: terrain_clicked.emit(event.position)
		elif walking and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			grab_focus()
			mouse_stick=event.button_index==MOUSE_BUTTON_LEFT and event.position.distance_to(joystick_center())<90
			mouse_look=not mouse_stick
			primary_down=event.button_index==MOUSE_BUTTON_LEFT and not mouse_stick and event.device>=0
			primary_started=Time.get_ticks_msec(); primary_motion=0.0
			if mouse_stick: stick_origin=joystick_center(); _stick(event.position)
		elif walking and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			slot_cycled.emit(-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1)
		accept_event()

func _input(event: InputEvent) -> void:
	if not walking: return
	# Root-viewport positions are converted back to this control's canvas space.
	if event is InputEventScreenTouch and not event.pressed:
		if event.index==move_touch: move_touch=-1; stick=Vector2.ZERO
		if event.index==look_touch: look_touch=-1
	elif event is InputEventScreenDrag:
		if event.index==move_touch:
			_stick(get_global_transform_with_canvas().affine_inverse()*event.position); get_viewport().set_input_as_handled()
		elif event.index==look_touch:
			view.walker.look(_local_delta(event.relative),float(view.terrain.rules.touch_sensitivity)); get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var local=get_global_transform_with_canvas().affine_inverse()*event.position
		var tap=primary_down and event.button_index==MOUSE_BUTTON_LEFT and event.device>=0
		tap=tap and primary_motion<=float(view.terrain.rules.click_slop) and Time.get_ticks_msec()-primary_started<=int(view.terrain.rules.click_hold_ms)
		tap=tap and Rect2(Vector2.ZERO,size).has_point(local) and get_viewport().gui_get_hovered_control()==self
		primary_down=false
		mouse_look=false; mouse_stick=false
		if move_touch<0: stick=Vector2.ZERO
		if tap: primary_requested.emit()
	elif event is InputEventMouseMotion and (mouse_look or mouse_stick):
		primary_motion+=_local_delta(event.relative).length()
		if mouse_stick: _stick(get_global_transform_with_canvas().affine_inverse()*event.position)
		else: view.walker.look(_local_delta(event.relative),float(view.terrain.rules.mouse_sensitivity))
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (has_focus() or not event.pressed):
		var code=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if event.pressed and not event.echo and code>=KEY_1 and code<=KEY_9:
			slot_requested.emit(code-KEY_1); get_viewport().set_input_as_handled()
		if event.pressed and not event.echo and code in [KEY_M,KEY_E,KEY_SPACE,KEY_B,KEY_TAB]:
			if code==KEY_M: journey_requested.emit()
			elif code==KEY_E: collect_requested.emit()
			elif code in [KEY_B,KEY_TAB]: build_requested.emit()
			else: view.walker.jump()
			get_viewport().set_input_as_handled()
		if code in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_LEFT,KEY_DOWN,KEY_RIGHT,KEY_SHIFT]:
			if event.pressed: keys[code]=true
			else: keys.erase(code)
			get_viewport().set_input_as_handled()
	_refresh_movement()

func _stick(at: Vector2) -> void:
	stick=((at-stick_origin)/float(view.terrain.rules.joystick_radius)).limit_length(1)
	if stick.length()<0.12: stick=Vector2.ZERO
	_refresh_movement()
	queue_redraw()

func _local_delta(delta: Vector2) -> Vector2:
	var inverse=get_global_transform_with_canvas().affine_inverse()
	return inverse*delta-inverse*Vector2.ZERO

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT: clear_input()

func _process(_dt: float) -> void:
	if walking: queue_redraw()

func _refresh_movement() -> void:
	if not walking or view==null: return
	var axis=Vector2(int(keys.has(KEY_D) or keys.has(KEY_RIGHT))-int(keys.has(KEY_A) or keys.has(KEY_LEFT)),int(keys.has(KEY_S) or keys.has(KEY_DOWN))-int(keys.has(KEY_W) or keys.has(KEY_UP)))
	view.walker.movement=(axis+stick).limit_length(1)
	view.walker.running=keys.has(KEY_SHIFT)

func _draw() -> void:
	if not walking or view==null: return
	var mint=Color("a5efd1"); var center=joystick_center()
	draw_circle(center,62,Color(0.04,0.12,0.14,0.64))
	draw_arc(center,62,0,TAU,48,Color(mint,0.55),2,true)
	draw_circle(center+stick*48,23,Color(mint,0.65))
	var aim=size*0.5
	draw_line(aim-Vector2(5,0),aim+Vector2(5,0),Color(1,1,1,0.65),1)
	draw_line(aim-Vector2(0,5),aim+Vector2(0,5),Color(1,1,1,0.65),1)
	# Local compass map is drawn from the same terrain and player coordinates.
	var map_center=Vector2(size.x-92,size.y-94); var scale=2.1
	draw_circle(map_center,68,Color(0.04,0.12,0.14,0.8))
	draw_circle(map_center,63,Color("678366"))
	var player=view.walker.position
	for i in range(-27,28):
		var z=player.y+i; var relative=Vector2(view.terrain.river_x(z),z)-player
		if relative.length()>27: continue
		var p=map_center+relative*scale
		draw_line(p,p+Vector2(0,scale+1),Color("78bbca"),7)
	for c in view.CENTERS.values():
		var relative=Vector2(c.x,c.z)-player
		if relative.length()<29: draw_circle(map_center+relative*scale,2.5,Color("ffe0a3"))
	var pos=map_center
	draw_circle(pos,4,mint)
	draw_line(pos,pos+Vector2(-sin(view.walker.yaw),-cos(view.walker.yaw))*12,mint,2,true)
