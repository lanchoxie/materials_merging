extends RefCounted
## Conditional device calculations. A hypothetical input never becomes a measured property.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/player_materials.json"))
var thermal=preload("res://scripts/material_lab.gd").new()
var electrical=preload("res://scripts/electrical_lab.gd").new()

func number(value,low: float,high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=low and value<=high

func properties_valid(values) -> bool:
	if not values is Dictionary or values.size()!=rules.properties.size(): return false
	for key in rules.properties:
		if not values.has(key): return false
		var r=rules.properties[key]
		if values[key]!=null and not number(values[key],float(r.min),float(r.max)): return false
	return true

func unknown() -> Dictionary:
	var result={}
	for key in rules.properties: result[key]=null
	return result

func calculate(kind: String,mode: String,values: Dictionary) -> Dictionary:
	if kind not in ["sink","wire"] or mode not in ["same_size","same_mass"] or not properties_valid(values): return {}
	var key="conductivity_W_mK" if kind=="sink" else "resistivity_ohm_m"
	if values.density_kg_m3==null or values[key]==null: return {}
	var f=thermal.data.fixture if kind=="sink" else electrical.data.fixture
	var length=float(f.length_m) if kind=="sink" else float(f.loop_length_m)
	var area=float(f.area_m2) if mode=="same_size" else float(f.mass_kg)/(float(values.density_kg_m3)*length)
	var result={"length_m":length,"area_m2":area,"mass_kg":float(values.density_kg_m3)*area*length,"temperature_K":295.0 if kind=="sink" else 293.15}
	if kind=="sink":
		result.conductance_W_K=float(values[key])*area/length
		result.assembly_conductance_W_K=1.0/(1.0/result.conductance_W_K+float(f.contact_resistance_K_W)+float(f.external_resistance_K_W))
	else:
		result.resistance_ohm=float(values[key])*length/area
	return result

func canonical(value,world_values: bool=false) -> String:
	return preload("res://scripts/stable_identity.gd").canonical(value,world_values)

func build(record_id: String,kind: String,mode: String,values: Dictionary) -> Dictionary:
	var result=calculate(kind,mode,values)
	if result.is_empty(): return {}
	var inputs=values.duplicate(true)
	inputs["resistivity_ohm_m" if kind=="sink" else "conductivity_W_mK"]=null
	var proof={"model":rules.model,"record_id":record_id,"kind":kind,"mode":mode,"basis":"player_hypothesis","properties":inputs,"result":result}
	proof.id="custom:"+canonical(proof).sha256_text().substr(0,24)
	return proof

func valid(proof) -> bool:
	if proof is Dictionary and proof.get("basis")=="family_model": return preload("res://scripts/laminate_model.gd").new().valid(proof)
	if not proof is Dictionary or not proof.get("record_id") is String or proof.record_id.length()!=32 or not proof.get("properties") is Dictionary: return false
	var expected=build(proof.record_id,str(proof.get("kind","")),str(proof.get("mode","")),proof.properties)
	return not expected.is_empty() and electrical._same(proof,expected)

func valid_receipts(receipts) -> bool:
	if not receipts is Array or receipts.size()>int(rules.trial_placements): return false
	for id in receipts:
		if not id is String or not id.begins_with("custom:") or id.length()!=31: return false
	return true
