extends Node3D
## Bounded representative models; their poses follow cohorts, never drive the model.
var builder
var sites: Dictionary={}
var snapshot: Dictionary={}
var anim_time=0.0
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_ecology.json"))

func setup(host) -> void:
	builder=host
	_make_region("microbe",Vector3(-1.12,1.35,2.14))
	_make_region("fish",Vector3(1.13,0.65,2.53))

func _make_region(id: String,normal: Vector3) -> void:
	var b=builder; var root=Node3D.new(); add_child(root)
	var up=normal.normalized(); var right=Vector3.UP.cross(up).normalized()
	root.transform=Transform3D(Basis(right,up,right.cross(up).normalized()),up*2.68)
	b._cylinder(root,0.94,0.20,Vector3.ZERO,"3b6869")
	b._ring(root,0.75,0.92,Vector3(0,0.14,0),"d4c395")
	b._cylinder(root,0.74,0.045,Vector3(0,0.13,0),"366b78" if id=="microbe" else "388c9e")
	var marker=b._ring(root,0.96,0.985,Vector3(0,0.17,0),"a5efd1"); marker.visible=false
	var station=Node3D.new(); station.position=Vector3(0.63,0.28,0.43); root.add_child(station)
	b._box(station,Vector3(0.36,0.07,0.30),Vector3.ZERO,"d2d9c9")
	b._cylinder(station,0.11,0.35,Vector3(0,0.21,0),"567fbc")
	b._ring(station,0.108,0.12,Vector3(0,0.30,0),"e4eddf")
	var gas=b._cylinder(station,0.055,0.25,Vector3(0.16,0.17,0),"a5efd1")
	var light=b._sphere(station,0.055,Vector3(0,0.46,0),"ffd18c")
	b._box(station,Vector3(0.52,0.045,0.045),Vector3(-0.24,0.04,-0.08),"ebc996")
	var core=b._box(station,Vector3(0.08,0.27,0.19),Vector3(-0.18,0.22,0),"d99367")
	var heat=b._cylinder(station,0.023,0.26,Vector3(-0.28,0.20,0),"eea177")
	var bubbles=[]
	for i in range(7): bubbles.append(b._sphere(root,0.024,Vector3.ZERO,"b9ede2"))
	var info={"root":root,"marker":marker,"station":station,"gas":gas,"light":light,"bubbles":bubbles,"core":core,"heat":heat}
	if id=="microbe":
		var sensitive=[]; var tolerant=[]
		for i in range(13):
			var angle=float(i)*2.399; var radius=sqrt(float(i)/13.0)*0.54
			var pos=Vector3(cos(angle)*radius,0.17,sin(angle)*radius)
			sensitive.append(b._cylinder(root,0.135,0.035,pos,"be8aad"))
			tolerant.append(b._cylinder(root,0.07,0.025,pos+Vector3(0.07,0.015,0.04),"accd70"))
		var refuge=Node3D.new(); refuge.position=Vector3(-0.72,0.18,-0.34); root.add_child(refuge)
		b._cylinder(refuge,0.24,0.10,Vector3.ZERO,"476064")
		var survivors=b._cylinder(refuge,0.19,0.025,Vector3(0,0.06,0),"c9a0be")
		var lid=b._ring(refuge,0.21,0.26,Vector3(0,0.10,0),"f5dda5")
		for i in range(3):
			var stone=Node3D.new(); stone.position=Vector3(0.3+i*0.14,0.22,-0.63); root.add_child(stone)
			for j in range(3): b._cylinder(stone,0.09-j*0.018,0.04,Vector3(0,j*0.035,0),"93bcb0" if j%2==0 else "4a7c74")
		info.merge({"sensitive":sensitive,"tolerant":tolerant,"refuge":survivors,"lid":lid})
	else:
		b._cylinder(root,0.36,0.12,Vector3(-0.90,0.10,-0.23),"458a94")
		b._ring(root,0.33,0.38,Vector3(-0.90,0.18,-0.23),"afccad")
		b._box(root,Vector3(0.42,0.03,0.16),Vector3(-0.64,0.18,-0.23),"7fcece")
		var gate=b._box(root,Vector3(0.035,0.18,0.19),Vector3(-0.62,0.27,-0.23),"e1b787")
		var fish=[]
		for i in range(12):
			var animal=Node3D.new(); root.add_child(animal)
			var body=b._sphere(animal,0.058,Vector3.ZERO,"ffd490" if i%2==0 else "ef9b6d"); body.scale=Vector3(1.6,0.65,0.65)
			var tail=CylinderMesh.new(); tail.top_radius=0.045; tail.bottom_radius=0; tail.height=0.07; tail.radial_segments=3
			var fin=b._mesh(animal,tail,Vector3(-0.10,0,0),"ebc98a"); fin.rotation.z=PI*0.5
			b._sphere(animal,0.008,Vector3(0.064,0.02,0.032),"193b4d")
			animal.position=Vector3(-0.9,0.23,-0.23); fish.append(animal)
		var losses=b._box(root,Vector3(0.19,0.035,0.09),Vector3(0.48,0.20,-0.28),"bdc9c7"); losses.rotation.y=0.5
		info.merge({"fish":fish,"gate":gate,"losses":losses})
	sites[id]=info

func sync(world: Dictionary) -> void:
	snapshot=world.duplicate(true)

func _process(dt: float) -> void:
	if not visible or snapshot.is_empty(): return
	if not snapshot.paused: anim_time+=dt
	for id in sites:
		var info=sites[id]; var r=snapshot.ecology.regions[id]
		info.station.visible=r.device
		var running=r.device and r.enabled and r.gas>0 and r.energy>0 and not r.cooling
		info.light.material_override=builder._mat("ef7e6e" if r.cooling else ("a5efd1" if running else "edb386"))
		info.heat.scale.y=maxf(0.02,float(r.heat)/100.0)
		info.core.visible=not r.component.is_empty()
		if info.core.visible:
			var lab=builder.material_view.lab; var d=lab.data.designs[r.component.recipe]; var design=lab.design(str(r.component.recipe))
			info.core.material_override=builder._mat(str(lab.data.materials[d.material].color))
			info.core.scale.x=sqrt(float(design.area_m2)/float(lab.data.fixture.area_m2))
		info.gas.scale.y=maxf(0.02,float(r.gas)/float(rules.device.cartridge_units))
		for i in range(info.bubbles.size()):
			var bubble=info.bubbles[i]; bubble.visible=running
			var phase=fmod(anim_time*float(r.flow)*0.65+i/7.0,1.0)
			bubble.position=Vector3(0.18+sin(i*3+phase*5)*0.04,0.18+phase*0.50,0.35+cos(i*2)*0.04)
			bubble.scale=Vector3.ONE*(0.6+phase*0.8)
		if id=="microbe":
			for i in range(info.sensitive.size()):
				var scale_sensitive=sqrt(maxf(0,float(r.sensitive))/80.0)*(0.9+sin(anim_time+i)*0.04)
				info.sensitive[i].scale=Vector3(maxf(0.001,scale_sensitive),1,maxf(0.001,scale_sensitive))
				var scale_tolerant=sqrt(maxf(0,float(r.tolerant))/20.0)
				info.tolerant[i].scale=Vector3(maxf(0.001,scale_tolerant),1,maxf(0.001,scale_tolerant))
			info.refuge.scale=Vector3.ONE*maxf(0.001,sqrt(float(r.refuge)/float(rules.microbe.refuge_capacity)))
			info.lid.rotation.z=0.0 if r.sealed else 0.85
		else:
			info.gate.position.y=0.27 if not r.gate_open else 0.09
			info.losses.visible=float(r.dead)>0.2
			for i in range(info.fish.size()):
				var animal=info.fish[i]; var group_size=(float(rules.fish.initial_bay)+float(rules.fish.initial_outer))/info.fish.size()
				var represented=(float(i)+0.5)*group_size
				animal.visible=represented<float(r.bay)+float(r.outer)
				var in_bay=represented<float(r.bay)
				animal.scale=Vector3.ONE*(1.0 if in_bay else 0.65)
				var angle=anim_time*(0.38 if in_bay else 0.24)+TAU*i/info.fish.size()
				var radius=(0.28+(i%3)*0.08) if in_bay else (0.25+(i%2)*0.02)
				var target=Vector3(cos(angle)*radius,0.23+sin(angle*2)*0.015,sin(angle)*radius)
				if not in_bay: target+=Vector3(-0.90,0,-0.23)
				animal.position=animal.position.lerp(target,minf(1,dt*2.8))
				animal.rotation.y=-angle-PI*0.5
