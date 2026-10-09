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

func _ready() -> void:
	mat=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.roughness=0.92; mat.metallic_specular=0.25
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

func set_first_person(enabled: bool) -> void:
	if first_person==enabled: return
	first_person=enabled; walker.stop(); hands.visible=enabled
	if not enabled: overview_at=walker.position if has_walk_position and walker.position.length()>40 else Vector2.ZERO
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE if enabled else Camera3D.PROJECTION_ORTHOGONAL
	camera.near=0.06; camera.far=180; camera.fov=72
	if enabled and not has_walk_position: walker.enter(selected); has_walk_position=true
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
	if first_person:
		var before=walker.position
		walker.step(dt); hands.moving=walker.movement.length(); camera.position=walker.eye(); camera.rotation=Vector3(walker.pitch,walker.yaw,0); marker.hide()
		_feel(dt,walker.position.distance_to(before))
		var id=terrain.region_at(walker.position)
		if id!=selected: selected=id; region_selected.emit(id)
		return
	var target: Vector3=CENTERS[selected] if close_view else Vector3.ZERO
	if overview_at!=Vector2.ZERO: target=Vector3(overview_at.x,0,overview_at.y)
	target.y=_height(target.x,target.z)*0.5
	var distance=16.0 if close_view else 67.0
	var offset=Vector3(sin(yaw)*distance,distance*0.9,cos(yaw)*distance)
	camera.position=camera.position.lerp(target+offset,minf(1,dt*7))
	camera.size=lerpf(camera.size,(15.0 if close_view else 66.0)*zoom,minf(1,dt*7))
	camera.look_at(target)
	marker.position=CENTERS[selected]+Vector3(0,0.3+_height(CENTERS[selected].x,CENTERS[selected].z),0)
	marker.visible=not close_view and overview_at==Vector2.ZERO

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
		env.fog_light_color=env.fog_light_color.lerp(Color("4c5560"),dark).lerp(Color("dcc28a"),haze*0.9)
		env.ambient_light_color=env.ambient_light_color.lerp(Color("66737f"),dark).lerp(Color("ecd29a"),haze*0.6)
		sky_material.sky_top_color=sky_material.sky_top_color.lerp(Color("343e49"),dark).lerp(Color("cdb88a"),haze*0.45)
		sky_material.sky_horizon_color=sky_material.sky_horizon_color.lerp(Color("5f6873"),dark).lerp(Color("e8cf98"),haze*0.8)
	else: env.background_color=env.background_color.lerp(Color("1a222b"),dark*0.6)
	sky_phase=-1.0 if dark>0.01 or haze>0.01 else sky_phase
	rain.emitting=weather_now.y>0.05
	if rain.emitting: rain.material_override.albedo_color.a=0.45*clampf(weather_now.y,0.0,1.0)
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
	sky_material.ground_horizon_color=sky_material.sky_horizon_color
	sky_material.sun_angle_max=10.0+phase*20.0
	env.fog_light_color=sky_material.sky_horizon_color
	env.ambient_light_color=Color("8ea4c4").lerp(Color("bfd3d0"),phase)

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
