extends Node3D
## Display only. Static scenery is merged; persistent animal nodes interpolate snapshots.
signal region_selected(id: String)
const Terrain=preload("res://scripts/river_terrain.gd")
const Walker=preload("res://scripts/river_walker.gd")
const Stream=preload("res://scripts/river_chunk_stream.gd")
const LifeView=preload("res://scripts/river_life_view.gd")
const G=preload("res://scripts/river_geometry.gd")
const Rig=preload("res://scripts/creature_rig.gd")
const CENTERS=Terrain.CENTERS
var terrain=Terrain.new()
var walker=Walker.new(terrain)
## v0.42 地球仪: the god view is a globe of the whole planet with a pin where the player last stood.
const Globe=preload("res://scripts/planet_globe.gd")
const Shape=preload("res://scripts/planet_shape.gd")
var globe: Node3D
var globe_pin: MeshInstance3D
var globe_pitch=0.35
var globe_shown=false
const GLOBE_RADIUS=10.0
const GLOBE_LAYER=1<<19
## v0.48 星际飞船: parked on the planet; boarding opens the star map (no flight in the world).
var ship_node: Node3D
var ship_parked=false
var ship_at=Vector2.ZERO

func park_ship(at,heading: float=0.0) -> void:
	if at==null:
		ship_parked=false
		if ship_node!=null: ship_node.hide()
		return
	if ship_node==null: ship_node=_ship_mesh(); add_child(ship_node)
	ship_at=at; ship_parked=true
	ship_node.position=Vector3(at.x,terrain.ground(at),at.y); ship_node.rotation=Vector3(0,heading,0); ship_node.show()

func _ship_mesh() -> Node3D:
	var root=Node3D.new()
	var mat=func(hex: String,metal: float=0.4,emit: bool=false):
		var m=StandardMaterial3D.new(); m.albedo_color=Color(hex); m.metallic=metal; m.roughness=0.35
		if emit: m.emission_enabled=true; m.emission=Color(hex)
		return m
	var add=func(mesh: Mesh,at: Vector3,material: Material,turn: Vector3=Vector3.ZERO):
		var n=MeshInstance3D.new(); n.mesh=mesh; n.position=at; n.rotation=turn; n.material_override=material; root.add_child(n); return n
	var hull=CapsuleMesh.new(); hull.radius=1.5; hull.height=9.0
	add.call(hull,Vector3(0,3.2,0),mat.call("e8ecf2",0.5),Vector3(PI/2,0,0))
	var nose=CylinderMesh.new(); nose.top_radius=0.0; nose.bottom_radius=1.2; nose.height=2.4
	add.call(nose,Vector3(0,3.2,-5.4),mat.call("c9a7ff",0.4),Vector3(-PI/2,0,0))
	var canopy=SphereMesh.new(); canopy.radius=0.9; canopy.height=1.2
	add.call(canopy,Vector3(0,4.4,-2.6),mat.call("7fd8ff",0.1,true))
	for side in [-1,1]:
		var wing=BoxMesh.new(); wing.size=Vector3(4.2,0.18,3.0)
		add.call(wing,Vector3(side*2.8,2.7,1.4),mat.call("8b95a3",0.6),Vector3(0,0,side*0.18))
		var leg=BoxMesh.new(); leg.size=Vector3(0.2,2.2,0.2)
		add.call(leg,Vector3(side*1.6,1.1,-1.5),mat.call("2a3038",0.6))
		add.call(leg,Vector3(side*1.6,1.1,2.5),mat.call("2a3038",0.6))
		var engine=CylinderMesh.new(); engine.top_radius=0.55; engine.bottom_radius=0.7; engine.height=1.6
		add.call(engine,Vector3(side*1.1,3.0,4.9),mat.call("5b6670",0.7),Vector3(PI/2,0,0))
		var glow=CylinderMesh.new(); glow.top_radius=0.45; glow.bottom_radius=0.45; glow.height=0.1
		add.call(glow,Vector3(side*1.1,3.0,5.75),mat.call("9ff3ff",0.0,true),Vector3(PI/2,0,0))
	var fin=BoxMesh.new(); fin.size=Vector3(0.16,2.2,2.0)
	add.call(fin,Vector3(0,5.0,3.6),mat.call("c9a7ff",0.4))
	var lamp=OmniLight3D.new(); lamp.position=Vector3(0,1.0,0); lamp.omni_range=8.0; lamp.light_energy=0.8; lamp.light_color=Color("d9c8ff"); root.add_child(lamp)
	return root

## v0.47 小飞机: parked, or flown from a chase camera; far terrain and an opening fog while flying.
const Aircraft=preload("res://scripts/planet_plane.gd")
var plane
var flying=false
var plane_parked=false
var plane_node: Node3D
var far_terrain
## v0.49: the native tribe's people and woodpile.
var native_view
var sea_node: MeshInstance3D
## v0.45 盾构机: parked on the planet, or bored from its seat (a chase camera inside the tunnel).
const Tbm=preload("res://scripts/planet_tbm.gd")
var tbm
var boring=false
var tbm_parked=false
var tbm_node: Node3D
## The planet model the TBM bores into (set by the panel).
var v2
## v0.41 rover: parked or driven in first person, seen from a chase camera while driving.
const Rover=preload("res://scripts/river_rover.gd")
var rover
var driving=false
var rover_parked=false
var rover_node: Node3D
var chase_ready=false
var hands
var ranch
var first_person=false
var has_walk_position=false
var chunks={}
var stream
var life_view
var construction_view
var settlement_view
var organic_view
var field_view
var journey_view
## v0.33.1: the god view looks at where the player last walked, not always at the home bend.
## Vector2.ZERO means the classic home overview with its four regions.
var overview_at=Vector2.ZERO
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
var water_mat: ShaderMaterial
var flock: Node3D
var season_seen=-1
var render_keys={}
var marker: MeshInstance3D
var yaw=-0.35
var zoom=1.0
var kick_amount=0.0
var fill: DirectionalLight3D
var sky_material: ProceduralSkyMaterial
var sky_phase=-1.0
var stride=0.0
## v0.36 weather from the incident director: {dark, rain, haze}. Rain streaks follow the camera.
var weather: Dictionary={"dark":0.0,"rain":0.0,"haze":0.0}
var rain: CPUParticles3D
var weather_now=Vector3.ZERO
## v0.38 LED headlamp from 星锻岛: {nm, color, range, lumens} or {} — lights up at night, in storms and caves.
var lamp_spec: Dictionary={}
var lamp: SpotLight3D
var lamp_on=false
var snowing=false
var rain_drop: Mesh
var flake: QuadMesh

func _ready() -> void:
	mat=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.roughness=0.92; mat.metallic_specular=0.25
	# v0.50: block faces sample a small procedural atlas (white at UV 0,0, so nothing else changes).
	mat.albedo_texture=preload("res://scripts/river_textures.gd").atlas()
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var environment=WorldEnvironment.new(); env=Environment.new(); environment.environment=env
	env.background_mode=Environment.BG_COLOR; env.background_color=Color("102c37")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("b0cacc"); env.ambient_light_energy=0.8
	# v0.33: a painted sky for first person (the god view keeps its dark studio backdrop).
	sky_material=ProceduralSkyMaterial.new(); sky_material.sun_angle_max=12.0; sky_material.sun_curve=0.08
	sky_material.ground_bottom_color=Color("2c4a3a"); sky_material.ground_horizon_color=Color("a9c7c4")
	var sky=Sky.new(); sky.sky_material=sky_material; sky.process_mode=Sky.PROCESS_MODE_QUALITY; env.sky=sky
	env.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED; env.ambient_light_sky_contribution=0.0
	add_child(environment)
	sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-55,-30,0); sun.light_energy=1.3; sun.light_color=Color("ffe6bf")
	sun.shadow_enabled=not (OS.has_feature("android") or OS.has_feature("web")); sun.directional_shadow_max_distance=40.0
	sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS; sun.shadow_bias=0.04; sun.shadow_normal_bias=1.2; sun.shadow_opacity=0.72
	add_child(sun)
	fill=DirectionalLight3D.new(); fill.rotation_degrees=Vector3(-28,150,0); fill.light_color=Color("bfe2ea"); fill.light_energy=0.22; fill.sky_mode=DirectionalLight3D.SKY_MODE_LIGHT_ONLY; add_child(fill)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=21; add_child(camera); camera.current=true
	hands=preload("res://scripts/first_person_hands.gd").new(); camera.add_child(hands); hands.hide()
	lamp=SpotLight3D.new(); lamp.spot_angle=38.0; lamp.spot_attenuation=0.6; lamp.shadow_enabled=false; lamp.position=Vector3(0,0.05,0); camera.add_child(lamp); lamp.hide()
	terrain_root=Node3D.new(); add_child(terrain_root)
	var sea=MeshInstance3D.new(); var ocean=PlaneMesh.new()
	ocean.size=Vector2.ONE*float(terrain.rules.radius)*6
	var sea_material=ShaderMaterial.new(); sea_material.shader=preload("res://assets/shaders/sea.gdshader"); sea_material.set_shader_parameter("use_mask",0.0)
	water_mat=ShaderMaterial.new(); water_mat.shader=preload("res://assets/shaders/planet_water.gdshader")
	ocean.material=sea_material; sea.mesh=ocean; sea.position.y=terrain.Geology.bedrock_y()-1.0; terrain_root.add_child(sea)  # below bedrock: dug pits must not fill with sea
	sea_node=sea
	far_terrain=preload("res://scripts/planet_far_terrain.gd").new(); far_terrain.terrain=terrain; far_terrain.visible=false; terrain_root.add_child(far_terrain)
	stream=Stream.new(); stream.terrain=terrain; stream.material=mat; stream.water_material=water_mat; terrain_root.add_child(stream); chunks=stream.chunks
	for id in CENTERS:
		var n=MeshInstance3D.new(); terrain_root.add_child(n); water_nodes[id]=n
		crop_nodes[id]=MeshInstance3D.new(); terrain_root.add_child(crop_nodes[id])
		building_nodes[id]=MeshInstance3D.new(); terrain_root.add_child(building_nodes[id])
	flock=Node3D.new(); flock.visible=false; add_child(flock)
	for i in range(6):
		var b=Rig.bird(mat); b.scale=Vector3.ONE*1.6; flock.add_child(b)
	life_view=LifeView.new(); life_view.terrain=terrain; life_view.material=mat; life_view.water_material=water_mat; terrain_root.add_child(life_view)
	construction_view=preload("res://scripts/river_construction_view.gd").new(); construction_view.material=mat; terrain_root.add_child(construction_view)
	settlement_view=preload("res://scripts/river_settlement_view.gd").new(); settlement_view.material=mat; settlement_view.terrain=terrain; terrain_root.add_child(settlement_view)
	native_view=preload("res://scripts/river_native_view.gd").new(); native_view.material=mat; native_view.terrain=terrain; terrain_root.add_child(native_view)
	field_view=preload("res://scripts/river_field_view.gd").new(); field_view.material=mat; terrain_root.add_child(field_view)
	organic_view=preload("res://scripts/river_organic_view.gd").new(); organic_view.material=mat; terrain_root.add_child(organic_view)
	journey_view=preload("res://scripts/journey_view.gd").new(); journey_view.material=mat; journey_view.terrain=terrain; terrain_root.add_child(journey_view)
	var ring=TorusMesh.new(); ring.inner_radius=4.8; ring.outer_radius=4.9; ring.rings=32; ring.ring_segments=4
	marker=MeshInstance3D.new(); marker.mesh=ring; var m=StandardMaterial3D.new(); m.albedo_color=Color("f5d789"); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; marker.material_override=m; add_child(marker)
	rain=CPUParticles3D.new(); rain.amount=700; rain.lifetime=0.9; rain.emitting=false; rain.local_coords=false
	rain.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX; rain.emission_box_extents=Vector3(14,0.5,14)
	rain.direction=Vector3(0.15,-1,0.05); rain.spread=4.0; rain.gravity=Vector3(0,-30,0); rain.initial_velocity_min=16; rain.initial_velocity_max=20
	var drop=QuadMesh.new(); drop.size=Vector2(0.025,0.55); rain.mesh=drop
	var dm=StandardMaterial3D.new(); dm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; dm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color=Color(0.78,0.86,0.95,0.45); dm.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y; dm.cull_mode=BaseMaterial3D.CULL_DISABLED; rain.material_override=dm
	add_child(rain)
	_camera(1.0)

func _surface() -> SurfaceTool:
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_material(mat); return st

func _cube(st: SurfaceTool,p: Vector3,size: Vector3,color: Color) -> void:
	G.cube(st,p,size,color)

func _region_at(x: float,z: float) -> String:
	return terrain.region_at(Vector2(x,z))

func _height(x: float,z: float) -> float:
	return terrain.height_at(Vector2(x,z))

func _terrain(season: int) -> void:
	# v0.47: high in the air the near chunks stay as they are (streaming at 60 m/s would stall);
	# the far terrain mesh shows the land below instead.
	if flying and plane.height_above_ground()>25.0: return
	stream.schedule(observer(),season)

func observer() -> Vector2:
	return walker.position if first_person else overview_at

func _water(id: String,r: Dictionary) -> void:
	var st=G.surface(water_mat); var count=0
	for i in range(-29,30):
		var z=float(i); var x=terrain.river_x(z)
		if _region_at(x,z)!=id or not terrain.inside(Vector2(x,z),1.0): continue
		var width=1.6+float(r.water)*2.8
		_cube(st,Vector3(x,0.1+r.water*0.15,z),Vector3(width,0.06,1.02),Color("59aab8").lerp(Color("85965a"),r.pollution*0.7))
		count+=1
	if id in ["meadow","highland"]:
		# The region's little pond grows with its water level; it sits flush in the ground.
		var c: Vector3=CENTERS[id]+Vector3(-1,0,0.8); c=c.round(); c.y=_height(c.x,c.z)+0.02
		_cube(st,c,Vector3(0.2+r.water*0.75,0.02,0.25+r.water*0.75),Color("3f7f8c"))
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
				var n=Rig.make(str(a.species),mat); terrain_root.add_child(n); animal_nodes[key]=n
			animal_nodes[key].set_meta("animal",a); animal_nodes[key].set_meta("region",id)
	for key in animal_nodes.keys():
		if key not in alive: animal_nodes[key].queue_free(); animal_nodes.erase(key)
	walker.barriers=terrain.building_barriers(w.regions)

func entity_hitboxes() -> Dictionary:
	# Target the interpolated, rotated bodies the player actually sees. These
	# transient bounds never own health or enter a save file.
	var shapes={}
	for node in animal_nodes.values():
		var a: Dictionary=node.get_meta("animal"); var id=str(node.get_meta("region"))
		_entity_shape(shapes,"animal:"+id+":"+str(int(a.id)),node)
	for key in life_view.moving:
		var parts=str(key).split("/")
		_entity_shape(shapes,("wild:" if parts[1]=="animal" else "visitor:")+parts[0]+":"+parts[2],life_view.moving[key])
	for id in settlement_view.members:
		_entity_shape(shapes,"resident:"+str(int(id)),settlement_view.members[id].get_child(0))
	for id in native_view.members:
		_entity_shape(shapes,"native:"+str(int(id)),native_view.members[id].get_child(0))
	return shapes

func _entity_shape(shapes: Dictionary,key: String,node: MeshInstance3D) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.is_visible_in_tree() or node.mesh==null: return
	var bounds: AABB=node.global_transform*(node.get_meta("bounds") if node.has_meta("bounds") else node.mesh.get_aabb())
	if bounds.get_center().distance_to(walker.eye())<8:
		shapes[key]=bounds.grow(0.04)

func focus(id: String,enter: bool=true) -> void:
	var changed=selected!=id
	selected=id; close_view=enter; zoom=1.0; overview_at=Vector2.ZERO
	if changed:
		if first_person: walker.enter(id)
		else: has_walk_position=false

func _ensure_globe() -> void:
	if globe!=null: return
	globe=Node3D.new(); add_child(globe)
	var m=StandardMaterial3D.new(); m.roughness=0.85
	if terrain.environment!=null: m.albedo_texture=Globe.equirect(terrain.environment)
	var ball=MeshInstance3D.new(); ball.mesh=Globe.sphere_mesh(GLOBE_RADIUS,m); globe.add_child(ball)
	var halo=MeshInstance3D.new(); var shell=SphereMesh.new(); shell.radius=GLOBE_RADIUS*1.03; shell.height=GLOBE_RADIUS*2.06
	var hm=StandardMaterial3D.new(); hm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; hm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color=Color(0.55,0.8,1.0,0.10); hm.cull_mode=BaseMaterial3D.CULL_FRONT; shell.material=hm; halo.mesh=shell; globe.add_child(halo)
	globe_pin=MeshInstance3D.new(); var cone=CylinderMesh.new(); cone.top_radius=0.0; cone.bottom_radius=0.22; cone.height=0.9
	var pm=StandardMaterial3D.new(); pm.albedo_color=Color("ffd36b"); pm.emission_enabled=true; pm.emission=Color("ffb347"); cone.material=pm
	globe_pin.mesh=cone; globe.add_child(globe_pin)
	for node in [ball,halo,globe_pin]: node.layers=GLOBE_LAYER
	globe.position=Vector3(0,-4000,0)

## v0.50: remember where the player is standing (called when leaving first person and by the panel).
func remember_position() -> void:
	if v2==null or not first_person or driving or flying or boring: return
	v2.walk_at={"x":walker.position.x,"z":walker.position.y,"yaw":walker.yaw,"pitch":walker.pitch}

## Where the player last stood on the planet (home before the first walk).
func last_position() -> Vector2:
	return walker.position if has_walk_position else Vector2(10,15)

func pin_lon_lat() -> Vector2:
	var at=last_position()
	return Vector2(Shape.longitude(at.x),Shape.latitude(at.y))

func _show_globe(on: bool) -> void:
	if on==globe_shown: return
	globe_shown=on
	_ensure_globe(); globe.visible=on
	# The globe lives on its own render layer, so the camera simply stops drawing the ground.
	camera.cull_mask=GLOBE_LAYER if on else (0xFFFFF & ~GLOBE_LAYER)
	if on:
		var ll=pin_lon_lat()
		yaw=deg_to_rad(ll.x); globe_pitch=clampf(deg_to_rad(ll.y)*0.8,-1.1,1.1)

func _globe_camera(dt: float) -> void:
	var ll=pin_lon_lat()
	var tip=Globe.sphere_point(ll.x,ll.y,GLOBE_RADIUS)
	globe_pin.position=tip+tip.normalized()*0.45
	globe_pin.basis=Basis(Quaternion(Vector3.UP,tip.normalized()))
	var distance=34.0*zoom
	var want=Vector3(cos(globe_pitch)*sin(yaw),sin(globe_pitch),cos(globe_pitch)*cos(yaw))*distance
	want+=globe.position
	camera.position=want if dt<=0.0 else camera.position.lerp(want,minf(1.0,dt*6.0))
	camera.look_at(globe.position,Vector3.UP)

## Drag on the globe: sideways spins it, up/down tilts it.
func tilt(amount: float) -> void:
	globe_pitch=clampf(globe_pitch+amount,-1.2,1.2)

func spin(delta: Vector2) -> void:
	yaw-=delta.x*0.006; tilt(delta.y*0.006)

## The body the input drives: the rover while seated, otherwise the walker.
func pilot():
	if flying: return plane
	if boring: return tbm
	return rover if driving else walker

func _ensure_plane(spec: Dictionary) -> void:
	if plane!=null: return
	plane=Aircraft.new(spec); plane.terrain=terrain; plane_node=_plane_mesh(); add_child(plane_node); plane_node.hide()

func park_plane(at,facing: float=0.0) -> void:
	if plane==null: return
	if at==null: plane_parked=false; flying=false; plane_node.hide(); return
	plane.construction=walker.construction; plane.place(at,facing); plane_parked=true; _pose_plane()

func enter_plane() -> void:
	if not plane_parked: return
	flying=true; chase_ready=false; walker.stop(); hands.hide(); plane.stop(); plane.look_yaw=0.0
	far_terrain.env=terrain.environment

## Climb out beside the plane once it has stopped on the ground or water; false otherwise.
func exit_plane() -> bool:
	if not flying or not plane.can_exit(): return false
	var f=plane.forward(); var side=Vector2(-f.y,f.x)
	for offset in [side*2.6,-side*2.6,-f*4.0,f*4.0,side*4.0,-side*4.0]:
		var p=plane.position+offset
		if not terrain.inside(p,3) or terrain.blocked(p,walker.barriers): continue
		flying=false; plane.stop(); plane.speed=0.0; plane.throttle=0.0
		walker.position=p; walker.yaw=plane.heading; walker.pitch=-0.1; walker.reset_height(); walker.stop()
		hands.visible=first_person; far_terrain.visible=false; sea_node.visible=true; stream.visible=true; _ground_sky(false)
		return true
	return false

func _plane_mesh() -> Node3D:
	var root=Node3D.new()
	var mat=func(hex: String,metal: float=0.2,emit: bool=false):
		var m=StandardMaterial3D.new(); m.albedo_color=Color(hex); m.metallic=metal; m.roughness=0.4
		if emit: m.emission_enabled=true; m.emission=Color(hex)
		return m
	var add=func(parent: Node3D,size: Vector3,at: Vector3,material: Material) -> MeshInstance3D:
		var n=MeshInstance3D.new(); var b=BoxMesh.new(); b.size=size; n.mesh=b; n.position=at; n.material_override=material; parent.add_child(n); return n
	var white=mat.call("eef2f5"); var blue=mat.call("2f6f93"); var dark=mat.call("2a3038",0.5)
	add.call(root,Vector3(1.0,1.0,5.2),Vector3(0,1.5,0.1),white)
	add.call(root,Vector3(0.82,0.5,1.3),Vector3(0,2.1,-0.9),mat.call("7fd8ff",0.1))
	add.call(root,Vector3(9.0,0.12,1.4),Vector3(0,2.05,-0.3),white)
	add.call(root,Vector3(9.02,0.13,0.25),Vector3(0,2.06,-0.95),blue)
	add.call(root,Vector3(3.2,0.1,0.9),Vector3(0,1.75,2.4),white)
	add.call(root,Vector3(0.12,1.3,1.0),Vector3(0,2.4,2.4),blue)
	add.call(root,Vector3(0.5,0.5,0.4),Vector3(0,1.5,-2.65),dark)
	var prop=Node3D.new(); prop.position=Vector3(0,1.5,-2.9); root.add_child(prop)
	add.call(prop,Vector3(0.14,2.2,0.06),Vector3.ZERO,dark)
	add.call(prop,Vector3(2.2,0.14,0.06),Vector3.ZERO,dark)
	for x in [-1.25,1.25]:
		add.call(root,Vector3(0.45,0.4,4.6),Vector3(x,0.2,0.0),mat.call("ffcf5c",0.3))
		for z in [-1.0,1.0]: add.call(root,Vector3(0.08,1.0,0.08),Vector3(x*0.6,0.85,z),dark)
	var lamp=OmniLight3D.new(); lamp.position=Vector3(0,1.6,-3.4); lamp.omni_range=10.0; lamp.light_energy=0.8; lamp.light_color=Color("fff1d0"); root.add_child(lamp)
	root.set_meta("prop",prop)
	return root

## Below a curved horizon the sky's "ground" shows: in flight it is sea haze, not the green floor.
func _ground_sky(aloft: bool) -> void:
	if aloft:
		sky_material.ground_horizon_color=sky_material.sky_horizon_color
		sky_material.ground_bottom_color=sky_material.sky_horizon_color.lerp(Color("1b4d6e"),0.6)
	else:
		sky_material.ground_bottom_color=Color("2c4a3a"); sky_material.ground_horizon_color=Color("a9c7c4")

func _pose_plane() -> void:
	if plane_node==null: return
	plane_node.visible=plane_parked
	if not plane_parked: return
	plane_node.position=Vector3(plane.position.x,plane.altitude,plane.position.y)
	plane_node.rotation=Vector3(plane.pitch,plane.heading,plane.bank)
	plane_node.get_meta("prop").rotation.z=plane.spin

func _ensure_tbm(spec: Dictionary) -> void:
	if tbm!=null: return
	tbm=Tbm.new(spec); tbm_node=_tbm_mesh(); add_child(tbm_node); tbm_node.hide()

## Park the TBM with its floor at cell `at` (or hide it when `at` is null).
func park_tbm(at,face: int=0,grade: int=0) -> void:
	if tbm==null: return
	if at==null: tbm_parked=false; boring=false; tbm_node.hide(); return
	tbm.place(at,face); tbm.grade=grade; tbm_parked=true; _pose_tbm()

func enter_tbm() -> void:
	if not tbm_parked: return
	boring=true; walker.stop(); hands.hide(); tbm.stop(); tbm.look_yaw=0.0

## Climb out behind the machine (in the tunnel), or beside it; false if there's nowhere to stand.
func exit_tbm() -> bool:
	if not boring: return false
	var c: Vector3i=tbm.cell; var d=Vector2(tbm.dir().x,tbm.dir().z); var s=Vector2(tbm.side().x,tbm.side().z)
	# Cell centres only: the stepped floor of a dive tunnel changes from one cell to the next.
	for offset in [-d*3,-d*3+s,-d*3-s,-d*4,-d*2,-d*2+s,-d*2-s,s*2,-s*2]:
		var p=Vector2(c.x,c.z)+offset
		if not terrain.inside(p,3): continue
		# A dive or climb leaves the tunnel floor a metre or two off the machine's floor behind it.
		var feet: float=walker.construction.floor_at(p,c.y+2.7) if walker.construction!=null else terrain.ground(p)
		if not is_finite(feet) or feet<c.y-2.6 or feet>c.y+2.7: continue
		if terrain.overlaps(p,feet,float(terrain.rules.body_height)): continue
		if walker.construction!=null and walker.construction.overlaps(p,feet,float(terrain.rules.body_height)): continue
		boring=false; tbm.stop()
		walker.position=p; walker.feet_y=feet; walker.last_position=p; walker.yaw=tbm.facing_yaw(); walker.pitch=-0.1; walker.stop()
		hands.visible=first_person
		return true
	return false

func _tbm_mesh() -> Node3D:
	var root=Node3D.new()
	var mat=func(hex: String,metal: float,emit: bool=false):
		var m=StandardMaterial3D.new(); m.albedo_color=Color(hex); m.metallic=metal; m.roughness=0.45
		if emit: m.emission_enabled=true; m.emission=Color(hex)
		return m
	var add=func(parent: Node3D,mesh: Mesh,at: Vector3,material: Material,turn: Vector3=Vector3.ZERO) -> MeshInstance3D:
		var n=MeshInstance3D.new(); n.mesh=mesh; n.position=at; n.rotation=turn; n.material_override=material; parent.add_child(n); return n
	var shell=CylinderMesh.new(); shell.top_radius=1.36; shell.bottom_radius=1.36; shell.height=2.4; shell.radial_segments=18
	add.call(root,shell,Vector3(0,0,0.1),mat.call("f2b134",0.3),Vector3(PI/2,0,0))
	for z in [-0.55,0.75]:
		var band=CylinderMesh.new(); band.top_radius=1.39; band.bottom_radius=1.39; band.height=0.14; band.radial_segments=18
		add.call(root,band,Vector3(0,0,z),mat.call("2a3038",0.4),Vector3(PI/2,0,0))
	var cutter=Node3D.new(); cutter.position=Vector3(0,0,-1.28); root.add_child(cutter)
	var disc=CylinderMesh.new(); disc.top_radius=1.44; disc.bottom_radius=1.44; disc.height=0.2; disc.radial_segments=18
	add.call(cutter,disc,Vector3.ZERO,mat.call("6b7682",0.7),Vector3(PI/2,0,0))
	var spoke=BoxMesh.new(); spoke.size=Vector3(0.2,2.7,0.12)
	for k in range(3): add.call(cutter,spoke,Vector3(0,0,-0.14),mat.call("2a3038",0.5),Vector3(0,0,k*PI/3))
	var tooth=BoxMesh.new(); tooth.size=Vector3(0.14,0.14,0.16)
	for k in range(12):
		var a=k*TAU/12.0; var r=0.55+0.6*float(k%2)
		add.call(cutter,tooth,Vector3(cos(a)*r,sin(a)*r,-0.2),mat.call("d9dee3",0.8))
	var hub=SphereMesh.new(); hub.radius=0.26; hub.height=0.4
	add.call(cutter,hub,Vector3(0,0,-0.2),mat.call("ffcf5c",0.6,true))
	var gantry=BoxMesh.new(); gantry.size=Vector3(1.9,1.3,1.2)
	add.call(root,gantry,Vector3(0,-0.4,1.85),mat.call("8b95a3",0.5))
	var window=BoxMesh.new(); window.size=Vector3(1.0,0.36,0.04)
	add.call(root,window,Vector3(0,0.05,2.46),mat.call("7fd8ff",0.1,true))
	var belt=BoxMesh.new(); belt.size=Vector3(0.36,0.22,2.6)
	add.call(root,belt,Vector3(0.75,-1.0,1.7),mat.call("2a3038",0.3))
	var lamp=OmniLight3D.new(); lamp.position=Vector3(0,0.4,-1.9); lamp.omni_range=9.0; lamp.light_energy=1.7; lamp.light_color=Color("ffe2b0"); root.add_child(lamp)
	var cab=OmniLight3D.new(); cab.position=Vector3(0,0.6,3.2); cab.omni_range=6.0; cab.light_energy=0.9; cab.light_color=Color("cfe8ff"); root.add_child(cab)
	root.set_meta("cutter",cutter)
	return root

func _pose_tbm() -> void:
	if tbm_node==null: return
	tbm_node.visible=tbm_parked
	if not tbm_parked: return
	tbm_node.position=tbm.centre()
	tbm_node.rotation=Vector3(0.14*tbm.grade,lerp_angle(tbm_node.rotation.y,tbm.facing_yaw(),0.25),0)
	tbm_node.get_meta("cutter").rotation.z=tbm.spin

func _ensure_rover() -> void:
	if rover!=null: return
	rover=Rover.new(terrain,terrain.rules.rover)
	rover_node=_rover_mesh(); add_child(rover_node); rover_node.hide()

## Park the rover (or hide it when `at` is null).
func park_rover(at,facing: float=0.0) -> void:
	_ensure_rover()
	if at==null: rover_parked=false; driving=false; rover_node.hide(); return
	rover.construction=walker.construction; rover.barriers=walker.barriers
	rover.place(at,facing); rover_parked=true; _pose_rover()

func enter_rover() -> void:
	if not rover_parked: return
	driving=true; chase_ready=false; walker.stop(); hands.hide(); rover.stop()

## Climb out beside the rover; returns false when there is no free spot (stay seated).
func exit_rover() -> bool:
	if not driving: return false
	var f=rover.forward(); var side=Vector2(-f.y,f.x)
	for offset in [side*2.2,-side*2.2,-f*2.8,f*2.8,side*3.5,-side*3.5]:
		var p=rover.position+offset
		if terrain.inside(p,2) and not terrain.blocked(p,walker.barriers) and (walker.construction==null or not walker.construction.overlaps(p,terrain.ground(p),float(terrain.rules.body_height))):
			driving=false; rover.stop(); rover.speed=0.0
			walker.position=p; walker.yaw=rover.heading; walker.pitch=-0.12; walker.reset_height(); walker.stop()
			hands.visible=first_person
			return true
	return false

## Chassis, cab frame, roof solar, four wheels and headlights: cubes, like everything else here.
func _rover_mesh() -> Node3D:
	var root=Node3D.new()
	var material=StandardMaterial3D.new(); material.vertex_color_use_as_albedo=true; material.roughness=0.6
	var st=G.surface(material)
	var paint=Color("ffcf5c"); var dark=Color("2f3a42"); var steel=Color("8b95a3")
	G.cube(st,Vector3(0,0.75,0),Vector3(1.5,0.45,2.6),paint)
	G.cube(st,Vector3(0,0.52,0),Vector3(1.3,0.12,2.4),dark)
	G.cube(st,Vector3(0,1.12,0.35),Vector3(1.32,0.32,1.2),paint.darkened(0.1))
	for x in [-0.62,0.62]:
		for z in [-0.25,0.95]: G.cube(st,Vector3(x,1.55,z),Vector3(0.07,0.75,0.07),steel)
	G.cube(st,Vector3(0,1.94,0.35),Vector3(1.36,0.06,1.32),Color("233c70"))
	G.cube(st,Vector3(0,1.32,-0.28),Vector3(1.2,0.5,0.04),Color(0.7,0.9,1.0))
	for x in [-0.45,0.45]: G.cube(st,Vector3(x,0.82,-1.31),Vector3(0.26,0.14,0.04),Color("fff6c8"))
	G.cube(st,Vector3(0,0.9,1.31),Vector3(1.1,0.12,0.04),Color("c94f3d"))
	var body=MeshInstance3D.new(); body.mesh=st.commit(); root.add_child(body)
	var wheels=[]
	for x in [-0.82,0.82]:
		for z in [-0.88,0.88]:
			var ws=G.surface(material)
			G.cube(ws,Vector3.ZERO,Vector3(0.32,0.62,0.62),Color("26282c"))
			G.cube(ws,Vector3(signf(x)*0.17,0,0),Vector3(0.04,0.3,0.3),steel)
			var wheel=MeshInstance3D.new(); wheel.mesh=ws.commit(); wheel.position=Vector3(x,0.32,z); root.add_child(wheel); wheels.append(wheel)
	var beam=SpotLight3D.new(); beam.position=Vector3(0,0.85,-1.35); beam.light_color=Color("fff2c8"); beam.spot_range=22; beam.spot_angle=34; beam.light_energy=2.0; beam.hide(); root.add_child(beam)
	root.set_meta("wheels",wheels); root.set_meta("beam",beam)
	return root

func _pose_rover() -> void:
	if rover_node==null: return
	rover_node.visible=rover_parked
	if not rover_parked: return
	rover_node.position=Vector3(rover.position.x,rover.body_y,rover.position.y)
	rover_node.rotation=Vector3(rover.tilt.x,rover.heading,rover.tilt.y)
	var spin=rover.travelled/0.31
	for w in rover_node.get_meta("wheels"): w.rotation.x=-spin
	rover_node.get_meta("beam").visible=driving and lamp_needed(_sun_phase())

func _sun_phase() -> float:
	return sin(float(snapshot.get("elapsed",0))/60.0*TAU-PI/2)*0.5+0.5 if not snapshot.is_empty() else 1.0

func set_first_person(enabled: bool) -> void:
	if first_person==enabled: return
	if not enabled and driving: exit_rover()
	if not enabled and boring and not exit_tbm(): boring=false
	if not enabled and flying and not exit_plane():
		# Leaving first person mid-flight: the plane comes down where it is (a safe auto-landing).
		plane.airborne=false; plane.speed=0.0; plane.throttle=0.0; plane.altitude=plane.floor_at(plane.position,INF); flying=false
		far_terrain.visible=false; sea_node.visible=true; stream.visible=true; _ground_sky(false)
	first_person=enabled; walker.stop(); hands.visible=enabled
	# v0.50: entering first person puts you back where you left off (not at the spawn).
	if enabled and v2!=null and not v2.walk_at.is_empty():
		walker.position=Vector2(float(v2.walk_at.x),float(v2.walk_at.z)); walker.yaw=float(v2.walk_at.yaw); walker.pitch=float(v2.walk_at.pitch); has_walk_position=true
	if not enabled: overview_at=walker.position if has_walk_position and walker.position.length()>40 else Vector2.ZERO
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.near=0.06 if enabled else 0.5; camera.far=180; camera.fov=72 if enabled else 38
	if enabled and not has_walk_position: walker.enter(selected); has_walk_position=true
	if not enabled: remember_position()
	env.fog_enabled=enabled; env.fog_mode=Environment.FOG_MODE_DEPTH; env.fog_density=1.0
	env.fog_depth_begin=26; env.fog_depth_end=48; env.fog_sky_affect=0.0
	env.background_mode=Environment.BG_SKY if enabled else Environment.BG_COLOR
	env.ambient_light_energy=0.55 if enabled else 0.8
	sky_phase=-1.0
	_camera(0.0 if enabled else 1.0)
	_terrain(maxi(0,season_seen))

func travel(at: Vector2) -> bool:
	if not terrain.inside(at,3): return false
	var found=false
	for radius in range(0,9):
		for n in range(1 if radius==0 else 16):
			var candidate=at+Vector2.from_angle(n*TAU/16)*radius
			if terrain.inside(candidate,3) and not terrain.blocked(candidate,walker.barriers) and (walker.construction==null or not walker.construction.overlaps(candidate,terrain.ground(candidate),float(terrain.rules.body_height))):
				at=candidate; found=true; break
		if found: break
	if not found: return false
	if not first_person: set_first_person(true)
	var target=Vector2(10,10) if at.length()<32 else (at/float(terrain.rules.site_spacing)).round()*float(terrain.rules.site_spacing)
	var toward=target-at
	walker.position=at; walker.yaw=atan2(-toward.x,-toward.y); walker.pitch=-0.12
	walker.reset_height()
	walker.stop(); _camera(0); _terrain(maxi(0,season_seen))
	return true

func orbit(amount: float) -> void:
	yaw+=amount

func _camera(dt: float) -> void:
	if first_person: _show_globe(false)
	if first_person and flying:
		plane.construction=walker.construction
		plane.step(dt)
		walker.position=plane.position; walker.feet_y=plane.altitude+0.6; walker.last_position=walker.position; walker.yaw=plane.heading
		var ang=plane.heading+plane.look_yaw; var back=Vector3(sin(ang),0,cos(ang))
		var target=Vector3(plane.position.x,plane.altitude+1.8,plane.position.y)
		var want=target+back*13.0+Vector3(0,4.0-plane.pitch*6.0,0)
		want.y=maxf(want.y,plane.floor_at(Vector2(want.x,want.z),want.y+2.0)+1.0)
		camera.position=want if not chase_ready else camera.position.lerp(want,minf(1.0,dt*5.0))
		chase_ready=true
		camera.look_at(target-back*12.0); hands.hide(); marker.hide()
		camera.far=3200.0
		# Far terrain below, bent by the planet's curvature around the plane; the flat sea plane
		# would show through the curved far sea, so it hides while flying.
		far_terrain.env=terrain.environment; far_terrain.want(plane.position)
		far_terrain.visible=far_terrain.mesh!=null; sea_node.visible=not far_terrain.visible
		far_terrain.set_origin(Vector3(plane.position.x,0,plane.position.y))
		# High up the flat near chunks would float out of place over the curved far terrain.
		stream.visible=plane.height_above_ground()<=25.0
		_pose_plane()
		return
	if plane_node!=null: _pose_plane()
	if first_person and boring:
		if v2!=null: tbm.step(dt,v2)
		var ctr: Vector3=tbm.centre()
		walker.position=Vector2(ctr.x,ctr.z); walker.feet_y=ctr.y-1.5; walker.last_position=walker.position; walker.yaw=tbm.facing_yaw()
		if tbm.is_shaft():
			# Vertical shaft: camera looks straight down from above the machine.
			var above=ctr+Vector3(0,6.0,0)
			camera.position=above; camera.look_at(ctr+Vector3(0,-1,0)); hands.hide(); marker.hide()
			_pose_tbm()
			return
		var ang=tbm.facing_yaw()+tbm.look_yaw; var back=Vector3(sin(ang),0,cos(ang))
		# Chase camera behind the machine, pulled in closer when rock is behind (after a turn).
		var want=ctr+Vector3(0,0.6-tbm.look_pitch*1.5,0)
		for dist in [3.6,2.6,1.6,0.4]:
			want=ctr+back*dist+Vector3(0,0.6-tbm.look_pitch*1.5,0)
			if terrain.material(Vector3i(roundi(want.x),floori(want.y),roundi(want.z)))=="": break
		camera.position=want; camera.look_at(ctr-back*2.5+Vector3(0,-0.15,0)); hands.hide(); marker.hide()
		_pose_tbm()
		return
	if tbm_node!=null: _pose_tbm()
	if first_person and driving:
		rover.construction=walker.construction; rover.barriers=walker.barriers
		rover.step(dt)
		# The seat carries the walker along, so observers, the trail and targeting follow the rover.
		walker.position=rover.position; walker.feet_y=rover.body_y+0.45; walker.last_position=walker.position; walker.yaw=rover.heading
		var ang=rover.heading+rover.look_yaw
		var target=Vector3(rover.position.x,rover.body_y+1.3,rover.position.y)
		var want=target+Vector3(sin(ang),0,cos(ang))*7.0+Vector3(0,2.4-rover.look_pitch*5.0,0)
		want.y=maxf(want.y,terrain.ground(Vector2(want.x,want.z))+0.6)
		camera.position=want if not chase_ready else camera.position.lerp(want,minf(1.0,dt*6.0))
		chase_ready=true
		camera.look_at(target); hands.hide(); marker.hide()
		_pose_rover()
		var id=terrain.region_at(rover.position)
		if id!=selected: selected=id; region_selected.emit(id)
		return
	if rover_node!=null: _pose_rover()
	if first_person:
		var before=walker.position
		walker.step(dt); hands.moving=walker.movement.length(); camera.position=walker.eye(); camera.rotation=Vector3(walker.pitch,walker.yaw,0); marker.hide()
		_feel(dt,walker.position.distance_to(before))
		var id=terrain.region_at(walker.position)
		if id!=selected: selected=id; region_selected.emit(id)
		return
	# v0.42: the god view is the globe.
	_show_globe(true); _globe_camera(dt); marker.hide()

## Tool impact: a short camera dip that settles within a few frames (never moves the walker).
func kick(amount: float=1.0) -> void:
	kick_amount=maxf(kick_amount,amount)

func _feel(dt: float,walked: float) -> void:
	if kick_amount>0.001:
		camera.rotation.x-=0.035*kick_amount; camera.rotation.z+=0.012*kick_amount*sin(Time.get_ticks_msec()*0.04)
		kick_amount=move_toward(kick_amount,0.0,dt*6.0)
	if not walker.grounded or walked>1.5: stride=0.0; return
	stride+=walked
	if stride>=(2.1 if walker.running else 1.6):
		stride=0.0
		var sfx=get_node_or_null("/root/Sfx")
		if sfx: sfx.play("step")

## v0.33: the sun crosses the sky with the day (long morning shadows, warm dusk) and the sky
## colours follow it. Sky colours are only pushed when the phase moves, so radiance stays cheap.
## A loose flock wheeling over the walker by day; scenery only, never targetable.
func _birds(sun_phase: float) -> void:
	flock.visible=first_person and sun_phase>0.25
	if not flock.visible: return
	var t=Time.get_ticks_msec()/1000.0; var eye=walker.eye()
	for i in range(flock.get_child_count()):
		var b: Node3D=flock.get_child(i); var a=t*0.16+i*0.55; var r=13.0+sin(i*1.7)*3.0
		b.position=Vector3(eye.x+cos(a)*r,eye.y+6.5+sin(t*0.7+i)*0.8+i*0.3,eye.z+sin(a)*r)
		b.rotation=Vector3(0,PI-a,sin(t+i)*0.15)
		var flap=sin(t*(8.0+i)+i)*0.7 if fmod(t*0.4+i*0.37,1.0)<0.55 else 0.12
		for w in b.get_meta("wings"): w.rotation.z=flap*signf(w.scale.x)
## Storms darken the sky and sun and pull the fog in; droughts add a warm haze. Eased so a warning
## hour slowly clouds over. Rain only falls where the camera is.
func _weather(dt: float) -> void:
	var target=Vector3(float(weather.get("dark",0.0)),float(weather.get("rain",0.0)),float(weather.get("haze",0.0)))
	weather_now=weather_now.lerp(target,minf(1.0,dt*0.6))
	var dark=weather_now.x; var haze=weather_now.z
	sun.light_energy*=1.0-dark*0.7
	if first_person:
		env.fog_depth_begin=lerpf(26.0,10.0,dark); env.fog_depth_end=lerpf(48.0,30.0,dark)
		env.fog_depth_begin=lerpf(env.fog_depth_begin,14.0,haze*0.6)
		if flying:
			# v0.47: the higher you fly, the farther you see (fog out to ~2.6 km).
			var h=clampf(plane.height_above_ground(),0.0,400.0)
			env.fog_depth_end=lerpf(clampf(60.0+h*7.0,60.0,2600.0),30.0,dark); env.fog_depth_begin=env.fog_depth_end*0.45
			_ground_sky(true)
		env.fog_light_color=env.fog_light_color.lerp(Color("4c5560"),dark).lerp(Color("dcc28a"),haze*0.9)
		env.ambient_light_color=env.ambient_light_color.lerp(Color("66737f"),dark).lerp(Color("ecd29a"),haze*0.6)
		sky_material.sky_top_color=sky_material.sky_top_color.lerp(Color("343e49"),dark).lerp(Color("cdb88a"),haze*0.45)
		sky_material.sky_horizon_color=sky_material.sky_horizon_color.lerp(Color("5f6873"),dark).lerp(Color("e8cf98"),haze*0.8)
	else: env.background_color=env.background_color.lerp(Color("1a222b"),dark*0.6)
	sky_phase=-1.0 if dark>0.01 or haze>0.01 else sky_phase
	rain.emitting=weather_now.y>0.05
	# v0.39: a blizzard turns the rain streaks into slow white snow.
	var snow=float(weather.get("snow",0.0))>0.0
	if snow!=snowing:
		snowing=snow
		rain.gravity=Vector3(0.6,-2.0,0) if snow else Vector3(0,-30,0)
		rain.initial_velocity_min=1.5 if snow else 16.0; rain.initial_velocity_max=3.0 if snow else 20.0
		rain.lifetime=3.2 if snow else 0.9; rain.spread=25.0 if snow else 4.0
		if rain_drop==null: rain_drop=rain.mesh
		if snow and flake==null: flake=QuadMesh.new(); flake.size=Vector2(0.09,0.09)
		rain.mesh=flake if snow else rain_drop
		rain.material_override.albedo_color=Color(1,1,1,0.0) if snow else Color(0.78,0.86,0.95,0.0)
	if rain.emitting: rain.material_override.albedo_color.a=(0.8 if snow else 0.45)*clampf(weather_now.y,0.0,1.0)
	if rain.emitting:
		var at=walker.eye() if first_person else camera.global_position.lerp(Vector3(camera.global_position.x,0,camera.global_position.z),0.7)
		rain.global_position=at+Vector3(0,9,0)

## Dark enough for the headlamp: night, a storm sky, or standing more than 2 m below the natural surface.
func lamp_needed(sun_phase: float) -> bool:
	if not first_person or lamp_spec.is_empty(): return false
	var eye=walker.eye()
	var under=eye.y<terrain.natural_height(Vector2(eye.x,eye.z))-0.4
	return sun_phase<0.3 or weather_now.x>0.5 or under

func _lamp(sun_phase: float) -> void:
	lamp_on=lamp_needed(sun_phase)
	lamp.visible=lamp_on
	if not lamp_on: return
	lamp.light_color=lamp_spec.color; lamp.spot_range=float(lamp_spec.range)
	lamp.light_energy=clampf(1.2+float(lamp_spec.lumens)/60.0,1.2,5.0)

func _daylight(phase: float,day: float) -> void:
	var arc=fposmod(day,1.0)
	sun.rotation_degrees=Vector3(-lerpf(14.0,58.0,phase),lerpf(-110.0,70.0,clampf(arc*1.3-0.15,0,1)),0)
	sun.light_color=Color("ffb27a").lerp(Color("fff0d4"),smoothstep(0.15,0.6,phase))
	fill.light_energy=0.1+phase*0.1
	if not first_person or absf(phase-sky_phase)<0.01: return
	sky_phase=phase
	sky_material.sky_top_color=Color("1a2c4c").lerp(Color("4f93c9"),phase)
	sky_material.sky_horizon_color=Color("d9906a").lerp(Color("bcdbe0"),smoothstep(0.1,0.7,phase)).lerp(Color("2a3a55"),1.0-smoothstep(0.0,0.25,phase))
	# v0.48: another planet's sky (赤砂星's dusty orange horizon).
	var tint=str(terrain.profile.get("sky_tint",""))
	if tint!="":
		sky_material.sky_horizon_color=sky_material.sky_horizon_color.lerp(Color(tint),0.55)
		sky_material.sky_top_color=sky_material.sky_top_color.lerp(Color(tint).darkened(0.35),0.3)
	sky_material.ground_horizon_color=sky_material.sky_horizon_color
	sky_material.sun_angle_max=10.0+phase*20.0
	env.fog_light_color=sky_material.sky_horizon_color
	env.ambient_light_color=Color("8ea4c4").lerp(Color("bfd3d0"),phase)

func pick(at: Vector2) -> String:
	if first_person or globe_shown: return selected
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
	# Shadowed directional light reads about twice as bright on the compatibility renderer.
	sun.light_energy=(0.3+sun_phase*0.62)*(0.6 if sun.shadow_enabled else 1.0) if first_person else 0.35+sun_phase*0.95
	env.background_color=Color("223951").lerp(Color("aacbd1"),sun_phase) if first_person else Color("12283c").lerp(Color("264b58"),sun_phase)
	if not first_person: env.fog_light_color=env.background_color
	env.fog_light_energy=1.0
	_daylight(sun_phase,float(snapshot.elapsed)/60.0)
	# v0.38: first-person nights are darker, so a headlamp matters (day stays at the v0.33 ambient).
	if first_person: env.ambient_light_energy=lerpf(0.28,0.55,smoothstep(0.0,0.35,sun_phase))
	_weather(dt)
	_lamp(sun_phase)
	_birds(sun_phase)
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
		Rig.animate(node,dt,Vector2(delta.x,delta.z).length()*minf(1,dt*6),clock)
		node.scale=Vector3.ONE*(0.65 if a.age<1 else 1.0)
		if ranch!=null and a.species!="marsh_fish":
			var task=ranch.lives.get("animal:"+id+":"+str(int(a.id)),{}).get("task","")
			node.rotation.x=lerpf(node.rotation.x,0.22 if task in ["吃草","饮水","吃饲料"] else 0.0,minf(1,dt*6))
			if task=="休息": node.scale.y*=0.5
