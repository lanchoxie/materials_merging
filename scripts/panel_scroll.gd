extends RefCounted
## Restore after container layout, and cancel stale restores when tabs change.
var revision=0
var pending=false
var position=Vector2i.ZERO

func refresh(scroll: ScrollContainer, reset: bool=false) -> void:
	if reset: position=Vector2i.ZERO
	elif not pending: position=Vector2i(scroll.scroll_horizontal,scroll.scroll_vertical)
	revision+=1; pending=true
	_restore(scroll,revision)

func _restore(scroll: ScrollContainer, ticket: int) -> void:
	if not is_instance_valid(scroll) or not scroll.is_inside_tree(): return
	var tree=scroll.get_tree()
	await tree.process_frame
	await tree.process_frame
	if not is_instance_valid(scroll) or ticket!=revision: return
	scroll.scroll_horizontal=position.x; scroll.scroll_vertical=position.y
	pending=false
