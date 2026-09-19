extends RefCounted
## A two-phase assembly model, never an atomistic alloy predictor.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/laminates.json"))
var thermal=preload("res://scripts/material_lab.gd").new()
const Identity=preload("res://scripts/stable_identity.gd")
func counts(work: Dictionary) -> Dictionary:
	var result={"Cu":0,"Al":0}
	for atom in work.get("atoms",[]):
		if atom not in ["Cu","Al"]: return {}
		result[atom]+=1
	return result if result.Cu>0 and result.Al>0 and result.Cu+result.Al<=64 else {}
func valid_counts(c) -> bool:
	if not c is Dictionary or c.size()!=2: return false
	for key in ["Cu","Al"]:
		if not preload("res://scripts/island_storage.gd").count_ok(c.get(key)) or c[key]<1: return false
	return c.Cu+c.Al<=64
func build(record_id: String,c: Dictionary,orientation: String,mode: String) -> Dictionary:
	if not valid_counts(c) or orientation not in ["parallel","series"] or mode not in ["same_size","same_mass"]: return {}
	var cu=thermal.data.materials.copper; var al=thermal.data.materials.aluminum
	var vc=float(c.Cu)*float(rules.molar_mass_g_mol.Cu)/float(cu.density_kg_m3)
	var va=float(c.Al)*float(rules.molar_mass_g_mol.Al)/float(al.density_kg_m3)
	var fraction=vc/(vc+va)
	var density=fraction*float(cu.density_kg_m3)+(1-fraction)*float(al.density_kg_m3)
	var parallel=fraction*float(cu.conductivity_W_mK)+(1-fraction)*float(al.conductivity_W_mK)
	var series=1.0/(fraction/float(cu.conductivity_W_mK)+(1-fraction)/float(al.conductivity_W_mK))
	var k=parallel if orientation=="parallel" else series
	var f=thermal.data.fixture; var length=float(f.length_m)
	var area=float(f.area_m2) if mode=="same_size" else float(f.mass_kg)/(density*length)
	var mass=density*length*area; var g=k*area/length
	var result={"temperature_K":rules.temperature_K,"length_m":length,"area_m2":area,"mass_kg":mass,"conductance_W_K":g,"assembly_conductance_W_K":1.0/(1.0/g+float(f.contact_resistance_K_W)+float(f.external_resistance_K_W))}
	var feed={"Cu":float(cu.density_kg_m3)*fraction*length*area,"Al":float(al.density_kg_m3)*(1-fraction)*length*area}
	var proof={"model":rules.model,"record_id":record_id,"kind":"sink","mode":mode,"basis":"family_model","counts":c.duplicate(true),"orientation":orientation,"volume_fraction_Cu":fraction,"bounds_W_mK":[series,parallel],"sources":rules.sources.duplicate(true),"properties":{"density_kg_m3":density,"conductivity_W_mK":k,"resistivity_ohm_m":null},"result":result,"feed_kg":feed}
	proof.id="custom:"+Identity.canonical(proof).sha256_text().substr(0,24); return proof
func valid(proof) -> bool:
	if not proof is Dictionary or not proof.get("record_id") is String or proof.record_id.length()!=32 or not valid_counts(proof.get("counts")): return false
	var expected=build(proof.record_id,proof.counts,str(proof.get("orientation","")),str(proof.get("mode","")))
	return not expected.is_empty() and preload("res://scripts/electrical_lab.gd").new()._same(proof,expected)
func name(d: Dictionary) -> String:
	return "铜铝层芯 · %s · %s · %d:%d" % ["顺流" if d.orientation=="parallel" else "横层","等重" if d.mode=="same_mass" else "等尺寸",d.counts.Cu,d.counts.Al]
