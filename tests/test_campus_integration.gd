extends SceneTree
const State=preload("res://scripts/lab_state.gd")
var checks=0
var failures=[]
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error(message)
func _initialize() -> void:
	var s=State.new()
	s.coins=20000; s.materials=[10000,10000,10000]
	check(s.layout.plaza_index>=9 and s.plots[0].kind=="empty","plaza preserves starter land identities")
	var before=s.coins
	s.campus_hire("doctor")
	check(s.coins==before and s.campus.role_count("doctor")==0,"failed hiring does not charge")
	s.campus_build(3,"engineer_house")
	s.tick(1)
	check(s.campus.people[0].home_plot==3,"existing engineer moves into available home")
	s.campus_prop(3,0,"flower"); s.campus_prop(3,1,"bench")
	check(s.plots[3].kind=="engineer_house" and s.plots[3].props.size()==2,"house and multiple props coexist")
	before=s.coins; s.campus_prop(3,0,"lamp")
	check(s.coins==before and s.plots[3].props.size()==2,"occupied prop position is atomic")
	s.campus_upgrade(3)
	check(s.layout.capacity(s.plots[3])==6,"housing upgrade expands configured capacity")
	s.campus_build(5,"institute")
	s.campus_build(7,"doctor_dorm")
	s.campus_hire("doctor"); s.campus_hire("doctor")
	for entry in [[0,"professor_apartment"],[1,"academician_villa"],[2,"canteen"],[6,"park"]]:
		s.buy_plot(entry[0]); s.campus_build(entry[0],entry[1]); s.campus_road(entry[0])
	s.campus_hire("professor"); s.campus_hire("academician")
	check(s.campus.people.size()==5,"different roles recruit against housing and institute capacities")
	before=s.coins; s.campus_hire("academician")
	check(s.coins==before,"full villa prevents charge")
	var positions=s.reactors[0].positions.duplicate(true)
	s.campus_start_research("perovskite_chloride")
	check(s.campus.research_jobs.size()==1,"complete team starts research")
	for n in range(480): s.tick(1)
	check("perovskite_chloride" in s.campus.unlocked_materials,"arrived scientific team completes recipe")
	check(s.reactors[0].positions==positions,"research never adjusts player atom coordinates")
	s.change_template(0,"perovskite_chloride")
	s.campus.elapsed=(int(s.campus.elapsed/480)+1)*480+100
	for n in range(60): s.tick(1)
	check(s.reactors[0].template=="perovskite_chloride","researched recipe appears in manufacturing API")
	s.deliveries=3; s.campus_prop(3,2,"trophy")
	check(s.plots[3].props.size()==3,"earned trophy shares a housing plot")
	var path="res://saves/campus-integration.json"
	s.save_game(path)
	var loaded=State.new()
	check(loaded.load_game(path),"campus save reloads")
	check(loaded.plots==s.plots and loaded.campus.people.size()==5,"roads props homes and residents persist")
	check(loaded.campus.unlocked_materials==s.campus.unlocked_materials,"completed team project persists")
	s.buy_plot(8); s.campus_road(8)
	var resident=s.campus.people[0]
	resident.current_plot=3; resident.next_plot=3; resident.target_plot=3; resident.arrived=true; resident.moving=false; resident.travel_route=[]; resident.travel_index=0; resident.movement_progress=0; resident.travel_target=3
	s.move_building(3,8)
	s.save_game(path)
	check(loaded.load_game(path) and not loaded.campus.people[0].arrived,"moving occupied housing preserves a valid travel save")
	var raw=JSON.parse_string(FileAccess.get_file_as_string(path))
	raw.campus.people[0].current_plot=5000
	check(not loaded._validate_save(raw),"out-of-map resident travel is rejected")
	var staff=State.CampusSim.new(); staff.setup(0,8)
	staff.elapsed=100
	staff.tick(1,{"plaza_plot":0,"reactors":[],"buildings":[{"plot":1,"kind":"institute","connected":true,"capacity":3},{"plot":2,"kind":"institute","connected":true,"capacity":4}]})
	var first=0; var second=0; var unassigned=0
	for person in staff.people:
		if person.work_plot==1: first+=1
		elif person.work_plot==2: second+=1
		else: unassigned+=1
	check(first==3 and second==4 and unassigned==1,"multiple institutes respect each workplace capacity")
	for suffix in ["",".bak"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	s.close_science(); loaded.close_science()
	print("PASS: ",checks," campus integration checks" if failures.is_empty() else " FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
