extends SceneTree
const Main=preload("res://scripts/main.gd")
const UI=preload("res://scripts/ui.gd")
var game
var checks=0
var failures=[]
var clicks=0
func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): push_error("Use -- --release-ui-test to protect player saves"); quit(2); return
	# Enable the engine's desktop touchscreen hint; Android provides it natively.
	Input.emulate_touch_from_mouse=true
	root.size=Vector2i(1440,900); run.call_deferred()
	create_timer(45).timeout.connect(func(): push_error("Touch scrolling timeout"); quit(2))
func scrolls(n: Node) -> Array:
	var result=[]
	if n is ScrollContainer: result.append(n)
	for child in n.get_children(): result+=scrolls(child)
	return result
func button(n: Node,area: Rect2):
	if n is Button and not n.disabled and area.encloses(n.get_global_rect()): return n
	for child in n.get_children():
		var found=button(child,area)
		if found!=null: return found
	return null
func swipe(at: Vector2,delta: Vector2) -> void:
	await game._test_touch(at,true)
	for i in range(1,7):
		var e=InputEventScreenDrag.new(); e.index=0; e.position=at+delta*i/6.0; e.relative=delta/6.0; Input.parse_input_event(e); await process_frame
	await game._test_touch(at+delta,false); await process_frame
func run() -> void:
	game=Main.new(); root.add_child(game); game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var s=game.state; s.coins=10000
	game._show_toolbox(); game.modal._tab("elements"); await process_frame; await process_frame
	var scroll=game.modal.scroll; var b=button(scroll,scroll.get_global_rect()); var coins=s.coins
	check(b!=null,"element list has a visible purchase button")
	await swipe(b.get_global_rect().get_center(),Vector2(0,-150))
	check(scroll.scroll_vertical>80,"finger starting on purchase button scrolls element list")
	check(s.coins==coins,"purchase-button swipe does not spend money")
	# Separate the reverse gesture from the previous flick inertia; judge displacement.
	await create_timer(.8).timeout; scroll.scroll_vertical=200; await process_frame; await process_frame
	var downward_start=scroll.scroll_vertical
	await swipe(scroll.get_global_rect().get_center(),Vector2(0,110))
	check(scroll.scroll_vertical<downward_start-60,"finger swipe down moves content back")
	game._close_modal(); s.campus.setup(4,0); game._show_campus("people"); await process_frame; await process_frame
	scroll=game.modal.scroll
	await swipe(scroll.global_position+Vector2(180,320),Vector2(0,-140))
	check(scroll.scroll_vertical>40,"resident cards scroll by dragging card content")
	game._close_modal(); game._show_factory(); var p=game.modal
	s.planet.command(s,"join"); p._open_materials(); p.material_details=true; p._redraw(); await process_frame; await process_frame
	scroll=scrolls(p)[0]; coins=s.coins; var reports=s.planet.reports.duplicate(true)
	await swipe(scroll.global_position+Vector2(140,350),Vector2(0,-170))
	check(scroll.scroll_vertical>80,"independent factory sidebar scrolls by content swipe")
	check(s.coins==coins and s.planet.reports==reports,"factory swipe neither purchases nor records a calculation")
	game._close_modal()
	var body=game._dialog("滚动回归","手指起点覆盖嵌套卡片、文字和按钮")
	for i in range(12):
		var card=PanelContainer.new(); body.add_child(card); var column=UI.column(card)
		column.add_child(UI.paragraph("卡片文字覆盖区域，用来检查手指滑动是否传到列表。",18))
		column.add_child(UI.button("测试点击",func(): clicks+=1))
	await process_frame; await process_frame; scroll=scrolls(game.modal)[0]
	var row=body.get_child(1)
	await swipe(row.get_global_rect().position+Vector2(30,25),Vector2(0,-100))
	check(scroll.scroll_vertical>60,"nested panel and paragraph forward finger motion")
	await create_timer(0.8).timeout; scroll.scroll_vertical=0; await process_frame; await process_frame
	b=button(scroll,scroll.get_global_rect()); await swipe(b.get_global_rect().get_center(),Vector2(0,-100))
	check(scroll.scroll_vertical>60 and clicks==0,"swipe starting on ordinary button cancels activation")
	await create_timer(0.8).timeout; scroll.scroll_vertical=0; await process_frame; await process_frame
	b=button(scroll,scroll.get_global_rect()); var at=b.get_global_rect().get_center()
	await game._test_touch(at,true); await game._test_touch(at,false)
	check(clicks==1,"stationary tap still activates once")
	var old=scroll.scroll_vertical; var wheel=InputEventMouseButton.new(); wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN; wheel.pressed=true; wheel.position=scroll.get_global_rect().get_center(); Input.parse_input_event(wheel); await process_frame
	check(scroll.scroll_vertical>old,"desktop mouse wheel still works")
	game._close_modal()
	body=game._dialog("横向滑动","原子选项带使用相同按钮")
	scroll=scrolls(game.modal)[0]; scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	var line=UI.row(body)
	for i in range(15):
		b=UI.button(str(i),func(): clicks+=1); b.custom_minimum_size=Vector2(100,70); line.add_child(b)
	await process_frame; await process_frame
	await swipe(line.get_child(2).get_global_rect().get_center(),Vector2(-150,0))
	check(scroll.scroll_horizontal>80 and clicks==1,"horizontal option strip swipes without selecting atoms")
	game._close_modal(); game._show_collection(); await process_frame; await process_frame
	scroll=scrolls(game.modal)[0]
	await swipe(scroll.get_global_rect().get_center(),Vector2(0,-150))
	check(scroll.scroll_vertical>80,"collection cards support direct touch scrolling")
	game._close_modal(); game._show_sandbox(); await process_frame; await process_frame
	scroll=scrolls(game.modal)[0]
	await swipe(scroll.global_position+Vector2(190,300),Vector2(0,-150))
	check(scroll.scroll_vertical>80,"structure library grid forwards finger movement")
	game._close_modal(); game._open_sandbox_editor(s.sandbox_from_baseline("water","滚动样品")); await process_frame; await process_frame
	var editor=game.modal; var original=editor.draft.duplicate(true)
	for candidate in scrolls(editor):
		if candidate.global_position.x>900: scroll=candidate
	b=button(scroll,scroll.get_global_rect())
	await swipe(b.get_global_rect().get_center(),Vector2(0,-150))
	check(scroll.scroll_vertical>80 and editor.draft==original,"atom sidebar swipes without nudging or replacing atoms")
	game._close_modal(); s.close_science(); print("TOUCH SCROLL: ",checks," checks, ",failures.size()," failures"); quit(0 if failures.is_empty() else 1)
