extends Node3D
## Render the exact archived atom positions; normalized presentation is not a relaxed geometry.
var builder
var specimen: Node3D
var laminate: Node3D
var laminate_key=""
var record_id=""
var atom_count=0
var heat_particles=[]
var heat_phase=0.0
func setup(b) -> void:
	builder=b
	b._cylinder(self,2.6,.16,Vector3(0,-.65,0),"223c50")
	b._ring(self,2.3,2.34,Vector3(0,-.55,0),"b4ace2")
	b._cylinder(self,1.3,.12,Vector3(0,-.51,0),"385269")
	specimen=Node3D.new(); add_child(specimen)
	laminate=Node3D.new(); add_child(laminate); laminate.hide()
func show_record(record: Dictionary,elements: Dictionary) -> void:
	var id=str(record.get("id",""))
	if id==record_id: return
	hide_laminate()
	record_id=id; atom_count=0
	for child in specimen.get_children(): specimen.remove_child(child); child.queue_free()
	if record.is_empty(): return
	var work=record.work; var points=[]; var center=Vector3.ZERO
	for xyz in work.positions:
		var point=Vector3(xyz[0],xyz[1],xyz[2]); points.append(point); center+=point
	center/=points.size(); var radius=.5
	for point in points: radius=maxf(radius,(point-center).length())
	var scale_factor=1.6/radius
	for i in range(points.size()):
		points[i]=(points[i]-center)*scale_factor+Vector3(0,1.1,0)
		var element=elements[work.atoms[i]]
		builder._sphere(specimen,.13 if work.atoms[i]=="H" else .21,points[i],str(element.color))
		atom_count+=1
	var count=0
	for bond in work.bonds:
		if count>=128: break
		var a=points[int(bond[0])]; var b=points[int(bond[1])]; var delta=b-a
		if delta.length()<.0001: continue
		var link=builder._cylinder(specimen,.035,delta.length(),(a+b)*.5,"769aab")
		link.quaternion=Quaternion(Vector3.UP,delta.normalized()); count+=1

func hide_laminate() -> void:
	laminate.hide(); specimen.scale=Vector3.ONE; specimen.position=Vector3.ZERO
func show_laminate(d: Dictionary) -> void:
	laminate.show(); specimen.scale=Vector3.ONE*.46; specimen.position=Vector3(-1.55,.4,0)
	if laminate_key==d.id: return
	laminate_key=d.id
	heat_particles.clear()
	for child in laminate.get_children(): laminate.remove_child(child); child.queue_free()
	var f=float(d.volume_fraction_Cu); var center=Vector3(.85,.65,0)
	if d.orientation=="series":
		builder._box(laminate,Vector3(2*f,.42,.65),center+Vector3(-1+f,0,0),"d99367")
		builder._box(laminate,Vector3(2*(1-f),.42,.65),center+Vector3(f,0,0),"c5d9df")
	else:
		builder._box(laminate,Vector3(2,.6*f,.65),center+Vector3(0,.3-.3*f,0),"d99367")
		builder._box(laminate,Vector3(2,.6*(1-f),.65),center+Vector3(0,-.3*f,0),"c5d9df")
	for i in range(5): heat_particles.append(builder._sphere(laminate,.04,center+Vector3(-.8+i*.4,.42,0),"f2d299"))
	builder._box(laminate,Vector3(.08,.66,.72),center+Vector3(-1.08,0,0),"ef9277")
	builder._box(laminate,Vector3(.08,.66,.72),center+Vector3(1.08,0,0),"83bde3")
	var label=Label3D.new(); label.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf"); label.text="标准铜 / 铝层料\n"+("顺着层片传热" if d.orientation=="parallel" else "横穿层片传热"); label.font_size=32; label.pixel_size=.009; label.position=center+Vector3(0,1,0); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; laminate.add_child(label)
func _process(delta: float) -> void:
	if not is_visible_in_tree() or not laminate.visible: return
	heat_phase=fmod(heat_phase+delta*.45,1.0)
	for i in range(heat_particles.size()): heat_particles[i].position.x=.85-1+2*fmod(heat_phase+i*.2,1.0)
