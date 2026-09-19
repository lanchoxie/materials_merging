extends RefCounted
## SI reference fixture; gameplay budgets and device efficiencies live elsewhere.
var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/electrical_lab.json"))

func calculate(material: String,mode: String) -> Dictionary:
	if not data.materials.has(material) or mode not in ["same_size","same_mass"]: return {}
	var m=data.materials[material]; var f=data.fixture
	var area=float(f.area_m2) if mode=="same_size" else float(f.mass_kg)/(float(m.density_kg_m3)*float(f.loop_length_m))
	var resistance=float(m.resistivity_ohm_m)*float(f.loop_length_m)/area
	var flow=circuit(resistance,float(f.load_W),float(f.voltage_V),INF)
	return {"model":data.model,"source":m.source,"material":material,"mode":mode,"temperature_K":m.temperature_K,"area_m2":area,"mass_kg":float(m.density_kg_m3)*area*float(f.loop_length_m),"resistance_ohm":resistance,"conductivity_S_m":1.0/float(m.resistivity_ohm_m),"current_A":flow.current_A,"load_W":flow.load_W,"wire_loss_W":flow.wire_loss_W}

func circuit(resistance: float,rated_load: float,voltage: float,budget: float) -> Dictionary:
	if not is_finite(resistance) or resistance<=0 or not is_finite(rated_load) or rated_load<=0 or not is_finite(voltage) or voltage<=0 or is_nan(budget) or budget<0: return {}
	var load_r=voltage*voltage/rated_load
	var current=minf(voltage/(resistance+load_r),sqrt(budget/(resistance+load_r)))
	return {"current_A":current,"load_W":current*current*load_r,"wire_loss_W":current*current*resistance,"source_W":current*current*(resistance+load_r)}

func design(id: String) -> Dictionary:
	if not data.designs.has(id): return {}
	var d=data.designs[id]; return calculate(str(d.material),str(d.mode))

func proof(mode: String) -> Dictionary:
	if mode not in ["same_size","same_mass"]: return {}
	return {"batch_id":"reference:"+str(data.model)+":"+mode,"method":data.model,"mode":mode,"copper":calculate("copper",mode),"aluminum":calculate("aluminum",mode)}

func valid_report(report,mode: String) -> bool:
	return report is Dictionary and not proof(mode).is_empty() and _same(report,proof(mode))

func _same(a,b) -> bool:
	# SI values range from micrometre areas to 10^7 S/m; tolerate JSON rounding,
	# without applying a large absolute tolerance to tiny physical quantities.
	if (a is int or a is float) and (b is int or b is float):
		return is_finite(float(a)) and absf(float(a)-float(b))<=maxf(1e-20,absf(float(b))*1e-12)
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in b:
			if not a.has(key) or not _same(a[key],b[key]): return false
		return true
	return typeof(a)==typeof(b) and a==b
