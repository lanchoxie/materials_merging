extends SceneTree
const State = preload("res://scripts/lab_state.gd")
func _initialize() -> void:
	var state = State.new()
	var failures := 0
	for id in state.templates:
		var sample = state._new_reactor(3, id, 0)
		if state.quality(sample) >= 0.85 or state.quality(sample) < 0.25:
			failures += 1; push_error("Exported initial geometry out of range: " + id)
		var work = state.sandbox_from_baseline(id)
		if not state.sandbox_validate(work) or work.positions == state.baseline_data(id).positions:
			failures += 1; push_error("Exported workshop still gives reference geometry: " + id)
	state.close_science()
	print("STRUCTURE START PACKAGE: 28 checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
