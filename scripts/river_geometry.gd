extends RefCounted
static func surface(material: Material) -> SurfaceTool:
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_material(material); return st
## v0.33: cheap baked shading. Undersides are darker and the lower edge of every wall is shaded,
## which reads as contact occlusion on the compatibility renderer (no SSAO there).
static func face(st: SurfaceTool,points: Array,color: Color) -> void:
	var normal=(points[2]-points[0]).cross(points[1]-points[0]).normalized()
	if normal.y<-0.5: color=color.darkened(0.22)
	var low=minf(minf(points[0].y,points[1].y),minf(points[2].y,points[3].y))
	var wall=absf(normal.y)<0.5 and maxf(maxf(points[0].y,points[1].y),maxf(points[2].y,points[3].y))-low>0.001
	var foot=color.darkened(0.16)
	for i in [0,1,2,0,2,3]:
		st.set_color(foot if wall and points[i].y<=low+0.0001 else color); st.set_normal(normal); st.add_vertex(points[i])
static func cube(st: SurfaceTool,p: Vector3,size: Vector3,color: Color) -> void:
	var h=size*0.5
	var v=[p+Vector3(-h.x,-h.y,-h.z),p+Vector3(h.x,-h.y,-h.z),p+Vector3(h.x,h.y,-h.z),p+Vector3(-h.x,h.y,-h.z),p+Vector3(-h.x,-h.y,h.z),p+Vector3(h.x,-h.y,h.z),p+Vector3(h.x,h.y,h.z),p+Vector3(-h.x,h.y,h.z)]
	for f in [[0,1,2,3],[5,4,7,6],[4,0,3,7],[1,5,6,2],[3,2,6,7],[4,5,1,0]]: face(st,[v[f[0]],v[f[1]],v[f[2]],v[f[3]]],color)
