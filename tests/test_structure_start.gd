extends SceneTree

const State = preload("res://scripts/lab_state.gd")
const Fixtures = preload("res://tests/fixtures_v09.gd")
var checks := 0
var failures: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	var s = State.new()
	var references = s.templates.duplicate(true)
	var baselines = s.sandbox.baselines.duplicate(true)
	var lowest := 1.0
	var highest := 0.0
	for id in s.templates:
		var scores_ok := true
		var coordinates_ok := true
		for variant in range(32):
			var r = s._new_reactor(3, id, 0)
			var q: float = s.quality(r)
			lowest = minf(lowest, q); highest = maxf(highest, q)
			scores_ok = scores_ok and q > 0.25 and q < 0.85
			coordinates_ok = coordinates_ok and s._valid_positions(r.positions, r.atoms.size())
			var ideal = r.duplicate(true); ideal.positions = s.templates[id].positions.duplicate(true)
			scores_ok = scores_ok and s.quality(ideal) > 0.999 and s.income(ideal) > s.income(r)
		check(scores_ok, id + ": 32 reactor starts need tuning; actual reference still reaches full score and higher income")
		check(coordinates_ok, id + ": all starts stay inside editing bounds")
		var work = s.sandbox_from_baseline(id)
		check(s.sandbox_validate(work) and work.positions != baselines[id].positions, id + ": workshop starts valid and offset")
		check(work == s.sandbox_from_baseline(id), id + ": reopening a recipe does not reroll a perfect draft")
		var info = s.sandbox_reference(work)
		if info.known:
			var custom = s.reactors[0].duplicate(true)
			s._install_sandbox(custom, work)
			check(s.quality(custom) < 0.85 and s.quality(custom) > 0.25, id + ": sandbox installation preserves imperfect coordinates")
	check(s.templates == references and s.sandbox.baselines == baselines, "generation never modifies reference tables")
	check(s.initial_positions("water", "R001") == s.reactors[0].positions, "starter uses the same generation rule")
	check(s.new_sandbox_structure("草稿", "water").positions == s.sandbox_from_baseline("water").positions, "alternate draft API uses the same start")
	s.coins = 10000
	s.place_reactor(3, "hydrogen")
	check(s.quality(s.reactors[-1]) < 0.85, "public construction path does not grant full match")
	var r: Dictionary = s.reactors[0]
	var before = r.positions.duplicate(true)
	s.change_template(0, "methane")
	check(r.positions == before, "queued recipe leaves active geometry unchanged until installation")
	Fixtures.install(s)
	check(s.reference_id(r) == "methane" and s.quality(r) < 0.85, "doctor installs unoptimized new recipe")
	var initial: Array = r.positions.duplicate(true)
	s.change_template(0, "hydrogen"); Fixtures.install(s)
	s.change_template(0, "methane"); Fixtures.install(s)
	check(r.positions == initial, "recipe switching cannot reroll a better same-reactor start")
	var before_quality: float = s.quality(r)
	r.pending = 3; r.stock = 3
	s.apply_edit(0, s.templates.methane.positions.duplicate(true))
	check(s.quality(r) > 0.999, "player adjustment can reach full score without a hidden cap")
	check(s.storage.batches.size() == 1 and is_equal_approx(s.storage.batches[0].quality, before_quality), "old output keeps its original quality after tuning")
	var path := "res://saves/test_structure_start.json"
	check(s.save_game(path).begins_with("已保存"), "sample save succeeds")
	var restored = State.new()
	check(restored.load_game(path), "sample save loads")
	check(Fixtures.same(restored.reactors, s.reactors) and Fixtures.same(restored.storage.batches, s.storage.batches), "load preserves perfect, initial and collected sample coordinates")
	check(s.quality(restored.reactors[0]) > 0.999, "previously tuned samples remain fully matched")
	var work = s.sandbox_from_baseline("water")
	work.positions[1][0] += 0.037
	check(s.save_sandbox_structure("test_structure_start", work).begins_with("作品已保存"), "edited workshop draft saves")
	check(Fixtures.same(s.load_sandbox_structure("test_structure_start").positions, work.positions), "work library never reseeds saved coordinates")
	s.delete_sandbox_structure("test_structure_start")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	s.close_science(); restored.close_science()
	print("STRUCTURE START: ", checks, " checks, ", failures.size(), " failures; 448 fresh samples range ", lowest, "..", highest)
	quit(0 if failures.is_empty() else 1)
