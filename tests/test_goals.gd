extends SceneTree
## v0.23 "Goals": milestone track, save v22 + migration, capped offline catch-up, bigger reactor buffer.

const State = preload("res://scripts/lab_state.gd")
const Milestones = preload("res://scripts/milestones.gd")

var failures: Array = []
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_data()
	_test_claiming()
	_test_save_and_migration()
	_test_offline()
	await _test_main()
	if failures.is_empty(): print("PASS: %d goal checks" % checks)
	else: print("FAILED: %d of %d goal checks" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _test_data() -> void:
	var s = State.new()
	var ids := {}
	for m in Milestones.all():
		check(not ids.has(m.id), "milestone id is unique: " + str(m.id))
		ids[m.id] = true
		check(str(m.stat) in ["harvests", "reactors", "plots", "people", "deliveries", "discovered", "crates", "max_level", "best_fit"], "known stat: " + str(m.id))
		check(not Milestones.reward_text(m).is_empty(), "every goal pays something: " + str(m.id))
	check(Milestones.all().size() >= 15, "the track is long enough to carry the early game")
	check(s.reactor_capacity(s.reactors[0]) == 12, "reactor buffer raised to twelve units")

func _test_claiming() -> void:
	var s = State.new()
	var first: Dictionary = Milestones.current(s)
	check(first.id == "tune_80", "fresh island starts on the first goal")
	var coins: float = s.coins
	check(Milestones.claim(s).begins_with("目标尚未完成") and s.coins == coins and s.milestones_claimed.is_empty(), "unfinished goal cannot be claimed")
	s.apply_edit(0, s.templates.water.positions.duplicate(true))
	check(Milestones.done(s, first), "tuning to the reference geometry completes the fit goal")
	coins = s.coins
	var message: String = Milestones.claim(s)
	check(message.begins_with("目标达成") and is_equal_approx(s.coins, coins + 20.0), "claim pays the listed reward once")
	check(Milestones.current(s).id == "harvest_1", "the track advances in order")
	check(Milestones.claim(s).begins_with("目标尚未完成") and is_equal_approx(s.coins, coins + 20.0), "no double payout")
	var F = load("res://scripts/island_feedback.gd")
	check(F.classify({"coins": 1.0}, {"coins": 21.0}, message) == "goal", "claim gets its own feedback kind")

func _test_save_and_migration() -> void:
	var path := "res://saves/test_goals.json"
	var s = State.new()
	s.milestones_claimed = ["tune_80"]
	check(s.save_game(path).begins_with("已保存"), "v22 save succeeds")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(data.version) == 22 and data.milestones_claimed == ["tune_80"] and int(data.saved_at) > 1600000000, "save v22 stores claimed goals and save time")
	var loaded = State.new()
	check(loaded.load_game(path) and loaded.milestones_claimed == ["tune_80"] and loaded.saved_at == int(data.saved_at), "claimed goals and save time load back")
	var bad = data.duplicate(true); bad.milestones_claimed = [3]
	check(not loaded._validate_save(bad), "non-string goal ids are rejected")
	bad = data.duplicate(true); bad.erase("saved_at")
	check(not loaded._validate_save(bad), "v22 save without save time is rejected")
	# A v21 save of a player who already harvested: reached goals settle without payout.
	var legacy = data.duplicate(true)
	legacy.version = 21; legacy.erase("milestones_claimed"); legacy.erase("saved_at")
	legacy.total_harvests = 6
	legacy.reactors[0].positions = s.templates.water.positions.duplicate(true)
	var file = FileAccess.open(path, FileAccess.WRITE); file.store_string(JSON.stringify(legacy)); file.close()
	var migrated = State.new()
	check(migrated.load_game(path), "v21 save still loads")
	check(migrated.saved_at == 0 and is_equal_approx(migrated.coins, float(legacy.coins)), "migration pays nothing and has no offline time")
	check(migrated.milestones_claimed.slice(0, 2) == ["tune_80", "harvest_1"] and Milestones.current(migrated).id == "crate_1", "migration settles reached goals up to the first unmet one")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))

func _test_offline() -> void:
	var s = State.new()
	var r: Dictionary = s.reactors[0]
	s.apply_edit(0, s.templates.water.positions.duplicate(true))
	var now := 2000000000
	s.saved_at = now - 30
	check(s.offline_catch_up(now).is_empty(), "short absences are ignored")
	s.saved_at = now - 240
	var coins: float = s.coins
	var elapsed: float = s.campus.elapsed
	var away: Dictionary = s.offline_catch_up(now)
	check(is_equal_approx(float(away.simulated), 120.0) and not away.capped, "offline time counts at half speed")
	check(int(away.units) == 5 and int(r.pending) == 5, "reactor produces during the absence (120 s / 24 s per unit)")
	check(float(away.coins) > 0.0, "stored coins accumulate offline")
	check(s.coins == coins and s.campus.elapsed == elapsed, "wallet, payroll and campus stay paused offline")
	check(s.saved_at == now, "catch-up is not applied twice")
	check(s.offline_catch_up(now).is_empty(), "second call is a no-op")
	s.saved_at = now - 36000
	away = s.offline_catch_up(now)
	check(away.capped and is_equal_approx(float(away.simulated), 3600.0), "long absences are capped at two hours (half speed)")
	check(int(r.pending) == s.reactor_capacity(r), "a full buffer stops offline production")

func _test_main() -> void:
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	await process_frame
	await process_frame
	var s = game.state
	game._update_goal()
	check(not game.goal_button.visible and game.quest_label.text.contains("目标 1/"), "quest bar shows the goal in progress")
	s.apply_edit(0, s.templates.water.positions.duplicate(true))
	game._update_goal()
	check(game.goal_button.visible and game.quest_label.text.contains("已完成"), "finished goal shows a claim button")
	var coins: float = s.coins
	game._claim_goal()
	check(is_equal_approx(s.coins, coins + 20.0) and not game.goal_button.visible, "claim button pays and hides")
	check(game.toast_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "toast never swallows clicks")
	game._show_goals()
	check(game.modal != null, "goal list opens")
	game._close_modal()
	game._show_welcome({"away": 5400, "simulated": 2700.0, "capped": false, "units": 7, "coins": 120.0})
	check(game.modal != null, "welcome-back summary opens")
	game._close_modal()
	game.queue_free()
	await process_frame
