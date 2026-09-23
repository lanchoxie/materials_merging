extends SceneTree
const State=preload("res://scripts/lab_state.gd")
const Program=preload("res://scripts/planet_program.gd")
const Same=preload("res://tests/fixtures_v09.gd")
var checks=0
var failures=[]
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func copy(v): return JSON.parse_string(JSON.stringify(v))
func _initialize() -> void:
	var s=State.new(); var p=s.planet
	check(not p.serialize().has("worlds") and p.serialize().version==11 and p.retired_planet.is_empty(),"new games create no legacy worlds")
	var before=p.serialize(); var coins=s.coins
	for action in ["deploy","fork","reset_trial","select","activate_modern","modern","activate_industry","industry","activate_habitat","habitat","activate_village","village","activate_watershed","watershed","ecology","pause","step_world","step_pair"]:
		p.command(s,action,{"world_id":"home","token":p.shipment_serial})
	check(Same.same(before,p.serialize()) and coins==s.coins,"retired commands cannot simulate debit or reward")
	for version in ["011","012","0121","013","014","015","016","017","018"]:
		var file="res://tests/fixtures/planet_v"+version+".json"
		var data=JSON.parse_string(FileAccess.get_file_as_string(file)); var loaded=Program.new()
		check(loaded.restore(data,s),"old planet fixture migrates "+version)
		var saved=loaded.serialize()
		check(not saved.has("worlds") and Same.same(saved.retired_planet,data.worlds),"old world kept only as inert data "+version)
		check(Same.same(saved.products,data.products) and Same.same(saved.job,data.job) and saved.feed==data.feed,"factory holdings unchanged "+version)
		var old=copy(saved.retired_planet); loaded.tick(30,1)
		check(Same.same(old,loaded.retired_planet),"background tick never advances archived world "+version)
		check(Program.new().restore(copy(loaded.serialize()),s),"migrated data reloads "+version)
	var full=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/game_v019.json"))
	var migrated=Program.new(); check(migrated.restore(full.planet,s),"real game with installed paid layers migrates")
	check(Same.same(migrated.laminates.serialize(),full.planet.laminates) and Same.same(migrated.materials.serialize(),full.planet.materials),"research stock installed accounting and work in progress preserved")
	var bad=migrated.serialize(); bad.laminates.stock[bad.laminates.installed.keys()[0]]+=1
	check(not Program.new().restore(copy(bad),s),"archived installation cannot also become free stock")
	bad=migrated.serialize(); bad.retired_planet.worlds[0].modern.family_receipts={}
	check(not Program.new().restore(copy(bad),s),"installed ledger remains checked despite retired simulation")
	var real=JSON.parse_string(FileAccess.get_file_as_string("res://saves/save.json"))
	check(s._validate_save(real),"player save validates without changing its file")
	check(Program.new().restore(copy(before),s),"fresh schema roundtrip")
	s.close_science()
	print("PLANET_RETIREMENT: %d checks, %d failures" % [checks,failures.size()])
	FileAccess.open("res://artifacts/v021-retirement-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
