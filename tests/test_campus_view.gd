extends SceneTree

const CampusView=preload("res://scripts/campus_view.gd")
const Layout=preload("res://scripts/campus_layout.gd")
const Campus=preload("res://scripts/campus_sim.gd")
var failures: Array=[]
var checks=0

class Island extends Node3D:
	var _detail_signature="visible-0-1-2"
	var _camera_target=Vector3.ZERO
	var _visible_plots={0:true,1:true,2:true}
	var _detailed_plots={0:true,1:true,2:true}

class Model extends RefCounted:
	var layout=Layout.new()
	var campus=Campus.new()
	var visitor_visits=0
	var available=true
	var plots=[{"x":0,"z":0,"unlocked":true,"kind":"plaza","road":true,"props":[]},
		{"x":1,"z":0,"unlocked":true,"kind":"engineer_house","road":true,"props":[{"kind":"fence","slot":0},{"kind":"fence","slot":1}]},
		{"x":2,"z":0,"unlocked":true,"kind":"institute","road":true,"props":[]}]
	func visitor_available(): return available

func check(condition: bool, label: String):
	checks+=1
	if not condition: failures.append(label); push_error(label)

func frames(view, seconds: float):
	for frame in range(ceili(seconds/0.04)): view._process(0.04)

func _initialize(): call_deferred("run")

func run():
	var model=Model.new()
	model.layout.initialize(model.plots)
	model.campus.setup(40,0)
	for person in model.campus.people:
		person.current_plot=0; person.next_plot=1; person.target_plot=1
		person.moving=true; person.arrived=false; person.movement_progress=0.4
		person.activity="construct"
	var island=Island.new(); root.add_child(island)
	var view=CampusView.new(); view.setup(model,island); view.set_process(false)
	check(view.actors.size()==24 and model.campus.people.size()==40,"render budget preserves all logical residents")
	check(view.static_rebuilds==1,"initial static geometry built once")
	var road=view.scenery.get_node("ConnectedRoads")
	check(road is MultiMeshInstance3D and road.multimesh.instance_count==5,"connected road hubs and links share one MultiMesh")
	var rebuilds=view.avatar_rebuilds
	for repeat in range(30): view.sync()
	check(view.static_rebuilds==1 and view.avatar_rebuilds==rebuilds,"idle sync rebuilds neither geometry nor residents")
	var actor=view.actors.values()[0]
	view._process(0.25)
	var expected=model.layout.hub(model.plots,0).lerp(model.layout.hub(model.plots,1),0.5)
	check(actor.node.position.is_equal_approx(expected),"renderer follows simulation road segment and interpolates its progress")
	check(is_zero_approx(actor.tool.rotation.x),"engineering work animation waits until actual arrival")
	view.sync(); view._process(0.25)
	check(actor.node.position.x>expected.x,"sync between simulation ticks does not rewind walking")
	var person=model.campus.people[0]
	person.current_plot=1; person.next_plot=1; person.movement_progress=0.0; person.moving=false; person.arrived=true; person.activity="research"
	island._camera_target=model.layout.hub(model.plots,1)
	view.sync(); view._process(0.1)
	check(not view.actors[int(person.id)].node.visible,"arrived researcher enters institute")
	for index in range(24):
		person=model.campus.people[index]
		person.current_plot=2; person.next_plot=2; person.target_plot=2
	island._visible_plots={0:true,1:true}; island._detailed_plots={0:true,1:true}; island._detail_signature="visible-0-1"
	view.sync()
	check(view.actors.size()==16 and view.avatar_rebuilds==rebuilds,"camera visibility reuses retired avatars instead of rebuilding them")
	check(view.static_rebuilds==2,"camera detail change rebuilds static geometry once")
	check(view.transport.get_meta("vehicle_style")=="bicycle","first buyer arrives by bicycle")
	frames(view,6)
	check(view.visitor_phase=="browsing" and view.buyer.node.visible,"buyer walks from parked transport into plaza")
	var transport_id=view.transport.get_instance_id()
	model.visitor_visits=1; model.available=false; view.sync()
	check(view.visitor_phase=="boarding" and view.transport.get_instance_id()==transport_id and view.visitor_key==0,"sale keeps outgoing buyer and vehicle through boarding")
	frames(view,7)
	check(view.visitor_phase=="absent" and not view.transport.visible and not view.buyer.node.visible,"buyer and transport finish departure during cooldown")
	check(view.vehicle_rebuilds==1,"cooldown does not create next vehicle early")
	model.available=true; view.sync()
	check(view.transport.get_meta("vehicle_style")=="car" and view.visitor_key==1 and view.vehicle_rebuilds==2,"next visit selects next vehicle after cooldown")
	frames(view,1)
	transport_id=view.transport.get_instance_id()
	model.visitor_visits=2; model.available=false; view.sync()
	check(view.visitor_phase=="departing" and view.transport.get_instance_id()==transport_id,"visitor dismissed while driving departs without teleporting or replacement")
	frames(view,6); model.available=true; view.sync()
	check(view.transport.get_meta("vehicle_style")=="minibus","third visit arrives by minibus")
	var untouched=model.campus.people[25].duplicate(true)
	frames(view,3)
	check(model.campus.people[25]==untouched,"presentation never mutates simulation work or arrival state")
	island.queue_free()
	await process_frame
	print("Campus view checks: %d, failures: %d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
