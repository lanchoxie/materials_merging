extends Control
## A draft-only authoring surface. Inventory/coins change only on Apply.

signal saved
signal applied
signal dismissed

const UI = preload("res://scripts/ui.gd")
const MAX_ATOMS := 64
const LIMIT := 20.0
var state
var reactor_index := -1
var draft: Dictionary = {}
var original: Dictionary = {}
var history: Array = []
var selected := -1
var element_choice := "C"
var viewport: SubViewport
var viewbox: SubViewportContainer
var scene: Node3D
var specimens: Node3D
var camera: Camera3D
var balls: Array = []
var center := Vector3.ZERO
var yaw := 0.35
var pitch := 0.24
var selected_label: Label
var summary_label: Label
var reference_label: Label
var cost_label: Label
var notice: Label
var name_input: LineEdit
var mode_choice: OptionButton
var atom_list: HFlowContainer
var element_buttons: Dictionary = {}
var pair_a: OptionButton
var pair_b: OptionButton
var bond_order: OptionButton
var bond_label: Label
var periodic_toggle: CheckButton
var repeat_toggle: CheckButton
var cell_inputs: Array = []
var apply_button: Button
var undo_button: Button
var delete_button: Button
var replace_button: Button
var save_button: Button
var updating := false
var repeat_preview := false
var dragging := false
var active_touch := -1
var drag_saved := false
var drag_origin := Vector3.ZERO
var grab_offset := Vector3.ZERO
var pending_confirmation: Callable
var confirmation: ConfirmationDialog

func setup(model, structure: Dictionary, index: int = -1) -> void:
	state = model
	reactor_index = index
	draft = structure.duplicate(true)
	for key in ["atoms", "positions", "bonds"]:
		if not draft.get(key) is Array: draft[key] = []
	if not draft.get("cell") is Array or draft.cell.size() != 3: draft.cell = [6.0, 6.0, 6.0]
	draft.periodic = bool(draft.get("periodic", false))
	draft.mode = str(draft.get("mode", "science"))
	draft.name = str(draft.get("name", "我的原子作品"))
	original = draft.duplicate(true)
	selected = 0 if not draft.atoms.is_empty() else -1
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.make_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color("0a1620")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var heading := UI.label("自由造物", 30)
	heading.position = Vector2(36, 24)
	add_child(heading)
	var subtitle := UI.label("ATOM STUDIO   /   从一个原子，搭出你的宇宙", 13, UI.MUTED)
	subtitle.position = Vector2(38, 67)
	add_child(subtitle)
	name_input = LineEdit.new()
	name_input.position = Vector2(450, 31)
	name_input.size = Vector2(390, 50)
	name_input.placeholder_text = "给作品起个名字"
	name_input.max_length = 48
	name_input.text = draft.name
	name_input.add_theme_stylebox_override("normal", UI.style(UI.INNER, 12))
	name_input.add_theme_stylebox_override("focus", UI.style(UI.INNER, 12, UI.MINT))
	name_input.text_changed.connect(func(value: String): draft.name = value)
	add_child(name_input)
	mode_choice = OptionButton.new()
	mode_choice.position = Vector2(868, 31)
	mode_choice.size = Vector2(264, 50)
	mode_choice.add_item("科学探索 · 参考几何")
	mode_choice.add_item("原子艺术 · 自由雕塑")
	mode_choice.selected = 1 if draft.mode == "art" else 0
	mode_choice.item_selected.connect(_set_mode)
	add_child(mode_choice)
	var close_button := UI.button("返回作品库  ×", _request_close)
	close_button.position = Vector2(1192, 31)
	close_button.size = Vector2(210, 50)
	add_child(close_button)
	_build_stage()
	_build_tools()
	_build_footer()
	confirmation = ConfirmationDialog.new()
	confirmation.title = "自由造物"
	confirmation.ok_button_text = "确认"
	confirmation.cancel_button_text = "继续编辑"
	confirmation.min_size = Vector2i(560, 160)
	confirmation.confirmed.connect(func():
		if pending_confirmation.is_valid(): pending_confirmation.call()
	)
	add_child(confirmation)
	_rebuild(true)

func _build_stage() -> void:
	var panel := UI.box(self, Rect2(34, 108, 858, 624), Color("102c35"))
	var body := UI.column(panel, 9)
	var top := UI.row(body)
	summary_label = UI.label("", 17, UI.MINT)
	summary_label.clip_text = true
	summary_label.tooltip_text = "原子数量与连线数量仅描述作品，不代表稳定性。"
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(summary_label)
	top.add_child(UI.label("拖动原子 · 右键旋转", 13))
	viewbox = SubViewportContainer.new()
	viewbox.stretch = true
	viewbox.custom_minimum_size = Vector2(800, 480)
	viewbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(viewbox)
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 480)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	viewbox.add_child(viewport)
	scene = Node3D.new()
	viewport.add_child(scene)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("102c35")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4ede4")
	environment.ambient_light_energy = 0.75
	world.environment = environment
	scene.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32, -28, 0)
	light.light_energy = 1.5
	scene.add_child(light)
	var glow := OmniLight3D.new()
	glow.position = Vector3(-4, 5, 4)
	glow.light_color = UI.MINT
	glow.light_energy = 1.0
	scene.add_child(glow)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 6.0
	scene.add_child(camera)
	specimens = Node3D.new()
	scene.add_child(specimens)
	viewbox.gui_input.connect(_view_input)
	var controls := UI.row(body, 7)
	for entry in [["← 左转", _orbit.bind(-0.28, 0.0)], ["右转 →", _orbit.bind(0.28, 0.0)], ["俯视", _orbit.bind(0.0, 0.20)], ["仰视", _orbit.bind(0.0, -0.20)], ["放大 +", _zoom.bind(0.82)], ["缩小 −", _zoom.bind(1.22)], ["适应视图", _fit_view]]:
		var button := UI.button(entry[0], entry[1])
		button.custom_minimum_size = Vector2(0, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(button)
	var atoms_panel := UI.box(self, Rect2(34, 745, 858, 100))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	atoms_panel.add_child(scroll)
	atom_list = HFlowContainer.new()
	atom_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	atom_list.add_theme_constant_override("h_separation", 7)
	atom_list.add_theme_constant_override("v_separation", 7)
	scroll.add_child(atom_list)

func _build_tools() -> void:
	var panel := UI.box(self, Rect2(912, 108, 492, 624))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var body := UI.column(scroll, 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reference_label = UI.paragraph("", 13, UI.MUTED)
	body.add_child(reference_label)
	selected_label = UI.label("", 18, UI.MINT)
	selected_label.clip_text = true
	body.add_child(selected_label)
	for axis in range(3):
		var row := UI.row(body, 6)
		var title := UI.label(["X · 左右", "Y · 上下", "Z · 深度"][axis], 14)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		for amount in [-0.1, 0.1]:
			var button := UI.button("− 0.10" if amount < 0 else "+ 0.10", _nudge.bind(axis, amount))
			button.custom_minimum_size = Vector2(108, 46)
			row.add_child(button)
	body.add_child(UI.label("元素盒 · 点击选择，再添加或替换", 15, UI.GOLD))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var symbols: Array = state.elements.keys()
	symbols.sort()
	for symbol in symbols:
		var button := UI.button(str(symbol), _choose_element.bind(str(symbol)))
		button.custom_minimum_size = Vector2(62, 47)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = str(state.elements[symbol].get("name", symbol))
		grid.add_child(button)
		element_buttons[symbol] = button
	if not state.elements.has(element_choice) and not symbols.is_empty(): element_choice = str(symbols[0])
	var actions := UI.row(body, 6)
	actions.add_child(UI.button("＋ 添加原子", _add_atom, true))
	replace_button = UI.button("替换选中", _replace_atom)
	actions.add_child(replace_button)
	delete_button = UI.button("删除选中", _delete_atom)
	actions.add_child(delete_button)
	body.add_child(UI.label("连接工具 · 任意两个原子", 15, UI.GOLD))
	var pair := UI.row(body, 6)
	pair_a = OptionButton.new()
	pair_b = OptionButton.new()
	bond_order = OptionButton.new()
	for selector in [pair_a, pair_b, bond_order]:
		selector.custom_minimum_size = Vector2(0, 46)
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pair.add_child(selector)
	for label_text in ["单键  1", "双键  2", "三键  3"]: bond_order.add_item(label_text)
	pair_a.item_selected.connect(func(_index): _update_bond_text())
	pair_b.item_selected.connect(func(_index): _update_bond_text())
	bond_label = UI.paragraph("", 13)
	body.add_child(bond_label)
	var bonds := UI.row(body)
	bonds.add_child(UI.button("建立 / 修改连接", _set_bond))
	bonds.add_child(UI.button("移除连接", _remove_bond))
	body.add_child(UI.label("晶胞与重复 · 正交教学晶胞", 15, UI.GOLD))
	periodic_toggle = CheckButton.new()
	periodic_toggle.text = "启用周期边界（PBC）"
	periodic_toggle.custom_minimum_size.y = 46
	periodic_toggle.toggled.connect(_periodic_changed)
	body.add_child(periodic_toggle)
	var cell_row := UI.row(body, 6)
	for axis in range(3):
		var column := UI.column(cell_row, 4)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(UI.label(["a / Å", "b / Å", "c / Å"][axis], 13))
		var spin := SpinBox.new()
		spin.min_value = 1.0
		spin.max_value = 20.0
		spin.step = 0.1
		spin.custom_minimum_size = Vector2(130, 46)
		spin.value_changed.connect(_cell_changed.bind(axis))
		column.add_child(spin)
		cell_inputs.append(spin)
	repeat_toggle = CheckButton.new()
	repeat_toggle.text = "显示 2×2×2 重复（预览不耗原子）"
	repeat_toggle.custom_minimum_size.y = 46
	repeat_toggle.toggled.connect(func(value: bool): repeat_preview = value; _render(); _fit_view())
	body.add_child(repeat_toggle)
	body.add_child(UI.paragraph("细线是晶胞边界；重复副本只用于观察。周期几何与创意连线不代表真实化学键能。", 12))
	var recovery := UI.row(body)
	undo_button = UI.button("撤销一步", _undo)
	recovery.add_child(undo_button)
	recovery.add_child(UI.button("恢复打开时的作品", _reset))

func _build_footer() -> void:
	cost_label = UI.paragraph("", 13, UI.GOLD)
	cost_label.max_lines_visible = 3
	cost_label.position = Vector2(919, 745)
	cost_label.size = Vector2(475, 57)
	add_child(cost_label)
	var actions := HBoxContainer.new()
	actions.position = Vector2(914, 809)
	actions.size = Vector2(488, 53)
	add_child(actions)
	save_button = UI.button("保存作品", _save, true)
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(save_button)
	apply_button = UI.button("应用到所选炉", _request_apply)
	apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(apply_button)
	notice = UI.label("草稿自由编辑；保存不消耗元素。只有应用到反应炉时结算。", 13, UI.MUTED)
	notice.position = Vector2(38, 870)
	notice.size = Vector2(1358, 25)
	notice.clip_text = true
	add_child(notice)

func _checkpoint() -> void:
	history.append(draft.duplicate(true))
	if history.size() > 50: history.pop_front()

func _rebuild(fit: bool = false) -> void:
	selected = clampi(selected, -1, draft.atoms.size() - 1)
	if selected < 0 and not draft.atoms.is_empty(): selected = 0
	updating = true
	name_input.text = str(draft.name)
	mode_choice.selected = 1 if draft.mode == "art" else 0
	periodic_toggle.set_pressed_no_signal(bool(draft.periodic))
	repeat_toggle.disabled = not bool(draft.periodic)
	for axis in range(3):
		cell_inputs[axis].set_value_no_signal(float(draft.cell[axis]))
		cell_inputs[axis].editable = bool(draft.periodic)
	var old_a: int = maxi(0, pair_a.selected)
	var old_b: int = maxi(1, pair_b.selected)
	pair_a.clear()
	pair_b.clear()
	UI.clear(atom_list)
	for i in range(draft.atoms.size()):
		var title := "%s %d" % [draft.atoms[i], i + 1]
		pair_a.add_item(title, i)
		pair_b.add_item(title, i)
		var button := UI.button(title, _select.bind(i))
		button.custom_minimum_size = Vector2(78, 46)
		if i == selected: button.add_theme_stylebox_override("normal", UI.style(Color("31574f"), 12, UI.MINT))
		atom_list.add_child(button)
	if not draft.atoms.is_empty():
		pair_a.select(mini(old_a, draft.atoms.size() - 1))
		pair_b.select(mini(old_b, draft.atoms.size() - 1))
	else:
		atom_list.add_child(UI.label("空白画布 · 从右侧元素盒添加第一个原子", 15, UI.MINT))
	updating = false
	_render()
	if fit: _fit_view()
	_update_readout()

func _select(index: int) -> void:
	selected = index
	_rebuild()

func _choose_element(symbol: String) -> void:
	element_choice = symbol
	_update_readout()

func _add_atom() -> void:
	if draft.atoms.size() >= MAX_ATOMS:
		_message("最多 64 个原子；可以先删除一个原子。")
		return
	_checkpoint()
	var point := Vector3.ZERO
	if selected >= 0:
		point = _position(selected) + Vector3(1.35, 0.0, 0.0)
	else:
		point = Vector3(float(draft.atoms.size()) * 1.2, 0.0, 0.0)
	# A fully editable empty canvas is intentional, even before validation.
	draft.atoms.append(element_choice)
	draft.positions.append([clampf(point.x, -LIMIT, LIMIT), clampf(point.y, -LIMIT, LIMIT), clampf(point.z, -LIMIT, LIMIT)])
	draft.baseline_id = ""
	selected = draft.atoms.size() - 1
	_rebuild(true)
	_message("已添加 %s · 草稿尚未消耗库存" % element_choice)

func _replace_atom() -> void:
	if selected < 0 or draft.atoms[selected] == element_choice: return
	_checkpoint()
	draft.atoms[selected] = element_choice
	draft.baseline_id = ""
	_rebuild()

func _delete_atom() -> void:
	if selected < 0: return
	_checkpoint()
	var removed := selected
	draft.atoms.remove_at(removed)
	draft.positions.remove_at(removed)
	var bonds: Array = []
	for bond in draft.bonds:
		var a := int(bond[0])
		var b := int(bond[1])
		if a == removed or b == removed: continue
		bonds.append([a - 1 if a > removed else a, b - 1 if b > removed else b, int(bond[2]) if bond.size() > 2 else 1])
	draft.bonds = bonds
	draft.baseline_id = ""
	selected = mini(removed, draft.atoms.size() - 1)
	_rebuild(true)

func _nudge(axis: int, amount: float) -> void:
	if selected < 0: return
	var old: float = float(draft.positions[selected][axis])
	var value := clampf(old + amount, -LIMIT, LIMIT)
	if is_equal_approx(old, value): return
	_checkpoint()
	draft.positions[selected][axis] = value
	_render()
	_update_readout()

func _set_bond() -> void:
	if pair_a.selected < 0 or pair_b.selected < 0 or pair_a.selected == pair_b.selected:
		_message("请选两个不同的原子。")
		return
	var a := mini(pair_a.selected, pair_b.selected)
	var b := maxi(pair_a.selected, pair_b.selected)
	var order := bond_order.selected + 1
	var index := _bond_index(a, b)
	if index >= 0 and _edge_order(draft.bonds[index]) == order: return
	_checkpoint()
	if index >= 0: draft.bonds[index] = [a, b, order]
	else: draft.bonds.append([a, b, order])
	draft.baseline_id = ""
	_render()
	_update_readout()

func _remove_bond() -> void:
	var index := _bond_index(pair_a.selected, pair_b.selected)
	if index < 0:
		_message("这两个原子之间还没有连接。")
		return
	_checkpoint()
	draft.bonds.remove_at(index)
	draft.baseline_id = ""
	_render()
	_update_readout()

func _bond_index(a: int, b: int) -> int:
	for i in range(draft.bonds.size()):
		var edge: Array = draft.bonds[i]
		if mini(int(edge[0]), int(edge[1])) == mini(a, b) and maxi(int(edge[0]), int(edge[1])) == maxi(a, b): return i
	return -1

func _edge_order(edge: Array) -> int:
	return int(edge[2]) if edge.size() > 2 else 1

func _set_mode(index: int) -> void:
	if updating: return
	_checkpoint()
	draft.mode = "art" if index == 1 else "science"
	_update_readout()

func _periodic_changed(value: bool) -> void:
	if updating: return
	_checkpoint()
	draft.periodic = value
	draft.baseline_id = ""
	_rebuild(true)

func _cell_changed(value: float, axis: int) -> void:
	if updating or is_equal_approx(float(draft.cell[axis]), value): return
	_checkpoint()
	draft.cell[axis] = value
	draft.baseline_id = ""
	_render()
	_update_readout()

func _undo() -> void:
	if history.is_empty(): return
	draft = history.pop_back()
	_rebuild(true)
	_message("已撤销一步。库存与金币未变化。")

func _reset() -> void:
	_checkpoint()
	draft = original.duplicate(true)
	_rebuild(true)
	_message("已恢复打开时的作品；可再撤销。")

func _save() -> void:
	draft.name = name_input.text.strip_edges()
	var result: String = state.save_sandbox_structure(draft.name, draft)
	_message(result)
	if result.begins_with("作品已保存"):
		original = draft.duplicate(true)
		saved.emit()

func _quote() -> Dictionary:
	if reactor_index < 0: return {"ready": false, "message": "先在小岛选中反应炉，再打开作品即可应用。", "fee": 0, "required": {}}
	if not state.has_method("sandbox_reactor_quote"): return {"ready": false, "message": "该反应炉暂不支持应用作品。", "fee": 0, "required": {}}
	return state.sandbox_reactor_quote(reactor_index, draft)

func _request_apply() -> void:
	var quote := _quote()
	if not bool(quote.get("ready", false)):
		_message(str(quote.get("message", "暂时无法应用")))
		return
	pending_confirmation = _apply
	confirmation.dialog_text = "将作品应用到所选反应炉？\n费用：%d 金币，元素按下方报价结算。\n更换组成需博士装炉，旧批次和待收金币保留。" % int(quote.get("fee", 0))
	confirmation.popup_centered()

func _apply() -> void:
	var quote := _quote()
	if not bool(quote.get("ready", false)):
		_message(str(quote.get("message", "暂时无法应用")))
		_update_readout()
		return
	var result = state.apply_sandbox_to_reactor(reactor_index, draft)
	_message(str(result))
	_update_readout()
	applied.emit()

func _request_close() -> void:
	if draft != original:
		pending_confirmation = _close
		confirmation.dialog_text = "还有尚未保存的修改。返回作品库将舍弃本次草稿；库存和金币不会变化。"
		confirmation.popup_centered()
	else: _close()

func _close() -> void:
	dismissed.emit()
	queue_free()

func handle_back() -> bool:
	if confirmation.visible: confirmation.hide()
	else: _request_close()
	return true

func _message(value: String) -> void:
	notice.text = value

func _update_readout() -> void:
	if selected_label == null: return
	summary_label.text = "%s  ·  %d / 64 原子  ·  %d 连接" % [state.sandbox_formula(draft), draft.atoms.size(), draft.bonds.size()]
	selected_label.text = "尚未选择原子" if selected < 0 else "%s #%02d    %.2f, %.2f, %.2f Å" % [draft.atoms[selected], selected + 1, draft.positions[selected][0], draft.positions[selected][1], draft.positions[selected][2]]
	delete_button.disabled = selected < 0
	replace_button.disabled = selected < 0
	undo_button.disabled = history.is_empty()
	save_button.disabled = draft.atoms.is_empty()
	var id := str(draft.get("baseline_id", ""))
	if draft.mode == "art":
		reference_label.text = "原子艺术 · 连接与晶胞都是创作工具。\n创意作品不声称真实稳定性或化学键能。"
	elif not id.is_empty():
		var info: Dictionary = state.baseline_data(id)
		reference_label.text = "配方参考：%s · 当前坐标可自由调节\n%s" % [str(info.get("formula", id)), str(info.get("description", "教学几何参考，不代表真实势能。"))]
	else:
		reference_label.text = "自由探索 · 应用时检查可用参考\n无适用参考的作品保留探索用途；半径与连线不能证明稳定性。"
	for symbol in element_buttons:
		var button: Button = element_buttons[symbol]
		button.add_theme_stylebox_override("normal", UI.style(Color("31574f") if symbol == element_choice else UI.INNER, 10, UI.MINT if symbol == element_choice else UI.LINE))
	_update_bond_text()
	var quote := _quote()
	var needs: Array[String] = []
	for symbol in quote.get("required", {}): needs.append("%s×%d" % [symbol, int(quote.required[symbol])])
	cost_label.text = "%s\n%d 金币 · 元素：%s" % [str(quote.get("message", "应用到反应炉时结算")), int(quote.get("fee", 0)), "无" if needs.is_empty() else " ".join(needs)]
	cost_label.tooltip_text = cost_label.text
	apply_button.disabled = not bool(quote.get("ready", false))
	for i in range(balls.size()):
		var material: StandardMaterial3D = balls[i].material_override
		material.emission_enabled = i == selected
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.55 if i == selected else 0.0

func _update_bond_text() -> void:
	if bond_label == null: return
	var a := pair_a.selected
	var b := pair_b.selected
	if a < 0 or b < 0 or a == b:
		bond_label.text = "选两个不同原子，可建立或修改 1 / 2 / 3 级连接。"
		return
	var index := _bond_index(a, b)
	bond_label.text = "间距 %.3f Å · %s" % [_position(a).distance_to(_position(b)), "尚未连接" if index < 0 else "当前连接级数 %d" % _edge_order(draft.bonds[index])]

func _position(index: int) -> Vector3:
	var p: Array = draft.positions[index]
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _render() -> void:
	UI.clear(specimens)
	balls.clear()
	_render_copy(Vector3.ZERO, true)
	if bool(draft.periodic):
		_draw_cell(Vector3.ZERO)
		if repeat_preview:
			for x in range(2):
				for y in range(2):
					for z in range(2):
						if x == 0 and y == 0 and z == 0: continue
						var offset := Vector3(x * float(draft.cell[0]), y * float(draft.cell[1]), z * float(draft.cell[2]))
						_render_copy(offset, false)
						_draw_cell(offset)

func _render_copy(offset: Vector3, editable_copy: bool) -> void:
	var reference: Dictionary = state.sandbox_reference(draft)
	var contexts: Array = reference.get("atom_contexts",[])
	for i in range(draft.atoms.size()):
		var info: Dictionary = state.elements.get(draft.atoms[i], {})
		var sphere := SphereMesh.new()
		sphere.radius = clampf(float(contexts[i].radius if i<contexts.size() else info.get("radius",0.75)) * 0.33, 0.16, 0.42)
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 24
		sphere.rings = 12
		var ball := MeshInstance3D.new()
		ball.mesh = sphere
		ball.position = _position(i) + offset
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(str(info.get("color", "a5efd1")))
		material.roughness = 0.26
		material.metallic = 0.15
		if not editable_copy: material.albedo_color = material.albedo_color.darkened(0.38)
		if editable_copy and i == selected:
			material.emission_enabled = true
			material.emission = material.albedo_color
			material.emission_energy_multiplier = 0.55
		ball.material_override = material
		specimens.add_child(ball)
		if editable_copy:
			balls.append(ball)
			var label3 := Label3D.new()
			label3.text = "%s %d" % [draft.atoms[i], i + 1]
			label3.font_size = 34
			label3.pixel_size = 0.006
			label3.position.y = sphere.radius + 0.15
			label3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label3.no_depth_test = true
			ball.add_child(label3)
	for bond in draft.bonds:
		var a := int(bond[0])
		var b := int(bond[1])
		if a < 0 or b < 0 or a >= draft.atoms.size() or b >= draft.atoms.size(): continue
		var first := _position(a) + offset
		var second := _position(b) + offset
		var direction := (second - first).normalized()
		var side := direction.cross(Vector3.FORWARD).normalized()
		if side.length_squared() < 0.01: side = Vector3.RIGHT
		var order := int(bond[2]) if bond.size() > 2 else 1
		for line in range(order):
			var shift := side * (float(line) - float(order - 1) / 2.0) * 0.13
			_tube(first + shift, second + shift, 0.032, Color("829ea6") if editable_copy else Color("405e66"))

func _tube(first: Vector3, second: Vector3, radius: float, color: Color) -> void:
	var direction := second - first
	if direction.length_squared() < 0.0001: return
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = direction.length()
	cylinder.radial_segments = 10
	var mesh := MeshInstance3D.new()
	mesh.mesh = cylinder
	mesh.position = (first + second) * 0.5
	mesh.quaternion = Quaternion(Vector3.UP, direction.normalized())
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.45
	mesh.material_override = material
	specimens.add_child(mesh)

func _draw_cell(offset: Vector3) -> void:
	for corner in range(8):
		var point := offset + Vector3(float(draft.cell[0]) if corner & 1 else 0.0, float(draft.cell[1]) if corner & 2 else 0.0, float(draft.cell[2]) if corner & 4 else 0.0)
		for bit in [1, 2, 4]:
			var other: int = corner ^ bit
			if other <= corner: continue
			var end := offset + Vector3(float(draft.cell[0]) if other & 1 else 0.0, float(draft.cell[1]) if other & 2 else 0.0, float(draft.cell[2]) if other & 4 else 0.0)
			_tube(point, end, 0.015, Color("39766c"))

func _fit_view() -> void:
	center = Vector3.ZERO
	var low := Vector3.ZERO
	var high := Vector3.ZERO
	for i in range(draft.atoms.size()):
		var p := _position(i)
		low = p if i == 0 else low.min(p)
		high = p if i == 0 else high.max(p)
	if bool(draft.periodic):
		low = low.min(Vector3.ZERO)
		high = high.max(Vector3(float(draft.cell[0]), float(draft.cell[1]), float(draft.cell[2])) * (2.0 if repeat_preview else 1.0))
	center = (low + high) * 0.5
	camera.size = clampf((high - low).length() * 1.4 + 2.0, 4.5, 110.0)
	_place_camera()

func _place_camera() -> void:
	camera.position = center + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 120.0
	camera.far = 300.0
	camera.look_at(center)

func _orbit(amount: float, elevation: float) -> void:
	yaw += amount
	pitch = clampf(pitch + elevation, -1.3, 1.3)
	_place_camera()

func _zoom(factor: float) -> void:
	camera.size = clampf(camera.size * factor, 1.5, 110.0)

func _viewport_point(point: Vector2) -> Vector2:
	return point * Vector2(viewport.size) / viewbox.size

func _view_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1: return
	if event is InputEventScreenTouch:
		if event.pressed and active_touch < 0:
			active_touch = event.index
			_begin_drag(_viewport_point(event.position), 64.0)
		elif not event.pressed and event.index == active_touch: _end_drag()
		viewbox.accept_event()
	elif event is InputEventScreenDrag:
		if event.index == active_touch and dragging: _drag(_viewport_point(event.position))
		viewbox.accept_event()
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: _zoom(0.9)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _zoom(1.1)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _begin_drag(_viewport_point(event.position), 42.0)
			else: _end_drag()
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT: _orbit(-event.relative.x * 0.008, event.relative.y * 0.008)
		elif dragging and event.button_mask & MOUSE_BUTTON_MASK_LEFT: _drag(_viewport_point(event.position))

func _begin_drag(point: Vector2, radius: float) -> void:
	dragging = false
	drag_saved = false
	var closest := radius
	for i in range(balls.size()):
		var distance := camera.unproject_position(balls[i].position).distance_to(point)
		if distance < closest:
			closest = distance
			selected = i
			dragging = true
	if dragging:
		drag_origin = _position(selected)
		var plane := Plane(camera.global_basis.z, drag_origin)
		var hit = plane.intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
		grab_offset = drag_origin - hit if hit != null else Vector3.ZERO
		_rebuild()

func _drag(point: Vector2) -> void:
	if selected < 0: return
	var plane := Plane(camera.global_basis.z, drag_origin)
	var hit = plane.intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if hit == null: return
	var target: Vector3 = hit + grab_offset
	target = target.clamp(Vector3.ONE * -LIMIT, Vector3.ONE * LIMIT)
	if target.distance_squared_to(_position(selected)) < 0.000001: return
	if not drag_saved:
		_checkpoint()
		drag_saved = true
	draft.positions[selected] = [target.x, target.y, target.z]
	_render()
	_update_readout()

func _end_drag() -> void:
	dragging = false
	active_touch = -1
	drag_saved = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and event.index == active_touch: _end_drag()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed: _end_drag()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _end_drag()
