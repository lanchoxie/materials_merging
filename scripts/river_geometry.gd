extends RefCounted
static func surface(material: Material) -> SurfaceTool:
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_material(material); return st
static func face(st: SurfaceTool,points: Array,color: Color) -> void:
	var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
	for i in [0,1,2,0,2,3]: st.set_color(color); st.set_normal(normal); st.add_vertex(points[i])
static func cube(st: SurfaceTool,p: Vector3,size: Vector3,color: Color) -> void:
	var h=size*0.5
	var v=[p+Vector3(-h.x,-h.y,-h.z),p+Vector3(h.x,-h.y,-h.z),p+Vector3(h.x,h.y,-h.z),p+Vector3(-h.x,h.y,-h.z),p+Vector3(-h.x,-h.y,h.z),p+Vector3(h.x,-h.y,h.z),p+Vector3(h.x,h.y,h.z),p+Vector3(-h.x,h.y,h.z)]
	for f in [[0,1,2,3],[5,4,7,6],[4,0,3,7],[1,5,6,2],[3,2,6,7],[4,5,1,0]]: face(st,[v[f[0]],v[f[1]],v[f[2]],v[f[3]]],color)
