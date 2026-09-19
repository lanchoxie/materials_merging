extends RefCounted
## Canonical identity across Godot StringName keys and JSON numeric representations.
static func canonical(value,world_values: bool=false) -> String:
	if value is Dictionary:
		# Dot-assigned keys can be StringName while JSON keys are String.
		var keys=[]
		for key in value: keys.append(str(key))
		keys.sort(); var parts=[]
		for key in keys: parts.append(JSON.stringify(str(key))+":"+canonical(value[key],world_values))
		return "{"+",".join(parts)+"}"
	if value is Array:
		var parts=[]
		for item in value: parts.append(canonical(item,world_values))
		return "["+",".join(parts)+"]"
	if value is float or value is int:
		# World identity ignores sub-micro-unit simulation residue; immutable design
		# IDs still identify tiny SI inputs. Property proofs use significant digits.
		if world_values: return "%.6f" % float(value)
		if float(value)==0: return "0"
		var exponent=int(floor(log(absf(float(value)))/log(10.0)))
		var mantissa=float(value)/pow(10,exponent)
		# JSON may round 0.9999999999999999 to 1; normalize decade boundaries.
		if absf(mantissa)>=10.0-0.5e-10: mantissa/=10; exponent+=1
		return "%.10f@%d" % [mantissa,exponent]
	return JSON.stringify(value)

