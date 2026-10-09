extends RefCounted
## v0.36 标本图鉴: the analyser records each species once, and again in every new biome where it is
## found. Cards name the real prototype; nothing is invented beyond the game species. Data:
## data/specimens.json. XP comes through the 岛主 legacy score (count() and biomes()).
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/specimens.json"))
var found: Dictionary={}   # species id -> [biome ids]
var revision=0

## Returns a line to add to the analyser text ("" when nothing new).
func record(species: String,biome: String) -> String:
	if not rules.species.has(species): return ""
	var spec: Dictionary=rules.species[species]
	if not found.has(species):
		found[species]=[biome]; revision+=1
		return "\n★ 新标本！%s · 原型 %s\n%s\n标本图鉴 %d/%d" % [spec.name,spec.prototype,spec.facts,found.size(),rules.species.size()]
	if biome!="" and biome not in found[species]:
		found[species].append(biome); revision+=1
		return "\n★ 新栖地记录：%s也生活在这片%s" % [spec.name,biome]
	return ""

func count() -> int:
	return found.size()

func biomes() -> int:
	var n=0
	for id in found: n+=maxi(0,found[id].size()-1)
	return n

func serialize() -> Dictionary:
	return {"version":1,"found":found.duplicate(true)}

func restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("found") is Dictionary: return false
	for id in data.found:
		var list=data.found[id]
		if not rules.species.has(id) or not list is Array or list.is_empty() or list.size()>8: return false
		for b in list:
			if not b is String or b.length()>16: return false
	found=data.found.duplicate(true); revision+=1
	return true
