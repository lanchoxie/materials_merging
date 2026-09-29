extends Node3D
## Public island scenery and precise picking only; never owns land or inventory.
const G=preload("res://scripts/river_geometry.gd")
const StaticGeometry=preload("res://scripts/static_geometry.gd")
var world
var revision=-1
var plaza=Vector3(INF,0,0)
var tip=Vector3.ZERO
var start=Vector3(-1.4,0.20,1.3)
var gate: Node3D
var scenery: Node3D
var rainbow: ShaderMaterial
var core: ShaderMaterial
var orbit: Node3D
var pulse=0.0
var clock=0.0
var builds=0

func setup(island, state) -> void:
	world=island; name="RainbowLightBridge"; world.add_child(self); sync(state)

func _clear_site(at: Vector3, state) -> bool:
	for p in state.plots:
		if p.unlocked and absf(at.x-float(p.x)*3)<2.65 and absf(at.z-float(p.z)*3)<2.65: return false
	return true

func sync(state) -> void:
	if revision==state.layout.revision: return
	revision=state.layout.revision
	var index=int(state.layout.plaza_index)
	if index<0: hide(); return
	var p=state.plots[index]; var anchor=Vector3(p.x*3,0,p.z*3)
	if gate!=null and anchor==plaza and _clear_site(plaza+tip,state): return
	plaza=anchor; position=plaza; show()
	# Prefer a little platform beyond the left-front corner. Occupied parcels
	# are never replaced; expanding the island can move this public annex outward.
	var found=false
	for distance in range(1,9):
		for side in [-1,1]:
			var candidate=Vector3(side*3,0.55,distance*3)
			if _clear_site(plaza+candidate,state): tip=candidate; found=true; break
		if found: break
	if not found: tip=Vector3(-1.1,4.2,1.0)
	start=Vector3(-1.4 if tip.x<0 else 1.4,0.20,1.3)
	_build()

func _material(color: String, glow: bool=false) -> StandardMaterial3D:
	var m=StandardMaterial3D.new(); m.albedo_color=Color(color); m.roughness=0.4
	if glow: m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _mesh(parent: Node3D, shape: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var n=MeshInstance3D.new(); n.mesh=shape; n.position=at; n.material_override=material; parent.add_child(n); return n

func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var shape=BoxMesh.new(); shape.size=size; return _mesh(parent,shape,at,material)

func _ring(parent: Node3D, inner: float, outer: float, at: Vector3, material: Material) -> MeshInstance3D:
	var shape=TorusMesh.new(); shape.inner_radius=inner; shape.outer_radius=outer; shape.rings=48; shape.ring_segments=8
	return _mesh(parent,shape,at,material)

func _build() -> void:
	builds+=1
	if is_instance_valid(scenery): scenery.free()
	scenery=Node3D.new(); add_child(scenery)
	var bronze=_material("b59662"); var stone=_material("365267"); var light=_material("b7f6ed",true)
	var shader=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded, cull_disabled; uniform float pulse=0.0; void fragment(){ float f=0.82+0.18*sin(UV.y*25.0-TIME*3.0); ALBEDO=COLOR.rgb*(f+pulse*0.7); }"
	rainbow=ShaderMaterial.new(); rainbow.shader=shader
	var colors=["e6a4dc","c4adff","88bffa","82e0da","a6e7b4","e5e3a3","edba85"]
	var along=(tip-start).normalized(); var side=Vector3(along.z,0,-along.x).normalized()
	var surface=G.surface(rainbow)
	for i in range(colors.size()):
		var left=(i/7.0-0.5); var right=((i+1)/7.0-0.5)
		var a=start+side*left*0.45; var b=start+side*right*0.45
		var c=tip+side*right; var d=tip+side*left
		surface.set_normal(Vector3.UP); surface.set_color(Color(colors[i]))
		for v in [[a,Vector2(0,0)],[b,Vector2(1,0)],[c,Vector2(1,1)],[a,Vector2(0,0)],[c,Vector2(1,1)],[d,Vector2(0,1)]]:
			surface.set_uv(v[1]); surface.add_vertex(v[0])
	var bridge=MeshInstance3D.new(); bridge.mesh=surface.commit(); scenery.add_child(bridge)
	for sign_value in [-1,1]:
		var a=start+side*0.26*sign_value; var b=tip+side*0.57*sign_value
		var rail=_box(scenery,Vector3(0.055,0.10,a.distance_to(b)),(a+b)*0.5,bronze); rail.look_at(plaza+b,Vector3.UP)
		for t in [0.25,0.5,0.75]:
			var at=a.lerp(b,t)
			_box(scenery,Vector3(0.055,0.36,0.055),at+Vector3(0,0.14,0),bronze)
			_box(scenery,Vector3(0.09,0.07,0.09),at+Vector3(0,0.34,0),light)
	var platform=CylinderMesh.new(); platform.top_radius=1.18; platform.bottom_radius=0.95; platform.height=0.28; platform.radial_segments=48
	_mesh(scenery,platform,tip-Vector3(0,0.14,0),stone)
	_ring(scenery,0.99,1.05,tip+Vector3(0,0.025,0),bronze)
	_ring(scenery,0.84,0.88,tip+Vector3(0,0.04,0),light)
	gate=Node3D.new(); scenery.add_child(gate); gate.position=tip+Vector3(0,1.28,0)
	var arrival=Vector3(start.x-tip.x,0,start.z-tip.z).normalized()
	var camera_side=Vector3(world.camera.position.x-plaza.x-tip.x,0,world.camera.position.z-plaza.z-tip.z).normalized()
	# A diagonal gateway reveals its face from both the bridge and the island camera.
	var facing=arrival+camera_side
	gate.look_at(gate.global_position+(arrival if facing.length()<0.01 else facing.normalized()),Vector3.UP)
	for spec in [[1.03,1.15,bronze],[0.91,0.97,light]]:
		var ring=_ring(gate,spec[0],spec[1],Vector3.ZERO,spec[2]); ring.rotation.x=PI/2
	for sign_value in [-1,1]: _box(gate,Vector3(0.24,1.8,0.35),Vector3(sign_value*1.03,-0.3,0),bronze)
	orbit=Node3D.new(); gate.add_child(orbit)
	orbit.set_meta("dynamic_geometry",true)
	for i in range(12):
		var angle=i*TAU/12
		var rune=_box(orbit,Vector3(0.065,0.18,0.06),Vector3(sin(angle)*1.09,cos(angle)*1.09,0.08),light); rune.rotation.z=-angle
	var vortex=Shader.new()
	vortex.code="shader_type spatial; render_mode unshaded, cull_disabled, blend_mix, depth_draw_never; uniform float pulse=0.0; void fragment(){vec2 q=UV*2.0-1.0; float r=length(q); if(r>1.0){discard;} float wave=0.5+0.5*sin(atan(q.y,q.x)*4.0-r*16.0+TIME*2.0); ALBEDO=mix(vec3(0.10,0.28,0.42),vec3(0.45,0.95,0.89),wave)*(0.7+pulse); ALPHA=0.82*(1.0-smoothstep(0.88,1.0,r));}"
	core=ShaderMaterial.new(); core.shader=vortex
	var disk=QuadMesh.new(); disk.size=Vector2.ONE*1.84; _mesh(gate,disk,Vector3.ZERO,core)
	var beam_mat=_material("98ddf1",true); beam_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; beam_mat.albedo_color.a=0.09; beam_mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	var beam=CylinderMesh.new(); beam.bottom_radius=0.035; beam.top_radius=0.24; beam.height=3.8; beam.radial_segments=16
	_mesh(scenery,beam,tip+Vector3(0,3.05,0),beam_mat)
	var sign_node=Label3D.new(); sign_node.text="彩虹光桥\n轻触 · 前往星球"; sign_node.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	sign_node.font_size=36; sign_node.pixel_size=0.007; sign_node.modulate=Color("c5f6ee"); sign_node.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	sign_node.position=tip+Vector3(0,3.0,0); scenery.add_child(sign_node)
	StaticGeometry.bake(orbit); StaticGeometry.bake(scenery)

func hit(camera: Camera3D, at: Vector2) -> bool:
	if not visible or gate==null: return false
	var origin=to_local(camera.project_ray_origin(at)); var direction=global_basis.inverse()*camera.project_ray_normal(at)
	var along=(tip-start).normalized(); var side=Vector3(along.z,0,-along.x).normalized()
	var contact=Plane(along.cross(side).normalized(),start).intersects_ray(origin,direction)
	if contact!=null:
		var t=(contact-start).dot(along)
		if t>=0 and t<=start.distance_to(tip) and absf((contact-start).dot(side))<=0.6: return true
	var local_origin=gate.to_local(camera.project_ray_origin(at)); var local_direction=gate.global_basis.inverse()*camera.project_ray_normal(at)
	if absf(local_direction.z)>0.00001:
		var t=-local_origin.z/local_direction.z
		if t>=0:
			var point=local_origin+local_direction*t
			if Vector2(point.x,point.y).length()<=1.18: return true
	var landing=Plane(Vector3.UP,tip).intersects_ray(origin,direction)
	return landing!=null and landing.distance_to(tip)<=1.18

func activate() -> void:
	pulse=1.0

func _process(dt: float) -> void:
	if gate==null: return
	# Only two uniforms and one transform change. No per-frame meshes or particles.
	clock+=dt; pulse=maxf(0,pulse-dt*1.4); orbit.rotation.z=clock*0.14
	rainbow.set_shader_parameter("pulse",pulse); core.set_shader_parameter("pulse",pulse)
