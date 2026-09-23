extends Node3D
## Chunked render meshes; the construction model owns every block and material.
const G=preload("res://scripts/river_geometry.gd")
const Components=preload("res://scripts/river_component_geometry.gd")
var material: Material
var chunks: Dictionary={}
var seen=""
var ghost: MeshInstance3D
var ghost_material: StandardMaterial3D

func _ready() -> void:
	ghost=MeshInstance3D.new(); var mesh=BoxMesh.new(); mesh.size=Vector3.ONE*1.025; ghost.mesh=mesh
	ghost_material=StandardMaterial3D.new(); ghost_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override=ghost_material; add_child(ghost); ghost.hide()

func sync(model,at: Vector2) -> void:
	var signature=str([model.revision,Vector2i(floori(at.x/16),floori(at.y/16))])
	if seen==signature: return
	seen=signature; var grouped={}
	for b in model.blocks.values():
		if Vector2(b.x,b.z).distance_to(at)>70: continue
		var k=Vector2i(floori(float(b.x)/16),floori(float(b.z)/16))
		if not grouped.has(k): grouped[k]=[]
		grouped[k].append(b)
	for k in chunks.keys():
		if not grouped.has(k): chunks[k].queue_free(); chunks.erase(k)
	for k in grouped:
		if not chunks.has(k): chunks[k]=MeshInstance3D.new(); add_child(chunks[k])
		var st=G.surface(material)
		for b in grouped[k]:
			var p=Vector3(b.x,b.y+0.5,b.z)
			Components.draw(st,p,str(b.kind),Color(model.rules.kinds[b.kind].color))
		chunks[k].mesh=st.commit()

func preview(model,actor: Dictionary,mode: String,products: Array,recipe_id: String="") -> String:
	ghost.hide()
	if actor.is_empty() or mode=="observe": return "E 采集成熟野草 · B 打开背包 · 1—9切换物品"
	var hit: Dictionary=model.trace(actor.eye,actor.direction)
	if hit.is_empty() or hit.has("blocked"): return "瞄准5米内的地面或自建构件"
	var c: Vector3i=hit.target; var error=""
	if mode=="remove":
		if str(hit.hit).is_empty(): return "地形暂不能挖掘；瞄准自建构件拆回"
		c=model.cell(model.blocks[hit.hit]); error="remove"
	else:
		error=model.place_error(c,actor)
		if error.is_empty() and model.available(mode,products,recipe_id)<1: error="材料不足，按B打开背包前往工艺车间"
	ghost.position=Vector3(c.x,c.y+0.5,c.z)
	ghost_material.albedo_color=Color(0.4,0.95,0.7,0.32) if error.is_empty() else Color(1,0.5,0.4,0.32)
	ghost.show()
	return "E 拆回此构件" if mode=="remove" else ("E 放置"+str(model.rules.kinds[mode].name) if error.is_empty() else error)
