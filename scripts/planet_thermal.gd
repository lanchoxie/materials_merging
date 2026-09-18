extends RefCounted
## Tunable dimensionless device rule. SI fixture math stays in MaterialLab.
const Lab=preload("res://scripts/material_lab.gd")
var lab=Lab.new()

func initialize_region(r: Dictionary) -> void:
	r.merge({"component":{},"heat":0.0,"cooling":false,"trips":0})

func step(r: Dictionary) -> Dictionary:
	var rule=lab.data.thermal_game; var was_cooling=bool(r.cooling)
	if r.cooling and r.heat<=float(rule.restart): r.cooling=false
	var dose=0.0
	if r.device and r.enabled and not r.cooling: dose=minf(float(r.flow),minf(r.gas,r.energy))
	var cooling=float(rule.passive_cooling)
	if not r.component.is_empty(): cooling+=float(lab.design(str(r.component.recipe)).assembly_conductance_W_K)*float(rule.conductance_scale)
	r.heat=clampf(float(r.heat)+float(rule.generation_per_flow_squared)*dose*dose-cooling,0,float(rule.maximum))
	if not r.cooling and r.heat>=float(rule.cutoff): r.cooling=true; r.trips=int(r.trips)+1
	return {"dose":dose,"stopped":not was_cooling and r.cooling,"resumed":was_cooling and not r.cooling}

func valid(r: Dictionary) -> bool:
	if not r.get("device") is bool: return false
	if not lab.valid_component(r.get("component")) or not r.get("cooling") is bool: return false
	if not (r.get("heat") is int or r.get("heat") is float) or not is_finite(float(r.heat)) or r.heat<0 or r.heat>float(lab.data.thermal_game.maximum): return false
	if not (r.get("trips") is int or r.get("trips") is float) or not is_finite(float(r.trips)) or r.trips<0 or r.trips>10000000 or r.trips!=floor(float(r.trips)): return false
	if not r.device and (not r.component.is_empty() or r.heat!=0 or r.cooling or r.trips!=0): return false
	return true
