extends SceneTree
const State=preload("res://scripts/lab_state.gd")
var checks=0
var failures=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	var s=State.new()
	var reference=preload("res://scripts/specimen.gd")
	for source in ["hydrogen","hydrogen_fluoride","sodium_chloride","lithium_fluoride","hydrogen_chloride"]:
		for atoms in [["H","Cl"],["Cl","H"]]:
			var info=reference.describe(source,atoms,s.templates,s.elements)
			check(info.known and info.reference_id=="hydrogen_chloride",source+" -> HCl recognized in either order")
			var r={"template":source,"atoms":atoms,"positions":info.positions,"level":1,"build_left":0.0}
			check(is_equal_approx(s.quality(r),1.0),"geometry is remapped to player indices")
			check(s.income_breakdown(r).rate==s.income_breakdown({"template":"hydrogen_chloride","atoms":atoms,"positions":info.positions,"level":1,"build_left":0.0}).rate,"same structure, same income")
	# All compatible starting labels must agree with the graph resolver.
	for from_id in s.templates:
		var base: Dictionary=s.templates[from_id]
		if base.has("cell"): continue
		for to_id in s.templates:
			var target: Dictionary=s.templates[to_id]
			if target.has("cell") or base.atoms.size()!=target.atoms.size(): continue
			var work={"atoms":target.atoms,"positions":base.positions,"bonds":base.bond_orders,"periodic":false,"mode":"science"}
			check(reference.reference_id(from_id,target.atoms,s.templates)==s.sandbox_reference(work).reference_id,"template / sandbox consistency: "+from_id+" -> "+to_id)
	check(reference.reference_id("oxygen",["H","Cl"],s.templates).is_empty(),"double bonds are not silently changed to single bonds")
	check(reference.reference_id("perovskite",["H","Cl"],s.templates).is_empty(),"crystal topology cannot become a diatomic reference")
	var disconnected=s.sandbox_from_baseline("hydrogen"); disconnected.atoms=["H","Cl"]; disconnected.bonds=[]
	check(not s.sandbox_reference(disconnected).known,"disconnected atoms remain unknown")
	# A pre-fix inventory keeps its identity and amount but receives corrected reference metadata.
	var old=s.sandbox_from_baseline("hydrogen")
	old.atoms=["H","Cl"]; old.positions=s.templates.hydrogen_chloride.positions.duplicate(true)
	s.storage.batches=[{"id":"legacy-HCl","quantity":4,"reference":"","quality":0.0,"formula":"探索组合","name":"未知","work":old}]
	var wallet=s.coins
	s._repair_legacy_references()
	check(s.storage.batches[0].reference=="hydrogen_chloride" and is_equal_approx(s.storage.batches[0].quality,1.0),"legacy HCl metadata repaired")
	check(s.storage.batches[0].id=="legacy-HCl" and s.storage.batches[0].quantity==4 and s.coins==wallet,"migration neither duplicates stock nor pays retroactive income")
	s._repair_legacy_references()
	check(s.storage.batches.size()==1 and s.storage.batches[0].quantity==4,"migration is idempotent")
	var path="res://saves/consistency-migration-test.json"
	s.storage.batches[0].reference=""; s.storage.batches[0].quality=0.0
	s.save_game(path)
	var saved=JSON.parse_string(FileAccess.get_file_as_string(path)); saved.version=9
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(saved))
	var loaded=State.new()
	check(loaded.load_game(path) and loaded.storage.batches[0].reference=="hydrogen_chloride","loading v9 executes migration")
	loaded.save_game(path)
	check(loaded.load_game(path) and loaded.storage.batches[0].quantity==4,"v10 round trip retains corrected batch")
	loaded.close_science()
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	s.close_science()
	print("CONSISTENCY: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
