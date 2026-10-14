extends RefCounted
## Player-authored structures used by the 0.4 sandbox.
##
## This layer deliberately keeps authoring data separate from the production
## templates in materials.json. A sandbox specimen can contain any valid
## element and any topology; the production economy only recognizes a
## structure when it has an explicit science baseline.

const MAX_ATOMS: int = 64
const MAX_COORDINATE: float = 20.0
const MAX_NAME_LENGTH: int = 48
const StructureStart = preload("res://scripts/structure_start.gd")

var elements: Dictionary = {}
var baselines: Dictionary = {}

func _init(element_data: Dictionary = {}) -> void:
	elements = element_data.duplicate(true)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/baselines.json"))
	if parsed is Dictionary:
		baselines = parsed.get("baselines", {})

func baseline_ids() -> Array:
	var ids: Array = baselines.keys()
	ids.sort()
	return ids

func baseline(id: String) -> Dictionary:
	if not baselines.has(id):
		return {}
	return baselines[id].duplicate(true)

func new_structure(name: String = "未命名样品", baseline_id: String = "") -> Dictionary:
	var result: Dictionary = {
		"version": 1,
		"name": _clean_name(name),
		"baseline_id": baseline_id if baselines.has(baseline_id) else "",
		"atoms": [],
		"positions": [],
		"bonds": []
	}
	if baselines.has(baseline_id):
		var source: Dictionary = baselines[baseline_id]
		result.atoms = source.get("atoms", []).duplicate()
		result.positions = StructureStart.positions(source.get("positions", []), "sandbox:" + baseline_id)
		result.bonds = source.get("bonds", []).duplicate(true)
		# v0.52: a crystal baseline opens as a crystal. Before this the cell and the site weights
		# existed in materials.json but never reached the editor, so 钙钛矿 opened as a ball of atoms
		# with no cell lines at all (the user: 否则构建晶格原子有些困难).
		if bool(source.get("fixed_display_cell", false)) or source.has("cell"):
			if source.has("cell"):
				result["cell"] = source.cell.duplicate()
				result["periodic"] = true
			if source.has("cell_angles"): result["cell_angles"] = source.cell_angles.duplicate()
			if source.has("occupancies"): result["occupancies"] = source.occupancies.duplicate()
	return result

func from_baseline(id: String, name: String = "") -> Dictionary:
	if not baselines.has(id):
		return {}
	var title: String = name if not name.is_empty() else str(baselines[id].get("name", id))
	return new_structure(title, id)

static func formula(structure: Dictionary) -> String:
	var atoms: Array = structure.get("atoms", [])
	var counts: Dictionary = {}
	for symbol in structure.get("atoms", []):
		counts[symbol] = int(counts.get(symbol, 0)) + 1
	# Hill-style order makes collection cards easier to scan. For common
	# no-carbon teaching molecules, keep the central/non-hydrogen atom first
	# (NH3, HF, LiF, NaCl) while retaining the familiar H2O spelling.
	var order: Array = []
	if counts.has("C"):
		order.append("C")
	if counts.has("H"):
		if counts.has("C") or counts.has("O"):
			order.append("H")
	if not counts.has("C") and counts.has("N"):
		order.append("N")
	if order.is_empty() and counts.has("H"):
		order.append("H")
	var rest: Array = counts.keys()
	rest.sort()
	if order.is_empty():
		for atom in structure.get("atoms", []):
			if atom not in order:
				order.append(atom)
	for symbol in rest:
		if symbol not in order:
			order.append(symbol)
	var output := ""
	for symbol in order:
		var amount := int(counts[symbol])
		output += str(symbol) + ("" if amount == 1 else _subscript(amount))
	return output if not output.is_empty() else "探索空笼"

func complexity(structure: Dictionary) -> float:
	var atoms: Array = structure.get("atoms", [])
	var unique: Dictionary = {}
	for symbol in atoms:
		unique[symbol] = true
	var bonds: Array = structure.get("bonds", [])
	return clampf(float(atoms.size()) * 0.55 + float(unique.size()) * 0.30 + float(bonds.size()) * 0.12, 0.0, 4.0)

func add_atom(structure: Dictionary, symbol: String, position: Array = [0.0, 0.0, 0.0]) -> int:
	if not validate(structure) or not elements.has(symbol) or structure.atoms.size() >= MAX_ATOMS:
		return -1
	if not _valid_position(position):
		return -1
	structure.atoms.append(symbol)
	structure.positions.append([float(position[0]), float(position[1]), float(position[2])])
	structure.baseline_id = ""
	return structure.atoms.size() - 1

func remove_atom(structure: Dictionary, index: int) -> bool:
	if not validate(structure) or index < 0 or index >= structure.atoms.size():
		return false
	structure.atoms.remove_at(index)
	structure.positions.remove_at(index)
	var remaining: Array = []
	for bond in structure.bonds:
		var a := int(bond[0])
		var b := int(bond[1])
		if a == index or b == index:
			continue
		remaining.append([a - 1 if a > index else a, b - 1 if b > index else b, int(bond[2])])
	structure.bonds = remaining
	structure.baseline_id = ""
	return true

func set_position(structure: Dictionary, index: int, position: Array) -> bool:
	if not validate(structure) or index < 0 or index >= structure.atoms.size() or not _valid_position(position):
		return false
	structure.positions[index] = [float(position[0]), float(position[1]), float(position[2])]
	structure.baseline_id = ""
	return true

func toggle_bond(structure: Dictionary, first: int, second: int, order: int = 1) -> bool:
	if not validate(structure) or first < 0 or second < 0 or first >= structure.atoms.size() or second >= structure.atoms.size() or first == second or order < 1 or order > 3:
		return false
	var a := mini(first, second)
	var b := maxi(first, second)
	for i in range(structure.bonds.size()):
		var bond: Array = structure.bonds[i]
		if int(bond[0]) == a and int(bond[1]) == b:
			structure.bonds.remove_at(i)
			structure.baseline_id = ""
			return true
	structure.bonds.append([a, b, order])
	structure.baseline_id = ""
	return true

func rename(structure: Dictionary, name: String) -> bool:
	if not validate(structure):
		return false
	var cleaned := _clean_name(name)
	if cleaned.is_empty():
		return false
	structure.name = cleaned
	return true

func validate(structure: Dictionary) -> bool:
	if not structure is Dictionary:
		return false
	if not structure.get("atoms") is Array or not structure.get("positions") is Array or not structure.get("bonds") is Array:
		return false
	var atoms: Array = structure.atoms
	var positions: Array = structure.positions
	if atoms.size() > MAX_ATOMS or positions.size() != atoms.size():
		return false
	for i in range(atoms.size()):
		if not atoms[i] is String or not elements.has(atoms[i]) or not _valid_position(positions[i]):
			return false
	var seen: Dictionary = {}
	for bond in structure.bonds:
		if not bond is Array or bond.size() != 3:
			return false
		for component in bond:
			if not (component is int or component is float) or not is_finite(float(component)) or float(component)!=floor(float(component)): return false
		var a := int(bond[0])
		var b := int(bond[1])
		var order := int(bond[2]) if bond.size() > 2 else 1
		if a < 0 or b < 0 or a >= atoms.size() or b >= atoms.size() or a == b or order < 1 or order > 3:
			return false
		var key := "%d:%d" % [mini(a,b), maxi(a,b)]
		if seen.has(key):
			return false
		seen[key] = true
	if not structure.get("name", "") is String or str(structure.name).length() > MAX_NAME_LENGTH:
		return false
	if structure.get("mode","science") not in ["science","art"]: return false
	if not structure.get("periodic",false) is bool: return false
	if structure.has("cell"):
		if not structure.cell is Array or structure.cell.size()!=3: return false
		for a in structure.cell:
			if not (a is float or a is int) or not is_finite(float(a)) or float(a)<2.0 or float(a)>20.0: return false
	if structure.has("cell_angles"):
		# v0.52: α/β/γ let the cell be triclinic, monoclinic, hexagonal…; 90° reproduces the old
		# orthogonal behaviour exactly, so old saves and the orthogonal presets stay valid.
		if not structure.cell_angles is Array or structure.cell_angles.size()!=3: return false
		for a in structure.cell_angles:
			if not (a is float or a is int) or not is_finite(float(a)) or float(a)<30.0 or float(a)>150.0: return false
	if structure.bonds.size() > MAX_ATOMS * 6: return false
	return true

# --- Lattice (v0.52) ---------------------------------------------------------------------------
## The cell as three vectors in Cartesian space, by the standard convention (a along x, b in the
## xy plane). Used for every fractional ↔ Cartesian conversion, so the drawn cell and the site
## readout can never disagree.
static func lattice(cell: Array, angles: Array=[]) -> Basis:
	var a=float(cell[0]); var b=float(cell[1]); var c=float(cell[2])
	var al=deg_to_rad(float(angles[0]) if angles.size()>0 else 90.0)
	var be=deg_to_rad(float(angles[1]) if angles.size()>1 else 90.0)
	var ga=deg_to_rad(float(angles[2]) if angles.size()>2 else 90.0)
	var ca=cos(al); var cb=cos(be); var cg=cos(ga); var sg=sin(ga)
	var va=Vector3(a,0,0)
	var vb=Vector3(b*cg,b*sg,0)
	var cx=c*cb
	var cy=c*(ca-cb*cg)/maxf(sg,0.000001)
	var cz=sqrt(maxf(c*c-cx*cx-cy*cy,0.0))
	return Basis(va,vb,Vector3(cx,cy,cz))

## Cartesian → fractional, wrapped into [0,1).
##
## The convention is the one the presets already use: the cell is **centred on the origin**, so a
## corner atom at (a/2, b/2, c/2) is fractional (1,1,1) ≡ (0,0,0) and the body centre is (½,½,½).
## (The perovskite template has its 8 Cs corners at ±3.15 Å of a 6.3 Å cell, which only makes sense
## this way — assuming the cell started at 0 put every site in the wrong class.)
static func fractional(structure: Dictionary, at: Vector3) -> Vector3:
	var m=lattice(structure.get("cell",[6.0,6.0,6.0]),structure.get("cell_angles",[]))
	return wrap_frac(m.inverse() * at + Vector3(0.5,0.5,0.5))

static func cartesian(structure: Dictionary, frac: Vector3) -> Vector3:
	var m=lattice(structure.get("cell",[6.0,6.0,6.0]),structure.get("cell_angles",[]))
	return m * (frac - Vector3(0.5,0.5,0.5))

## Where a fractional coordinate sits in the cell, and the multiplicity it carries (a corner atom
## stands for 1/8 of an atom, a face atom for 1/2). This is the ⌈0/1⌉ question the user asked for.
static func site(frac: Vector3, tolerance: float=0.02) -> Dictionary:
	var on=0
	for axis in [frac.x,frac.y,frac.z]:
		var f=fposmod(axis,1.0)
		if f<tolerance or f>1.0-tolerance: on+=1
	match on:
		3: return {"name":"角点","share":0.125}
		2: return {"name":"棱心","share":0.25}
		1: return {"name":"面心","share":0.5}
	return {"name":"胞内","share":1.0}

## Fractional coordinates wrapped into [0,1): the crystal's own periodic boundary condition.
static func wrap_frac(frac: Vector3) -> Vector3:
	return Vector3(fposmod(frac.x,1.0),fposmod(frac.y,1.0),fposmod(frac.z,1.0))

## Snap a Cartesian position onto the cell boundary when it is within `tolerance` (in fractional
## units; the default ≈0.38 Å on a 6.3 Å cell, a bit more than one nudge step), and wrap it inside
## the cell otherwise: the "吸附到晶胞边界" option.
static func snap_to_cell(structure: Dictionary, at: Vector3, tolerance: float=0.06) -> Vector3:
	var m=lattice(structure.get("cell",[6.0,6.0,6.0]),structure.get("cell_angles",[]))
	var f=wrap_frac(m.inverse() * at + Vector3(0.5,0.5,0.5))
	var out=Vector3(f.x,f.y,f.z)
	for axis in 3:
		var v=out[axis]
		if v<tolerance: out[axis]=0.0
		elif v>1.0-tolerance: out[axis]=0.0   # 1.0 is 0.0 on the next cell: same site, no duplicate
	return m * (out - Vector3(0.5,0.5,0.5))

func serializable(structure: Dictionary) -> Dictionary:
	if not validate(structure):
		return {}
	var result: Dictionary = structure.duplicate(true)
	result["formula"] = formula(structure)
	result["complexity"] = complexity(structure)
	return result

func _valid_position(position) -> bool:
	if not position is Array or position.size() != 3:
		return false
	for value in position:
		if not (value is int or value is float) or not is_finite(float(value)) or absf(float(value)) > MAX_COORDINATE:
			return false
	return true

func _clean_name(value: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned.is_empty():
		return "未命名样品"
	return cleaned.left(MAX_NAME_LENGTH)

static func _subscript(value: int) -> String:
	var digits := ["₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉"]
	var text := str(value)
	var result := ""
	for character in text:
		result += digits[int(character)]
	return result
