extends SceneTree
## v0.24 "Discovery": codex rarity, best harvested fit (stars), star gifts, save v23 + migration,
## first-synthesis reveal card and the codex dialogs.

const State = preload("res://scripts/lab_state.gd")
const Codex = preload("res://scripts/codex.gd")
const Feedback = preload("res://scripts/island_feedback.gd")
const Editor = preload("res://scripts/atom_editor.gd")

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
	_test_rules()
	_test_record()
	_test_harvest()
	_test_save_and_migration()
	await _test_main()
	if failures.is_empty(): print("PASS: %d codex checks" % checks)
	else: print("FAILED: %d of %d codex checks" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _test_rules() -> void:
	var s = State.new()
	check(Codex.rarity(s.templates.water).id == "common" and Codex.rarity(s.templates.methane).id == "rare", "small structures are common, five atoms rare")
	check(Codex.rarity(s.templates.ethanol).id == "precious" and Codex.rarity(s.templates.perovskite).id == "legendary", "nine atoms precious, crystals legendary")
	check(Codex.stars(0.79) == 0 and Codex.stars(0.8) == 1 and Codex.stars(0.93) == 2 and Codex.stars(0.98) == 3, "star thresholds 80 / 93 / 98 %")
	check(Editor.stars(0.95) == Codex.stars(0.95) and Editor.PERFECT_FIT == Codex.PERFECT_FIT, "editor stars share the codex thresholds")
	check(Codex.max_stars(s) == s.templates.size() * 3, "three stars per structure")
	var last := 0
	for reward in Codex.rewards():
		check(int(reward.stars) > last and int(reward.stars) <= Codex.max_stars(s), "gift thresholds ascend within reach: %d" % int(reward.stars))
		check(s.layout.config.props.has(str(reward.prop)) and int(reward.get("count", 1)) >= 1, "gift is a real decoration: " + str(reward.prop))
		last = int(reward.stars)

func _test_record() -> void:
	var s = State.new()
	check(s.best_fit.is_empty() and s.star_rewards == 0 and Codex.total_stars(s) == 0, "fresh island has an empty codex")
	check(Codex.record(s, "water", 0.85).is_empty() and Codex.best_stars(s, "water") == 1, "first star recorded without a gift")
	Codex.record(s, "water", 0.5)
	check(is_equal_approx(float(s.best_fit.water), 0.85), "best fit never goes down")
	check(Codex.record(s, "", 1.0).is_empty() and Codex.record(s, "nope", 1.0).is_empty() and not s.best_fit.has("nope"), "unknown structures are ignored")
	Codex.record(s, "methane", 1.0)
	check(Codex.best_stars(s, "methane") == 0 and Codex.total_stars(s) == 1, "undiscovered structures do not count toward stars")
	var flowers := int(s.storage.decorations.get("flower", 0))
	var gifts: Array = Codex.record(s, "water", 0.99)
	check(gifts.size() == 1 and s.star_rewards == 1 and int(s.storage.decorations.flower) == flowers + 2, "reaching three stars hands out the first gift")
	check(Codex.record(s, "water", 1.0).is_empty() and s.star_rewards == 1, "a gift is handed out once")
	for id in ["hydrogen", "oxygen", "nitrogen", "urea"]: s.discovered.append(id)
	s.best_fit.erase("methane")
	for id in ["hydrogen", "oxygen", "nitrogen", "urea"]: gifts.append_array(Codex.record(s, id, 0.99))
	check(Codex.total_stars(s) == 15 and s.star_rewards == 4 and gifts.size() == 4, "several gifts can arrive in order")
	check("orbit_mobile" in s.storage.unlocked and int(s.storage.decorations.orbit_mobile) >= 1, "exploration props from gifts are unlocked for placement")
	check("bench" not in s.storage.unlocked, "ordinary props stay out of the exploration unlock list")

func _test_harvest() -> void:
	var s = State.new()
	var r: Dictionary = s.reactors[0]
	s.apply_edit(0, s.templates.water.positions.duplicate(true))
	for i in range(80): s.tick(1.0)
	check(int(r.pending) > 0, "tuned reactor produced")
	var flowers := int(s.storage.decorations.get("flower", 0))
	var message: String = s.harvest(0)
	check(Codex.best_stars(s, "water") == 3 and float(s.best_fit.water) >= 0.98, "harvest records the batch fit in the codex")
	check(message.contains("图鉴奖励") and int(s.storage.decorations.flower) == flowers + 2, "the first gift is announced with the harvest")
	var fresh := Feedback.snapshot(State.new())
	check(fresh.has("gifts") and Feedback.snapshot(s).gifts == 1, "feedback snapshot sees handed-out gifts")
	var card: Dictionary = Feedback.reveal_card(s, "water")
	check(card.title == s.templates.water.formula and str(card.rarity).begins_with("常见") and card.stars == "★★★", "reveal card shows formula, rarity and stars")
	# The untuned starter sample earns only its fit; it cannot earn stars it has not reached.
	var t = State.new()
	for i in range(80): t.tick(1.0)
	t.harvest(0)
	check(Codex.best_stars(t, "water") == Codex.stars(t.quality(t.reactors[0])), "stars follow the harvested batch fit")

func _test_save_and_migration() -> void:
	var path := "res://saves/test_codex.json"
	var s = State.new()
	s.best_fit = {"water": 0.95}
	s.star_rewards = 1
	check(s.save_game(path).begins_with("已保存"), "v23 save succeeds")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(int(data.version) == 23 and is_equal_approx(float(data.best_fit.water), 0.95) and int(data.star_rewards) == 1, "save v23 stores the codex")
	var loaded = State.new()
	check(loaded.load_game(path) and is_equal_approx(float(loaded.best_fit.water), 0.95) and loaded.star_rewards == 1, "codex loads back")
	for bad_case in [["best_fit", {"nope": 0.5}], ["best_fit", {"water": 1.5}], ["best_fit", []], ["star_rewards", 99], ["star_rewards", 1.5]]:
		var bad = data.duplicate(true)
		bad[bad_case[0]] = bad_case[1]
		check(not loaded._validate_save(bad), "invalid codex rejected: %s" % str(bad_case))
	var legacy = data.duplicate(true)
	legacy.version = 22
	legacy.erase("best_fit")
	legacy.erase("star_rewards")
	legacy.reactors[0].positions = s.templates.water.positions.duplicate(true)
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated = State.new()
	check(migrated.load_game(path), "v22 save still loads")
	check(float(migrated.best_fit.get("water", 0.0)) >= 0.98, "migration seeds the codex from current samples")
	check(migrated.star_rewards == 1 and int(migrated.storage.decorations.get("flower", 0)) == int(legacy.storage.decorations.get("flower", 0)), "gifts already within reach settle without payout")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))

func _count_cards(node: Node) -> int:
	var n := 1 if node is Button and node.custom_minimum_size == Vector2(206, 150) else 0
	for child in node.get_children(): n += _count_cards(child)
	return n

func _texts(node: Node, into: Array) -> Array:
	if node is Label: into.append(node.text)
	for child in node.get_children(): _texts(child, into)
	return into

func _test_main() -> void:
	var game = load("res://scripts/main.gd").new()
	root.add_child(game)
	await process_frame
	await process_frame
	var s = game.state
	s.best_fit = {"water": 0.94}
	game._show_collection()
	check(game.modal != null and _count_cards(game.modal) == s.templates.size(), "codex shows one card per structure")
	var texts: Array = _texts(game.modal, [])
	check("？？？" in texts and "★★☆" in texts, "locked cards hide the formula; found cards show stars")
	check(texts.any(func(t): return str(t).begins_with("下一份图鉴奖励")), "codex shows the next star gift")
	game._show_codex_entry("water")
	texts = _texts(game.modal, [])
	check(texts.any(func(t): return str(t).begins_with("图鉴最佳")), "entry shows the best fit")
	game._show_codex_entry("glycerol")
	check(game.modal != null, "locked entry opens with a hint")
	game._close_modal()
	game.queue_free()
	await process_frame
