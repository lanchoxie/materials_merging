extends SceneTree
## v0.22 "Juice": autoloads exist under --script, every sound imports, feedback never errors,
## and island actions trigger the matching feedback kind.

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
	var sfx = root.get_node_or_null("Sfx")
	var fx = root.get_node_or_null("Fx")
	check(sfx != null, "Sfx autoload is present under --script")
	check(fx != null, "Fx autoload is present under --script")
	if sfx == null or fx == null:
		_finish()
		return
	for sound in sfx.MIX.keys():
		check(sfx.has_sound(sound), "sound imports: " + sound)
	check(sfx.has_sound("amb_island") and sfx.has_sound("amb_river"), "ambience loops import")
	check(not sfx.has_sound("does_not_exist"), "missing sounds are reported, not fatal")
	sfx.play("does_not_exist")
	sfx.play("coin", 1.5)
	sfx.ambience("amb_island", 0.05)
	fx.pop_text(Vector2(100, 100), "+12")
	fx.burst(Vector2(100, 100), Vector2(400, 40), 8)
	fx.sparkle(Vector2(200, 200))
	fx.banner("完美契合!", "测试")
	fx.flash()
	var probe = Control.new()
	probe.size = Vector2(40, 20)
	root.add_child(probe)
	fx.punch(probe)
	for i in range(1000):
		fx.pop_text(Vector2(10, 10), "x")
	check(fx.get_child_count() <= fx.MAX_LIVE_NODES + 2, "juice node count is capped")
	await create_timer(2.5).timeout
	check(fx.get_child_count() <= 2, "juice nodes clean themselves up")
	check(probe.scale.is_equal_approx(Vector2.ONE), "punch settles back to scale 1")
	probe.queue_free()
	sfx.ambience("", 0.05)
	_test_classify()
	await _test_main_integration()
	_finish()

func _test_classify() -> void:
	var F = load("res://scripts/island_feedback.gd")
	var base = {"coins": 100.0, "m0": 1, "m1": 1, "m2": 1, "catalysts": 0, "harvests": 0, "reactors": 1, "levels": 1, "plots": 5, "people": 1, "deliveries": 0, "discovered": 0, "crates": 0}
	var with = func(changes: Dictionary) -> Dictionary:
		var d = base.duplicate(); d.merge(changes, true); return d
	check(F.classify(base, with.call({"coins": 102.0}), "+2 金币 · 微光正在聚集") == "tap", "tap classified")
	check(F.classify(base, with.call({"coins": 140.0, "harvests": 3}), "收获 +40 金币") == "harvest", "harvest classified")
	check(F.classify(base, base, "全岛收获 +0 金币 · +0 建材") == "empty", "empty harvest is not celebrated")
	check(F.classify(base, with.call({"coins": 10.0, "levels": 2, "catalysts": 0}), "反应炉升至Lv.2") == "upgrade", "upgrade classified")
	check(F.classify(base, with.call({"coins": 250.0, "deliveries": 1, "catalysts": 1}), "精品成交！") == "sell", "sale classified")
	check(F.classify(base, with.call({"plots": 6}), "开拓") == "expand", "expansion classified")
	check(F.classify(base, base, "升级需要90金币和1枚精品催化晶") == "fail", "unchanged state + failure text = fail")
	check(F.classify(base, with.call({"coins": 50.0}), "已招募") == "spend", "coin spend classified")
	check(F.classify({}, base, "x") == "none", "no snapshot yet -> no feedback")
	var E = load("res://scripts/atom_editor.gd")
	check(E.stars(0.99) == 3 and E.stars(0.95) == 2 and E.stars(0.85) == 1 and E.stars(0.5) == 0, "editor star thresholds")
	check(E.stars_text(0.95) == "★★☆", "star text")
	var P = load("res://scripts/planet_v2_panel.gd")
	var sfx = root.get_node("Sfx")
	for action in P.ACTION_SOUNDS:
		check(sfx.MIX.has(P.ACTION_SOUNDS[action][0]), "river action has a real sound: " + action)
	for action in P.KICK_ACTIONS:
		check(P.ACTION_SOUNDS.has(action), "kicking action also makes a sound: " + action)

func _test_main_integration() -> void:
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	await process_frame
	await process_frame
	var coins_before: float = game.state.coins
	game._action(game.state.click_energy())
	check(game.feedback.combo == 1 and is_equal_approx(game.state.coins, coins_before + 2.0), "tapping feeds the combo")
	game._action(game.state.click_energy())
	check(game.feedback.combo == 2, "rapid taps build a combo")
	var r: Dictionary = game.state.reactors[0]
	r.pending = 2; r.stored_coins = 30.0; r.stock = 2
	var harvests_before: int = game.state.total_harvests
	game._tap_harvest(4)
	check(game.state.total_harvests == harvests_before + 2, "tapping a ready reactor in the world harvests it")
	var after_tap: int = game.state.total_harvests
	game._tap_harvest(4)
	check(game.state.total_harvests == after_tap, "tapping an empty reactor only selects it")
	await create_timer(1.2).timeout
	check(game.gold_label.text == "%d" % int(game.state.coins), "rolling coin counter settles on the real value")
	game.queue_free()
	await process_frame

func _finish() -> void:
	if failures.is_empty(): print("PASS: %d juice checks" % checks)
	else: print("FAILED: %d of %d juice checks" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
