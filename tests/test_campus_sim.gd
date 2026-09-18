extends SceneTree

const Campus = preload("res://scripts/campus_sim.gd")
var checks = 0
var failures: Array = []

func check(condition: bool, label: String):
	checks += 1
	if not condition: failures.append(label); push_error(label)

func context() -> Dictionary:
	return {"coins":10000,"plaza_plot":0,"plots":[],"road_graph":{},"reactors":[{"plot":10,"build_left":12.0}],"templates":{"perovskite_chloride":{}},
		"buildings":[{"plot":1,"kind":"house","capacity":2,"level":1,"connected":true},
			{"plot":2,"kind":"doctor_dorm","capacity":4,"level":1,"connected":true},
			{"plot":3,"kind":"professor_apartment","capacity":2,"level":1,"connected":true},
			{"plot":4,"kind":"academician_villa","capacity":1,"level":1,"connected":true},
			{"plot":5,"kind":"institute","capacity":8,"level":1,"connected":true},
			{"plot":6,"kind":"canteen","capacity":8,"level":1,"connected":true},
			{"plot":7,"kind":"park","capacity":0,"level":1,"connected":true}]}

func advance(sim, seconds: int, ctx: Dictionary):
	for i in range(seconds): sim.tick(1,ctx)

func _initialize():
	var sim = Campus.new()
	sim.rng.seed = 20260919
	sim.setup(2,1)
	var ctx = context()
	check(sim.role_count("engineer") == 2 and sim.role_count("doctor") == 1,"legacy roles migrate without losing workers")
	check(sim.people[0].legacy_home and int(sim.people[0].home_plot) == -1,"legacy housing remains playable")
	sim.tick(0.2,ctx)
	check(sim.elapsed == 0,"people do not update every render frame")
	sim.tick(0.8,ctx)
	check(sim.elapsed == 1 and sim.people[0].activity == "construct" and sim.people[0].target_plot == 10,"engineers target actual unfinished reactor")
	check(sim.construction_factor(10) > 1 and sim.construction_factor(11) == 0,"construction effort belongs only to assigned site")
	ctx.reactors.append({"plot":11,"build_left":12.0})
	sim.tick(1,ctx)
	check(sim.construction_factor(10) > 0 and sim.construction_factor(11) > 0,"engineers spread over construction sites")
	ctx.reactors[0].build_left = 0; ctx.reactors[1].build_left = 0
	sim.tick(1,ctx)
	check(sim.people[0].activity == "maintain","finished sites change work to maintenance")
	var lacking = context(); lacking.buildings = []
	check(not sim.quote_hire("professor",lacking).ready,"science recruitment needs housing")
	lacking.buildings = [{"plot":3,"kind":"professor_apartment","capacity":1,"connected":true}]
	check(not sim.quote_hire("professor",lacking).ready,"science recruitment also needs institute")
	lacking = context(); lacking.buildings[3].connected = false
	check(not sim.quote_hire("academician",lacking).ready,"unconnected villa does not support recruitment")
	lacking = context(); lacking.coins = 0
	var before = sim.people.size()
	check(not sim.hire("engineer",lacking).ready and sim.people.size() == before,"failed hire is atomic")
	lacking = context(); lacking.buildings[4].capacity = 1
	check(not sim.hire("professor",lacking).ready,"research institute capacity limits new scientific residents")
	var hired = sim.hire("academician",ctx)
	check(hired.ready and hired.cost == 1400 and sim.role_count("academician") == 1,"academic hiring returns exact configured cost")
	check(not sim.hire("academician",ctx).ready,"one-person villa cannot double-book")
	check(sim.hire("professor",ctx).ready,"professor moves into matching apartment")
	check(sim.hire("doctor",ctx).ready,"doctor can join existing legacy doctor")
	check(sim.quote_research("perovskite_chloride",ctx).ready,"full team enables crystal recipe research")
	var started = sim.start_research("perovskite_chloride",ctx)
	check(started.ready and started.cost == 280 and sim.research_jobs[0].team.size() == 4,"research reserves exact stable team")
	check(not sim.start_research("perovskite_chloride",ctx).ready,"duplicate project cannot charge or double count staff")
	lacking = context(); lacking.buildings[4].connected = false
	sim.tick(1,lacking)
	check(sim.research_jobs[0].status == "waiting_institute" and sim.research_jobs[0].progress == 0,"disconnected institute cannot research")
	var supervisor_found = false
	for p in sim.people:
		if p.role == "doctor" and p.supervisor_id > 0: supervisor_found = true
	check(supervisor_found,"professor supervision is explicitly assigned")
	var saved = JSON.parse_string(JSON.stringify(sim.serialize()))
	var resumed = Campus.new()
	check(resumed.restore(saved),"active campus round trips through JSON")
	check(resumed.research_jobs[0].team == sim.research_jobs[0].team,"assigned research identities survive save")
	var snapshot = JSON.stringify(resumed.serialize())
	var broken = saved.duplicate(true); broken.people[0].traits.diligence = NAN
	check(not resumed.restore(broken) and JSON.stringify(resumed.serialize()) == snapshot,"nonfinite trait rejected without partial mutation")
	broken = saved.duplicate(true); broken.people[1].id = broken.people[0].id
	check(not resumed.restore(broken),"duplicate population id rejected")
	broken = saved.duplicate(true); broken.research_jobs[0].team.append(broken.research_jobs[0].team[0])
	check(not resumed.restore(broken),"duplicate research assignment rejected")
	broken = saved.duplicate(true); broken.unlocked_materials.append("perovskite_chloride")
	check(not resumed.restore(broken),"unfinished job cannot claim material unlocked")
	var science_person = sim.person(int(sim.research_jobs[0].team[0]))
	sim.dismiss(int(science_person.id))
	sim.tick(1,ctx)
	check(sim.research_jobs[0].status == "waiting_team","dismissal creates research vacancy")
	check(sim.hire("academician",ctx).ready,"vacated villa can recruit replacement")
	advance(sim,100,ctx)
	check(sim.research_jobs[0].team.size() == 4 and sim.research_jobs[0].progress > 0,"new hire fills stable research vacancy")
	var academy_id = -1
	for p in sim.people:
		if p.role == "academician": academy_id = int(p.id); p.hunger = 85
	sim.tick(1,ctx)
	check(sim.people[0].activity == "deliver_meal" and sim.person(academy_id).hunger > 80,"meal delivery requires travel time")
	advance(sim,12,ctx)
	check(sim.person(academy_id).hunger < 30,"engineer meal courier completes actual meal")
	var professor = {}
	for p in sim.people:
		if p.role == "professor": professor = p; p.hunger = 85
	sim.tick(1,ctx)
	check(professor.activity == "eat" and professor.target_plot == 6,"hungry professor visits canteen")
	advance(sim,15,ctx)
	check(professor.hunger < 30 and professor.activity == "research","meal lasts until appetite recovered")
	var positions_before = JSON.stringify(ctx.templates)
	advance(sim,360,ctx)
	check("perovskite_chloride" in sim.unlocked_materials and sim.research_jobs[0].status == "complete","team research unlocks recipe")
	check(JSON.stringify(ctx.templates) == positions_before,"research never edits template atoms or coordinates")
	check(sim.research_jobs[0].team.is_empty(),"finished job releases members")
	check(resumed.restore(JSON.parse_string(JSON.stringify(sim.serialize()))),"completed state restores")
	sim.dismiss(academy_id)
	check(resumed.restore(JSON.parse_string(JSON.stringify(sim.serialize()))),"dismissing alumnus does not invalidate completed project")
	var events = Campus.new(); events.setup(10,0); events.rng.seed = 20
	events.config.events.chance = 1.0
	advance(events,470,ctx)
	check(events.pending_requests.size() == 3,"daily request cap prevents notification storm")
	var requesters: Array = []
	for r in events.pending_requests: requesters.append(r.person_id)
	check(requesters.size() == 3 and requesters[0] != requesters[1] and requesters[1] != requesters[2] and requesters[0] != requesters[2],"one request per person with cooldown")
	var request: Dictionary = events.pending_requests[0]
	var person_before = events.person(int(request.person_id)).duplicate(true)
	var declined = events.resolve_request(int(request.id),"later",ctx)
	check(declined.ready and declined.cost == 0 and events.person(int(request.person_id)).morale == person_before.morale,"postponing a request has no hidden penalty")
	check(not events.resolve_request(int(request.id),"accept",ctx).ready,"request cannot be fulfilled twice")
	var roundtrip = Campus.new()
	check(roundtrip.restore(JSON.parse_string(JSON.stringify(events.serialize()))),"pending events and cooldowns survive save")
	advance(events,60,ctx)
	check(events.pending_requests.size() <= 3,"day rollover produces at most one new request each interval")
	var cooling = Campus.new(); cooling.setup(1,0); cooling.config.events.chance = 1
	advance(cooling,120,ctx)
	check(cooling.pending_requests.size() == 1,"first need waits for configured settling period")
	cooling.resolve_request(int(cooling.pending_requests[0].id),"later",ctx)
	advance(cooling,479,ctx)
	check(cooling.pending_requests.is_empty(),"same person remains quiet through request cooldown")
	advance(cooling,1,ctx)
	check(cooling.pending_requests.size() == 1,"new request only after full person cooldown")
	var event_sim = Campus.new(); event_sim.setup(1,0)
	event_sim.elapsed = 130; event_sim.day_time = 130
	event_sim.pending_requests = [{"id":1,"person_id":1,"kind":"move_request","title":"move","detail":"move","created_at":120.0}]
	var old_home = event_sim.people[0].home_plot
	lacking = context(); lacking.buildings = []
	check(not event_sim.resolve_request(1,"accept",lacking).ready and event_sim.people[0].home_plot == old_home,"moving cannot invent unavailable housing")
	var moved = event_sim.resolve_request(1,"accept",ctx)
	check(moved.ready and moved.cost == 25 and event_sim.people[0].home_plot == 1,"accepted moving uses real available bed")
	check(event_sim.housing_usage(ctx)[0].used == 1,"housing occupancy reports real assigned beds")
	_test_travel_and_housing()
	# Twelve independent populations: bounded trait ranges and genuine variability.
	var samples: Array = []
	for seed_value in range(12):
		var cohort = Campus.new(); cohort.rng.seed = seed_value; cohort.setup(8,0)
		for p in cohort.people: samples.append(float(p.traits.diligence))
	samples.sort()
	check(samples[0] >= 0.45 and samples[-1] <= 0.95 and samples[-1] - samples[0] > 0.4,"personality distribution is bounded and varied")
	var large = Campus.new(); large.setup(80,16)
	var begun = Time.get_ticks_usec()
	advance(large,480,ctx)
	var spent = Time.get_ticks_usec() - begun
	check(large.people.size() == 96 and spent < 3000000,"96 people one full day update under three seconds headless")
	print("Campus simulation: ",checks," checks, ",failures.size()," failures; 96-person day ",spent," us")
	quit(0 if failures.is_empty() else 1)

func _test_travel_and_housing():
	var ctx = context()
	ctx.road_links = {0:[1],1:[0,2],2:[1,3],3:[2,4],4:[3,5],5:[4,6],6:[5,7],7:[6]}
	ctx.reachable_plots = [0,1,2,3,4,5,6,7]
	ctx.reactors = [{"plot":7,"build_left":12.0},{"plot":10,"build_left":12.0}]
	var sim = Campus.new(); sim.setup(1,0)
	sim.tick(1,ctx)
	check(sim.people[0].home_plot == 1 and not sim.people[0].legacy_home,"new linked housing automatically accommodates temporary worker")
	check(sim.people[0].activity == "construct" and sim.people[0].target_plot == 7,"unreachable construction site is excluded from assignments")
	check(sim.people[0].current_plot == 0 and sim.people[0].next_plot == 1 and is_equal_approx(sim.people[0].movement_progress,0.4),"travel advances fractionally along first road edge")
	check(sim.construction_factor(7) == 0 and not sim.people[0].arrived,"worker cannot build before arriving")
	var traveling = sim.serialize()
	var resumed = Campus.new()
	check(resumed.restore(JSON.parse_string(JSON.stringify(traveling))) and is_equal_approx(resumed.people[0].movement_progress,0.4),"mid-route travel survives save")
	var corrupted = traveling.duplicate(true); corrupted.people[0].next_plot = 7
	check(not resumed.restore(corrupted),"save cannot skip a travel segment")
	advance(sim,17,ctx)
	check(sim.people[0].current_plot == 7 and sim.people[0].arrived and sim.construction_factor(7) > 0,"construction starts only after full road journey")
	ctx.road_links[6] = [5]; ctx.road_links[7] = []; ctx.reachable_plots.erase(7)
	sim.tick(1,ctx)
	check(sim.people[0].activity != "construct" and sim.construction_factor(7) == 0,"road severance removes construction contribution immediately")
	ctx.road_links[6] = [5,7]; ctx.road_links[7] = [6]; ctx.reachable_plots.append(7)
	sim.tick(1,ctx)
	check(sim.construction_factor(7) > 0,"reconnected worker resumes on site")
	var migration = traveling.duplicate(true); migration.version = 1
	for p in migration.people:
		for key in ["current_plot","next_plot","movement_progress","moving","arrived","travel_target","travel_route","travel_index","meal_stage"]: p.erase(key)
	check(resumed.restore(migration) and not resumed.people[0].arrived,"early campus saves migrate safely without instant work")
	var crowded = Campus.new(); crowded.setup(4,0)
	crowded.tick(1,ctx)
	var accommodated = 0
	for p in crowded.people:
		if not p.legacy_home: accommodated += 1
	check(accommodated == 2,"automatic placement never exceeds real housing capacity")
	ctx.buildings.append({"plot":7,"kind":"house","capacity":2,"connected":true})
	crowded.tick(1,ctx)
	check(not crowded.people[2].legacy_home and not crowded.people[3].legacy_home,"later housing accommodates remaining temporary residents")
	var science = Campus.new(); science.setup(1,0)
	science.hire("doctor",ctx); science.hire("doctor",ctx); science.hire("professor",ctx); science.hire("academician",ctx)
	science.elapsed = 80; science.day_time = 80
	science.start_research("perovskite_chloride",ctx)
	science.tick(1,ctx)
	check(science.research_jobs[0].progress == 0,"research has no contribution while all staff commute")
	advance(science,8,ctx)
	check(science.research_jobs[0].progress > 0,"arrived scientists contribute to research")
	var academic = {}
	for p in science.people:
		if p.role == "academician": academic = p; p.hunger = 85
	science.tick(1,ctx)
	check(science.people[0].meal_stage == "pickup" and science.people[0].target_plot == 6,"meal task first travels to actual canteen")
	var pickup_seen = false
	var handover_seen = false
	for i in range(35):
		science.tick(1,ctx)
		if science.people[0].meal_stage == "pickup" and science.people[0].arrived: pickup_seen = true
		if science.people[0].meal_stage == "dropoff": handover_seen = true
	check(pickup_seen and handover_seen and academic.hunger < 35,"courier picks up food and delivers at academic's physical location")
	check(resumed.restore(JSON.parse_string(JSON.stringify(science.serialize()))),"travel and courier states remain valid after completion")
