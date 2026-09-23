extends RefCounted
## Initial guesses are separate from the immutable reference geometry.
## A deterministic, positive expansion avoids overlaps and free perfect samples.
## Only new recipe instances call this; loading or editing never reseeds them.

static func positions(reference: Array, variant: String) -> Array:
	if reference.size() < 2: return reference.duplicate(true)
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/structure_start.json"))
	var random := RandomNumberGenerator.new()
	random.seed = variant.hash()
	var stretch := Vector3.ZERO
	var shear := Vector3.ZERO
	for axis in range(3):
		stretch[axis] = random.randf_range(float(rules.stretch_min), float(rules.stretch_max))
		shear[axis] = random.randf_range(-float(rules.shear_max), float(rules.shear_max))
	var center := Vector3.ZERO
	for point in reference: center += Vector3(point[0], point[1], point[2])
	center /= reference.size()
	var result: Array = []
	for point in reference:
		var p := Vector3(point[0], point[1], point[2]) - center
		var guess := center + Vector3(
			stretch.x * p.x + shear.x * p.y + shear.z * p.z,
			shear.x * p.x + stretch.y * p.y + shear.y * p.z,
			shear.z * p.x + shear.y * p.y + stretch.z * p.z)
		result.append([guess.x, guess.y, guess.z])
	return result
