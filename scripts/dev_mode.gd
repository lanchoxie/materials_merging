extends Node
## v0.60 Dev Build: when the export has the `devbuild` feature, keep all resources
## pinned at comfortable maxima so every building and upgrade is always reachable.
## Registered as autoload (DevMode) in project.godot. Immediately frees itself if the
## feature is absent, so it has zero cost in the player build.
##
## The game state (lab_state) is a RefCounted held by main.gd's `state` var, NOT a
## scene node. So we find the root node "AtomAtelier" and read its `.state` property
## directly, then walk the state.planet / state.industry / state.refinery sub-objects.

const COINS   := 99_000_000.0
const CREDITS := 999_990
const XP      := 999_990
const MAT     := 999_990
const ELEM    := 9_990
const MINERAL := 9_990
const FIELD   := 9_990
const REFINERY_LEVEL := 5

var _tick := 0.0

static func enabled() -> bool:
	return OS.has_feature("devbuild") or "--dev-mode" in OS.get_cmdline_user_args()

func _ready() -> void:
	if not enabled():
		queue_free()
		return
	print("[DEV MODE] 无限资源已激活")

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0: return
	_tick = 0.0
	_top_up()

func _top_up() -> void:
	# Find the main scene root node (AtomAtelier) which holds the lab_state in `.state`.
	var main = get_tree().current_scene
	if main == null or not main.has_method("get"): return
	var s = main.get("state")
	if s == null: return
	# lab_state direct fields
	if s.get("coins") != null and float(s.coins) < COINS * 0.5:
		s.coins = COINS
	if s.get("materials") is Array:
		for i in s.materials.size():
			if int(s.materials[i]) < MAT * 0.5:
				s.materials[i] = MAT
	if s.get("element_inventory") is Dictionary:
		for sym in s.element_inventory:
			if int(s.element_inventory[sym]) < ELEM * 0.5:
				s.element_inventory[sym] = ELEM
	# industry (Starforge Isle)
	var ind = s.get("industry")
	if ind != null:
		if not ind.get("unlocked"): ind.set("unlocked", true)
		if ind.get("credits") != null and int(ind.credits) < CREDITS * 0.5:
			ind.credits = CREDITS
		if ind.get("xp") != null and int(ind.xp) < XP * 0.5:
			ind.xp = XP
		if ind.get("plots") != null and int(ind.plots) < 36:
			ind.plots = 36
	# refinery
	var ref = s.get("refinery")
	if ref != null and ref.get("level") != null and int(ref.level) < REFINERY_LEVEL:
		ref.level = REFINERY_LEVEL
	# planet (minerals + river-field backpack)
	var planet = s.get("planet")
	if planet != null:
		var v2 = planet.get("v2")
		if v2 != null:
			var nature = v2.get("nature")
			if nature != null and nature.get("minerals") is Dictionary:
				for mid in nature.minerals:
					if int(nature.minerals[mid]) < MINERAL * 0.5:
						nature.minerals[mid] = MINERAL
			var field = v2.get("field")
			if field != null and field.get("stock") is Dictionary:
				for k in field.stock:
					if int(field.stock[k]) < FIELD * 0.5:
						field.stock[k] = FIELD
