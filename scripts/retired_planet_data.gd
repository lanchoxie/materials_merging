extends RefCounted
## Read-only legacy save envelope. No scenes, simulation, rewards or commands.
const Count=preload("res://scripts/island_storage.gd")
var data: Dictionary={}
var home: Dictionary={}

func restore(value) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not Count.count_ok(value.get("version",1)) or int(value.get("version",1)) not in [1,2,3,4,5,6,7,8,9,10]: return false
	if not value.get("worlds") is Array or value.worlds.is_empty() or value.worlds.size()>3: return false
	if JSON.stringify(value).length()>32000000: return false
	var found={}; var ids=[]
	for w in value.worlds:
		if not w is Dictionary or not w.get("id") is String or w.id in ids: return false
		ids.append(w.id)
		if w.id=="home": found=w
	if found.is_empty(): return false
	for domain in ["ecology","watershed"]:
		if not found.get(domain,{}) is Dictionary: return false
		var regions=found.get(domain,{}).get("regions",{})
		if not regions is Dictionary: return false
		for region in regions.values():
			if not region is Dictionary or not region.get("component",{}) is Dictionary: return false
	if not found.get("modern",{}) is Dictionary: return false
	var receipts=found.get("modern",{}).get("family_receipts",{})
	if not receipts is Dictionary: return false
	for id in receipts:
		if not id is String or not Count.count_ok(receipts[id]): return false
	data=value.duplicate(true); home=data.worlds[ids.find("home")]; return true

func components() -> Array:
	var result=[]
	for domain in ["ecology","watershed"]:
		for region in home.get(domain,{}).get("regions",{}).values():
			if not region.get("component",{}).is_empty(): result.append(region.component)
	return result

func family_receipts() -> Dictionary:
	return home.get("modern",{}).get("family_receipts",{})
