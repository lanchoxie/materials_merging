extends Control

signal applied
signal dismissed
const UI = preload("res://scripts/ui.gd")
var state
var reactor_index: int = 0
var draft: Dictionary
var points: Array = []
var atom_nodes: Array = []
var viewport: SubViewport
var viewbox: SubViewportContainer
var scene: Node3D
var molecule: Node3D
var bonds_node: Node3D
var camera: Camera3D
var picked: int = 0
var dragging: bool = false
var zoom: float = 5.0
var center: Vector3 = Vector3.ZERO
var selected_label: Label
var position_label: Label
var rate_label: Label
var response_label: Label
var hint_label: Label
var preview_bar: ProgressBar
var atom_buttons: HBoxContainer
var bond_info: Label
var active_touch: int = -1
var grab_offset: Vector3 = Vector3.ZERO
var symbols: Array = []
var heading_label: Label
var context_label: Label
var cost_label: Label
var apply_button: Button
var palette: Control
var replace_group: bool = false
var palette_buttons: Dictionary = {}

func setup(model, index: int) -> void:
	state = model
	reactor_index = index
	draft = state.reactors[index].duplicate(true)
	symbols = state.atom_symbols(draft).duplicate()
	draft.atoms = symbols.duplicate()
	points = draft.positions.duplicate(true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.make_theme()
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.08, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var heading = UI.label("结构工作台", 30)
	heading.position = Vector2(50, 32)
	add_child(heading)
	var sub = UI.label("STRUCTURE STUDIO   /   每个位置，都有新的可能", 13, UI.MUTED)
	sub.position = Vector2(52, 76)
	add_child(sub)
	var close_b = UI.button("返回工坊  ×", _cancel)
	close_b.position = Vector2(1240, 38)
	close_b.size.x = 150
	add_child(close_b)
	_build_view()
	_build_sidebar()
	_render_molecule()
	_update_readout()

func _build_view() -> void:
	var panel = UI.box(self, Rect2(40, 112, 938, 672), Color("102730"))
	viewbox = SubViewportContainer.new()
	viewbox.stretch = true
	viewbox.custom_minimum_size = Vector2(900, 620)
	panel.add_child(viewbox)
	viewport = SubViewport.new()
	viewport.size = Vector2i(900, 620)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewbox.add_child(viewport)
	scene = Node3D.new()
	viewport.add_child(scene)
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("102730")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c6dfed")
	env.ambient_light_energy = 0.8
	environment.environment = env
	scene.add_child(environment)
	var key = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -25, 0)
	key.light_energy = 1.6
	scene.add_child(key)
	var fill = OmniLight3D.new()
	fill.position = Vector3(-3, 1, 3)
	fill.light_color = UI.MINT
	fill.light_energy = 1.0
	scene.add_child(fill)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5
	scene.add_child(camera)
	molecule = Node3D.new()
	scene.add_child(molecule)
	bonds_node = Node3D.new()
	scene.add_child(bonds_node)
	viewbox.gui_input.connect(_on_view_input)
	var tip = UI.label("拖动彩球调整位置 · 按钮旋转 / 缩放 · 右键与滚轮也可用", 14, UI.MUTED)
	tip.position = Vector2(68, 674)
	add_child(tip)
	var controls = HBoxContainer.new()
	controls.position = Vector2(66, 711)
	controls.add_theme_constant_override("separation", 10)
	add_child(controls)
	for entry in [["左转", _orbit.bind(0.28, 0.0)], ["右转", _orbit.bind(-0.28, 0.0)], ["俯视", _orbit.bind(0.0, 0.18)], ["平视", _orbit.bind(0.0, -0.18)], ["放大 +", _zoom_view.bind(0.82)], ["缩小 −", _zoom_view.bind(1.22)]]:
		var button = UI.button(entry[0], entry[1])
		button.custom_minimum_size = Vector2(132, 58)
		controls.add_child(button)
	var atom_scroll = ScrollContainer.new()
	atom_scroll.position = Vector2(42,804)
	atom_scroll.size = Vector2(930,70)
	atom_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(atom_scroll)
	atom_buttons = HBoxContainer.new()
	atom_buttons.add_theme_constant_override("separation", 8)
	atom_scroll.add_child(atom_buttons)
	_build_atom_buttons()

func _build_atom_buttons() -> void:
	UI.clear(atom_buttons)
	for i in range(symbols.size()):
		var b = UI.button("%s %d" % [symbols[i], i+1], func(): picked = i; _update_readout())
		b.custom_minimum_size = Vector2(82, 58)
		atom_buttons.add_child(b)

func _build_sidebar() -> void:
	var panel = UI.box(self, Rect2(1000, 112, 398, 734))
	var outer = UI.column(panel, 12)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var v = UI.column(scroll, 11)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_label = UI.label("",25,UI.MINT)
	v.add_child(heading_label)
	UI.spacer(v, 2)
	selected_label = UI.label("", 20)
	v.add_child(selected_label)
	position_label = UI.label("", 13, UI.MUTED)
	v.add_child(position_label)
	context_label = UI.paragraph("",13,UI.MUTED)
	v.add_child(context_label)
	var swap_button = UI.button("替换这个位点的元素   ⇄",_show_palette,true)
	swap_button.custom_minimum_size.y = 50
	v.add_child(swap_button)
	for axis in range(3):
		var h = UI.row(v)
		var l = UI.label(["X · 左右", "Y · 上下", "Z · 深度"][axis], 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		for direction in [-1, 1]:
			var b = UI.button("− 0.05" if direction < 0 else "+ 0.05", _nudge.bind(axis, direction * 0.05))
			b.custom_minimum_size.y = 50
			h.add_child(b)
	UI.spacer(v, 2)
	v.add_child(UI.label("反应炉的反馈", 16, UI.GOLD))
	response_label = UI.label("", 14, UI.MINT)
	v.add_child(response_label)
	rate_label = UI.label("", 30)
	v.add_child(rate_label)
	preview_bar = ProgressBar.new()
	preview_bar.custom_minimum_size.y = 8
	preview_bar.show_percentage = false
	v.add_child(preview_bar)
	bond_info = UI.paragraph("", 13)
	v.add_child(bond_info)
	var actions = UI.row(v)
	actions.add_child(UI.button("轻微扰动", _jitter))
	actions.add_child(UI.button("撤销全部", _restore))
	hint_label = UI.paragraph("能量函数尚未解锁。先观察产率，\n寻找更合适的原子间距。", 13, UI.MUTED)
	v.add_child(hint_label)
	var fee = state.edit_cost(state.reactors[reactor_index])
	cost_label = UI.paragraph("",14,UI.GOLD)
	outer.add_child(cost_label)
	apply_button = UI.button("应用结构   ·   %d 金币" % fee, _apply, true)
	apply_button.custom_minimum_size.y = 58
	outer.add_child(apply_button)
	outer.add_child(UI.paragraph("更换元素由博士装炉，坐标调整即时生效。\n旧批次保留；几何评分不等同真实能量。", 12))

func _element(symbol: String) -> Dictionary:
	return state.elements.get(symbol, {"color": "a5efd1", "covalent_radius": 0.65})

func _render_molecule() -> void:
	UI.clear(molecule)
	atom_nodes.clear()
	var info_template: Dictionary = state.structure_data(draft)
	center = Vector3.ZERO
	for p in points:
		center += Vector3(p[0], p[1], p[2])
	center /= max(1, points.size())
	var extent: float = 1.4
	for i in range(points.size()):
		var info = _element(symbols[i])
		var pos = Vector3(points[i][0], points[i][1], points[i][2])
		extent = max(extent, pos.distance_to(center))
		var mesh = SphereMesh.new()
		var radius: float = float(info_template.atom_contexts[i].radius)
		mesh.radius = clampf(radius * 0.31, 0.14, 0.44)
		mesh.height = mesh.radius * 2
		mesh.radial_segments = 40
		mesh.rings = 24
		var ball = MeshInstance3D.new()
		ball.mesh = mesh
		ball.position = pos
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(info.get("color", "a5efd1"))
		mat.metallic = 0.15
		mat.roughness = 0.24
		ball.material_override = mat
		molecule.add_child(ball)
		var label3 = Label3D.new()
		label3.text = symbols[i]
		label3.font_size = 42
		label3.pixel_size = 0.006
		label3.position.y = mesh.radius + 0.19
		label3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label3.no_depth_test = true
		ball.add_child(label3)
		atom_nodes.append(ball)
	zoom = max(4.8, extent * 2.7)
	camera.size = zoom
	camera.position = center + (Vector3(8,5,11) if info_template.has("cell") else Vector3(0.1,0.55,8))
	camera.look_at(center)
	_update_bonds()

func _update_bonds() -> void:
	UI.clear(bonds_node)
	var pairs: Array = state.structure_data(draft).get("bonds", [])
	for bond in pairs:
		var a: int = int(bond.get("a", 0)) if bond is Dictionary else int(bond[0])
		var b: int = int(bond.get("b", 1)) if bond is Dictionary else int(bond[1])
		if a >= points.size() or b >= points.size():
			continue
		var start = Vector3(points[a][0], points[a][1], points[a][2])
		var end = Vector3(points[b][0], points[b][1], points[b][2])
		var direction = end - start
		if direction.length() < 0.01:
			continue
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.043
		cyl.bottom_radius = 0.043
		cyl.height = direction.length()
		var mesh = MeshInstance3D.new()
		mesh.mesh = cyl
		mesh.position = (start+end)/2
		mesh.quaternion = Quaternion(Vector3.UP, direction.normalized())
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color("83999a")
		mat.metallic = 0.45
		mesh.material_override = mat
		bonds_node.add_child(mesh)
	# Cell edges are a geometric guide, distinct from Pb-Br connections.
	if state.templates[draft.template].has("cell"):
		for i in range(8):
			for bit in [1,2,4]:
				var j: int = i ^ bit
				if j <= i:
					continue
				var start = Vector3(points[i][0],points[i][1],points[i][2])
				var end = Vector3(points[j][0],points[j][1],points[j][2])
				var direction = end-start
				if direction.length() < 0.01:
					continue
				var cyl = CylinderMesh.new()
				cyl.top_radius = 0.014
				cyl.bottom_radius = 0.014
				cyl.height = direction.length()
				var mesh = MeshInstance3D.new()
				mesh.mesh = cyl
				mesh.position = (start+end)/2
				mesh.quaternion = Quaternion(Vector3.UP,direction.normalized())
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color("568477")
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.material_override = mat
				bonds_node.add_child(mesh)

func _on_view_input(event: InputEvent) -> void:
	# Handle native touch once; Buttons elsewhere still use Godot's mouse emulation.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		return
	if event is InputEventScreenTouch:
		if event.pressed and active_touch < 0:
			active_touch = event.index
			_begin_drag(_viewport_position(event.position), 74.0)
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
			dragging = false
		viewbox.accept_event()
		return
	if event is InputEventScreenDrag:
		if event.index == active_touch and dragging:
			_drag_atom(_viewport_position(event.position))
		viewbox.accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_view(0.90)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_view(1.10)
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = false
			if event.pressed:
				_begin_drag(_viewport_position(event.position), 50.0)
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_orbit(-event.relative.x * 0.008, 0.0)
		elif dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_drag_atom(_viewport_position(event.position))

func _viewport_position(local_position: Vector2) -> Vector2:
	return local_position * Vector2(viewport.size) / viewbox.size

func _input(event: InputEvent) -> void:
	# Releasing beyond the work surface must never leave an atom captured.
	if event is InputEventScreenTouch and not event.pressed and event.index == active_touch:
		active_touch = -1
		dragging = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false

func _begin_drag(screen_position: Vector2, pick_radius: float) -> void:
	dragging = false
	var distance = pick_radius
	for i in range(atom_nodes.size()):
		var screen = camera.unproject_position(atom_nodes[i].position)
		var d = screen.distance_to(screen_position)
		if d < distance:
			distance = d
			picked = i
			dragging = true
	if dragging:
		var old = Vector3(points[picked][0], points[picked][1], points[picked][2])
		var plane = Plane(camera.global_basis.z, old)
		var hit = plane.intersects_ray(camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
		grab_offset = old - hit if hit != null else Vector3.ZERO
	_update_readout()

func _drag_atom(screen_position: Vector2) -> void:
	var old = Vector3(points[picked][0], points[picked][1], points[picked][2])
	var plane = Plane(camera.global_basis.z, old)
	var hit = plane.intersects_ray(camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))
	if hit != null:
		hit += grab_offset
		points[picked] = [clampf(hit.x,-10,10), clampf(hit.y,-10,10), clampf(hit.z,-10,10)]
		_position_changed()

func _orbit(yaw: float, pitch: float) -> void:
	var offset = camera.position - center
	var radius = offset.length()
	var angle = atan2(offset.x, offset.z) + yaw
	var elevation = clampf(asin(offset.y / radius) + pitch, -1.2, 1.2)
	camera.position = center + Vector3(sin(angle) * cos(elevation), sin(elevation), cos(angle) * cos(elevation)) * radius
	camera.look_at(center)

func _zoom_view(factor: float) -> void:
	camera.size = clampf(camera.size * factor, 2.0, 18.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		active_touch = -1
		dragging = false

func _nudge(axis: int, amount: float) -> void:
	points[picked][axis] = clampf(points[picked][axis] + amount, -10, 10)
	_position_changed()

func _position_changed() -> void:
	draft.positions = points.duplicate(true)
	for i in range(atom_nodes.size()):
		atom_nodes[i].position = Vector3(points[i][0], points[i][1], points[i][2])
	_update_bonds()
	_update_readout()

func _update_readout() -> void:
	if selected_label == null:
		return
	var info: Dictionary = state.structure_data(draft)
	heading_label.text = "%s   ·   Lv.%d" % [info.formula,draft.level]
	selected_label.text = "正在调整  %s  #%02d" % [symbols[picked], picked+1]
	position_label.text = "坐标  %.2f, %.2f, %.2f Å" % points[picked]
	var context: Dictionary = info.atom_contexts[picked]
	context_label.text = "%.2f Å · %s" % [context.radius,context.radius_type]
	if context.oxidation_state != null:
		context_label.text += "\n价态 %s · 配位数 %s" % [str(context.oxidation_state),str(context.coordination)]
	var q: float = state.quality(draft)
	rate_label.text = "%.2f  金币 / 秒" % state.income(draft)
	preview_bar.value = q * 100.0
	response_label.text = "几何匹配  %d%%   ·   %s" % [roundi(q*100), "平稳运转" if q > 0.8 else "继续探索"] if info.known else "探索样品 · 科学匹配度未知"
	bond_info.text = "彩球大小参考原子半径；圆柱表示\n模板中的连接关系，可旋转检查深度。"
	if info.has("cell"):
		bond_info.text = "细线为理想晶胞边界，粗线为配位示意。\n半径构造的教学晶胞，非真实基态。"
	if not info.known:
		bond_info.text = "没有适用参考；连线沿用原模板作编辑辅助。\n仅有0.15金币/秒探索收益，不产生可售产物。"
	var quote: Dictionary = state.edit_quote(reactor_index,points,symbols)
	var needs: Array[String] = []
	for symbol in quote.required:
		needs.append("%s × %d（有%d）" % [symbol,quote.required[symbol],state.element_inventory.get(symbol,0)])
	cost_label.text = "编辑费 %d 金币\n元素：%s" % [quote.fee,"不消耗" if needs.is_empty() else "、".join(needs)]
	apply_button.disabled = not quote.ready
	apply_button.text = "应用本次修改   ·   %d 金币" % quote.fee
	hint_label.text = quote.message
	if info.known:
		hint_label.text += "\n参考：%s。替换保留坐标，可继续调整距离与角度。" % info.formula
	for i in range(atom_nodes.size()):
		var mat: StandardMaterial3D = atom_nodes[i].material_override
		mat.emission_enabled = i == picked
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 0.35 if i == picked else 0.0

func _jitter() -> void:
	for i in range(points.size()):
		for axis in range(3):
			points[i][axis] += randf_range(-0.16, 0.16)
	_position_changed()

func _restore() -> void:
	draft = state.reactors[reactor_index].duplicate(true)
	symbols = state.atom_symbols(draft).duplicate()
	draft.atoms = symbols.duplicate()
	points = state.reactors[reactor_index].positions.duplicate(true)
	_build_atom_buttons()
	_render_molecule()
	_update_readout()

func _apply() -> void:
	var before: float = state.coins
	var result = state.apply_structure_edit(reactor_index, points, symbols)
	if before == state.coins:
		hint_label.text = str(result)
	else:
		applied.emit()
		queue_free()

func _cancel() -> void:
	dismissed.emit()
	queue_free()

func _close_palette() -> void:
	if is_instance_valid(palette): palette.queue_free()
	palette = null
	palette_buttons.clear()

func handle_back() -> bool:
	if is_instance_valid(palette):
		_close_palette()
		return true
	return false

func _show_palette() -> void:
	_close_palette()
	replace_group = false
	palette = Control.new()
	palette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(palette)
	var dim = ColorRect.new()
	dim.color = Color(0.01,0.03,0.05,0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palette.add_child(dim)
	var panel = UI.box(palette,Rect2(235,155,970,590))
	var body = UI.column(panel,14)
	var top = UI.row(body)
	var title = UI.label("给 %s #%d 换一种可能" % [symbols[picked],picked+1],27,UI.MINT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UI.button("返回",_close_palette))
	body.add_child(UI.paragraph("选择后只更新预览。应用时才扣除库存和一次编辑费，拆下的元素不返还。",16))
	var group = CheckButton.new()
	group.text = "整组替换当前所有 %s 位点（适合晶体中的卤素位点）" % symbols[picked]
	group.custom_minimum_size.y = 48
	group.toggled.connect(func(enabled:bool): replace_group = enabled)
	body.add_child(group)
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	body.add_child(grid)
	for symbol in state.elements:
		var element: Dictionary = state.elements[symbol]
		var b = UI.button("%s  %s\n仓库 %d 份" % [symbol,element.name,state.element_inventory.get(symbol,0)],_replace_element.bind(symbol))
		b.add_theme_color_override("font_color",Color(element.color))
		b.add_theme_font_size_override("font_size",20)
		b.custom_minimum_size = Vector2(225,118)
		grid.add_child(b)
		palette_buttons[symbol] = b
	body.add_child(UI.paragraph("试试 O→S 得到H₂S；H₂中的一个H→Cl得到HCl；CsPbBr₃的全部Br→Cl得到教学CsPbCl₃。其他组合可能暂时无法识别。",15,UI.LILAC))

func _replace_element(symbol: String) -> void:
	var old_symbol: String = symbols[picked]
	if replace_group:
		for i in range(symbols.size()):
			if symbols[i] == old_symbol: symbols[i] = symbol
	else:
		symbols[picked] = symbol
	draft.atoms = symbols.duplicate()
	draft.positions = points.duplicate(true)
	_close_palette()
	_build_atom_buttons()
	_render_molecule()
	_update_readout()
