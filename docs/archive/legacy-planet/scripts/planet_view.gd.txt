extends Node3D
const EcologyView=preload("res://scripts/planet_ecology_view.gd")
## Procedural display only: it consumes a world snapshot and never changes inventory.
var city_sun: DirectionalLight3D
var city_fill: DirectionalLight3D
var scene_environment: Environment
var camera: Camera3D
var globe: Node3D
var sites: Dictionary={}
var materials: Dictionary={}
var time=0.0
var target_yaw=0.0
var target_pitch=0.0
var distance=9.6
var highlighted=""
var highlight_valid=true
var snapshot: Dictionary={}
var watershed_view
var village_view
var modern_view
var background_moon: Node3D
var industry_view
var habitat_view
var player_view
var material_view
var ecology_view
var display_mode="water"

func _ready() -> void:
	var env=WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("0b1b2b")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("8fb5cb"); env.environment.ambient_light_energy=0.5
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	add_child(env); scene_environment=env.environment
	var sun=DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-35,-35,0); sun.light_color=Color("ffe3ba"); sun.light_energy=1.1; add_child(sun); city_sun=sun
	var fill=DirectionalLight3D.new(); fill.rotation_degrees=Vector3(20,145,0); fill.light_color=Color("76cddb"); fill.light_energy=0.6; add_child(fill); city_fill=fill
	camera=Camera3D.new(); camera.fov=43; camera.position=Vector3(0,2.0,distance); add_child(camera); camera.look_at(Vector3.ZERO); camera.current=true
	globe=Node3D.new(); add_child(globe)
	_make_surface()
	_make_stars()
	var orbit=Node3D.new(); orbit.rotation_degrees=Vector3(18,0,-22); add_child(orbit)
	_ring(orbit,3.53,3.54,Vector3.ZERO,"527b89")
	_ring(orbit,3.69,3.70,Vector3.ZERO,"294652")
	_make_site("deep",Vector3(-1.12,1.35,2.14),false)
	_make_site("shelf",Vector3(1.13,0.65,2.53),true)
	ecology_view=EcologyView.new(); globe.add_child(ecology_view); ecology_view.setup(self); ecology_view.hide()
	material_view=preload("res://scripts/material_lab_view.gd").new(); add_child(material_view); material_view.setup(self); material_view.scale=Vector3.ONE*1.22; material_view.hide()
	watershed_view=preload("res://scripts/planet_watershed_view.gd").new(); add_child(watershed_view); watershed_view.setup(self); watershed_view.hide()
	village_view=preload("res://scripts/planet_village_view.gd").new(); add_child(village_view); village_view.setup(self); village_view.hide()
	habitat_view=preload("res://scripts/planet_habitat_view.gd").new(); add_child(habitat_view); habitat_view.setup(self); habitat_view.hide()
	industry_view=preload("res://scripts/planet_industry_view.gd").new(); add_child(industry_view); industry_view.setup(self); industry_view.hide()
	modern_view=preload("res://scripts/planet_modern_view.gd").new(); add_child(modern_view); modern_view.setup(self); modern_view.hide()
	player_view=preload("res://scripts/player_material_view.gd").new(); add_child(player_view); player_view.setup(self); player_view.hide()
	var moon=Node3D.new(); moon.position=Vector3(3.4,1.6,-1.7); add_child(moon); background_moon=moon
	_sphere(moon,0.23,Vector3.ZERO,"edc58c")

func _mat(hex: String,metal: float=0.0) -> StandardMaterial3D:
	if materials.has(hex): return materials[hex]
	var mat=StandardMaterial3D.new(); mat.albedo_color=Color(hex); mat.roughness=0.67; mat.metallic=metal
	materials[hex]=mat; return mat

func _mesh(parent: Node,mesh: Mesh,pos: Vector3,color: String) -> MeshInstance3D:
	var node=MeshInstance3D.new(); node.mesh=mesh; node.position=pos; node.material_override=_mat(color); parent.add_child(node); return node

func _sphere(parent: Node,r: float,pos: Vector3,color: String) -> MeshInstance3D:
	var shape=SphereMesh.new(); shape.radius=r; shape.height=r*2; shape.radial_segments=16; shape.rings=8
	return _mesh(parent,shape,pos,color)

func _box(parent: Node,size: Vector3,pos: Vector3,color: String) -> MeshInstance3D:
	var shape=BoxMesh.new(); shape.size=size; return _mesh(parent,shape,pos,color)

func _cylinder(parent: Node,r: float,height: float,pos: Vector3,color: String) -> MeshInstance3D:
	var shape=CylinderMesh.new(); shape.top_radius=r; shape.bottom_radius=r; shape.height=height; shape.radial_segments=32
	return _mesh(parent,shape,pos,color)

func _ring(parent: Node,inner: float,outer: float,pos: Vector3,color: String) -> MeshInstance3D:
	var shape=TorusMesh.new(); shape.inner_radius=inner; shape.outer_radius=outer; shape.rings=48; shape.ring_segments=8
	return _mesh(parent,shape,pos,color)

func _point(lat: float,lon: float) -> Vector3:
	return Vector3(sin(lat)*cos(lon),cos(lat),sin(lat)*sin(lon))

func _make_surface() -> void:
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise=FastNoiseLite.new(); noise.seed=9192026; noise.frequency=1.1
	for y in range(20):
		for x in range(40):
			var points=[_point(PI*y/20.0,TAU*x/40.0),_point(PI*(y+1)/20.0,TAU*x/40.0),_point(PI*y/20.0,TAU*(x+1)/40.0),_point(PI*(y+1)/20.0,TAU*(x+1)/40.0)]
			for indices in [[0,1,2],[2,1,3]]:
				var center=(points[indices[0]]+points[indices[1]]+points[indices[2]])/3.0
				var n=noise.get_noise_3dv(center*3.0)
				var color=Color("456775").lerp(Color("87a49d"),clampf((n+0.4)*1.2,0,1))
				if n>0.22: color=Color("c39978").lerp(Color("ead0a1"),clampf(n,0,1))
				if n < -0.43: color=Color("d57c50")
				for i in indices:
					st.set_color(color); st.set_normal(points[i]); st.add_vertex(points[i]*2.75)
	var mat=StandardMaterial3D.new(); mat.vertex_color_use_as_albedo=true; mat.roughness=0.92; mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	var terrain=MeshInstance3D.new(); terrain.mesh=st.commit(); globe.add_child(terrain)

func _make_stars() -> void:
	var mult=MultiMesh.new(); mult.transform_format=MultiMesh.TRANSFORM_3D
	var shape=SphereMesh.new(); shape.radius=0.025; shape.height=0.05; shape.radial_segments=6; shape.rings=3; mult.mesh=shape
	mult.instance_count=100
	var rng=RandomNumberGenerator.new(); rng.seed=111
	for i in range(100):
		var t=Transform3D.IDENTITY; t.origin=Vector3(rng.randf_range(-16,16),rng.randf_range(-8,12),-8)
		t=t.scaled_local(Vector3.ONE*rng.randf_range(0.4,1.5)); mult.set_instance_transform(i,t)
	var field=MultiMeshInstance3D.new(); field.multimesh=mult; field.material_override=_mat("668f9f"); add_child(field)

func _make_site(id: String,normal: Vector3,shallow: bool) -> void:
	var root=Node3D.new(); root.name=id; globe.add_child(root)
	var up=normal.normalized(); var right=Vector3.UP.cross(up).normalized(); var back=right.cross(up).normalized()
	root.transform=Transform3D(Basis(right,up,back),up*2.68)
	_cylinder(root,0.94,0.20,Vector3.ZERO,"3c585b")
	_ring(root,0.72,0.91,Vector3(0,0.12,0),"dfc39b")
	_ring(root,0.71,0.78,Vector3(0,0.18,0),"8faaa0")
	_cylinder(root,0.68,0.04,Vector3(0,0.10,0),"455c65")
	var water=_cylinder(root,0.65,0.016,Vector3(0,0.15,0),"63cbd0" if shallow else "359eaf")
	var shoreline=_ring(root,0.61,0.63,Vector3(0,0.22,0),"bce6d3")
	var marker=_ring(root,0.96,0.985,Vector3(0,0.15,0),"ffd18c"); marker.visible=false
	_box(root,Vector3(0.30,0.40,0.27),Vector3(0.68,0.35,0.23),"e4ede0")
	_box(root,Vector3(0.32,0.08,0.29),Vector3(0.68,0.60,0.23),"3f858a")
	_box(root,Vector3(0.07,0.2,0.12),Vector3(0.68,0.37,0.38),"85d9dd")
	_box(root,Vector3(0.46,0.055,0.06),Vector3(0.48,0.29,0.20),"ebc996")
	var pump=_sphere(root,0.07,Vector3(0.65,0.66,0.23),"ffd18c")
	for i in range(5):
		var angle=0.7+i*0.45
		_box(root,Vector3(0.08,0.045,0.16),Vector3(cos(angle)*0.82,0.18,sin(angle)*0.82),"f5e6c5")
	var tank=Node3D.new(); root.add_child(tank)
	_cylinder(tank,0.13,0.30,Vector3.ZERO,"d5e4dc")
	_cylinder(tank,0.137,0.035,Vector3(0,0.07,0),"58b8bf")
	_box(tank,Vector3(0.32,0.07,0.32),Vector3(0,-0.18,0),"526d79")
	if not shallow:
		_box(root,Vector3(0.28,0.20,0.25),Vector3(-0.67,0.30,-0.30),"f4dfb9")
		var roof=_box(root,Vector3(0.34,0.07,0.32),Vector3(-0.67,0.43,-0.30),"487e83"); roof.rotation.z=0.12
	sites[id]={"root":root,"water":water,"shore":shoreline,"marker":marker,"pump":pump,"tank":tank,"shallow":shallow,"shown":0.0}

func sync(world: Dictionary) -> void:
	if snapshot.get("id","")!=world.id or int(snapshot.get("seconds",0))>int(world.seconds):
		for zone in world.zones:
			if sites.has(zone.id): sites[zone.id].shown=float(zone.water)
	snapshot={"id":world.id,"seconds":world.seconds,"paused":world.paused,"zones":world.zones.duplicate(true),"ecology":{"regions":world.ecology.regions.duplicate(true)}}
	ecology_view.sync(snapshot)
	watershed_view.sync(world)
	village_view.sync(world)
	habitat_view.sync(world)
	industry_view.sync(world)
	modern_view.sync(world)

func set_mode(mode: String) -> void:
	display_mode=mode
	player_view.visible=mode=="dossiers"
	habitat_view.visible=mode=="habitat"
	industry_view.visible=mode=="industry"
	modern_view.visible=mode=="modern"
	background_moon.visible=mode not in ["modern","dossiers"]
	globe.visible=mode in ["water","ecology"]; material_view.visible=mode=="materials"; watershed_view.visible=mode=="watershed"; village_view.visible=mode=="village"
	for info in sites.values(): info.root.visible=mode=="water"
	ecology_view.visible=mode=="ecology"

func active_sites() -> Dictionary:
	if display_mode=="modern": return modern_view.sites
	if display_mode=="industry": return industry_view.sites
	if display_mode=="habitat": return habitat_view.sites
	if display_mode in ["materials","dossiers"]: return {}
	if display_mode=="watershed": return watershed_view.sites
	if display_mode=="village": return {"village_depot":village_view.sites.depot}
	return sites if display_mode=="water" else ecology_view.sites

func project_site(id: String) -> Vector2:
	var all=active_sites()
	if not all.has(id): return Vector2(-1000,-1000)
	return camera.unproject_position(all[id].root.to_global(Vector3(0,0.2,0)))

func site_visible(id: String) -> bool:
	if not active_sites().has(id): return false
	var root: Node3D=active_sites()[id].root
	return root.global_basis.y.dot((camera.global_position-root.global_position).normalized())>0.20

func pick(at: Vector2) -> String:
	var closest=""; var distance_px=90.0
	for id in active_sites():
		if not site_visible(id): continue
		var d=project_site(id).distance_to(at)
		if d<distance_px: closest=id; distance_px=d
	return closest

func rotate_view(delta: Vector2) -> void:
	target_yaw+=delta.x*0.007; target_pitch=clampf(target_pitch+delta.y*0.006,-0.85,0.85)

func zoom(amount: float) -> void:
	distance=clampf(distance+amount,7.9,12.4)

func reset_camera() -> void:
	target_yaw=0; target_pitch=0; distance=7.9 if display_mode in ["habitat","industry","modern"] else 9.6

func _process(dt: float) -> void:
	time+=dt
	var modern_night=false
	if display_mode=="modern" and not modern_view.snapshot.is_empty():
		modern_night=posmod(int(modern_view.snapshot.modern.elapsed),int(modern_view.rules.day.period))>=modern_view.rules.day.daylight
	city_sun.light_energy=0.18 if modern_night else 1.1; city_fill.light_energy=0.22 if modern_night else 0.6
	scene_environment.ambient_light_energy=0.22 if modern_night else 0.5
	globe.rotation.y=lerp_angle(globe.rotation.y,target_yaw,minf(1,dt*12))
	globe.rotation.x=lerpf(globe.rotation.x,target_pitch,minf(1,dt*12))
	camera.position.z=lerpf(camera.position.z,distance,minf(1,dt*10))
	camera.position.y=lerpf(camera.position.y,6.0 if display_mode in ["materials","watershed","village","habitat","industry","modern"] else 2.0,minf(1,dt*10)); camera.look_at(Vector3.ZERO)
	material_view.rotation=globe.rotation; watershed_view.rotation=globe.rotation; village_view.rotation=globe.rotation
	habitat_view.rotation=globe.rotation; industry_view.rotation=globe.rotation; modern_view.rotation=globe.rotation
	if display_mode=="modern":
		for id in modern_view.sites:
			var marker=modern_view.sites[id].marker; marker.visible=id==highlighted
			marker.material_override=_mat("a5efd1" if highlight_valid else "e7958c")
		return
	if display_mode=="industry":
		for id in industry_view.sites:
			var marker=industry_view.sites[id].marker; marker.visible=id==highlighted
			marker.material_override=_mat("a5efd1" if highlight_valid else "e7958c")
		return
	if display_mode=="habitat":
		for id in habitat_view.sites:
			var marker=habitat_view.sites[id].marker
			if id.begins_with("habitat_"): marker.visible=id==highlighted
			marker.material_override=_mat(("a5efd1" if highlight_valid else "e7958c") if id==highlighted else "ffd18c")
		return
	if display_mode=="watershed":
		for id in watershed_view.sites:
			var marker=watershed_view.sites[id].marker; marker.visible=id==highlighted
			marker.material_override=_mat("a5efd1" if highlight_valid else "e7958c")
		return
	if display_mode=="village":
		for id in village_view.sites:
			var marker=village_view.sites[id].marker; marker.visible=id=="depot" and highlighted=="village_depot"; marker.material_override=_mat("a5efd1" if highlight_valid else "e7958c")
		return
	if display_mode=="dossiers":
		player_view.rotation.y=globe.rotation.y; player_view.rotation.x=globe.rotation.x; return
	if display_mode=="materials": return
	if display_mode=="ecology":
		for id in ecology_view.sites:
			var marker=ecology_view.sites[id].marker; marker.visible=id==highlighted
			marker.material_override=_mat("a5efd1" if highlight_valid else "e7958c")
		return
	for id in sites:
		var info=sites[id]; info.marker.visible=id==highlighted
		info.marker.material_override=_mat("a5efd1" if highlight_valid else "e7958c")
		if snapshot.is_empty(): continue
		var water=0.0; var target=0
		for zone in snapshot.zones:
			if zone.id==id: water=float(zone.water); target=int(zone.target)
		info.shown=lerpf(float(info.shown),water,minf(1,dt*6))
		var amount=float(info.shown)
		info.water.visible=amount>0.005; info.shore.visible=amount>0.005
		var radius=sqrt(clampf(amount/3.0,0.002,1.0)) if info.shallow else 0.30+minf(1,amount/3.0)*0.20
		info.water.scale=Vector3(radius,1,radius); info.water.position.y=(0.16+0.01*amount) if info.shallow else (0.132+0.022*amount)
		info.shore.scale=Vector3(radius,1,radius); info.shore.position.y=info.water.position.y+0.019
		info.tank.visible=target>0
		info.tank.position=Vector3(-0.56,0.43+maxf(0,target-water)*0.22,0.36)
		info.pump.scale=Vector3.ONE*(1.0+sin(time*4)*0.12 if water<target and not snapshot.paused else 1.0)
