extends Node3D
## Display only. Static scenery is merged; persistent animal nodes interpolate snapshots.
signal region_selected(id: String)
const Terrain=preload("res://scripts/river_terrain.gd")
const Walker=preload("res://scripts/river_walker.gd")
const Stream=preload("res://scripts/river_chunk_stream.gd")
const LifeView=preload("res://scripts/river_life_view.gd")
const CENTERS=Terrain.CENTERS
var terrain=Terrain.new()
var walker=Walker.new(terrain)
var hands
var ranch
var first_person=false
var has_walk_position=false
var chunks={}
var stream
var life_view
var construction_view
var settlement_view
var field_view
var camera: Camera3D
var terrain_root: Node3D
var sun: DirectionalLight3D
var env: Environment
var selected="wetland"
var close_view=false
var clock=0.0
var snapshot: Dictionary={}
var animal_nodes={}
var water_nodes={}
var crop_nodes={}
var building_nodes={}
var mat: StandardMaterial3D
var meshes={}
var season_seen=-1
var render_keys={}
var marker: MeshInstance3D
var yaw=-0.35
var zoom=1.0

func _ready() -> void:
	mat=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.roughness=0.92
	var environment=WorldEnvironment.new(); env=Environment.new(); environment.environment=env
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("102c37")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("b0cacc"); env.ambient_light_energy=0.8
	add_child(environment)
	sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-55,-30,0); sun.light_energy=1.3; sun.light_color=Color("ffe6bf"); add_child(sun)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=21; add_child(camera); camera.current=true
	hands=preload("res://scripts/first_person_hands.gd").new(); camera.add_child(hands); hands.hide()
	terrain_root=Node3D.new(); add_child(terrain_root)
	var sea=MeshInstance3D.new(); var ocean=PlaneMesh.new()
	ocean.size=Vector2.ONE*float(terrain.rules.radius)*6
	var sea_material=StandardMaterial3D.new(); sea_material.albedo_color=Color("4e8caa"); sea_material.roughness=0.85
	ocean.material=sea_material; sea.mesh=ocean; sea.position.y=-1.3; terrain_root.add_child(sea)
	stream=Stream.new(); stream.terrain=terrain; stream.material=mat; terrain_root.add_child(stream); chunks=stream.chunks
	for id in CENTERS:
		var n=MeshInstance3D.new(); terrain_root.add_child(n); water_nodes[id]=n
		crop_nodes[id]=MeshInstance3D.new(); terrain_root.add_child(crop_nodes[id])
		building_nodes[id]=MeshInstance3D.new(); terrain_root.add_child(building_nodes[id])
	for kind in ["marsh_fish","meadow_herbivore","woodland_boar"]: meshes[kind]=_animal_mesh(kind)
	life_view=LifeView.new(); life_view.terrain=terrain; life_view.material=mat; life_view.animal_mesh=meshes.meadow_herbivore; life_view.boar_mesh=meshes.woodland_boar; terrain_root.add_child(life_view)
	construction_view=preload("res://scripts/river_construction_view.gd").new(); construction_view.material=mat; terrain_root.add_child(construction_view)
	settlement_view=preload("res://scripts/river_settlement_view.gd").new(); settlement_view.material=mat; settlement_view.terrain=terrain; terrain_root.add_child(settlement_view)
	field_view=preload("res://scripts/river_field_view.gd").new(); field_view.material=mat; terrain_root.add_child(field_view)
	var ring=TorusMesh.new(); ring.inner_radius=4.8; ring.outer_radius=4.9; ring.rings=32; ring.ring_segments=4
	marker=MeshInstance3D.new(); marker.mesh=ring; var m=StandardMaterial3D.new(); m.albedo_color=Color("f5d789"); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; marker.material_override=m; add_child(marker)
	_camera(1.0)

func _surface() -> SurfaceTool:
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_material(mat); return st

func _cube(st: SurfaceTool,p: Vector3,size: Vector3,color: Color) -> void:
	var h=size*0.5
	var v=[p+Vector3(-h.x,-h.y,-h.z),p+Vector3(h.x,-h.y,-h.z),p+Vector3(h.x,h.y,-h.z),p+Vector3(-h.x,h.y,-h.z),p+Vector3(-h.x,-h.y,h.z),p+Vector3(h.x,-h.y,h.z),p+Vector3(h.x,h.y,h.z),p+Vector3(-h.x,h.y,h.z)]
	var faces=[[0,1,2,3],[5,4,7,6],[4,0,3,7],[1,5,6,2],[3,2,6,7],[4,5,1,0]]
	for face in faces:
		var normal=(v[face[2]]-v[face[0]]).cross(v[face[1]]-v[face[0]]).normalized()
		for i in [0,1,2,0,2,3]: st.set_color(color); st.set_normal(normal); st.add_vertex(v[face[i]])

func _region_at(x: float,z: float) -> String:
	return terrain.region_at(Vector2(x,z))

func _height(x: float,z: float) -> float:
	return terrain.height_at(Vector2(x,z))

func _terrain(season: int) -> void:
	stream.schedule(walker.position if first_person else Vector2.ZERO,season)

func _water(id: String,r: Dictionary) -> void:
	var st=_surface(); var count=0
	for i in range(-29,30):
		var z=float(i); var x=terrain.river_x(z)
		if _region_at(x,z)!=id or not terrain.inside(Vector2(x,z),1.0): continue
		var width=1.6+float(r.water)*2.8
		_cube(st,Vector3(x,0.1+r.water*0.15,z),Vector3(width,0.06,1.02),Color("59aab8").lerp(Color("85965a"),r.pollution*0.7))
		count+=1
	if id in ["meadow","highland"]:
		var c: Vector3=CENTERS[id]+Vector3(-1,0,0.8); c.y=_height(c.x,c.z)+0.09
		_cube(st,c,Vector3(0.2+r.water*1.1,0.045,0.25+r.water*1.2),Color("7bb6bb"))
		count+=1
	water_nodes[id].visible=count>0 and r.water>0.02
	if count>0: water_nodes[id].mesh=st.commit()

func _crops(id: String,r: Dictionary) -> void:
	var st=_surface(); var center: Vector3=CENTERS[id]; var count=0
	for i in range(r.crops.size()):
		var plot=r.crops[i]; var x=center.x+1.65+float(i%2)*0.75; var z=center.z-1.0+float(i/2)*0.8
		var h=_height(x,z)
		_cube(st,Vector3(x,h+0.07,z),Vector3(0.62,0.1,0.65),Color("635043"))
		for j in range(4):
			var size=0.1+plot.growth*0.55
			_cube(st,Vector3(x-0.18+(j%2)*0.32,h+size*0.5+0.13,z-0.16+(j/2)*0.3),Vector3(0.12,size,0.12),Color("dfc46c") if plot.ready else Color("9dcc79"))
		count+=1
	crop_nodes[id].visible=count>0
	if count>0: crop_nodes[id].mesh=st.commit()

func _buildings(id: String,r: Dictionary) -> void:
	var st=_surface(); var center: Vector3=CENTERS[id]; var count=0
	center.y=_height(center.x,center.z)-0.35
	for key in r.buildings:
		var p=center+Vector3(0.5,0,1.8); p.y=_height(p.x,p.z)
		if key=="frame_bundle":
			var rails=terrain.building_barriers({id:{"buildings":{"frame_bundle":1},"enclosed":r.enclosed}})
			for rect in rails:
				var at=rect.get_center(); var h=terrain.ground(at)
				_cube(st,Vector3(at.x,h+0.65,at.y),Vector3(rect.size.x,0.13,rect.size.y),Color("d5ba8f"))
				for tip in [rect.position,rect.end]:
					_cube(st,Vector3(tip.x,terrain.ground(tip)+0.42,tip.y),Vector3(0.13,0.84,0.13),Color("cbb48a"))
		elif key=="shade_canopy":
			p.x+=1.3
			for dx in [-0.5,0.5]:
				for dz in [-0.5,0.5]: _cube(st,p+Vector3(dx,0.7,dz),Vector3(0.08,1.4,0.08),Color("d2bd93"))
			_cube(st,p+Vector3(0,1.43,0),Vector3(1.3,0.12,1.3),Color("d9bb86"))
		else:
			if key=="screen_station": p.z-=1.0
			_cube(st,p+Vector3(0,0.32,0),Vector3(0.55,0.65,0.65),Color("c4ddd8"))
			_cube(st,p+Vector3(0,0.7,0),Vector3(0.5,0.1,0.57),Color("438e93"))
			_cube(st,p+Vector3(-0.38,0.15,0),Vector3(0.45,0.12,0.12),Color("e4c97d"))
		count+=1
	building_nodes[id].visible=count>0
	if count>0: building_nodes[id].mesh=st.commit()

func _animal_mesh(kind: String) -> Mesh:
	var st=_surface()
	if kind=="marsh_fish":
		_cube(st,Vector3.ZERO,Vector3(0.22,0.15,0.48),Color("f2cb81"))
		_cube(st,Vector3(0,0,0.27),Vector3(0.33,0.06,0.14),Color("e0a761"))
		for side in [-1,1]: _cube(st,Vector3(side*0.114,0.035,-0.15),Vector3(0.016,0.055,0.065),Color("263c48"))
	elif kind=="woodland_boar":
		_cube(st,Vector3(0,0.34,0),Vector3(0.56,0.45,0.76),Color("8a6754"))
		_cube(st,Vector3(0,0.31,-0.48),Vector3(0.4,0.28,0.32),Color("b38b73"))
		for side in [-1,1]:
			_cube(st,Vector3(side*0.21,0.65,-0.25),Vector3(0.15,0.20,0.08),Color("79543e"))
			_cube(st,Vector3(side*0.2,0.35,-0.64),Vector3(0.06,0.16,0.07),Color("f2e4c1"))
			_cube(st,Vector3(side*0.20,0.42,-0.42),Vector3(0.025,0.05,0.08),Color("292c30"))
			for z in [-0.23,0.23]: _cube(st,Vector3(side*0.18,0.1,z),Vector3(0.1,0.2,0.12),Color("624d43"))
	else:
		_cube(st,Vector3(0,0.3,0),Vector3(0.34,0.3,0.55),Color("e2c5a3"))
		_cube(st,Vector3(0,0.5,-0.26),Vector3(0.3,0.28,0.3),Color("e9d3b6"))
		_cube(st,Vector3(0,0.43,-0.43),Vector3(0.23,0.13,0.12),Color("b28f74"))
		for side in [-1,1]:
			_cube(st,Vector3(side*0.16,0.67,-0.25),Vector3(0.12,0.17,0.08),Color("d5af93"))
			_cube(st,Vector3(side*0.151,0.55,-0.33),Vector3(0.02,0.06,0.05),Color("34414a"))
			for dz in [-0.18,0.18]: _cube(st,Vector3(side*0.11,0.1,dz),Vector3(0.08,0.2,0.1),Color("846b5b"))
	return st.commit()

func sync(w: Dictionary,season: int) -> void:
	if terrain_root==null: return
	snapshot=w
	if season!=season_seen: season_seen=season; _terrain(season)
	var alive=[]
	for id in CENTERS:
		var r: Dictionary=w.regions[id]
		var water_key=str([int(r.water*40),int(r.pollution*20)])
		if render_keys.get(id+"water")!=water_key: _water(id,r); render_keys[id+"water"]=water_key
		var crops=[]
		for crop in r.crops: crops.append([crop.crop,int(crop.growth*20),crop.ready])
		var crop_key=str(crops)
		if render_keys.get(id+"crop")!=crop_key: _crops(id,r); render_keys[id+"crop"]=crop_key
		var building_key=str([r.buildings,r.enclosed])
		if render_keys.get(id+"building")!=building_key: _buildings(id,r); render_keys[id+"building"]=building_key
		for a in r.animals:
			var key=int(a.id); alive.append(key)
			if not animal_nodes.has(key):
				var n=MeshInstance3D.new(); n.mesh=meshes[a.species]; terrain_root.add_child(n); animal_nodes[key]=n
			animal_nodes[key].set_meta("animal",a); animal_nodes[key].set_meta("region",id)
	for key in animal_nodes.keys():
		if key not in alive: animal_nodes[key].queue_free(); animal_nodes.erase(key)
	walker.barriers=terrain.building_barriers(w.regions)

func focus(id: String,enter: bool=true) -> void:
	var changed=selected!=id
	selected=id; close_view=enter; zoom=1.0
	if changed:
		if first_person: walker.enter(id)
		else: has_walk_position=false

func set_first_person(enabled: bool) -> void:
	if first_person==enabled: return
	first_person=enabled; walker.stop(); hands.visible=enabled
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE if enabled else Camera3D.PROJECTION_ORTHOGONAL
	camera.near=0.06; camera.far=180; camera.fov=72
	if enabled and not has_walk_position: walker.enter(selected); has_walk_position=true
	env.fog_enabled=enabled; env.fog_mode=Environment.FOG_MODE_DEPTH; env.fog_density=1.0
	env.fog_depth_begin=28; env.fog_depth_end=46
	_camera(0.0 if enabled else 1.0)
	_terrain(maxi(0,season_seen))

func travel(at: Vector2) -> void:
	if not terrain.inside(at,3): return
	if not first_person: set_first_person(true)
	var target=Vector2(10,10) if at.length()<32 else (at/float(terrain.rules.site_spacing)).round()*float(terrain.rules.site_spacing)
	var toward=target-at
	walker.position=at; walker.yaw=atan2(-toward.x,-toward.y); walker.pitch=-0.12
	walker.reset_height()
	walker.stop(); _camera(0); _terrain(maxi(0,season_seen))

func orbit(amount: float) -> void:
	yaw+=amount

func _camera(dt: float) -> void:
	if first_person:
		walker.step(dt); hands.moving=walker.movement.length(); camera.position=walker.eye(); camera.rotation=Vector3(walker.pitch,walker.yaw,0); marker.hide()
		var id=terrain.region_at(walker.position)
		if id!=selected: selected=id; region_selected.emit(id)
		return
	var target: Vector3=CENTERS[selected] if close_view else Vector3.ZERO
	target.y=_height(target.x,target.z)*0.5
	var distance=16.0 if close_view else 67.0
	var offset=Vector3(sin(yaw)*distance,distance*0.9,cos(yaw)*distance)
	camera.position=camera.position.lerp(target+offset,minf(1,dt*7))
	camera.size=lerpf(camera.size,(15.0 if close_view else 66.0)*zoom,minf(1,dt*7))
	camera.look_at(target)
	marker.position=CENTERS[selected]+Vector3(0,0.3+_height(CENTERS[selected].x,CENTERS[selected].z),0)
	marker.visible=not close_view

func pick(at: Vector2) -> String:
	if first_person: return selected
	var origin=camera.project_ray_origin(at); var ray=camera.project_ray_normal(at)
	for i in range(600):
		var p=origin+ray*i*0.25; var ground=Vector2(p.x,p.z)
		if terrain.inside(ground) and p.y<=terrain.ground(ground): return terrain.region_at(ground)
	return ""

func _process(dt: float) -> void:
	if camera==null or snapshot.is_empty(): return
	_camera(dt)
	_terrain(maxi(0,season_seen))
	if not snapshot.paused: clock+=dt*minf(4,float(snapshot.speed))
	var sun_phase=sin(float(snapshot.elapsed)/60.0*TAU-PI/2)*0.5+0.5
	sun.light_energy=0.35+sun_phase*0.95
	env.background_color=Color("223951").lerp(Color("aacbd1"),sun_phase) if first_person else Color("12283c").lerp(Color("264b58"),sun_phase)
	env.fog_light_color=env.background_color; env.fog_light_energy=1.0
	for node in animal_nodes.values():
		var a: Dictionary=node.get_meta("animal"); var id=str(node.get_meta("region")); var c: Vector3=CENTERS[id]
		var phase=clock*2.2+int(a.id)
		var spread=1.0 if snapshot.regions[id].enclosed else 2.2
		var x=c.x+float(a.x)*spread; var z=c.z+float(a.z)*spread
		var y=_height(x,z)+0.08
		if a.species=="marsh_fish":
			z=c.z+float(a.z)*2.2; x=terrain.river_x(z)+float(a.x)*0.4
			y=0.18+snapshot.regions[id].water*0.15
		elif not snapshot.paused: y+=absf(sin(phase*3))*0.025
		var target=Vector3(x,y,z)
		if not node.has_meta("placed"): node.position=target; node.set_meta("placed",true)
		var delta=target-node.position
		if Vector2(delta.x,delta.z).length()>0.01:
			node.rotation.y=lerp_angle(node.rotation.y,atan2(-delta.x,-delta.z),minf(1,dt*6))
		node.position=node.position.lerp(target,minf(1,dt*6))
		node.scale=Vector3.ONE*(0.65 if a.age<1 else 1.0)
		if ranch!=null and a.species!="marsh_fish":
			var task=ranch.lives.get("animal:"+id+":"+str(int(a.id)),{}).get("task","")
			node.rotation.x=lerpf(node.rotation.x,0.22 if task in ["吃草","饮水","吃饲料"] else 0.0,minf(1,dt*6))
			if task=="休息": node.scale.y*=0.5
