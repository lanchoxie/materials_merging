extends SceneTree
const Main=preload("res://scripts/main.gd")
var game
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	if "--release-ui-test" not in OS.get_cmdline_user_args(): push_error("Player save isolation flag required"); quit(2); return
	root.size=Vector2i(1440,900); run.call_deferred()
	create_timer(70).timeout.connect(func(): push_error("Player materials UI timeout"); quit(2))
func find_button(node: Node,text: String):
	if node is Button and node.text.begins_with(text): return node
	for child in node.get_children():
		var found=find_button(child,text)
		if found!=null: return found
	return null
func button(text: String) -> void:
	var b=find_button(game.modal,text); check(b!=null,"button exists: "+text)
	if b!=null: b.pressed.emit()
	await process_frame; await process_frame
func run() -> void:
	pass
