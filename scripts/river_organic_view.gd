extends Node3D
## Nearby tanks share two meshes; rebuild only at visible level changes.
const G=preload("res://scripts/river_geometry.gd")
var material: Material
var liquid_material: StandardMaterial3D
var liquid: MeshInstance3D
var crystals: MeshInstance3D
var seen=""

func _ready() -> void:
	liquid_material=StandardMaterial3D.new(); liquid_material.vertex_color_use_as_albedo=true
	liquid_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; liquid_material.roughness=0.25
	liquid=MeshInstance3D.new(); add_child(liquid)
	crystals=MeshInstance3D.new(); add_child(crystals)

func sync(o,c,at: Vector2) -> void:
	var cell=Vector2i(floori(at.x/8),floori(at.y/8)); var signature=[cell,c.revision]
	for key in o.tanks:
		var t=o.tanks[key]; signature.append([key,int(t.water_l*8),int(t.solid_g*2),int(t.dissolved_g*2)])
	var stamp=str(signature)
	if stamp==seen: return
	seen=stamp
	var fluid=G.surface(liquid_material); var grain=G.surface(material); var nf=0; var ng=0
	for key in c.blocks:
		var b=c.blocks[key]
		if b.kind!="mixing_tank" or Vector2(b.x,b.z).distance_to(at)>60: continue
		var p=Vector3(b.x,b.y,b.z); var t=o.tanks.get(key,{})
		# Transparent inspection windows remain visible even in an empty tank.
		for z in [-0.36,0.36]: G.cube(fluid,p+Vector3(0,0.53,z),Vector3(0.64,0.65,0.02),Color(0.55,0.89,0.91,0.16)); nf+=1
		for x in [-0.36,0.36]: G.cube(fluid,p+Vector3(x,0.53,0),Vector3(0.02,0.65,0.64),Color(0.55,0.89,0.91,0.16)); nf+=1
		if t.get("water_l",0)>0:
			var h=0.05+float(t.water_l)/float(o.rules.game.tank_capacity_l)*0.55
			G.cube(fluid,p+Vector3(0,0.21+h/2,0),Vector3(0.63,h,0.63),Color(0.41,0.8,0.9,0.58)); nf+=1
		var count=mini(18,ceili(float(t.get("solid_g",0))*2))
		for i in range(count):
			G.cube(grain,p+Vector3((i%3)*0.16-0.16,0.24+(i/9)*0.075,((i/3)%3)*0.16-0.16),Vector3(0.11,0.065,0.11),Color("fff5e4")); ng+=1
	liquid.mesh=fluid.commit() if nf>0 else null; crystals.mesh=grain.commit() if ng>0 else null
