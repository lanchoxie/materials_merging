extends MeshInstance3D
## v0.47 远景地形: what you see from the plane beyond the streamed chunks. A coarse grid (40 m cells,
## 2.4 km radius, past the horizon even at 400 m altitude) with heights from the same terrain
## function as the ground (`legacy_height`) and colours from the globe painter (`Globe.color_at`).
## The sea is a flat surface at sea level. It sits a little below the real ground so the near chunks
## always win, and its shader bends it with the planet's curvature. Built a few rows per frame and
## swapped in when finished, so flying never stalls; rebuilt after the plane moves 600 m.
const Globe=preload("res://scripts/planet_globe.gd")
const Shape=preload("res://scripts/planet_shape.gd")
const RADIUS=2400.0
const CELL=40.0
const ROWS_PER_FRAME=4
const SINK=1.4
var terrain
var env
var centre=Vector2.INF
var job: Dictionary={}
var shader_material: ShaderMaterial

func _ready() -> void:
	_ensure_material()

func _ensure_material() -> void:
	if shader_material!=null: return
	shader_material=ShaderMaterial.new(); shader_material.shader=preload("res://assets/shaders/far_terrain.gdshader")
	material_override=shader_material; cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func size() -> int:
	return int(RADIUS*2.0/CELL)+1

## Start a rebuild around `at` when needed (call every frame while flying).
func want(at: Vector2) -> void:
	if not job.is_empty(): return
	if centre!=Vector2.INF and at.distance_to(centre)<600.0: return
	var c=(at/CELL).round()*CELL
	job={"centre":c,"row":0,"heights":PackedFloat32Array(),"colors":PackedColorArray()}

func set_origin(o: Vector3) -> void:
	_ensure_material(); shader_material.set_shader_parameter("origin",o)

## Height and colour of one far point (the sea is flat at sea level).
func sample(x: float,z: float) -> Array:
	var wx=Shape.wrap_x(x)
	if not Shape.on_surface(Vector2(wx,z)): return [2.0,Color("eef3f4")]
	var h: float=terrain.legacy_height(Vector2(wx,z))
	var color: Color=Globe.color_at(env,wx,z) if env!=null else Color("86a865")
	if h<Shape.SEA_LEVEL: return [Shape.SEA_LEVEL-0.3,color]
	return [h-SINK,color]

func _process(_dt: float) -> void:
	if job.is_empty(): return
	_rows(ROWS_PER_FRAME)

func _rows(count: int) -> void:
	var n=size(); var c: Vector2=job.centre
	for r in range(count):
		var j=int(job.row)
		if j>=n: break
		var z=c.y-RADIUS+j*CELL
		for i in range(n):
			var s=sample(c.x-RADIUS+i*CELL,z)
			job.heights.append(float(s[0])); job.colors.append(s[1])
		job.row=j+1
	if int(job.row)>=n: _commit()

## Build everything now (tests, or the first frame of a flight).
func build_now(at: Vector2) -> void:
	job={}; centre=Vector2.INF; want(at); _rows(size())

func _commit() -> void:
	var n=size(); var c: Vector2=job.centre; var hs: PackedFloat32Array=job.heights; var cs: PackedColorArray=job.colors
	var verts=PackedVector3Array(); var normals=PackedVector3Array(); var indices=PackedInt32Array()
	verts.resize(n*n); normals.resize(n*n)
	for j in range(n):
		for i in range(n):
			verts[j*n+i]=Vector3(c.x-RADIUS+i*CELL,hs[j*n+i],c.y-RADIUS+j*CELL)
	for j in range(n):
		for i in range(n):
			var l=hs[j*n+maxi(i-1,0)]; var rr=hs[j*n+mini(i+1,n-1)]; var u=hs[maxi(j-1,0)*n+i]; var d=hs[mini(j+1,n-1)*n+i]
			normals[j*n+i]=Vector3(l-rr,2.0*CELL,u-d).normalized()
	for j in range(n-1):
		for i in range(n-1):
			var a=j*n+i
			indices.append_array([a,a+1,a+n,a+1,a+n+1,a+n])
	var arrays=[]; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts; arrays[Mesh.ARRAY_NORMAL]=normals; arrays[Mesh.ARRAY_COLOR]=cs; arrays[Mesh.ARRAY_INDEX]=indices
	var m=ArrayMesh.new(); m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh=m; centre=c; job={}
