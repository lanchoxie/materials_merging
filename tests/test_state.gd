extends SceneTree

const Fixtures=preload("res://tests/fixtures_v09.gd")
const State = preload("res://scripts/lab_state.gd")
var failures: Array = []
var checks: int = 0

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize():
	var state = State.new()
	_test_reward_rules(state)
	_test_element_workflow()
	state.rng.seed = 9182026
	check(state.coins == 220.0 and state.reactors.size() == 1, "new island initial state")
	check(state.plots.size() > 9 and state.plots[4].rid == 0 and state.unlocked_plot_count() == 5, "island has central reactor and adjacent expansion frontier")
	var original_coordinates = true
	for i in range(9):
		original_coordinates = original_coordinates and state.plot_at(i % 3 - 1, int(i / 3) - 1) == i
	check(original_coordinates, "original nine plot identities preserve their coordinates")
	check(state.plot_at(2, 0) >= 9 and state.can_expand(state.plot_at(2, 0)), "frontier permits expansion beyond starter island")
	check(state.plot_cost(0) == 2 and state.plot_cost(state.plot_at(2, 0)) == 3, "outer rings require progressively more materials")
	check(not state.can_expand(-1) and not state.can_expand(4) and state.plot_at(128, 128) == -1, "invalid and already open plots cannot expand")
	check(state.plot_label(4) == "地块 (0, 0)", "plot labels use stable coordinates")
	check(state.templates.size() == 14, "seven science templates including substitution discoveries")
	check(State.save_root_for_platform("Android") == "user://saves", "Android saves use writable app storage")
	check(State.save_root_for_platform("Windows") == "res://saves", "desktop preserves project-local save directory")
	check(State.save_path_allowed_for_platform("user://saves/save.json", "Android"), "Android app save path accepted")
	check(not State.save_path_allowed_for_platform("res://saves/save.json", "Android"), "Android rejects read-only APK save location")
	check(not State.save_path_allowed_for_platform("user://saves/save.json", "Windows"), "desktop saves remain inside current project")
	for unsafe in ["user://saves/../outside.json", "user://saves/nested/save.json", "user://saves/nested\\save.json", "user://saves/save.json:stream", "user://saves/.json"]:
		check(not State.save_path_allowed_for_platform(unsafe, "Android"), "reject unsafe Android save path: " + unsafe)
	for id in state.templates:
		var candidate = {"template": id, "positions": state.templates[id].positions.duplicate(true), "level": 1, "build_left": 0.0}
		check(state.quality(candidate) > 0.999, "reference geometry: " + id)
	var r = state.reactors[0]
	var before_quality = state.quality(r)
	check(before_quality > 0.0 and before_quality < 0.95, "starter structure invites editing")
	var initial_cost = state.edit_cost(r)
	var initial_coins = state.coins
	state.apply_edit(0, r.positions.duplicate(true))
	check(state.coins == initial_coins, "unchanged positions do not charge")
	state.apply_edit(0, [[0, 0, 0]])
	check(state.coins == initial_coins, "wrong atom count does not charge")
	var bad_coordinates = r.positions.duplicate(true)
	bad_coordinates[0][0] = NAN
	state.apply_edit(0, bad_coordinates)
	check(state.coins == initial_coins, "nonfinite coordinates do not charge")
	state.apply_edit(0, state.templates.water.positions.duplicate(true))
	check(state.coins == initial_coins - initial_cost and state.quality(r) > 0.999, "one confirmed edit charge and quality improves")
	var reference = r.positions.duplicate(true)
	var signature = r.signature
	reference[1][0] += 0.03
	state.apply_edit(0, reference)
	check(state.coins == initial_coins - 2 * initial_cost and state.edit_cost(r) == initial_cost, "same level has fixed edit price")
	check(r.signature != signature, "changed coordinates have a new fingerprint")
	var collision = r.duplicate(true)
	collision.positions[1] = collision.positions[0].duplicate()
	check(state.quality(collision) < state.quality(r), "overlap penalized")
	var translate = r.duplicate(true)
	for point in translate.positions:
		point[0] += 2.0
		point[1] += 1.0
	check(absf(state.quality(translate) - state.quality(r)) < 0.0001, "rigid translation preserves geometry score")
	state.coins = 10000.0
	state.apply_edit(0, state.templates.water.positions.duplicate(true))
	for n in range(100): state.tick(1.0)
	check(r.stock >= 3 and r.stored_coins > 0.0, "passive production")
	var stock_before = r.stock
	state.harvest(0)
	state.deliver(0)
	check(state.storage.batch(state.signature(r)).quantity == stock_before - 3 and state.upgrades == 1 and state.deliveries == 1, "premium order consumes stock and awards catalyst")
	var next_order = state.order.template
	state.deliver(0)
	check(state.order.template == next_order, "cannot deliver without enough inventory")
	state.upgrade_reactor(0)
	check(r.level == 2 and state.upgrades == 0 and state.edit_cost(r) > initial_cost, "upgrade consumes catalyst and raises fixed edit cost")
	state.tick(60.0)
	state._dry_harvests=7
	var total_materials_before = int(state.materials[0]) + int(state.materials[1]) + int(state.materials[2])
	state.harvest(0)
	var total_materials_after = int(state.materials[0]) + int(state.materials[1]) + int(state.materials[2])
	check(total_materials_after > total_materials_before, "harvest material drought protection")
	var coins_after_harvest = state.coins
	state.harvest(0)
	check(state.coins == coins_after_harvest, "harvest cannot collect coins twice")
	state.change_template(0, "methane")
	Fixtures.install(state)
	state.apply_edit(0, state.templates.methane.positions.duplicate(true))
	Fixtures.offer(state,"methane")
	check(r.stock == 0 and r.stored_coins == 0.0 and r.pending == 0, "switch clears previous product buffers")
	for n in range(80): state.tick(1)
	state.harvest(0)
	state.deliver(0)
	check(state.upgrades == 1 and state.deliveries == 2, "next template premium order works")
	state.change_template(0, "water")
	Fixtures.install(state)
	state.apply_edit(0, state.templates.water.positions.duplicate(true))
	Fixtures.offer(state,"methane")
	for n in range(80): state.tick(1)
	state.harvest(0)
	state.deliver(0)
	check(state.deliveries == 3 and state.upgrades == 1, "nonmatching template has ordinary sale but no catalyst")
	state.place_reactor(3, "hydrogen")
	var building = state.reactors[1]
	state.campus_build(5,"engineer_house")
	state.hire_engineer()
	check(state.engineers==2,"housing permits engineer recruitment")
	state.tick(1.0)
	check(building.build_left>0 and building.stock==0,"travel and construction block production")
	for n in range(40): state.tick(1.0)
	check(building.build_left==0,"on-site engineers complete construction")
	for n in range(40): state.tick(1.0)
	check(building.stock>0,"unoptimized starting geometry still produces after its slower cycle")
	# This test checks the old science API; recruitment is covered by campus integration.
	state.campus.setup(2,1)
	state._sync_campus_counts()
	check(state.scientists == 1, "legacy research count maps to a doctor")
	var shifted = r.positions.duplicate(true)
	shifted[1][0] += 0.22
	state.apply_edit(0, shifted)
	state.optimize(0)
	check(state.quality(r) > 0.999, "H-O assist restores reference geometry")
	var cost_before_wrong_system = state.coins
	state.optimize(1)
	check(state.coins == cost_before_wrong_system, "unresearched system assist does not charge")
	state.crate_count = 9
	var engineers_before = state.engineers
	state.open_crate()
	check(state.engineers == engineers_before + 1 and state.crate_count == 10, "tenth crate engineer guarantee")
	state.materials = [2, 2, 2]
	state.buy_plot(0)
	check(state.plots[0].unlocked and state.materials == [0, 0, 0], "expansion consumes all three building materials")
	state.place_decoration(0, "garden")
	check(state.plots[0].kind == "garden", "decoration occupies selected plot")
	var before_occupied = state.coins
	state.place_reactor(0)
	check(state.coins == before_occupied, "occupied plot does not consume construction coins")
	var save_path = "res://saves/test_state.json"
	var corrupt_path = "res://saves/test_corrupt.json"
	var legacy_path = "res://saves/test_legacy.json"
	var expanded_path = "res://saves/test_expanded.json"
	var test_paths = [save_path, save_path + ".bak", corrupt_path, corrupt_path + ".bak", legacy_path, legacy_path + ".bak", expanded_path, expanded_path + ".bak"]
	for path in test_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(state.save_game(save_path).begins_with("已保存"), "save to project succeeds")
	var loaded = State.new()
	check(loaded.load_game(save_path), "load valid save")
	check(absf(loaded.coins - state.coins) < 0.0001 and loaded.reactors.size() == 2 and loaded.plots[0].kind == "garden", "save round-trip preserves state")
	check(loaded.reactors[0].signature == state.reactors[0].signature, "save round-trip preserves geometry fingerprint")
	state.coins += 3.0
	check(state.save_game(save_path).begins_with("已保存"), "atomic save replacement succeeds")
	var broken = FileAccess.open(save_path, FileAccess.WRITE)
	broken.store_string("{truncated")
	broken.close()
	check(loaded.load_game(save_path), "corrupt primary save recovers valid backup")
	var old_coins = loaded.coins
	var corrupt = FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt.store_string("{\"version\":1,\"coins\":-500}")
	corrupt.close()
	check(not loaded.load_game(corrupt_path) and loaded.coins == old_coins, "invalid save leaves live state untouched")
	check(not loaded.load_game("res://saves/../data/materials.json"), "save path traversal rejected")
	var valid_file = JSON.parse_string(FileAccess.get_file_as_string(save_path + ".bak"))
	valid_file.reactors[0].positions = [[0, 0, 0]]
	check(not loaded._validate_save(valid_file), "save rejects wrong atom count")
	valid_file = JSON.parse_string(FileAccess.get_file_as_string(save_path + ".bak"))
	valid_file.plots[0].rid = 0
	check(not loaded._validate_save(valid_file), "save rejects inconsistent plot ownership")
	var baseline = JSON.parse_string(FileAccess.get_file_as_string(save_path + ".bak"))
	check(int(baseline.version) == 21, "new saves use version twenty-one")
	valid_file = baseline.duplicate(true)
	valid_file.plots[9].x = valid_file.plots[4].x
	valid_file.plots[9].z = valid_file.plots[4].z
	check(not loaded._validate_save(valid_file), "save rejects duplicate plot coordinates")
	for invalid_coordinate in [NAN, INF, 0.5, 129, -129, "north"]:
		valid_file = baseline.duplicate(true)
		valid_file.plots[9].x = invalid_coordinate
		check(not loaded._validate_save(valid_file), "save rejects invalid frontier coordinate: " + str(invalid_coordinate))
	valid_file = baseline.duplicate(true)
	valid_file.plots[0].x = -8
	check(not loaded._validate_save(valid_file), "save cannot reassign original plot coordinates")
	valid_file = baseline.duplicate(true)
	valid_file.reactors[0].plot = valid_file.plots.size()
	check(not loaded._validate_save(valid_file), "save rejects reactor outside dynamic land array")
	valid_file = baseline.duplicate(true)
	valid_file.plots.resize(1025)
	check(not loaded._validate_save(valid_file), "save rejects oversized frontier arrays")
	valid_file = baseline.duplicate(true)
	valid_file.reactors.resize(129)
	check(not loaded._validate_save(valid_file), "save rejects oversized reactor arrays")
	var legacy = baseline.duplicate(true)
	legacy.version = 1
	legacy.plots = legacy.plots.slice(0, 9)
	for p in legacy.plots:
		p.erase("x")
		p.erase("z")
	var legacy_file = FileAccess.open(legacy_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy,"",true,true))
	legacy_file.close()
	var migrated = State.new()
	check(migrated.load_game(legacy_path), "version one save migrates successfully")
	check(migrated.coins == float(legacy.coins) and migrated.discovered == legacy.discovered and migrated.reactors[0].stock == int(legacy.reactors[0].stock), "migration preserves wallet, discoveries and production stock")
	check(migrated.plots[0].kind == "garden" and migrated.plots[3].rid == 1 and migrated.plots[4].rid == 0, "migration preserves buildings and reactor identities")
	check(migrated.plot_at(-1, -1) == 0 and migrated.plot_at(0, 0) == 4 and migrated.can_expand(migrated.plot_at(2, 0)), "migration adds coordinate frontier without replacing old plots")
	check(migrated.save_game(legacy_path).begins_with("已保存"), "migrated island saves in new format")
	var legacy_backup = JSON.parse_string(FileAccess.get_file_as_string(legacy_path + ".bak"))
	check(int(legacy_backup.version) == 1 and FileAccess.get_file_as_string(legacy_path + ".bak") == JSON.stringify(legacy,"",true,true), "first migrated save preserves original version one backup")
	var frontier = State.new()
	frontier.materials = [1000000, 1000000, 1000000]
	frontier.coins = 10000.0
	frontier.plots.append({"x": 20, "z": 20, "unlocked": false, "kind": "empty", "rid": -1})
	var materials_before_remote = frontier.materials.duplicate()
	var remote_index = frontier.plots.size() - 1
	check(not frontier.can_expand(remote_index), "remote land cannot skip adjacency")
	frontier.buy_plot(remote_index)
	check(frontier.materials == materials_before_remote and not frontier.plots[remote_index].unlocked, "rejected remote purchase leaves resources intact")
	frontier.plots.pop_back()
	var identities = {}
	for x in range(2, 13):
		var plot = frontier.plot_at(x, 0)
		identities[x] = plot
		frontier.buy_plot(plot)
	check(frontier.unlocked_plot_count() == 16 and frontier.plot_at(13, 0) >= 0, "successive purchases extend far beyond original nine plots")
	var stable = frontier.plot_at(0, 0) == 4
	for x in identities:
		stable = stable and frontier.plot_at(x, 0) == identities[x]
	check(stable, "appending frontier keeps every existing plot identity stable")
	var distant_plot = frontier.plot_at(10, 0)
	frontier.place_reactor(distant_plot, "hydrogen")
	for x in range(2,11): frontier.campus_road(frontier.plot_at(x,0))
	for n in range(90): frontier.tick(1.0)
	check(frontier.plots[distant_plot].rid == 1 and frontier.reactors[1].plot == distant_plot and frontier.reactors[1].stock > 0, "distant plots support normal construction and production")
	check(frontier.save_game(expanded_path).begins_with("已保存"), "expanded island saves")
	var restored_frontier = State.new()
	check(restored_frontier.load_game(expanded_path), "expanded island reloads")
	check(restored_frontier.plot_at(10, 0) == distant_plot and restored_frontier.plots[distant_plot].rid == 1 and restored_frontier.reactors[1].plot == distant_plot, "expanded save preserves distant reactor links")
	check(restored_frontier.plots == frontier.plots and restored_frontier.materials == frontier.materials and restored_frontier.reactors[1].stock == frontier.reactors[1].stock, "expanded round trip preserves frontier, resources and production")
	for x in range(13, 125):
		frontier.buy_plot(frontier.plot_at(x, 0))
	check(frontier.unlocked_plot_count() == 128 and frontier.plots.size() <= 1024, "island reaches supported expansion capacity with sparse frontier")
	var cap_materials = frontier.materials.duplicate()
	var cap_plot = frontier.plot_at(125, 0)
	var cap_message = frontier.buy_plot(cap_plot)
	check(cap_message.contains("128") and frontier.materials == cap_materials and not frontier.can_expand(cap_plot), "capacity limit explains itself and never consumes resources")
	check(frontier.save_game(expanded_path).begins_with("已保存") and restored_frontier.load_game(expanded_path) and restored_frontier.unlocked_plot_count() == 128, "maximum supported island survives save round trip")
	for path in test_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("PASS: ", checks, " state checks (geometry, economy, stock, edits, crates, research, expanding land, save integrity)")
		quit(0)
	else:
		print("FAILED: ", failures.size(), " of ", checks, " checks")
		quit(1)

func _test_reward_rules(state) -> void:
	var previous: float = 0.0
	for id in ["hydrogen","water","methane","perovskite"]:
		var tpl: Dictionary = state.templates[id]
		var profile: Dictionary = state.economy.profile(tpl)
		check(profile.base_rate > previous and profile.complexity <= 4.0, "progressive rewards stay bounded: " + id)
		previous = profile.base_rate
	var crystal: Dictionary = state.economy.profile(state.templates.perovskite)
	check(crystal.atoms == 5.0, "periodic corner and face occupancies do not inflate complexity")
	var valid: Dictionary = {"template":"water","positions":state.templates.water.positions.duplicate(true),"level":1,"build_left":0.0}
	var poor: Dictionary = valid.duplicate(true)
	poor.positions[1] = poor.positions[0].duplicate()
	check(state.income(valid) > state.income(poor), "same composition rewards better geometry")
	var level_two: Dictionary = valid.duplicate(true)
	level_two.level = 2
	check(is_equal_approx(state.income(level_two) / state.income(valid),1.45), "upgrade scales current rewards without changing complexity")
	level_two.build_left = 1.0
	check(state.income(level_two) == 0.0, "construction never receives complexity income")
	var q: Dictionary = state.economy.quote("water",0.931,3,false,state.order)
	var below: Dictionary = state.economy.quote("water",0.929,3,false,state.order)
	check(q.premium and not below.premium, "premium threshold uses percentage point distance")
	var other: Dictionary = state.economy.quote("methane",0.98,3,false,state.order)
	check(not other.premium and other.catalysts == 0 and other.payment < q.payment, "other material gets a discounted sale with no catalyst")
	check(not state.economy.quote("water",0.98,2,false,state.order).ready, "quote cannot authorize a sale with insufficient stock")
	check(not state.economy.quote("water",0.98,3,true,state.order).ready, "quote cannot authorize a sale during construction")
	var ranked = state.market_candidates()
	check(ranked.size() == state.reactors.size() and float(ranked[0].score) >= float(ranked[-1].score), "market candidates are ranked by completion and value")
	check(ranked[0].has("reason") and not str(ranked[0].reason).is_empty(), "market ranking exposes a human-readable reason")
	var seller = State.new()
	seller.reactors[0].positions = seller.templates.water.positions.duplicate(true)
	seller.reactors[0].stock = 3
	seller.reactors[0].pending = 3
	seller.harvest(0)
	Fixtures.offer(seller)
	var advertised: Dictionary = seller.delivery_quote(0)
	var wallet: float = seller.coins
	seller.deliver(0)
	check(seller.coins == wallet + advertised.payment and seller.upgrades == advertised.catalysts and seller.reactors[0].stock == 0, "quoted price and delivered amount agree exactly")
	check(not seller.visitor_available() and seller.market.clock > 0.0, "buyer visit starts an adjustable cooldown")
	var blocked_wallet: float = seller.coins
	check(seller.deliver(0).contains("后到访") and seller.coins == blocked_wallet, "cooldown blocks repeated delivery without changing the wallet")
	for n in range(72): seller.tick(1)
	check(seller.visitor_available() and seller.visitor_countdown_text().contains("可以接待"), "buyer becomes available after cooldown")
	var fake: Dictionary = state.templates.water.duplicate(true)
	fake.atoms = []
	for i in range(400): fake.atoms.append("H")
	check(state.economy.profile(fake).complexity <= 4.0, "large atom count cannot create unbounded rewards")

func _test_element_workflow() -> void:
	var s = State.new()
	check(s.element_inventory.S == 1 and s.element_inventory.Cl == 2, "starter supplies enable molecule substitutions")
	var wallet: float = s.coins
	var inventory: Dictionary = s.element_inventory.duplicate(true)
	for request in [["H",0],["H",-1],["Cl",100],["Unknown",1]]:
		s.buy_elements(request[0],request[1])
	check(s.coins == wallet and s.element_inventory == inventory, "invalid purchases do not mutate wallet or supplies")
	s.coins = 0
	s.buy_elements("Cl",1)
	check(s.coins == 0 and s.element_inventory == inventory, "insufficient coins cannot purchase elements")
	s.coins = wallet
	s.element_inventory.H = 9999
	s.buy_elements("H",1)
	check(s.coins == wallet and s.element_inventory.H == 9999, "warehouse capacity cannot overflow")
	s.element_inventory = inventory.duplicate(true)
	var purchase: Dictionary = s.purchase_quote("Cl",5)
	s.buy_elements("Cl",5)
	check(s.coins == wallet - purchase.total and s.element_inventory.Cl == 7, "purchase charges exactly the preview price")
	var r: Dictionary = s.reactors[0]
	var old_positions: Array = r.positions.duplicate(true)
	var old_signature: String = s.signature(r)
	var draft_atoms: Array = ["S","H","H"]
	var preview: Dictionary = s.edit_quote(0,old_positions,draft_atoms)
	check(preview.ready and preview.reference_id == "hydrogen_sulfide" and preview.required == {"S":1}, "oxygen-to-sulfur preview resolves H2S and spends one S")
	wallet = s.coins
	inventory = s.element_inventory.duplicate(true)
	check(s.atom_symbols(r) == ["O","H","H"] and s.coins == wallet and s.element_inventory == inventory, "substitution preview never edits actual structure or inventory")
	var unchanged: Dictionary = s.edit_quote(0,old_positions,["O","H","H"])
	check(not unchanged.changed and unchanged.fee == 0 and unchanged.required.is_empty(), "reverting draft before commit costs nothing")
	s.apply_structure_edit(0,old_positions,["S","Unknown","H"])
	check(s.coins == wallet and s.element_inventory == inventory, "invalid element edit is atomic")
	s.element_inventory.S = 0
	s.apply_structure_edit(0,old_positions,draft_atoms)
	check(s.coins == wallet and s.atom_symbols(r)[0] == "O", "short inventory cannot change atoms or charge edit fee")
	s.element_inventory = inventory.duplicate(true)
	s.tick(30)
	s.apply_structure_edit(0,old_positions,draft_atoms)
	check(s.coins == wallet - preview.fee and s.element_inventory.S == inventory.S - 1, "confirmed substitution charges one fixed edit and exact inventory")
	Fixtures.install(s)
	check(r.positions == old_positions and s.reference_id(r) == "hydrogen_sulfide", "substitution preserves player coordinates and changes scientific reference")
	check(r.stock == 0 and r.pending == 0 and r.stored_coins == 0 and r.progress == 0, "old products never become substituted products")
	check(s.signature(r) != old_signature, "element identity contributes to specimen fingerprint")
	var mismatched_geometry: float = s.quality(r)
	inventory = s.element_inventory.duplicate(true)
	s.apply_edit(0,s.templates.hydrogen_sulfide.positions.duplicate(true))
	check(s.quality(r) > 0.999 and s.quality(r) > mismatched_geometry and s.element_inventory == inventory, "coordinates use the new H2S reference without spending atoms again")
	s.scientists = 1
	wallet = s.coins
	s.optimize(0)
	check(s.coins == wallet and s.reference_id(r) == "hydrogen_sulfide", "water-only assistance cannot overwrite a substituted molecule")
	s.tick(25)
	s.harvest(0)
	check(s.discovered.has("hydrogen_sulfide"), "harvesting substitution unlocks its science card")
	var new_buyer = State.new()
	new_buyer.reactors[0].atoms = ["S","H","H"]
	new_buyer.reactors[0].positions = new_buyer.templates.hydrogen_sulfide.positions.duplicate(true)
	new_buyer.reactors[0].stock = 3
	new_buyer.reactors[0].pending = 3
	new_buyer.harvest(0)
	Fixtures.offer(new_buyer,"hydrogen_sulfide")
	new_buyer.deliveries = 4
	new_buyer._update_order()
	check(new_buyer.order.template == "hydrogen_sulfide" and new_buyer.delivery_quote(0).premium, "new buyer recognizes the substituted composition instead of its original template")
	new_buyer.deliver(0)
	check(new_buyer.upgrades == 1 and new_buyer.reactors[0].stock == 0 and new_buyer.discovered.has("hydrogen_sulfide"), "new-structure premium order pays catalyst and discovers the correct card")
	wallet = s.coins
	s.change_template(0,"hydrogen_chloride")
	s.place_reactor(3,"perovskite_chloride")
	check(s.coins == wallet and s.reactors.size() == 1, "new discoveries cannot bypass element costs through template loading")
	s.apply_structure_edit(0,r.positions.duplicate(true),["S","Cl","H"])
	Fixtures.install(s)
	check(s.reference_id(r).is_empty() and s.quality(r) == 0, "unrecognized composition never inherits old quality")
	for n in range(100): s.tick(1)
	check(is_equal_approx(r.stored_coins,15.0) and r.stock == 0 and r.pending == 0, "unknown chemistry earns only capped exploration income and no sellable products")
	r.level = 20
	check(s.income(r) == 0.15 and not s.delivery_quote(0).ready and s.delivery_quote(0).payment == 0, "unknown sample cannot boost stipend by level or claim order value")
	wallet = s.coins
	s.deliver(0)
	check(s.coins == wallet and s.upgrades == 0, "unknown sample never yields a premium catalyst")
	var diatomic: Dictionary = {"template":"hydrogen","atoms":["Cl","H"],"positions":[[-0.6375,0,0],[0.6375,0,0]],"level":1}
	check(s.reference_id(diatomic) == "hydrogen_chloride" and s.quality(diatomic) > 0.999, "HCl recognition is invariant under swapping the two atom slots")
	check(is_equal_approx(float(s.structure_data(diatomic).atom_contexts[0].radius),1.02), "HCl uses chlorine covalent radius")
	var crystal: Dictionary = {"template":"perovskite","atoms":s.templates.perovskite_chloride.atoms.duplicate(),"positions":s.templates.perovskite_chloride.positions.duplicate(true),"level":1}
	check(s.reference_id(crystal) == "perovskite_chloride" and s.quality(crystal) > 0.999, "whole halide-site group resolves chloride teaching cell")
	check(is_equal_approx(float(s.structure_data(crystal).atom_contexts[9].radius),1.81), "chloride crystal uses ionic radius with its own context")
	crystal.atoms[9] = "Br"
	check(s.reference_id(crystal).is_empty(), "mixed halides never silently reuse pure chloride data")
	var save_path: String = "res://saves/test_elements_v03.json"
	check(s.save_game(save_path).begins_with("已保存"), "substitution and inventory can be saved")
	var loaded = State.new()
	check(loaded.load_game(save_path) and loaded.element_inventory == s.element_inventory and loaded.atom_symbols(loaded.reactors[0]) == s.atom_symbols(r), "v3 save round trip preserves inventory and exploratory atoms")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	data.element_inventory.Cl = -1
	check(not loaded._validate_save(data), "negative element inventory is rejected")
	data.element_inventory.Cl = 1
	data.reactors[0].atoms[0] = "Unknown"
	check(not loaded._validate_save(data), "unknown element symbols in saves are rejected")
	var old = State.new()
	old.save_game(save_path)
	data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	data.version = 2
	data.erase("element_inventory")
	for reactor in data.reactors: reactor.erase("atoms")
	var file = FileAccess.open(save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(loaded.load_game(save_path) and loaded.atom_symbols(loaded.reactors[0]) == ["O","H","H"] and loaded.element_inventory.S == 1, "v2 migration reconstructs atoms and grants one starter pack")
	loaded.element_inventory.S = 0
	loaded.save_game(save_path)
	check(loaded.load_game(save_path) and loaded.element_inventory.S == 0, "starter pack is never granted again on v3 reload")
	for path in [save_path,save_path+".bak",save_path+".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
