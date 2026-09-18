extends Node3D
## Reusable steady-flow teaching fixture; animation is not a transient heat solution.
const Lab=preload("res://scripts/material_lab.gd")
var lab=Lab.new()
var mode="same_size"
var parts: Dictionary={}
var elapsed=0.0

func setup(b) -> void:
	for index in range(2):
		var id="copper" if index==0 else "aluminum"; var m=lab.data.materials[id]
		var root=Node3D.new(); root.position.x=-1.48 if index==0 else 1.48; add_child(root)
		b._box(root,Vector3(2.6,0.22,3.5),Vector3(0,-0.45,0),"274855")
		b._box(root,Vector3(2.45,0.04,3.32),Vector3(0,-0.32,0),"376070")
		for z in [-1.1,1.1]:
			b._box(root,Vector3(1.3,0.48,0.5),Vector3(0,0,z),"71c8ce" if z<0 else "f4b66f")
			for i in range(5): b._box(root,Vector3(0.07,0.16,0.55),Vector3(-0.48+i*0.24,0.32,z),"a1dce0" if z<0 else "ffdda5")
		var bar=b._box(root,Vector3(0.30,0.30,1.9),Vector3.ZERO,str(m.color))
		var dots=[]
		for i in range(7): dots.append(b._sphere(root,0.045,Vector3(0,0.24,0),"ffe6b0"))
		var label=Label3D.new(); label.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); label.font_size=68; label.pixel_size=0.007; label.text=str(m.symbol)+"  /  "+str(m.name); label.position=Vector3(0,1.15,-0.5); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; root.add_child(label)
		var stats=Label3D.new(); stats.font=label.font; stats.font_size=44; stats.pixel_size=0.006; stats.position=Vector3(0,-0.30,2.1); stats.billboard=BaseMaterial3D.BILLBOARD_ENABLED; root.add_child(stats)
		parts[id]={"bar":bar,"dots":dots,"stats":stats}
	set_mode(mode)

func set_mode(value: String) -> void:
	mode=value
	for id in parts:
		var result=lab.calculate(str(id),mode); var part=parts[id]
		var width=sqrt(float(result.area_m2)/float(lab.data.fixture.area_m2))
		part.bar.scale=Vector3(width,width,1)
		part.stats.text="%.1f g   |   %.3f W/K\n截面 %.3f cm²" % [result.mass_kg*1000,result.conductance_W_K,result.area_m2*10000]

func _process(dt: float) -> void:
	if not visible: return
	elapsed+=dt
	for id in parts:
		var result=lab.calculate(str(id),mode); var part=parts[id]
		for i in range(part.dots.size()):
			var phase=fmod(elapsed*float(result.conductance_W_K)+i/7.0,1.0)
			part.dots[i].position=Vector3(0,0.19*part.bar.scale.y,0.85-phase*1.7)
