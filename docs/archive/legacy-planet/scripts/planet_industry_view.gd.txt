extends Node3D
## Utility animation reads real delivered power, staffing, cargo and repair state.
var builder
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_industry.json"))
var sites={}
var wires={}
var windows={}
var people=[]
var snapshot={}
var time=0.0
var flywheel: Node3D
var chimney: Node3D
var engine: Node3D
var recovery: Node3D
var cargo: Node3D
var truck: Node3D
var train: Node3D
var vehicle: Node3D
var smoke=[]
var supplies=[]
var warning: Node3D
var workshop_rotor: Node3D
var damage_marks={}
var repair_tools=[]
var heat_pipe: Node3D
var heat_pulse: Node3D
var heat_start: Vector3
var heat_end: Vector3
var rails: Node3D

func _pos(id: String) -> Vector3:
	var a=rules.nodes[id]; return Vector3(float(a[0]),0.05,float(a[1]))

func setup(b) -> void:
	builder=b; var scenery=Node3D.new(); add_child(scenery)
	var land=b._sphere(scenery,3.6,Vector3(0,-0.59,0),"617577"); land.scale=Vector3(1.1,0.16,0.8)
	var coast=b._sphere(scenery,3.63,Vector3(0,-0.76,0),"3e6472"); coast.scale=Vector3(1.1,0.16,0.82)
	for id in rules.nodes:
		if id=="junction": continue
		var p=_pos(id); var road=b._box(scenery,Vector3(0.29,0.028,p.length()),p*0.5,"9b9c8a"); road.look_at(Vector3(0,p.y,0))
		var root=Node3D.new(); root.position=p; add_child(root)
		var marker=b._ring(root,0.62,0.66,Vector3(0,0.04,0),"a5efd1"); marker.hide(); sites["industry_"+str(id)]={"root":root,"marker":marker}
		var building=Node3D.new(); root.add_child(building)
		b._box(building,Vector3(1.25,0.08,1.0),Vector3(0,-0.015,0),"899185")
		match id:
			"power":
				_house(building,Vector3(0.95,0.70,0.75),"947f69","4d6265")
				chimney=b._cylinder(building,0.12,1.05,Vector3(-0.35,0.55,-0.28),"a68a74")
				engine=Node3D.new(); root.add_child(engine)
				b._box(engine,Vector3(0.42,0.32,0.37),Vector3(0.24,0.19,0.56),"9bbaa8")
				flywheel=Node3D.new(); flywheel.name="Building"; flywheel.position=Vector3(0.48,0.22,0.57); engine.add_child(flywheel)
				b._cylinder(flywheel,0.19,0.04,Vector3.ZERO,"e0bd87").rotation.z=PI/2
				for i in range(4):
					var spoke=b._box(flywheel,Vector3(0.06,0.28,0.032),Vector3.ZERO,"617471"); spoke.rotation.x=i*PI/4
				recovery=Node3D.new(); root.add_child(recovery)
				for i in range(4): b._cylinder(recovery,0.04,0.4,Vector3(-0.35+i*0.1,0.23,0.58),"dbb78c")
				for i in range(6): smoke.append(b._sphere(root,0.065,Vector3(-0.35,1.25,-0.28),"c7c9b9"))
			"homes":
				for i in range(3):
					var home=Node3D.new(); home.position.x=-0.38+i*0.38; building.add_child(home); _house(home,Vector3(0.32,0.47,0.55),"b59d80","68827b")
			"clinic":
				_house(building,Vector3(0.8,0.65,0.72),"ddd3af","719c97")
				b._box(building,Vector3(0.16,0.045,0.025),Vector3(0,0.54,0.37),"dca15c"); b._box(building,Vector3(0.045,0.16,0.025),Vector3(0,0.54,0.37),"dca15c")
			"factory":
				b._box(building,Vector3(1.15,0.63,0.87),Vector3(0,0.315,0),"a18470")
				for i in range(3):
					var roof=b._box(building,Vector3(0.39,0.06,0.98),Vector3(-0.38+i*0.38,0.72,0),"718d91"); roof.rotation.z=-0.35
				workshop_rotor=Node3D.new(); root.add_child(workshop_rotor); workshop_rotor.position=Vector3(0.42,0.45,0.48)
				for i in range(4):
					var spoke=b._box(workshop_rotor,Vector3(0.25,0.025,0.035),Vector3.ZERO,"d9c9a5"); spoke.rotation.z=i*PI/4
			"signal":
				_house(building,Vector3(0.58,0.41,0.48),"aca991","667a7e")
				for x in [-0.28,0.28]: b._cylinder(building,0.025,1.3,Vector3(x,0.65,0),"b9c4b0")
				for i in range(4): b._box(building,Vector3(0.62,0.025,0.03),Vector3(0,0.42+i*0.28,0),"b9c4b0")
			"depot":
				_house(building,Vector3(1.0,0.45,0.65),"969e86","7c8172")
				var shelter=b._cylinder(building,0.33,0.7,Vector3(0.57,0.20,0.1),"7b897b"); shelter.rotation.z=PI/2
				for i in range(6): supplies.append(b._box(root,Vector3(0.14,0.14,0.14),Vector3(-0.44+i*0.16,0.10,0.44),"d1b381"))
		if rules.loads.has(id):
			var lamp=b._box(root,Vector3(0.15,0.15,0.026),Vector3(-0.22,0.32,0.46),"455d68"); windows[id]=lamp
		if id in ["power","signal"]:
			var damaged=Node3D.new(); root.add_child(damaged)
			for i in range(3):
				var crack=b._box(damaged,Vector3(0.025,0.16,0.028),Vector3(-0.12+i*0.035,0.25+i*0.09,0.40),"464f50"); crack.rotation.z=0.5 if i%2==0 else -0.5
			damage_marks[id]=damaged
		preload("res://scripts/static_geometry.gd").bake(building)
	# Static details are merged once; the few changing objects remain separate.
	for p in [Vector3(-1.2,0,1.45),Vector3(1.15,0,1.85),Vector3(-1.5,0,-1.8)]:
		b._cylinder(scenery,0.025,0.35,p+Vector3(0,0.18,0),"897d65")
		b._sphere(scenery,0.21,p+Vector3(0,0.47,0),"91a184")
	for p in [Vector3(-0.7,0.10,2.0),Vector3(1.1,0.10,0.65)]:
		b._box(scenery,Vector3(0.4,0.05,0.14),p,"c3b190")
		for x in [-0.14,0.14]: b._box(scenery,Vector3(0.03,0.1,0.08),p+Vector3(x,-0.05,0),"67776e")
	heat_start=_pos("power")+Vector3(0,0.1,0.6); heat_end=_pos("homes")+Vector3(0,0.1,0.35)
	heat_pipe=b._box(self,Vector3(0.07,0.07,heat_start.distance_to(heat_end)),(heat_start+heat_end)*0.5,"b78c63"); heat_pipe.look_at(heat_end)
	heat_pulse=b._sphere(self,0.045,heat_start,"edcf91")
	rails=Node3D.new(); add_child(rails)
	for segment in [[_pos("factory"),_pos("junction")],[_pos("junction"),_pos("depot")]]:
		var a: Vector3=segment[0]; var dest: Vector3=segment[1]; var side=(dest-a).normalized().cross(Vector3.UP)*0.12
		for sign in [-1,1]:
			var rail=b._box(rails,Vector3(0.018,0.024,a.distance_to(dest)),(a+dest)/2+side*sign+Vector3(0,0.014,0),"667677"); rail.look_at(dest+side*sign+Vector3(0,0.014,0))
		for i in range(12):
			var sleeper=b._box(rails,Vector3(0.32,0.018,0.05),a.lerp(dest,i/12.0)+Vector3(0,0.006,0),"837e6a"); sleeper.rotation.y=atan2(dest.x-a.x,dest.z-a.z)
	preload("res://scripts/static_geometry.gd").bake(rails)
	for id in rules.loads:
		var a=_pos("power")+Vector3(0,0.88,0); var dest=_pos(id)+Vector3(0,0.75,0); var mid=(a+dest)/2
		var wire=b._box(self,Vector3(0.02,0.02,a.distance_to(dest)),mid,"d2ac73"); wire.look_at(dest)
		var pulse=b._sphere(self,0.035,mid,"a5efd1"); wires[id]={"line":wire,"pulse":pulse,"a":a,"b":dest}
	warning=b._sphere(self,0.11,Vector3(0,0.58,0),"e0a472")
	for i in range(6):
		var root=Node3D.new(); add_child(root); b._cylinder(root,0.048,0.15,Vector3(0,0.16,0),"81989b" if i<3 else "c3b290"); b._sphere(root,0.045,Vector3(0,0.28,0),"e1c7a6")
		var legs=[]
		for x in [-0.028,0.028]: legs.append(b._box(root,Vector3(0.033,0.10,0.036),Vector3(x,0.06,0),"596966"))
		var tool=b._box(root,Vector3(0.1,0.06,0.06),Vector3(0.075,0.14,0),"d0b17c"); tool.visible=i==0
		repair_tools.append(tool)
		people.append({"root":root,"legs":legs})
	vehicle=Node3D.new(); add_child(vehicle); train=Node3D.new(); vehicle.add_child(train); truck=Node3D.new(); vehicle.add_child(truck)
	b._box(truck,Vector3(0.30,0.13,0.55),Vector3(0,0.16,0),"6f8f81"); b._box(truck,Vector3(0.29,0.19,0.23),Vector3(0,0.3,0.16),"9aad8e"); b._box(truck,Vector3(0.25,0.08,0.015),Vector3(0,0.33,0.28),"8fb9bd")
	b._cylinder(train,0.13,0.35,Vector3(0,0.28,0.04),"758b89").rotation.x=PI/2; b._box(train,Vector3(0.3,0.30,0.21),Vector3(0,0.25,-0.22),"b6a47c"); b._cylinder(train,0.048,0.24,Vector3(0,0.47,0.15),"6d7870")
	for body in [truck,train]:
		for x in [-0.16,0.16]:
			for z in [-0.18,0.18]: b._cylinder(body,0.076,0.035,Vector3(x,0.10,z),"384e52").rotation.z=PI/2
		preload("res://scripts/static_geometry.gd").bake(body)
	cargo=b._box(vehicle,Vector3(0.2,0.13,0.17),Vector3(0,0.31,-0.11),"d6b475")
	preload("res://scripts/static_geometry.gd").bake(scenery)

func _house(root: Node3D,size: Vector3,color: String,roof_color: String) -> void:
	builder._box(root,size,Vector3(0,size.y/2,0),color)
	for sign in [-1,1]:
		var roof=builder._box(root,Vector3(size.x*0.60,0.05,size.z*1.18),Vector3(sign*size.x*0.23,size.y+0.07,0),roof_color); roof.rotation.z=sign*-0.40
	builder._box(root,Vector3(size.x*0.17,size.y*0.50,0.025),Vector3(0,size.y*0.25,size.z*0.52),"596763")

func _location(p: Dictionary) -> Vector3:
	var result=_pos(p.at)
	if not p.route.is_empty(): result=result.lerp(_pos(p.route[0]),float(p.progress))
	return result+Vector3((int(p.id)%3-1)*0.13,0,0.3+(int(p.id)/3)*0.12)

func sync(world: Dictionary) -> void:
	var changed=snapshot.get("id","")!=world.id or int(snapshot.get("seconds",0))>int(world.seconds)
	var w={}
	for key in world.industry:
		if key!="history": w[key]=world.industry[key]
	snapshot={"id":world.id,"seconds":world.seconds,"paused":world.paused,"industry":w.duplicate(true)}
	if changed:
		for i in range(people.size()): people[i].root.position=_location(w.people[i])

func _process(dt: float) -> void:
	if not visible or snapshot.is_empty(): return
	var w=snapshot.industry
	if not snapshot.paused and w.enabled: time+=dt
	engine.visible=w.engine; recovery.visible=w.recovery; warning.visible=w.alert
	for id in damage_marks: damage_marks[id].visible=w.integrity[id]<1
	heat_pipe.visible=w.recovery; heat_pulse.visible=w.heat_service>0
	heat_pulse.position=heat_start.lerp(heat_end,fposmod(time*0.2,1.0))
	if not snapshot.paused and w.generated_W>0: flywheel.rotation.x+=dt*4
	for i in range(smoke.size()):
		smoke[i].visible=w.generated_W>0; smoke[i].position.y=1.1+fposmod(time*0.22+i*0.15,0.8); smoke[i].scale=Vector3.ONE*(0.6+fposmod(time*0.22+i*0.15,0.8))
	for id in wires:
		var v=wires[id]; v.line.visible=not w.cables[id].is_empty() or w.get("custom_cables",{}).has(id); v.pulse.visible=w.flow[id]>0
		v.pulse.position=v.a.lerp(v.b,fposmod(time*0.25,1.0))
		v.line.material_override=builder._mat("bbbcff" if w.get("custom_cables",{}).has(id) else "acccb9" if w.flow[id]>0 else "8b776d")
		windows[id].material_override=builder._mat("edcf91" if w.flow[id]>float(rules.loads[id].rated_W)*0.4 else "455d68")
	if not snapshot.paused and w.factory.active and w.flow.factory>0 and not (w.alert and w.era=="ww2"): workshop_rotor.rotation.z+=dt*2
	for i in range(people.size()):
		var p=w.people[i]; var v=people[i]; v.root.visible=w.enabled; var target=_location(p); var offset=target-v.root.position
		v.root.position=v.root.position.lerp(target,minf(1,dt*12))
		if offset.length()>0.02: v.root.rotation.y=atan2(offset.x,offset.z)
		for j in range(2): v.legs[j].rotation.x=sin(time*7+j*PI)*0.45 if not p.route.is_empty() and not snapshot.paused else 0
		if i==0: repair_tools[i].rotation.z=sin(time*6)*0.5 if p.task=="work" and w.repairs and not w.repair.target.is_empty() and not snapshot.paused else 0.0
	train.visible=w.era=="ww1"; rails.visible=w.era=="ww1"; truck.visible=w.era=="ww2"; vehicle.visible=w.enabled
	var t=w.truck; var factor=1.0-float(t.progress) if t.stage=="return" else (float(t.progress) if t.stage=="outbound" else 0.0)
	var a=_pos("factory"); var b=_pos("depot"); var middle=Vector3(0,0.05,0)
	vehicle.position=a.lerp(middle,factor*2) if factor<0.5 else middle.lerp(b,(factor-0.5)*2)
	var direction=(middle-a if factor<0.5 else b-middle)*( -1 if t.stage=="return" else 1)
	vehicle.rotation.y=atan2(direction.x,direction.z); cargo.visible=t.amount>0
	for i in range(supplies.size()): supplies[i].visible=i<w.stock.stock/2
