extends Node3D
## Chunked render meshes; the construction model owns every block and material.
const G=preload("res://scripts/river_geometry.gd")
const Components=preload("res://scripts/river_component_geometry.gd")
var material: Material
var chunks: Dictionary={}
var seen=""
var ghost: MeshInstance3D
var ghost_material: StandardMaterial3D
## v0.32: animated sprays and plumes for nearby Earth machines (render only).
var effects: Dictionary={}
const FX={"sprinkler":["8fd8ff",2.3,Vector3(0,1,0),70.0,2.2,-4.0],"oxygen_tower":["c8fbff",3.2,Vector3(0,1,0),12.0,0.9,0.4],"co2_tower":["9a948c",3.0,Vector3(0,1,0),18.0,0.8,0.15],"fertilizer_spreader":["e8d27a",0.7,Vector3(0,0.3,0),80.0,1.8,-5.0],"campfire":["ffb347",0.7,Vector3(0,1,0),18.0,1.1,1.5]}

func _ready() -> void:
	ghost=MeshInstance3D.new(); var mesh=BoxMesh.new(); mesh.size=Vector3.ONE*1.025; ghost.mesh=mesh
	ghost_material=StandardMaterial3D.new(); ghost_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override=ghost_material; add_child(ghost); ghost.hide()

## v0.41.2: every cell a build will occupy, like placing one block (green fits, red does not).
var cell_ghosts: Array=[]
func preview_cells(found: Dictionary) -> void:
	var cells: Array=found.get("cells",[])
	ghost.hide()
	var color=Color(0.4,0.95,0.7,0.30) if str(found.get("error","")).is_empty() else Color(1,0.5,0.4,0.30)
	ghost_material.albedo_color=color
	while cell_ghosts.size()<mini(cells.size(),64):
		var g=MeshInstance3D.new(); g.mesh=ghost.mesh; g.material_override=ghost_material; add_child(g); cell_ghosts.append(g)
	for i in range(cell_ghosts.size()):
		var on=i<cells.size()
		cell_ghosts[i].visible=on
		if on: var c: Vector3i=cells[i]; cell_ghosts[i].position=Vector3(c.x,c.y+0.5,c.z)

func hide_cells() -> void:
	for g in cell_ghosts: g.visible=false

## v0.33.1: the 微缩器 shows the whole build it would box (green) or why it can't (red).
func preview_box(found: Dictionary) -> void:
	if not found.has("low"): ghost.hide(); return
	var low: Vector3i=found.low; var high: Vector3i=found.high
	ghost.scale=Vector3(high-low)+Vector3.ONE
	ghost.position=(Vector3(low)+Vector3(high))*0.5+Vector3(0,0.5,0)
	ghost_material.albedo_color=Color(0.4,0.95,0.7,0.22) if found.error.is_empty() else Color(1,0.5,0.4,0.22)
	ghost.show()

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
	var wanted={}
	for b in model.blocks.values():
		if not FX.has(str(b.kind)) or Vector2(b.x,b.z).distance_to(at)>70 or wanted.size()>=16: continue
		wanted[model.key(model.cell(b))]=b
	for k in effects.keys():
		if not wanted.has(k): effects[k].queue_free(); effects.erase(k)
	for k in wanted:
		if not effects.has(k): effects[k]=_effect(wanted[k]); add_child(effects[k])

func _effect(b: Dictionary) -> CPUParticles3D:
	var spec: Array=FX[str(b.kind)]
	var fx=CPUParticles3D.new(); fx.position=Vector3(b.x,float(b.y)+float(spec[1]),b.z)
	var drop=BoxMesh.new(); drop.size=Vector3.ONE*(0.07 if b.kind!="co2_tower" else 0.22)
	var m=StandardMaterial3D.new(); m.albedo_color=Color(str(spec[0])); m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	if b.kind=="co2_tower": m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color.a=0.55
	drop.material=m; fx.mesh=drop
	fx.amount=36 if b.kind!="co2_tower" else 18; fx.lifetime=1.6 if b.kind!="co2_tower" else 3.0
	fx.direction=spec[2]; fx.spread=float(spec[3]); fx.initial_velocity_min=float(spec[4])*0.7; fx.initial_velocity_max=float(spec[4])
	fx.gravity=Vector3(0,float(spec[5]),0); fx.scale_amount_min=0.6; fx.scale_amount_max=1.4
	if b.kind=="co2_tower": fx.scale_amount_max=2.6
	if b.kind=="campfire":
		fx.amount=20; fx.lifetime=0.9
		var light=OmniLight3D.new(); light.light_color=Color("ff9b4a"); light.light_energy=1.6; light.omni_range=7.0; light.position=Vector3(0,0.2,0); fx.add_child(light)
	fx.emitting=true
	return fx

func preview(model,actor: Dictionary,mode: String,products: Array,recipe_id: String="") -> String:
	ghost.hide(); ghost.scale=Vector3.ONE; hide_cells()
	if actor.is_empty() or mode=="observe": return "E 采集成熟野草 · B 打开背包 · 1—9切换物品"
	var hit: Dictionary=model.trace(actor.eye,actor.direction)
	if hit.is_empty() or hit.has("blocked"): return "瞄准5米内的地面或自建构件"
	var c: Vector3i=hit.target; var error=""
	if mode=="remove":
		if str(hit.hit).is_empty(): return "拆卸锤用于自建构件；挖地请在背包装备地形铲"
		c=model.cell(model.blocks[hit.hit]); error="remove"
	else:
		error=model.place_error(c,actor)
		if error.is_empty() and model.available(mode,products,recipe_id)<1: error="材料不足，按B打开背包前往工艺车间"
	ghost.position=Vector3(c.x,c.y+0.5,c.z)
	ghost_material.albedo_color=Color(0.4,0.95,0.7,0.32) if error.is_empty() else Color(1,0.5,0.4,0.32)
	ghost.show()
	return "E 拆回此构件" if mode=="remove" else ("E 放置"+str(model.rules.kinds[mode].name) if error.is_empty() else error)
