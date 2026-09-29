extends RefCounted
## v0.23 goal track: an ordered list of small, concrete goals with rewards (data/milestones.json).
## Progress is always read from live state, so nothing can drift; only claimed ids are saved.

const DATA_PATH = "res://data/milestones.json"
const MATERIAL_NAMES = ["星砂", "晶露", "合金片"]

static var _list: Array = []

static func all() -> Array:
	if _list.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_list = data.milestones if data is Dictionary else []
	return _list

static func stat(state, key: String) -> float:
	match key:
		"harvests": return float(state.total_harvests)
		"reactors": return float(state.reactors.size())
		"plots": return float(state.unlocked_plot_count())
		"people": return float(state.campus.people.size())
		"deliveries": return float(state.deliveries)
		"discovered": return float(state.discovered.size())
		"crates": return float(state.crate_count)
		"max_level":
			var best := 0
			for r in state.reactors: best = maxi(best, int(r.level))
			return float(best)
		"best_fit":
			var best := 0.0
			for r in state.reactors:
				if float(r.build_left) <= 0.0 and not state.reference_id(r).is_empty(): best = maxf(best, state.quality(r))
			return best
	return 0.0

static func done(state, m: Dictionary) -> bool:
	return stat(state, str(m.stat)) >= float(m.target) - 0.000001

## The first unclaimed milestone, or {} when the track is finished.
static func current(state) -> Dictionary:
	for m in all():
		if str(m.id) not in state.milestones_claimed: return m
	return {}

static func claimed_count(state) -> int:
	var n := 0
	for m in all():
		if str(m.id) in state.milestones_claimed: n += 1
	return n

static func progress_text(state, m: Dictionary) -> String:
	if m.is_empty(): return ""
	var value := stat(state, str(m.stat))
	if str(m.stat) == "best_fit":
		return "%d%% / %d%%" % [floori(value * 100.0), roundi(float(m.target) * 100.0)]
	return "%d / %d" % [mini(int(value), int(m.target)), int(m.target)]

static func reward_text(m: Dictionary) -> String:
	var parts: Array = []
	var reward: Dictionary = m.get("reward", {})
	if int(reward.get("coins", 0)) > 0: parts.append("%d 金币" % int(reward.coins))
	if int(reward.get("catalysts", 0)) > 0: parts.append("%d 催化晶" % int(reward.catalysts))
	var mats: Array = reward.get("materials", [])
	for i in range(mini(mats.size(), 3)):
		if int(mats[i]) > 0: parts.append("%d %s" % [int(mats[i]), MATERIAL_NAMES[i]])
	return " + ".join(parts)

## Claim the current milestone if it is complete. Returns a toast message.
static func claim(state) -> String:
	var m := current(state)
	if m.is_empty(): return "所有目标都已完成"
	if not done(state, m): return "目标尚未完成：%s（%s）" % [m.hint, progress_text(state, m)]
	var reward: Dictionary = m.get("reward", {})
	state.coins = minf(100000000.0, float(state.coins) + float(reward.get("coins", 0)))
	state.upgrades += int(reward.get("catalysts", 0))
	var mats: Array = reward.get("materials", [])
	for i in range(mini(mats.size(), 3)): state.materials[i] += int(mats[i])
	state.milestones_claimed.append(str(m.id))
	return "目标达成「%s」 · 获得 %s" % [m.title, reward_text(m)]

## Old saves: goals that were already met count as claimed (no windfall), so the track starts at
## the first goal the player has not reached yet.
static func settle_existing(state) -> void:
	for m in all():
		if str(m.id) in state.milestones_claimed: continue
		if not done(state, m): return
		state.milestones_claimed.append(str(m.id))
