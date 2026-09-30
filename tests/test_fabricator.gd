extends SceneTree
## v0.30 "Fabricator": index crystals → pick heads (hardness) and solar panels (band gap); Fe/Sn smelting; save v26.
const State=preload("res://scripts/lab_state.gd")
const Fab=preload("res://scripts/fabricator.gd")
const Index=preload("res://scripts/chem_index.gd")
const Geology=preload("res://scripts/planet_geology.gd")
var checks=0
var failures=[]

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func best(formula: String) -> Dictionary:
	var list: Array=Index.crystals().filter(func(e): return str(e.formula)==formula)
	list.sort_custom(func(a,b): return float(a.e_hull)<float(b.e_hull))
	return list[0] if not list.is_empty() else {}

## A stored batch made the real way: a rock-salt reactor with substituted atoms, harvested into storage.
func harvest_crystal(s, atoms: Array, units: int) -> Dictionary:
	var r: Dictionary=s.reactors[0]
	r.build_left=0.0; r.template="sodium_chloride"; r.atoms=atoms; r.positions=[[-1.3,0,0],[1.3,0,0]]; r.pending=units; r.stored_coins=0.0
	s.harvest(0)
	for b in s.storage.batches:
		if str(b.get("formula",""))==Index.formula(s.structure_data(r).index.entry): return b
	return {}

func _run() -> void:
	var s=State.new()
	# Data: Fe and Sn are game elements, hematite and cassiterite have smelting processes, the index knows them.
	check(s.elements.has("Fe") and s.elements.has("Sn") and s.element_inventory.has("Fe"),"iron and tin are game elements")
	var p: Dictionary=s.refinery.process("hematite_iron"); var q: Dictionary=s.refinery.process("cassiterite_tin")
	check(p.inputs.has("hematite") and p.outputs.has("Fe") and q.inputs.has("cassiterite") and q.outputs.has("Sn"),"hematite and cassiterite smelt into Fe and Sn")
	s.planet.v2.nature.minerals["hematite"]=1; s.planet.v2.nature.minerals["coal"]=1
	var fe_before=int(s.element_inventory.Fe)
	check(s.refinery.start(s,"hematite_iron").contains("开始"),"iron smelting starts from mined ore")
	s.refinery.tick(s,float(p.seconds)+1.0)
	check(int(s.element_inventory.Fe)==fe_before+int(p.outputs.Fe),"the blast furnace yields iron units")
	check(not best("Fe").is_empty() and not best("SnO2").is_empty() and not best("Fe3C").is_empty(),"the rebuilt index covers iron and tin compounds")
	check(Index.crystals().all(func(e): return Array(str(e.chemsys).split("-")).all(func(x): return s.elements.has(x))),"every crystal uses game elements only")
	# Reference hardness (Broz et al. 2006) and rocks on the same scale.
	check(is_equal_approx(Fab.mohs_to_hv(3.0),1.49) and is_equal_approx(Fab.mohs_to_hv(7.0),12.2) and is_equal_approx(Fab.mohs_to_hv(9.0),19.6),"Mohs reference minerals map to their measured Vickers hardness")
	check(absf(Fab.hv_to_mohs(Fab.mohs_to_hv(6.5))-6.5)<0.001 and Fab.mohs_text(25.0)=="莫氏 >9","Vickers ↔ Mohs round-trips; above corundum reads > 9")
	check(is_equal_approx(Fab.rock_mohs("granite"),6.5) and is_equal_approx(Fab.rock_mohs("cassiterite"),6.5) and is_equal_approx(Fab.rock_mohs("halite"),2.5) and is_equal_approx(Fab.rock_mohs("clay"),-1.0),"rock Mohs: mixtures by main minerals, ranges by midpoint, loose ground ignored")
	var starter: float=float(Fab.rules().starter_pick.hv)
	check(Fab.dig_hits("limestone",3,starter)==3 and Fab.dig_hits("sand",1,0.1)==1,"the starter pick keeps soft-rock and loose-ground hits unchanged")
	check(Fab.dig_hits("granite",5,starter)==ceili(5.0*Fab.rock_hv("granite")/starter) and Fab.dig_hits("granite",5,starter)>5,"a pick softer than granite needs more hits")
	check(Fab.dig_hits("granite",5,20.0)==5 and Fab.dig_hits("granite",5,0.2)==15,"a harder pick digs at the base rate; the slowdown is capped at 3×")
	# Pick stats: Chen model where it applies, honest refusals where it does not.
	var aln: Dictionary=Fab.pick_stats(best("AlN")); var corundum: Dictionary=Fab.pick_stats(best("Al2O3"))
	check(aln.ok and absf(float(aln.hv)-16.3)<0.2 and corundum.ok and float(corundum.hv)>Fab.rock_hv("granite"),"AlN and corundum pick heads beat granite: %.1f / %.1f GPa" % [float(aln.get("hv",0)),float(corundum.get("hv",0))])
	var cu: Dictionary=Fab.pick_stats(best("Cu"))
	check(not cu.ok and str(cu.reason).contains("Pugh"),"ductile copper is outside the model (hardness depends on working)")
	check(not Fab.pick_stats(best("LiF")).ok and not Fab.pick_stats(best("NaCl")).ok,"alkali halides are refused as tools")
	var odd: Array=Index.crystals().filter(func(e): return float(e.get("bulk_gpa",0))>0 and float(e.get("shear_gpa",0))>1.5*float(e.get("bulk_gpa",0)))
	check(odd.is_empty() or not Fab.elastic(odd[0]).ok,"elastic data with an unphysical Poisson ratio is rejected")
	check(not Fab.pick_stats(Index.molecules()[0]).ok and not Fab.panel_stats(Index.molecules()[0]).ok,"molecules can't become gear")
	# Solar panels: detailed-balance limit at the MP gap.
	check(absf(Fab.sq_efficiency(1.25)-float(Fab.rules().sq_model.peak_efficiency))<0.002 and float(Fab.rules().sq_model.peak_efficiency)>0.29 and float(Fab.rules().sq_model.peak_efficiency)<0.32,"the SQ limit peaks near 30% around 1.25 eV")
	check(Fab.sq_efficiency(0.5)<Fab.sq_efficiency(1.2) and Fab.sq_efficiency(3.0)<Fab.sq_efficiency(1.6),"too small or too large a gap lowers the limit")
	check(not Fab.panel_stats(best("Cu")).ok and Fab.panel_stats(best("Cu2O")).ok,"metals can't be panels; Cu2O can")
	# Crafting from a real harvested batch.
	s.coins=1000.0
	var batch: Dictionary=harvest_crystal(s,["Al","N"],5)
	check(not batch.is_empty() and str(batch.get("index",""))==str(best("AlN").key),"a harvested AlN batch carries its index key")
	var found: Dictionary=s.batch_index(batch)
	check(Index.is_find(found) and str(found.entry.formula)=="AlN","the batch is identified as AlN")
	var salt: Dictionary=harvest_crystal(s,["Na","Cl"],1).duplicate(true); salt.erase("index"); salt.erase("index_match")
	check(str(s.batch_index(salt).get("entry",{}).get("formula",""))=="NaCl","pre-v0.30 batches of a known template are identified from their work")
	var coins: float=s.coins; var units=int(batch.quantity)
	var quote: Dictionary=s.fabricator.quote(s,str(batch.id),"pick")
	check(quote.ready and quote.message.contains("GPa"),"the pick quote shows the hardness: %s" % quote.message)
	var made: String=s.fabricator.craft(s,str(batch.id),"pick")
	check(made.contains("AlN") and made.contains("已换上") and s.fabricator.items.size()==1,"crafting a harder pick equips it: %s" % made)
	check(is_equal_approx(s.coins,coins-float(Fab.rules().pick.coins)) and int(s.storage.batch(str(batch.id)).get("quantity",0))==units-int(Fab.rules().pick.units),"crafting costs units and coins")
	check(is_equal_approx(s.planet.v2.nature.pick_hv,float(aln.hv)) and s.planet.v2.nature.pick_name=="AlN镐","the equipped pick reaches the planet")
	check(s.fabricator.quote(s,str(batch.id),"pick").message.contains("只有"),"too few units are explained")
	check(not s.fabricator.quote(s,str(batch.id),"panel").ready,"AlN's 4 eV gap still quotes, but the batch is short of units")
	# Digging on the planet uses the equipped pick.
	var v=s.planet.v2; var n=v.nature; var t=v.construction.terrain
	var cell=Vector3i(30,3,30); n.set_voxel(cell,"granite",t)
	var hits=int(Geology.info("granite").hits)
	for i in range(hits-1): n.dig({"voxel":cell},v)
	var last: String=n.dig({"voxel":cell},v)
	check(not t.solid(cell) and last.contains("花岗岩"),"granite breaks at its base hits with the AlN pick: %s" % last)
	s.fabricator.equip(s,"")
	check(s.planet.v2.nature.pick_hv==starter,"switching back to the starter pick")
	n.set_voxel(cell,"granite",t)
	var slow: String=""
	for i in range(hits): slow=n.dig({"voxel":cell},v)
	check(t.solid(cell) and slow.contains("比岩石软"),"the starter pick is slower in granite: %s" % slow)
	# Solar panel from a harvested Cu2O-free route: CsCl crystal is an insulator; use a rock-salt PbS (galena) batch.
	var pbs: Dictionary=harvest_crystal(s,["Pb","S"],8)
	var speed: float=s.refinery.speed()
	var panel: String=s.fabricator.craft(s,str(pbs.id),"panel")
	check(panel.contains("太阳能板") and panel.contains("精炼厂屋顶") and s.fabricator.panels.size()==1,"a PbS panel is installed on the refinery: %s" % panel)
	check(s.refinery.speed()>speed and is_equal_approx(s.refinery.speed(),speed*(1.0+s.fabricator.refinery_gain())),"panels speed up the refinery by their efficiency")
	var pid=str(s.fabricator.panels[0])
	s.fabricator.toggle_panel(s,pid)
	check(s.fabricator.panels.is_empty() and is_equal_approx(s.refinery.speed(),speed),"removing the panel restores the speed")
	s.fabricator.toggle_panel(s,pid)
	# Save v26 round trip and validation.
	var path="res://saves/test_fabricator.json"
	for f in [path,path+".bak"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	check(s.save_game(path).begins_with("已保存"),"fabricator save succeeds")
	var loaded=State.new()
	check(loaded.load_game(path) and loaded.fabricator.items.size()==2 and loaded.fabricator.panels.size()==1 and is_equal_approx(loaded.refinery.speed(),s.refinery.speed()),"gear survives save and load, and the refinery speed is restored")
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var bad: Dictionary=raw.duplicate(true); bad.fabricator.pick=pid
	check(not loaded._validate_save(bad),"a panel can't be equipped as a pick")
	bad=raw.duplicate(true); bad.fabricator.panels=[pid,pid]
	check(not loaded._validate_save(bad),"a panel can't take two slots")
	raw.version=25; raw.erase("fabricator")
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(raw)); file.close()
	var legacy=State.new()
	check(legacy.load_game(path) and legacy.fabricator.items.is_empty() and legacy.planet.v2.nature.pick_hv==starter,"a v25 save loads with the starter pick")
	for f in [path,path+".bak"]:
		if FileAccess.file_exists(f): DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	for st in [s,loaded,legacy]: st.close_science()
	print("FABRICATOR: ",checks," checks, ",failures.size()," failures")
	if not failures.is_empty(): print(failures)
	quit(0 if failures.is_empty() else 1)
