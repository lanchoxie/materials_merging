extends RefCounted
## SI reference calculations. No economy, ecology, UI or inferred unknown properties.
var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/material_lab.json"))

func is_component(id: String) -> bool:
	return data.designs.has(id)

func calculate(material: String,mode: String) -> Dictionary:
	if not data.materials.has(material) or mode not in ["same_size","same_mass"]: return {}
	var m=data.materials[material]; var f=data.fixture
	var length=float(f.length_m); var area=float(f.area_m2)
	if mode=="same_mass": area=float(f.mass_kg)/(float(m.density_kg_m3)*length)
	var g=float(m.conductivity_W_mK)*area/length
	var assembly=1.0/(1.0/g+float(f.contact_resistance_K_W)+float(f.external_resistance_K_W))
	return {"model":data.model,"source":data.source.id,"material":material,"mode":mode,"length_m":length,"area_m2":area,"mass_kg":float(m.density_kg_m3)*area*length,"conductance_W_K":g,"heat_flow_W":g*(float(f.hot_K)-float(f.cold_K)),"assembly_conductance_W_K":assembly}

func design(id: String) -> Dictionary:
	if not is_component(id): return {}
	var d=data.designs[id]
	return calculate(str(d.material),str(d.mode))

func fits(id: String,site: String) -> bool:
	if not is_component(id) or not data.device_mounts.has(site): return false
	var r=design(id); var slot=data.device_mounts[site]
	return r.area_m2<=float(slot.max_area_m2)+0.0000000001 and r.mass_kg<=float(slot.max_mass_kg)+0.0000000001

func proof(mode: String) -> Dictionary:
	if mode not in ["same_size","same_mass"]: return {}
	return {"batch_id":"reference:"+str(data.model)+":"+mode,"method":data.model,"source":data.source.id,"mode":mode,"copper":calculate("copper",mode),"aluminum":calculate("aluminum",mode)}

func valid_report(report,mode: String) -> bool:
	return report is Dictionary and not proof(mode).is_empty() and _same(report,proof(mode))

func valid_component(item) -> bool:
	if not item is Dictionary: return false
	if item.is_empty(): return true
	if not item.get("recipe") is String or not is_component(item.recipe): return false
	if not (item.get("id") is int or item.get("id") is float) or not is_finite(float(item.id)) or item.id<0 or item.id!=floor(float(item.id)): return false
	var d=data.designs[item.recipe]
	return item.get("recipe_version")==d.version and item.get("source_batch")==proof(str(d.mode)).batch_id

func _same(a,b) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_finite(float(a)) and absf(float(a)-float(b))<0.00000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in b:
			if not a.has(key) or not _same(a[key],b[key]): return false
		return true
	return typeof(a)==typeof(b) and a==b
