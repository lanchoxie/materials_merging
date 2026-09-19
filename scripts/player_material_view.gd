extends Node3D
## Render the exact archived atom positions; normalized presentation is not a relaxed geometry.
var builder
var specimen: Node3D
var record_id=""
var atom_count=0
func setup(b) -> void:
	builder=b
	b._cylinder(self,2.6,.16,Vector3(0,-.65,0),"223c50")
	b._ring(self,2.3,2.34,Vector3(0,-.55,0),"b4ace2")
	b._cylinder(self,1.3,.12,Vector3(0,-.51,0),"385269")
	specimen=Node3D.new(); add_child(specimen)
func show_record(record: Dictionary,elements: Dictionary) -> void:
	var id=str(record.get("id",""))
	if id==record_id: return
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
