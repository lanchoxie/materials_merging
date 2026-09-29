extends RefCounted
## Describe the selected action, not a generic instruction for every target.
static func button_text(action: Dictionary,target: Dictionary) -> String:
	match action.get("type",""):
		"collect": return "查看 E" if target.has("entity") or target.get("kind") in ["trough","feeder","mixing_tank"] else "采集 E"
		"strike": return "攻击 E"
		"build","mini_unfold","fill": return "放置 E"
		"remove": return "拆回 E"
		"plant","tree_plant": return "种植 E"
		"axe": return "砍树 E"
		"dig": return "挖土 E"
		"organic_solution": return "倒回 E" if target.get("kind")=="mixing_tank" or action.get("reference","urea")!="urea" else "施肥 E"
		"organic_sample": return "加料 E"
		"feed": return "喂食 E"
	return "使用 E"

static func prompt(v,item: Dictionary,target: Dictionary,fallback: String) -> String:
	var action: Dictionary=item.get("action",{}); var kind=str(action.get("type",""))
	if item.is_empty(): return "空格 · B 打开背包；F 可直接挥拳"
	if item.get("quantity",0)==0: return str(item.name)+" · 已用完，B换物品或前往车间补充"
	if kind=="build": return "%s ×%d · %s" % [item.name,item.quantity,fallback]
	if target.has("entity"):
		var e: Dictionary=target.entity; var rage=v.combat.records.get(e.key,{}).get("anger",0)
		var text="%s · 血量 %.0f%% · 怒气 %.0f%%" % [target.name,target.health*100,rage]
		if target.distance>float(v.combat.rules.reach): text+=" · 靠近至%.1f米内可攻击" % v.combat.rules.reach
		elif kind=="collect": text+=" · 左键/F 攻击 · E 查看"
		elif kind=="strike": text+=" · E/F 攻击"
		else: text+=" · F 攻击 · "+button_text(action,target)
		return text
	if kind=="organic_solution":
		if target.get("kind")=="mixing_tank" or action.get("reference","urea")!="urea": return str(item.name)+" · 瞄准空罐或同种罐 E 倒回再稀释"
		return str(item.name)+" · 瞄准种植箱 E 施肥 · 重复施用会累积"
	if kind=="organic_sample": return v.organics.substance_name(str(action.reference))+" · 瞄准配料罐 E 加入5教学克"
	if target.get("kind")=="mixing_tank" and kind=="sample": return "配料罐 · E 加入1份水样（1教学升）"
	if kind=="strike": return "挥拳 · 瞄准%.1f米内的动物或人物 · E/F 攻击" % v.combat.rules.reach
	if kind=="tree_plant": return str(item.name)+" · 瞄准空地，E种植"
	if kind=="fill": return "土方 ×%d · 瞄准地面，E填高" % item.quantity
	if kind=="mini_unfold": return str(item.name)+" · 瞄准空地，E展开作品"
	return fallback
