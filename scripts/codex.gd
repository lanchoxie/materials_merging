extends RefCounted
## v0.24 structure codex: rarity by atom count, best harvested fit per structure (stars), and
## decoration gifts for the codex star total (data/codex.json). State keeps only `best_fit`
## and how many gifts were handed out (`star_rewards`); everything else is derived.

const DATA_PATH = "res://data/codex.json"
const PERFECT_FIT = 0.98
const PREMIUM_FIT = 0.93
const GOOD_FIT = 0.8

static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {"rarity": [], "star_rewards": []}
	return _data

static func stars(q: float) -> int:
	return 3 if q >= PERFECT_FIT else 2 if q >= PREMIUM_FIT else 1 if q >= GOOD_FIT else 0

static func stars_text(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(3 - n)

static func rarity(template: Dictionary) -> Dictionary:
	var atoms: int = template.get("atoms", []).size()
	for tier in data().rarity:
		if atoms <= int(tier.max_atoms): return tier
	return data().rarity[-1]

static func best_stars(state, id: String) -> int:
	return stars(float(state.best_fit.get(id, 0.0))) if id in state.discovered else 0

static func total_stars(state) -> int:
	var n := 0
	for id in state.discovered: n += best_stars(state, str(id))
	return n

static func max_stars(state) -> int:
	return state.templates.size() * 3

static func rewards() -> Array:
	return data().star_rewards

## The next gift not yet handed out, or {} when all were given.
static func next_reward(state) -> Dictionary:
	return rewards()[state.star_rewards] if state.star_rewards < rewards().size() else {}

static func reward_text(state, reward: Dictionary) -> String:
	var info: Dictionary = state.layout.config.props.get(str(reward.prop), {})
	return "%s ×%d" % [info.get("name", str(reward.prop)), int(reward.get("count", 1))]

## Record a harvested batch of reference structure `id` at fit `q`; hand out any gifts the new
## star total reaches. Returns the gift texts (empty when nothing new was earned).
static func record(state, id: String, q: float) -> Array:
	if id.is_empty() or not state.templates.has(id) or not is_finite(q): return []
	if q > float(state.best_fit.get(id, 0.0)): state.best_fit[id] = clampf(q, 0.0, 1.0)
	var gifts: Array = []
	var total := total_stars(state)
	while state.star_rewards < rewards().size() and total >= int(rewards()[state.star_rewards].stars):
		var reward: Dictionary = rewards()[state.star_rewards]
		var kind := str(reward.prop)
		state.storage.decorations[kind] = mini(1000000, int(state.storage.decorations.get(kind, 0)) + int(reward.get("count", 1)))
		if state.layout.config.props.get(kind, {}).get("exploration", false) and kind not in state.storage.unlocked:
			state.storage.unlocked.append(kind)
		state.star_rewards += 1
		gifts.append(reward_text(state, reward))
	return gifts

## Old saves: gifts for stars already earned count as handed out (no windfall).
static func settle_existing(state) -> void:
	var total := total_stars(state)
	while state.star_rewards < rewards().size() and total >= int(rewards()[state.star_rewards].stars):
		state.star_rewards += 1
