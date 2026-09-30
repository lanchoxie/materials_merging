extends SceneTree
## v0.29 chemistry index: bundled MP crystals + PubChem molecules, honest matching, finds and save v25.
const State=preload("res://scripts/lab_state.gd")
const Index=preload("res://scripts/chem_index.gd")
var checks=0
var failures=[]
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var s=State.new()
	var game_elements: Dictionary=s.elements
	# Bundled data: sizes, provenance and the build-time filter hold for every entry.
	check(Index.crystals().size()>=1000 and Index.molecules().size()>=100,"index bundles about a thousand crystals and a hundred molecules")
	var bad_crystal=""
	for e in Index.crystals():
		var ok: bool=str(e.id).begins_with("mp-") and e.sites.size()==int(e.nsites) and int(e.nsites)<=24 and e.lattice.size()==3 and float(e.e_hull)<=0.1 and not str(e.get("spacegroup","")).is_empty()
		for site in e.sites: ok=ok and game_elements.has(str(site[0]))
		if not ok: bad_crystal=str(e.id); break
	check(bad_crystal.is_empty(),"every crystal is an MP entry of game elements, <= 24 sites, E_hull <= 0.1 (%s)" % bad_crystal)
	var bad_molecule=""
	for m in Index.molecules():
		var ok: bool=int(m.cid)>0 and m.atoms.size()<=20 and m.atoms.size()==m.positions.size() and not str(m.name).is_empty()
		for a in m.atoms: ok=ok and game_elements.has(str(a))
		for b in m.bonds: ok=ok and int(b[2])>=1 and int(b[2])<=3 and int(b[0])<m.atoms.size() and int(b[1])<m.atoms.size()
		if not ok: bad_molecule=str(m.name); break
	check(bad_molecule.is_empty(),"every molecule has a CID, game elements only, <= 20 atoms, bond orders 1-3 (%s)" % bad_molecule)
	check(Index.sources().size()==2 and str(Index.sources()[0].licence)=="CC BY 4.0" and str(Index.sources()[0].citation).contains("10.1063/1.4812323"),"sources carry the MP licence and citation")
	check(not Index.db_version().is_empty() and Index.db_version()!="unknown","MP database version is recorded")
	# Composition keys: occupancies count corner and face atoms as fractions.
	var pv: Dictionary=s.templates.perovskite
	check(Index.composition_key(pv.atoms,pv.occupancies,true)=="Br3Cs1Pb1","perovskite cell reduces to CsPbBr3 with occupancies")
	check(Index.composition_key(["O","H","H"])=="H2O1" and Index.composition_key(["Na","Cl","Na","Cl"],[],true)=="Cl1Na1","plain and reduced keys")
	# Every template is identified the right way.
	var water: Dictionary=s.structure_data({"template":"water","atoms":["O","H","H"]})
	check(water.index.get("match","")=="graph" and int(water.index.entry.cid)==962,"water template matches PubChem CID 962 by bond graph")
	var nacl: Dictionary=s.structure_data({"template":"sodium_chloride","atoms":["Na","Cl"]})
	check(nacl.index.get("match","")=="prototype" and str(nacl.index.entry.spacegroup)=="Fm-3m","NaCl template matches rock salt Fm-3m")
	var perovskite: Dictionary=s.structure_data({"template":"perovskite","atoms":pv.atoms})
	check(perovskite.index.get("kind","")=="crystal" and str(perovskite.index.entry.formula)=="CsPbBr3","perovskite template finds CsPbBr3")
	var unmatched: Array=[]
	for id in s.templates:
		var info: Dictionary=s.structure_data({"template":id,"atoms":s.templates[id].atoms})
		if not Index.is_find(info.get("index",{})): unmatched.append(id)
	check(unmatched.is_empty(),"every template is in the index: %s" % [unmatched])
	# Substitutions reach real compounds the templates do not cover.
	var licl: Dictionary=s.structure_data({"template":"sodium_chloride","atoms":["Li","Cl"]})
	check(not licl.known and licl.index.get("match","")=="prototype" and str(licl.index.entry.formula)=="LiCl" and int(licl.index.polymorphs)>=2,"Li for Na gives rock-salt LiCl with its polymorph count")
	check(licl.formula=="LiCl" and licl.name.contains("化学索引收录"),"an index match is named for what it is, while staying an exploration sample")
	var hbr: Dictionary=s.structure_data({"template":"hydrogen_chloride","atoms":["H","Br"]})
	check(hbr.index.get("match","")=="graph" and str(hbr.index.entry.name)=="溴化氢","Br for Cl gives hydrogen bromide")
	var thiourea: Dictionary=s.structure_data({"template":"urea","atoms":["C","S","N","N","H","H","H","H"]})
	check(thiourea.index.get("match","")=="graph" and str(thiourea.index.entry.name)=="硫脲","S for O in urea gives thiourea")
	# Honest misses.
	var ammonium: Dictionary=s.structure_data({"template":"methane","atoms":["N","H","H","H","H"]})
	check(ammonium.index.is_empty() and Index.summary(ammonium.index).contains("未收录 · 假说"),"NH4 (a cation, not a neutral molecule) stays a hypothesis")
	var chain: Dictionary=Index.identify({"atoms":["O","H","H"],"bonds":[[1,2,1],[0,1,1]]})
	check(chain.get("match","")=="isomer" and not Index.is_find(chain) and Index.summary(chain).contains("连接方式不同"),"H-H-O is flagged as an isomer of water, not a find")
	check(Index.identify({"atoms":["O","H","H"],"bonds":[[0,1,1],[0,2,1]],"mode":"art"}).is_empty(),"art mode never claims chemistry")
	var benzene: Dictionary=Index.identify({"atoms":["C","C","C","C","C","C","H","H","H","H","H","H"],"bonds":[[0,1,1],[1,2,2],[2,3,1],[3,4,2],[4,5,1],[5,0,2],[0,6,1],[1,7,1],[2,8,1],[3,9,1],[4,10,1],[5,11,1]]})
	check(benzene.get("match","")=="graph" and int(benzene.entry.cid)==241,"either Kekulé drawing of benzene matches")
	var cell: Dictionary=Index.identify({"atoms":["Cs","Cl"],"bonds":[],"periodic":true})
	check(cell.get("kind","")=="crystal" and str(cell.entry.formula)=="CsCl" and str(cell.entry.spacegroup)=="Pm-3m","a periodic sandbox cell matches by composition, most stable polymorph first")
	var sandbox: Dictionary=s.sandbox_reference({"name":"test","atoms":["H","Br"],"positions":[[0,0,0],[1.41,0,0]],"bonds":[[0,1,1]],"mode":"science","periodic":false})
	check(sandbox.index.get("match","")=="graph" and sandbox.formula=="HBr" and sandbox.name=="test","workshop builds are identified too and keep the player's name")
	# Properties never invent values.
	var rows: Array=Index.properties(licl.index.entry)
	var gap_row: Array=rows.filter(func(row): return row[0]=="带隙")
	check(rows.size()>=10 and gap_row.size()==1 and str(gap_row[0][1]).contains("eV"),"crystal cards show sourced properties")
	var missing: Array=Index.crystals().filter(func(e): return not e.has("bulk_gpa"))
	check(not missing.is_empty() and Index.properties(missing[0]).any(func(row): return row[0]=="体模量" and row[1]=="未测"),"missing moduli read 未测")
	check(Index.source_line(licl.index.entry).contains("Materials Project") and Index.source_line(hbr.index.entry).contains("PubChem CID"),"source lines name the database and id")
	# Economy: an index match earns double the exploration stipend; the first harvest pays once.
	var r: Dictionary=s.reactors[0]
	r.build_left=0.0; r.template="sodium_chloride"; r.atoms=["Li","Cl"]; r.positions=[[-1.3,0,0],[1.3,0,0]]
	var rate: Dictionary=s.income_breakdown(r)
	check(not rate.known and rate.index and is_equal_approx(float(rate.rate),float(s.economy.rules.exploration_rate)*Index.INDEX_RATE_FACTOR),"index matches earn double the exploration stipend")
	var before: float=s.coins
	r.stored_coins=5.0
	var text: String=s.harvest(0)
	check(text.contains("化学索引新收录") and s.index_found.has(str(licl.index.key)) and s.coins>=before+5.0+Index.REWARD_CRYSTAL,"first harvest of LiCl records the find and pays the reward: %s" % text)
	check(s.index_notice.get("formula","")=="LiCl","harvest raises an index notice")
	r.stored_coins=5.0; s.index_notice={}
	check(not s.harvest(0).contains("化学索引") and s.index_notice.is_empty(),"a second harvest does not pay again")
	check(Index.found_count(s,"crystal")==1 and Index.found_count(s,"molecule")==0,"found counts split by kind")
	check(Index.filtered("crystal",["Li","Cl"],true,s).size()==1 and Index.filtered("crystal",["Li","Cl"],false).size()>=2,"filters by element and by found")
	# Save v25 round trip; v24 saves settle what reactors already hold without paying.
	var path="res://saves/test_chem_index.json"
	for p in [path,path+".bak"]:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	check(s.save_game(path).begins_with("已保存"),"index save succeeds")
	var loaded=State.new()
	check(loaded.load_game(path) and loaded.index_found.has(str(licl.index.key)),"index finds survive save and load")
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	raw.index_found=[1,2]
	check(not loaded._validate_save(raw),"save rejects non-string index keys")
	raw.index_found=[]; raw.version=24; raw.erase("index_found")
	var file=FileAccess.open(path,FileAccess.WRITE); file.store_string(JSON.stringify(raw)); file.close()
	var legacy=State.new()
	check(legacy.load_game(path),"a v24 save loads")
	check(legacy.index_found.has(str(licl.index.key)) and absf(legacy.coins-float(raw.coins))<0.001,"v24 reactors settle into the index without a windfall")
	for p in [path,path+".bak"]:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	for st in [s,loaded,legacy]: st.close_science()
	print("CHEM INDEX: ",checks," checks, ",failures.size()," failures")
	if not failures.is_empty(): print(failures)
	quit(0 if failures.is_empty() else 1)
