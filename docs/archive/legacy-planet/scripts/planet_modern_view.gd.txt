extends Node3D
## Procedural scene consumes the simulation; no rendering callback changes resources.
var builder
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_modern.json"))
var sites={}
var panels={}
var people=[]
var windows=[]
var cells=[]
var servers=[]
var custom_badge: Node3D
var fan: Node3D
var park: Node3D
var scaffold: Node3D
var recycle_rotor: Node3D
var scrap=[]
var residue=[]
var power_lines=[]
var streetlights=[]
var light_materials={}
var sun: Node3D
var moon: Node3D
var glow: OmniLight3D
var snapshot={}
var time=0.0
func _pos(id: String) -> Vector3:
	var a=rules.nodes[id]; return Vector3(a[0],0.05,a[1])
func setup(b) -> void:
	builder=b; var scenery=Node3D.new(); add_child(scenery)
	var land=b._sphere(scenery,3.8,Vector3(0,-0.66,0),"698780"); land.scale=Vector3(1.08,.17,.91)
	var lower=b._sphere(scenery,3.82,Vector3(0,-.86,0),"466975"); lower.scale=Vector3(1.08,.17,.92)
	for id in rules.nodes:
		if id=="junction": continue
		var p=_pos(id); var road=b._box(scenery,Vector3(.24,.022,p.length()),p*.5,"b1b59e"); road.look_at(Vector3(0,p.y,0))
		var root=Node3D.new(); root.position=p; add_child(root)
		var mark=b._ring(root,.63,.66,Vector3(0,.05,0),"a5efd1"); mark.hide(); sites["modern_"+str(id)]={"root":root,"marker":mark}
		var fixed=Node3D.new(); root.add_child(fixed)
		match id:
			"roof":
				_tower(fixed,Vector3(1.05,.7,.82),"cfceba")
				b._box(fixed,Vector3(1.20,.07,.95),Vector3(0,.73,0),"bed0c3")
				_panel(root,id,.82)
			"field":
				b._box(fixed,Vector3(1.5,.05,1.0),Vector3(0,0,0),"adc3a2")
				_panel(root,id,.3)
			"battery":
				_tower(fixed,Vector3(.7,.52,.6),"93bdb3")
				for i in range(5): cells.append(b._box(root,Vector3(.08,.2,.025),Vector3(-.24+i*.12,.28,.32),"496a72"))
			"compute":
				_tower(fixed,Vector3(1.1,.9,.78),"8baab1")
				for i in range(3):
					var stripe=b._box(fixed,Vector3(.1,.92,.82),Vector3(-.45+i*.45,.45,0),"d0d5c3")
				for i in range(3):
					var rack=Node3D.new(); rack.position=Vector3(-.3+i*.3,.5,.42); root.add_child(rack)
					for j in range(4): b._box(rack,Vector3(.19,.045,.03),Vector3(0,-.23+j*.16,0),"78c7c4")
					servers.append(rack)
			"cooling":
				b._cylinder(fixed,.36,.45,Vector3(0,.23,0),"b5c8bb")
				custom_badge=b._box(root,Vector3(.22,.06,.22),Vector3(.33,.57,0),"bbbcff"); custom_badge.hide()
				fan=Node3D.new(); fan.position=Vector3(0,.49,0); root.add_child(fan)
				for i in range(4):
					var blade=b._box(fan,Vector3(.52,.025,.085),Vector3.ZERO,"648994"); blade.rotation.y=i*PI/4
				b._ring(fixed,.38,.41,Vector3(0,.49,0),"d4d3b9")
			"recycle":
				_tower(fixed,Vector3(.8,.45,.65),"b6bb97")
				var roof=b._box(fixed,Vector3(.88,.06,.76),Vector3(0,.5,0),"659b88"); roof.rotation.z=.12
				recycle_rotor=Node3D.new(); recycle_rotor.position=Vector3(0,.26,.35); root.add_child(recycle_rotor)
				for i in range(3):
					var spoke=b._box(recycle_rotor,Vector3(.2,.025,.03),Vector3.ZERO,"dfc38b"); spoke.rotation.z=i*PI/3
				for i in range(5):
					scrap.append(b._box(root,Vector3(.09,.1,.10),Vector3(-.4+i*.17,.07,.54),"91aab1"))
					residue.append(b._box(root,Vector3(.09,.1,.09),Vector3(-.4+i*.17,.07,-.50),"8c8a73"))
			"homes":
				for i in range(2):
					var home=Node3D.new(); home.position.x=-.25+i*.5; fixed.add_child(home); _tower(home,Vector3(.42,.7+i*.25,.48),"dacda7")
					for j in range(3): windows.append(b._box(root,Vector3(.11,.10,.025),Vector3(-.25+i*.5,.2+j*.2,.26),"50717b"))
			"park":
				park=Node3D.new(); root.add_child(park)
				b._cylinder(park,.45,.04,Vector3(0,.02,0),"93b991")
				for p2 in [Vector3(-.2,.1,-.05),Vector3(.23,.1,.2)]:
					b._cylinder(park,.025,.35,p2+Vector3(0,.1,0),"94846b"); b._sphere(park,.18,p2+Vector3(0,.34,0),"78a78b")
				b._box(park,Vector3(.34,.05,.1),Vector3(0,.13,-.3),"d2bc92")
				scaffold=Node3D.new(); root.add_child(scaffold)
				for x in [-.4,.4]: b._box(scaffold,Vector3(.025,.4,.025),Vector3(x,.2,0),"c4b793")
				b._box(scaffold,Vector3(.86,.04,.06),Vector3(0,.38,0),"c4b793")
				preload("res://scripts/static_geometry.gd").bake(park); preload("res://scripts/static_geometry.gd").bake(scaffold)
		preload("res://scripts/static_geometry.gd").bake(fixed)
	for id in ["roof","field","compute","homes","cooling","recycle"]:
		var a=_pos(id)+Vector3(0,.04,0); var dest=_pos("junction")+Vector3(0,.04,0)
		var line=b._box(scenery,Vector3(.04,.02,a.distance_to(dest)),(a+dest)*.5,"708f92"); line.look_at(dest)
		var pulse=b._sphere(self,.035,a,"ace7cd"); power_lines.append({"id":id,"a":a,"b":dest,"pulse":pulse})
	for p in [Vector3(-.5,0,1.8),Vector3(1.5,0,.8),Vector3(.4,0,-.7)]:
		b._cylinder(scenery,.018,.42,p+Vector3(0,.21,0),"7a9396")
		b._box(scenery,Vector3(.16,.018,.018),p+Vector3(.065,.42,0),"7a9396")
		streetlights.append(b._sphere(self,.035,p+Vector3(.13,.4,0),"edcf91"))
	for i in range(6):
		var root=Node3D.new(); add_child(root)
		b._cylinder(root,.045,.14,Vector3(0,.16,0),"779cac" if i<2 else "bcae8b" if i==2 else "9bc0ac"); b._sphere(root,.042,Vector3(0,.275,0),"e0c9af")
		var legs=[]
		for x in [-.027,.027]: legs.append(b._box(root,Vector3(.03,.10,.03),Vector3(x,.06,0),"536e75"))
		people.append({"root":root,"legs":legs})
	sun=b._sphere(self,.22,Vector3(-2.9,2.8,-2.0),"edce91"); moon=b._sphere(self,.17,Vector3(2.9,2.5,-2.0),"c6d8e3")
	glow=OmniLight3D.new(); glow.position=Vector3(0,2,0); glow.omni_range=7; glow.light_color=Color("c6e0e5"); glow.light_energy=.45; add_child(glow)
	preload("res://scripts/static_geometry.gd").bake(scenery)
func _tower(root: Node3D,size: Vector3,color: String) -> void:
	builder._box(root,size,Vector3(0,size.y/2,0),color); builder._box(root,Vector3(size.x*1.12,.05,size.z*1.1),Vector3(0,size.y+.015,0),"cfdbcd")
func _panel(root: Node3D,id: String,height: float) -> void:
	var deck=Node3D.new(); deck.position.y=height; deck.rotation.x=-.18; root.add_child(deck)
	var tiles=[]
	for x in range(3):
		for z in range(2): tiles.append(builder._box(deck,Vector3(.35,.045,.32),Vector3(-.37+x*.37,0,-.18+z*.36),"4b849f"))
	panels[id]={"root":deck,"tiles":tiles}
func _location(p: Dictionary) -> Vector3:
	var result=_pos(p.at)
	if not p.route.is_empty(): result=result.lerp(_pos(p.route[0]),float(p.progress))
	return result+Vector3((int(p.id)%3-1)*.13,0,.25+(int(p.id)/3)*.1)
func _lit(color: String) -> StandardMaterial3D:
	if not light_materials.has(color):
		var material=StandardMaterial3D.new(); material.albedo_color=Color(color); material.emission_enabled=true; material.emission=Color(color); material.emission_energy_multiplier=.7
		light_materials[color]=material
	return light_materials[color]
func sync(world: Dictionary) -> void:
	var changed=snapshot.get("id","")!=world.id or int(snapshot.get("seconds",0))>int(world.seconds)
	var state={}
	for key in world.modern:
		if key!="history": state[key]=world.modern[key]
	snapshot={"id":world.id,"seconds":world.seconds,"paused":world.paused,"modern":state.duplicate(true)}
	if changed:
		for i in range(people.size()): people[i].root.position=_location(state.people[i])
func _process(dt: float) -> void:
	if not visible or snapshot.is_empty(): return
	var w=snapshot.modern
	if not snapshot.paused and w.enabled: time+=dt
	var night=posmod(int(w.elapsed),int(rules.day.period))>=rules.day.daylight
	sun.visible=not night; moon.visible=night; glow.light_energy=.08 if night else .45
	for id in panels:
		var panel=w.panels[id]; panels[id].root.visible=not panel.recipe.is_empty()
		if not panel.recipe.is_empty():
			var color=Color(rules.panels[panel.recipe].color).lerp(Color("9c9a87"),floor((1-panel.quality)*10)/10.0)
			for tile in panels[id].tiles: tile.material_override=builder._mat(color.to_html(false))
	for i in range(cells.size()): cells[i].material_override=builder._mat("b4e5b9" if float(i+1)/5<=w.battery_J/float(rules.battery.capacity_J) else "496a72")
	for lamp in windows: lamp.material_override=_lit("edcf91") if w.flow.homes>100 else builder._mat("50717b")
	for lamp in streetlights: lamp.material_override=_lit("edcf91") if w.flow.homes>100 else builder._mat("50717b")
	for rack in servers:
		rack.visible=w.installed.server
		for lamp in rack.get_children(): lamp.material_override=_lit("dd9c88" if w.tripped else "9be7d1") if w.tripped or w.flow.compute>0 else builder._mat("526a77")
	custom_badge.visible=not w.get("custom_sink",{}).is_empty()
	if custom_badge.visible: custom_badge.material_override=builder._mat("d99367" if w.custom_sink.basis=="family_model" else "bbbcff")
	fan.visible=w.installed.fan
	if not snapshot.paused:
		fan.rotation.y+=dt*w.flow.fan*.025
		recycle_rotor.rotation.z+=dt*w.flow.recycle*.01
	park.visible=w.park; scaffold.visible=not w.park and w.park_spent>0
	for i in range(scrap.size()): scrap[i].visible=i<w.scrap; residue[i].visible=i<w.residue
	for line in power_lines:
		var active=w.solar_W>0 if line.id in ["roof","field"] else w.flow["fan" if line.id=="cooling" else line.id]>0
		line.pulse.visible=active; line.pulse.position=line.a.lerp(line.b,fposmod(time*.28,1.0))
	for i in range(people.size()):
		var p=w.people[i]; var view=people[i]; view.root.visible=w.enabled
		var target=_location(p); var delta=target-view.root.position; view.root.position=view.root.position.lerp(target,minf(1,dt*12))
		if delta.length()>.02: view.root.rotation.y=atan2(delta.x,delta.z)
		for j in range(2): view.legs[j].rotation.x=sin(time*7+j*PI)*.45 if not p.route.is_empty() and not snapshot.paused else 0
