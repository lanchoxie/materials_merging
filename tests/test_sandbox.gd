extends SceneTree

const State = preload("res://scripts/lab_state.gd")
var checks := 0
var failures: Array = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var state := State.new()
	var required := ["hydrogen", "oxygen", "nitrogen", "carbon_dioxide", "methane", "ammonia", "water", "hydrogen_fluoride", "lithium_fluoride", "sodium_chloride"]
	for id in required:
		check(id in state.baseline_ids(), "baseline exists: " + id)
		var sample := state.sandbox_from_baseline(id)
		check(state.sandbox_validate(sample), "baseline validates: " + id)
		check(state.sandbox_formula(sample) == str(state.baseline_data(id).formula), "formula: " + id)

	var work := state.sandbox_from_baseline("water", "我的水滴")
	check(work.atoms.size() == 3 and work.bonds.size() == 2, "water starts with atoms and bonds")
	var extra := state.sandbox_add_atom(work, "H", [0.0, -0.95, 0.0])
	check(extra == 3 and work.atoms.size() == 4, "add atom appends a valid site")
	check(state.sandbox_toggle_bond(work, 0, extra, 1), "add bond to appended atom")
	check(work.bonds.size() == 3, "bond count increments")
	check(state.sandbox_toggle_bond(work, 0, extra, 1), "toggle existing bond removes it")
	check(work.bonds.size() == 2, "bond count decrements")
	check(state.sandbox_set_position(work, 1, [1.1, 0, 0]), "move atom within bounds")
	check(not state.sandbox_set_position(work, 1, [999, 0, 0]), "reject out-of-bounds position")
	check(state.sandbox_remove_atom(work, extra), "remove appended atom")
	check(work.atoms.size() == 3 and work.bonds.size() == 2, "remove atom reindexes and restores topology")
	check(state.sandbox_formula(work) == "H₂O", "formula uses friendly subscripts")
	check(state.sandbox_complexity(work) > 0.0, "complexity is positive")

	var invalid := state.sandbox_from_baseline("hydrogen")
	invalid.bonds.append([0, 0, 1])
	check(not state.sandbox_validate(invalid), "self bond rejected")
	var before := state.sandbox_from_baseline("hydrogen")
	check(state.sandbox_add_atom(before, "Unobtainium", [0, 0, 0]) == -1, "unknown element rejected")

	var save_name := "test_sandbox_roundtrip"
	var save_result := state.save_sandbox_structure(save_name, work)
	check(save_result.begins_with("作品已保存"), "named work saves")
	var loaded := state.load_sandbox_structure(save_name)
	check(not loaded.is_empty() and loaded.name == save_name and loaded.atoms == work.atoms, "named work loads")
	check(loaded.bonds == work.bonds and preload("res://tests/fixtures_v09.gd").same(loaded.positions, work.positions), "named work round trips topology and coordinates within JSON precision")
	check(state.list_sandbox_structures().size() >= 1, "saved work appears in library")
	check(state.delete_sandbox_structure(save_name), "named work deletes")
	check(state.load_sandbox_structure(save_name).is_empty(), "deleted work is unavailable")
	if failures.is_empty():
		print("PASS: ", checks, " sandbox checks (baselines, atom editing, topology, formula, named saves)")
		quit(0)
	else:
		print("FAIL: ", failures.size(), " / ", checks)
		quit(1)
