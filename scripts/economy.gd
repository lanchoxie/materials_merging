extends RefCounted
## Rewards are game design. They must never be represented as scientific properties.

var rules: Dictionary = {}

func _init():
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/economy.json"))

func profile(template: Dictionary) -> Dictionary:
	var distinct: Dictionary = {}
	for symbol in template.atoms:
		distinct[str(symbol)] = true
	# Crystal occupancy prevents counting shared corner/face spheres as full atoms.
	var atom_count: float = float(template.atoms.size())
	if template.has("occupancies"):
		atom_count = 0.0
		for occupancy in template.occupancies:
			atom_count += float(occupancy)
	var c: Dictionary = rules.complexity
	var constraints: int = template.bonds.size() + template.angles.size()
	var atom_term: float = float(c.atom_weight) * sqrt(maxf(0.0, atom_count - 1.0))
	var element_term: float = float(c.element_weight) * maxf(0.0, distinct.size() - 1.0)
	var constraint_term: float = float(c.constraint_weight) * sqrt(float(constraints))
	var chapter_factor: float = float(c.chapter_factors.get(template.chapter, 1.0))
	var complexity: float = minf(float(c.maximum), (1.0 + atom_term + element_term + constraint_term) * chapter_factor)
	return {"atoms": atom_count, "elements": distinct.size(), "constraints": constraints,
		"atom_term": atom_term, "element_term": element_term, "constraint_term": constraint_term,
		"chapter_factor": chapter_factor, "complexity": complexity,
		"base_rate": float(rules.base_coins_per_second) * complexity}

func breakdown(template: Dictionary, quality: float, level: int, building: bool = false) -> Dictionary:
	var result: Dictionary = profile(template)
	result.geometry_factor = float(rules.geometry_floor) + float(rules.geometry_weight) * clampf(quality, 0.0, 1.0)
	result.level_factor = 1.0 + float(rules.level_increment) * (maxi(1, level) - 1)
	result.rate = 0.0 if building else result.base_rate * result.geometry_factor * result.level_factor
	return result

func make_order(deliveries: int, templates: Dictionary) -> Dictionary:
	var config: Dictionary = rules.orders
	var buyer: Dictionary = config.buyers[deliveries % config.buyers.size()]
	var result: Dictionary = buyer.duplicate(true)
	result.target_quality = float(config.target_quality)
	result.tolerance = float(config.tolerance)
	result.quantity = int(config.quantity)
	result.reward = roundi(profile(templates[buyer.template]).complexity * float(config.reward_per_complexity))
	result.description = "同类结构与目标相差不超过5个百分点为精品；其他样品可按报价成交。"
	return result

func quote(template_id: String, quality: float, stock: int, building: bool, order: Dictionary) -> Dictionary:
	var matching: bool = template_id == order.template
	var difference: float = absf(quality - float(order.target_quality))
	var premium: bool = matching and difference <= float(order.tolerance)
	var payment: int = int(order.reward)
	if not premium:
		var discount: float = float(rules.orders.same_type_discount if matching else rules.orders.other_type_discount)
		payment = maxi(int(rules.orders.minimum_payment), int(payment * maxf(0.25, 1.0 - difference) * discount))
	return {"premium": premium, "payment": payment, "matching": matching,
		"difference": difference, "ready": not building and stock >= int(order.quantity),
		"quantity": int(order.quantity), "catalysts": 1 if premium else 0}

func ranking_score(quote_data: Dictionary) -> float:
	var weights: Dictionary = rules.orders.get("ranking_weights", {})
	var score := 0.0
	if bool(quote_data.get("ready", false)): score += float(weights.get("ready", 1000))
	if bool(quote_data.get("premium", false)): score += float(weights.get("premium", 250))
	if bool(quote_data.get("matching", false)): score += float(weights.get("matching", 80))
	score += float(weights.get("quality", 120)) * (1.0 - float(quote_data.get("difference", 1.0)))
	score += float(weights.get("payment", 0.5)) * float(quote_data.get("payment", 0))
	return score

func ranking_reason(quote_data: Dictionary) -> String:
	if quote_data.get("exploration",false): return "创意展示样品 · 无科学评级"
	if not bool(quote_data.get("known", true)):
		return "探索组合，数据库暂无可交付参考"
	if bool(quote_data.get("premium", false)):
		return "精品匹配 · 可获得催化晶"
	if bool(quote_data.get("ready", false)) and bool(quote_data.get("matching", false)):
		return "同类匹配 · 库存可交付"
	if bool(quote_data.get("ready", false)):
		return "可交付 · 近似报价"
	if not bool(quote_data.get("matching", false)):
		return "异类替代 · 折价"
	return "同类样品 · 还缺库存"
