extends Node
## v0.60 Dev Build: when the export has the `devbuild` feature, keep all resources
## pinned at comfortable maxima so every building and upgrade is always reachable.
## This script is registered as an autoload (DevMode) in project.godot and
## immediately exits if the feature is absent, so it has zero cost in the player build.

const COINS   := 99_000_000.0   # keeps the lab_state.gd cap well below 1e8
const CREDITS := 999_990        # below industry.gd credits.max = 1_000_000
const XP      := 999_990        # very high rank without overflowing int
const MAT     := 999_990        # star-sand / crystal-dew / alloy
const ELEM    := 9_990          # per-element cap safe for save validator
const MINERAL := 9_990          # per-mineral
const FIELD   := 9_990          # river-field resources (food / timber / stone …)
const REFINERY_LEVEL := 5

var _tick := 0.0

static func enabled() -> bool:
	return OS.has_feature("devbuild") or "--dev-mode" in OS.get_cmdline_user_args()

func _ready() -> void:
	if not enabled():
		queue_free()   # not a dev build — remove immediately
		return
	print("[DEV MODE] 无限资源已激活")

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0: return
	_tick = 0.0
	_top_up()

func _top_up() -> void:
	# Walk the SceneTree looking for the lab_state / planet nodes.
	var root := get_tree().root
	for child in root.get_children():
		_patch_node(child)

func _patch_node(node: Node) -> void:
	# lab_state.gd: coins, materials, element_inventory
	if node.get_script() != null:
		var src: String = str(node.get_script().get_path())
		if src.ends_with("lab_state.gd"):
			_patch_lab(node)
		elif src.ends_with("industry.gd"):
			_patch_industry(node)
		elif src.ends_with("refinery.gd"):
			_patch_refinery(node)
		elif src.ends_with("river_natives.gd"):
			_patch_natives(node)
		elif src.ends_with("river_field.gd"):
			_patch_field(node)
	for child in node.get_children():
		_patch_node(child)

func _patch_lab(s: Object) -> void:
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
	# Ensure star map materials (planet.v2 nature minerals) are stocked.
	var planet = s.get("planet")
	if planet == null: return
	var v2 = planet.get("v2")
	if v2 == null: return
	var nature = v2.get("nature")
	if nature != null and nature.get("minerals") is Dictionary:
		for mid in nature.minerals:
			if int(nature.minerals[mid]) < MINERAL * 0.5:
				nature.minerals[mid] = MINERAL

func _patch_industry(ind: Object) -> void:
	if not ind.get("unlocked"): ind.set("unlocked", true)
	if ind.get("credits") != null and int(ind.credits) < CREDITS * 0.5:
		ind.credits = CREDITS
	if ind.get("xp") != null and int(ind.xp) < XP * 0.5:
		ind.xp = XP
	if ind.get("plots") != null and int(ind.plots) < 36:
		ind.plots = 36

func _patch_refinery(ref: Object) -> void:
	if ref.get("level") != null and int(ref.level) < REFINERY_LEVEL:
		ref.level = REFINERY_LEVEL

func _patch_natives(nat: Object) -> void:
	# Give the tribe plenty of stock so they can build freely.
	if nat.get("stock") is Dictionary:
		for k in nat.stock:
			if int(nat.stock[k]) < 50: nat.stock[k] = 50

func _patch_field(field: Object) -> void:
	# Keep the player's river-field backpack topped up.
	if field.get("stock") is Dictionary:
		for k in field.stock:
			if int(field.stock[k]) < FIELD * 0.5:
				field.stock[k] = FIELD
