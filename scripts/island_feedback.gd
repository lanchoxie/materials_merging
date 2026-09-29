extends RefCounted
## Turns island state changes into sound and motion.
## main.gd captures a cheap snapshot every frame and calls react() from _action(); the diff says
## what really happened, so feedback can never celebrate an action that silently failed.

# Colours come from the script, not the "Fx" global: tests preload game scripts before autoloads exist.
const Fx = preload("res://scripts/core/fx.gd")
const MATERIAL_NAMES = ["星砂", "晶露", "合金片"]
const MATERIAL_COLORS = [Color("ffe3a3"), Color("9fe7ff"), Color("d7c6ff")]
const COMBO_WINDOW = 0.85
const FAILURE_WORDS = ["需要", "不足", "请先", "请等待", "暂时", "不能", "无法", "尚未", "已达到", "还需", "没有", "稍后"]

var before: Dictionary = {}
var combo: int = 0
var best_combo: int = 0
var _last_tap: float = -10.0

static func snapshot(state) -> Dictionary:
	var levels := 0
	for r in state.reactors: levels += int(r.level)
	return {
		"coins": float(state.coins), "m0": int(state.materials[0]), "m1": int(state.materials[1]), "m2": int(state.materials[2]),
		"catalysts": int(state.upgrades), "harvests": int(state.total_harvests), "reactors": state.reactors.size(), "levels": levels,
		"plots": state.unlocked_plot_count(), "people": state.campus.people.size(), "deliveries": int(state.deliveries),
		"discovered": state.discovered.size(), "crates": int(state.crate_count),
	}

func capture(state) -> void:
	before = snapshot(state)

static func looks_like_failure(message: String) -> bool:
	for word in FAILURE_WORDS:
		if message.contains(word): return true
	return false

## Classify the change since the last capture. Pure, so tests can check it without a UI.
static func classify(a: Dictionary, b: Dictionary, message: String) -> String:
	if a.is_empty(): return "none"
	if message.begins_with("目标达成"): return "goal"
	if b.levels > a.levels: return "upgrade"
	if b.reactors > a.reactors: return "build"
	if b.deliveries > a.deliveries: return "sell"
	if b.harvests > a.harvests: return "harvest"
	if message.begins_with("收获") or message.begins_with("全岛收获"): return "harvest" if b.coins > a.coins + 0.5 else "empty"
	if b.plots > a.plots: return "expand"
	if b.people > a.people: return "hire"
	if b.crates > a.crates: return "crate"
	if is_equal_approx(b.coins - a.coins, 2.0) and message.begins_with("+2"): return "tap"
	if b.coins < a.coins - 0.5: return "spend"
	if b.coins > a.coins + 0.5: return "gain"
	if looks_like_failure(message): return "fail"
	return "none"

func react(game, message: String) -> String:
	var after := snapshot(game.state)
	var kind := classify(before, after, message)
	var fx = game.get_node_or_null("/root/Fx")
	var sfx = game.get_node_or_null("/root/Sfx")
	if fx == null or sfx == null or before.is_empty():
		before = after
		return kind
	var origin: Vector2 = game.pointer_position
	var coin_target: Vector2 = game.gold_label.get_global_rect().get_center()
	var gained := int(round(after.coins - before.coins))
	match kind:
		"tap":
			var now := Time.get_ticks_msec() / 1000.0
			combo = combo + 1 if now - _last_tap < COMBO_WINDOW else 1
			_last_tap = now
			best_combo = maxi(best_combo, combo)
			var heat := minf(combo, 24.0)
			sfx.play("tap", 1.0 + heat * 0.035)
			fx.pop_text(origin + Vector2(randf_range(-30, 30), -24), "+2", Fx.GOLD, 20 + int(heat * 0.4), 55.0 + heat * 2.0)
			fx.punch(game.gold_label, 0.06 + heat * 0.004)
			if combo >= 3:
				var hot := Fx.MINT if combo < 20 else Fx.LILAC
				# Above the rising "+2"s and away from the screen edge, so the meter stays readable.
				var meter := Vector2(maxf(origin.x, 150.0), origin.y - 130.0)
				fx.counter("combo", meter, "连击 ×%d" % combo, hot, 26 + mini(combo, 20), COMBO_WINDOW)
				if combo % 10 == 0:
					fx.sparkle(meter, hot, 14 + mini(combo, 18), 90.0)
					sfx.play("pop", 1.0 + heat * 0.02)
		"harvest":
			sfx.play("harvest")
			if gained > 0:
				_coins_to_counter(game, fx, sfx, origin, coin_target, gained)
			_material_pops(fx, origin, before, after)
		"goal":
			sfx.play("discovery")
			fx.banner("目标达成！", message.get_slice("·", 0).trim_prefix("目标达成").strip_edges(), Fx.GOLD)
			_coins_to_counter(game, fx, sfx, origin, coin_target, gained)
			_material_pops(fx, origin, before, after)
			if after.catalysts > before.catalysts:
				fx.pop_text(origin + Vector2(0, -60), "催化晶 +%d" % (after.catalysts - before.catalysts), Fx.LILAC, 24, 80.0, 0.3)
		"empty":
			sfx.play("error", 1.1)
		"sell":
			sfx.play("sell")
			_coins_to_counter(game, fx, sfx, origin, coin_target, gained)
			if after.catalysts > before.catalysts:
				fx.pop_text(origin + Vector2(0, -56), "精品！催化晶 +%d" % (after.catalysts - before.catalysts), Fx.LILAC, 26, 90.0, 0.25)
				fx.sparkle(origin, Fx.LILAC, 16, 110.0)
		"upgrade":
			sfx.play("upgrade")
			fx.flash(Fx.GOLD, 0.22, 0.5)
			fx.banner("升级！", message.get_slice("·", 0).strip_edges(), Fx.GOLD)
		"build":
			sfx.play("build")
			fx.sparkle(origin, Fx.MINT, 16, 90.0)
			fx.pop_text(origin + Vector2(0, -30), "新反应炉！", Fx.MINT, 26)
		"expand":
			sfx.play("build")
			sfx.play("whoosh")
			fx.sparkle(origin, Fx.MINT, 22, 130.0)
			fx.pop_text(origin + Vector2(0, -30), "新土地！", Fx.MINT, 28)
		"hire":
			sfx.play("open")
			sfx.play("pop", 1.2)
			fx.pop_text(origin + Vector2(0, -30), "新伙伴 +%d" % (after.people - before.people), Fx.LILAC, 26)
			fx.sparkle(origin, Fx.LILAC, 14)
		"crate":
			sfx.play("open")
			if gained > 0: _coins_to_counter(game, fx, sfx, origin, coin_target, gained)
			_material_pops(fx, origin, before, after)
		"spend":
			sfx.play("build", 1.25, -4.0)
			fx.pop_text(coin_target + Vector2(0, 30), "%d" % gained, Color("ff9f8c"), 20, 40.0)
			fx.sparkle(origin, Fx.MINT, 8, 50.0)
		"gain":
			sfx.play("coin")
			_coins_to_counter(game, fx, sfx, origin, coin_target, gained)
		"fail":
			sfx.play("error")
			if is_instance_valid(game.toast_panel): fx.punch(game.toast_panel, 0.05, 0.3)
	if after.discovered > before.discovered:
		sfx.play("discovery")
		var newest = game.state.discovered[game.state.discovered.size() - 1]
		var info: Dictionary = game.state.templates.get(newest, {})
		fx.banner("新发现！", "%s  %s 已收入结构图鉴" % [info.get("formula", newest), info.get("name", "")], Fx.MINT)
	before = after
	return kind

func _coins_to_counter(game, fx, sfx, origin: Vector2, target: Vector2, amount: int) -> void:
	if amount <= 0: return
	fx.pop_text(origin + Vector2(0, -28), "+%d" % amount, Fx.GOLD, 28 if amount < 100 else 34)
	var tokens := clampi(int(sqrt(float(amount)) * 0.9), 3, 12)
	var arrived := [0]
	# Coins can still be in flight when the scene closes: hold the counter weakly, never the game.
	var counter_ref: WeakRef = weakref(game.gold_label)
	fx.burst(origin, target, tokens, Fx.GOLD, func():
		arrived[0] += 1
		sfx.play("coin", 1.0 + arrived[0] * 0.045, -3.0)
		var counter = counter_ref.get_ref()
		if counter: fx.punch(counter, 0.1))

func _material_pops(fx, origin: Vector2, a: Dictionary, b: Dictionary) -> void:
	var delay := 0.2
	for i in range(3):
		var gain: int = int(b["m%d" % i]) - int(a["m%d" % i])
		if gain > 0:
			fx.pop_text(origin + Vector2(0, 12), "+%d %s" % [gain, MATERIAL_NAMES[i]], MATERIAL_COLORS[i], 22, 80.0, delay)
			delay += 0.18
