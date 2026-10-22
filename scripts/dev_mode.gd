extends Node
## v0.60 Dev Build: activated by the `devbuild` export feature or `--dev-mode` CLI flag.
## Every second, unconditionally tops up ALL resources to large values.
## lab_state is a RefCounted, not a Node — accessed via get_tree().current_scene.state.

const BIG := 999_990        # generic "a lot" for counts / credits / xp
const COINS := 99_000_000.0

## All industry item ids from data/industry.json items block.
const INDUSTRY_ITEMS := [
	"steel_ingot","bronze_ingot","solder","duralumin","al_li","steel_bit",
	"pe","pvc","ptfe","uf_resin","rubber","particleboard",
	"chair_nova","desk_board","sofa_float","ptfe_pan",
	"glass","cement","ceramic_tile","fertilizer",
	"polysilicon","wafer","solar_panel","photoresist","epoxy",
	"logic_chip","power_diode","led_chip","pcb","ic","control_board",
	"headlamp","insulated_suit",
	"lead_acid","lfp_cell","battery_pack","motor","power_drill",
	"rover","tbm","plane","starship",
]

## All recipe output ids from data/industry.json recipes block.
const RECIPE_OUTPUTS := [
	"carbon_steel","bronze","solder","duralumin","al_li","steel_bit",
	"polyethylene","pvc","ptfe","uf_resin","rubber","particleboard",
	"chair_nova","desk_board","sofa_float","ptfe_pan","soda_lime_glass",
	"cement","ceramic_tile","superphosphate","polysilicon","n_wafer",
	"solar_panel","photoresist","epoxy","logic_chip","power_diode",
	"led_chip","fr4_board","ic_package","control_board",
	"headlamp","insulated_suit","lead_acid","lfp_cell","battery_pack",
	"motor","power_drill","rover","tbm","plane","starship",
]

## Chemical formula keys used as recipe evidence (has_made check).
## Written into index_found so every recipe's evidence is satisfied.
const EVIDENCE_KEYS := [
	"Al2Cu","C2F4","C2H3Cl","C2H4","C4H6","C6H6O","CH2O","CaO",
	"Cl3HSi","CsPbBr3","Cu3Sn","Fe3C","H3O4P","LiAl","LiFePO4",
	"PbSO4","Si",
]

## Campus research unlock keys.
const CAMPUS_UNLOCKS := ["process_control","parallel_screening","laminate_design"]

## River-field stock keys (river_field.json resources).
const FIELD_KEYS := [
	"timber","stone","fiber","fruit","grain","soil","meat","roasted_meat",
	"porridge","hot_soup","pottery","trophy_axe","trophy_bone","trophy_feather","trophy_badge",
]

var _tick := 0.0

static func enabled() -> bool:
	return OS.has_feature("devbuild") or "--dev-mode" in OS.get_cmdline_user_args()

func _ready() -> void:
	if not enabled():
		queue_free()
		return
	print("[DEV MODE] 无限资源已激活 — 每秒顶满所有资源、解锁所有配方和工业品")
	# Top up immediately on first frame so resources are available from the start.
	await get_tree().process_frame
	_top_up()

func _process(delta: float) -> void:
	_tick += delta
	if _tick < 1.0: return
	_tick = 0.0
	_top_up()

func _top_up() -> void:
	var scene = get_tree().current_scene
	if scene == null: return
	var s = scene.get("state")
	if s == null: return
	_patch_lab(s)
	var ind = s.get("industry"); if ind != null: _patch_industry(s, ind)
	var ref = s.get("refinery"); if ref != null: _patch_refinery(ref)
	var campus = s.get("campus"); if campus != null: _patch_campus(campus)
	var planet = s.get("planet"); if planet != null: _patch_planet(planet)

func _patch_lab(s: Object) -> void:
	# Coins and star-materials
	s.coins = COINS
	if s.get("materials") is Array:
		for i in s.materials.size(): s.materials[i] = BIG
	# All elements
	if s.get("element_inventory") is Dictionary:
		for sym in s.element_inventory: s.element_inventory[sym] = BIG
	# index_found: write all evidence keys so has_made() returns true for every recipe
	if s.get("index_found") is Dictionary:
		for key in EVIDENCE_KEYS: s.index_found[key] = true
	# Ensure the player's inventory hotbar has the default tools (gloves, hammer, pick, scanner).
	# inventory is held on planet.v2, not directly on lab_state.
	var planet = s.get("planet"); if planet == null: return
	var v2 = planet.get("v2"); if v2 == null: return
	var inv = v2.get("inventory"); if inv == null: return
	if inv.get("slots") is Array:
		var defaults = ["tool:collect","tool:remove","tool:dig","tool:scan"]
		for tool_id in defaults:
			if tool_id not in inv.slots:
				for i in inv.slots.size():
					if inv.slots[i] == "" or inv.slots[i] == null:
						inv.slots[i] = tool_id; break

func _patch_industry(s: Object, ind: Object) -> void:
	ind.set("unlocked", true)
	ind.credits = BIG
	ind.xp = BIG
	ind.plots = 36
	# Industry items are capped at 9999 by the save validator (industry.gd _num check).
	# Exceeding this causes save() to fail → dev progress is lost on exit.
	if ind.get("items") is Dictionary:
		for id in INDUSTRY_ITEMS: ind.items[id] = 9999
		for id in RECIPE_OUTPUTS: ind.items[id] = 9999

func _patch_refinery(ref: Object) -> void:
	ref.level = 5

func _patch_campus(campus: Object) -> void:
	if campus.get("unlocked_materials") is Array:
		for key in CAMPUS_UNLOCKS:
			if key not in campus.unlocked_materials:
				campus.unlocked_materials.append(key)

func _patch_planet(planet: Object) -> void:
	var v2 = planet.get("v2"); if v2 == null: return
	# Minerals — capped at max_mineral_stock (default 999) so restore() passes validation.
	var nature = v2.get("nature")
	if nature != null and nature.get("minerals") is Dictionary:
		var mcap: int = int(nature.get("rules",{}).get("max_mineral_stock",999))
		for mid in nature.minerals: nature.minerals[mid] = mcap
	# River-field backpack — capped at max_stock (999) so restore() passes validation.
	# Only set keys that already exist in field.stock (validator rejects unknown keys).
	var field = v2.get("field")
	if field != null and field.get("stock") is Dictionary:
		var fcap: int = int(field.get("rules",{}).get("max_stock",999))
		for k in field.stock: field.stock[k] = fcap
