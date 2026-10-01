extends RefCounted
## v0.33 merged character parts: vertex-coloured boxes and low-poly balls in one SurfaceTool, so a
## whole figure is a handful of draw calls (body, two arms, two legs) on mobile.
const G=preload("res://scripts/river_geometry.gd")
static var _unit: Array=[]

static func _sphere() -> Array:
	if _unit.is_empty():
		var s=SphereMesh.new(); s.radius=1.0; s.height=2.0; s.radial_segments=12; s.rings=6
		_unit=s.get_mesh_arrays()
	return _unit

static func box(st: SurfaceTool,at: Vector3,size: Vector3,color: Color) -> void:
	G.cube(st,at,size,color)

static func ball(st: SurfaceTool,at: Vector3,radius: float,color: Color,squash: Vector3=Vector3.ONE) -> void:
	var a=_sphere(); var verts: PackedVector3Array=a[Mesh.ARRAY_VERTEX]; var normals: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array=a[Mesh.ARRAY_INDEX]
	# SphereMesh winds counter-clockwise for Godot's front faces; keep its order.
	for i in index:
		st.set_color(color); st.set_normal((normals[i]/squash).normalized()); st.add_vertex(at+verts[i]*radius*squash)
