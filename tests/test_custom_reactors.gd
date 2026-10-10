extends SceneTree
## v0.41.1 (user request): custom structures are first-class reactors. A custom molecule that matches
## a real PubChem 3D entry gets a reference geometry (match %, target bond lengths, income like a
## preset); designs are saved as 我的炉型 and built straight onto an empty plot (also from a blank
## reactor); the save keeps them and rejects malformed ones.
const State=preload("res://scripts/lab_state.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

## Methanol in the player's own atom order (C first), at rough starting coordinates.
func methanol(scale: float=1.0) -> Dictionary:
	return {"version":1,"name":"我的甲醇","baseline_id":"","atoms":["C","O","H","H","H","H"],
		"positions":[[0,0,0],[1.43*scale,0,0],[-0.36,1.0,0],[-0.36,-0.5,0.87],[-0.36,-0.5,-0.87],[1.75*scale,0.9,0]],
		"bonds":[[0,1,1],[0,2,1],[0,3,1],[0,4,1],[1,5,1]],"mode":"science","periodic":false,"cell":[6.0,6.0,6.0]}

func _initialize() -> void:
	var s=State.new()
	var work=methanol()
	var info: Dictionary=s.sandbox_reference(work)
	check(not info.known and str(info.get("geometry_ref","")).begins_with("pubchem:"),"custom methanol gets a PubChem 3D reference geometry")
	var co=-1.0
	for b in info.bonds:
		if (int(b[0])==0 and int(b[1])==1) or (int(b[0])==1 and int(b[1])==0): co=float(b[2])
	check(co>1.35 and co<1.50,"the reference C–O bond is real (%.3f Å)" % co)
	check(info.angles.size()>=6,"angles come from the reference too (%d)" % info.angles.size())
	var probe=s.design_probe(work); var q1=s.quality(probe)
	check(q1>0.3 and q1<1.0,"a rough build has a partial match (%d%%)" % roundi(q1*100))
	var tuned=work.duplicate(true); tuned.positions=info.positions.duplicate(true)
	var q2=s.quality(s.design_probe(tuned))
	check(q2>0.97,"at the reference coordinates the match is ~100%% (%d%%)" % roundi(q2*100))
	var stretched=methanol(1.6)
	check(s.quality(s.design_probe(stretched))<q1,"stretching the C–O bond lowers the match")
	var rate=s.income(s.design_probe(tuned))
	check(rate>float(s.economy.rules.exploration_rate)*2.0,"a tuned real molecule earns more than the exploration stipend (%.2f/s)" % rate)
	var art=work.duplicate(true); art.mode="art"
	check(not s.sandbox_reference(art).has("geometry_ref"),"atom art never claims a reference")
	# --- 我的炉型.
	check(s.save_player_template(work).contains("我的炉型") and s.player_templates.size()==1,"a design is saved as 我的炉型")
	check(s.save_player_template(tuned).contains("更新") and s.player_templates.size()==1,"saving the same name updates it")
	var other=methanol(); other.name="另一个"
	s.save_player_template(other)
	check(s.player_templates.size()==2 and str(s.player_templates[1].id)!=str(s.player_templates[0].id),"different names get their own ids")
	check(s.remove_player_template(str(s.player_templates[1].id)).contains("删除") and s.player_templates.size()==1,"a design can be removed")
	# --- Building a custom reactor on an empty plot.
	var plot=-1
	for i in range(s.plots.size()):
		if s.plots[i].unlocked and s.plots[i].kind=="empty": plot=i; break
	check(plot>=0,"an empty plot exists")
	check(not s.custom_reactor_quote(plot,tuned).ready,"building needs a doctor and elements")
	s.campus.people.append(s.campus._new_person("doctor",-1,true))
	s.element_inventory["C"]=5; s.element_inventory["O"]=5; s.element_inventory["H"]=10; s.coins=500
	var q=s.custom_reactor_quote(plot,tuned)
	check(q.ready and int(q.required.C)==1 and int(q.required.H)==4,"the quote asks for 100 coins and every atom: "+str(q.message))
	var n=s.reactors.size()
	check(s.place_custom_reactor(plot,tuned).contains("开始建造") and s.reactors.size()==n+1,"a custom reactor is built directly")
	var r: Dictionary=s.reactors.back()
	check(r.get("sandbox",false) and s.plots[plot].kind=="reactor" and int(s.plots[plot].rid)==s.reactors.size()-1,"it is a real reactor on that plot")
	check(s.quality(r)>0.97 and is_equal_approx(s.coins,400.0) and int(s.element_inventory.C)==4,"it keeps the tuned match; coins and atoms were paid")
	r.build_left=0.0
	check(s.income(r)>float(s.economy.rules.exploration_rate)*2.0,"it earns like a preset once built")
	# --- Save.
	var path="res://saves/custom-reactors.json"
	check(s.save_game(path).begins_with("已保存"),"the game saves")
	var loaded=State.new()
	check(loaded.load_game(path) and loaded.player_templates.size()==1 and loaded.player_templates[0].work.atoms==tuned.atoms,"我的炉型 survive a save")
	var text=FileAccess.get_file_as_string(ProjectSettings.globalize_path(path))
	var data=JSON.parse_string(text)
	data.player_templates[0].work.atoms=["Xx"]
	check(not State.new()._validate_save(data),"a malformed design is rejected")
	data=JSON.parse_string(text); data.erase("player_templates")
	check(State.new()._validate_save(data),"saves from before v0.41.1 still load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path)); DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
	if failures.is_empty(): print("CUSTOM REACTORS OK (%d checks)" % checks); quit(0)
	else: print("CUSTOM REACTORS FAILED: ",failures); quit(1)
