extends Node3D
const G=preload("res://scripts/river_geometry.gd")
const Components=preload("res://scripts/river_component_geometry.gd")
var revision=-1
var fingerprint=""

func sync(state) -> void:
	var c=state.planet.v2.construction
	var signature=str(c.revision)+":"+str(state.layout.revision)
	if fingerprint==signature: return
	fingerprint=signature
	for child in get_children(): child.queue_free()
	var material=StandardMaterial3D.new(); material.vertex_color_use_as_albedo=true; material.roughness=0.8
	for item in c.miniatures.values():
		var index=int(item.plot)
		if index<0 or index>=state.plots.size() or not state.plots[index].unlocked: continue
		var p=state.plots[index]; var base=Vector3(p.x*3+0.95,0.13,p.z*3-0.98)
		var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_material(material)
		G.cube(st,base+Vector3(0,0.19,0),Vector3(0.7,0.38,0.7),Color("e7ded0"))
		G.cube(st,base+Vector3(0,0.40,0),Vector3(0.76,0.04,0.76),Color("d3af63"))
		var stand=MeshInstance3D.new(); stand.mesh=st.commit(); add_child(stand)
		var size=Vector3.ONE
		for b in item.blocks: size=size.max(Vector3(b.x+1,b.y+1,b.z+1))
		st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_material(material)
		for b in item.blocks: Components.draw(st,Vector3(b.x,b.y+0.5,b.z)-Vector3((size.x-1)/2,0,(size.z-1)/2),b.kind,Color(c.rules.kinds[b.kind].color))
		var model=MeshInstance3D.new(); model.mesh=st.commit(); model.scale=Vector3.ONE*(0.64/maxf(size.x,maxf(size.z,size.y))); model.position=base+Vector3(0,0.43,0); add_child(model)
