extends RefCounted
## Bake opaque, immobile meshes by material within a parcel. Animated children stay live.
static func bake(root: Node3D) -> void:
	var groups: Dictionary = {}
	_gather(root, Transform3D.IDENTITY, groups)
	for key in groups:
		var group: Dictionary = groups[key]
		if group.items.size() < 2: continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for item in group.items:
			for i in range(item.node.mesh.get_surface_count()):
				surface.append_from(item.node.mesh, i, item.transform)
		surface.set_material(group.material)
		var merged := MeshInstance3D.new()
		merged.name = "StaticBatch"
		merged.mesh = surface.commit()
		root.add_child(merged)
		for item in group.items: item.node.free()

static func _gather(node: Node3D, transform: Transform3D, groups: Dictionary) -> void:
	for child in node.get_children():
		if not child is Node3D or child.name in ["Molecule","Building"] or child.get_meta("dynamic_geometry",false): continue
		var relative: Transform3D = transform * child.transform
		if child is MeshInstance3D and child.mesh != null:
			var mat = child.material_override
			if mat is StandardMaterial3D and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				var key = mat.get_instance_id()
				if not groups.has(key): groups[key] = {"material":mat,"items":[]}
				groups[key].items.append({"node":child,"transform":relative})
		_gather(child,relative,groups)
