extends Node3D
## v0.33.1 display only: the player's waypoints as cairns with a tall light beam and a name, and in
## the god view the walked trail as a dotted line on the ground.
const G=preload("res://scripts/river_geometry.gd")
var terrain
var material: Material
var beam_material: StandardMaterial3D
var beacons: Dictionary={}
var trail_node: MeshInstance3D
var seen_points=-1
var seen_trail=""

func _ready() -> void:
	beam_material=StandardMaterial3D.new(); beam_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; beam_material.albedo_color=Color(1.0,0.84,0.4,0.38)
	beam_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	trail_node=MeshInstance3D.new(); add_child(trail_node)

## `overview` is the god view; `at` is the walker (first person) or the god view's centre.
func sync(journey,at: Vector2,overview: bool) -> void:
	if journey.revision!=seen_points: _beacons(journey); seen_points=journey.revision
	for id in beacons:
		var n: Node3D=beacons[id]; var d=at.distance_to(Vector2(n.position.x,n.position.z))
		n.visible=d<(700.0 if overview else 900.0)
		n.get_node("Label").visible=n.visible and (overview or d>6.0)
	trail_node.visible=overview
	if not overview: return
	var key="%d/%d/%d" % [journey.trail_revision,roundi(at.x/16.0),roundi(at.y/16.0)]
	if key!=seen_trail: seen_trail=key; trail_node.mesh=_trail(journey.trail,at)

func _beacons(journey) -> void:
	for id in beacons.keys():
		if not journey.points.has(id): beacons[id].queue_free(); beacons.erase(id)
	for id in journey.points:
		if beacons.has(id): continue
		var row: Dictionary=journey.points[id]; var p=Vector2(row.x,row.z); var y=terrain.ground(p)
		var root=Node3D.new(); root.position=Vector3(p.x,y,p.y); add_child(root); beacons[id]=root
		var st=G.surface(material)
		for i in range(3):
			var w=0.9-i*0.25
			G.cube(st,Vector3(0,0.15+i*0.28,0),Vector3(w,0.28,w),Color("8f948c").lightened(i*0.06))
		G.cube(st,Vector3(0,1.0,0),Vector3(0.16,0.3,0.16),Color("f5d789"))
		var cairn=MeshInstance3D.new(); cairn.mesh=st.commit(); root.add_child(cairn)
		var beam=MeshInstance3D.new(); var cylinder=CylinderMesh.new(); cylinder.top_radius=0.12; cylinder.bottom_radius=0.22; cylinder.height=36.0
		cylinder.radial_segments=8; cylinder.rings=1; beam.mesh=cylinder; beam.material_override=beam_material; beam.position.y=19.0; root.add_child(beam)
		var label=Label3D.new(); label.name="Label"; label.font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
		label.text=str(row.name); label.font_size=40; label.outline_size=8; label.position.y=3.0
		label.modulate=Color("f5d789"); label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.no_depth_test=true; label.fixed_size=true; label.pixel_size=0.0012
		root.add_child(label)

## Short flat dashes between consecutive points of one segment, within the god view's frame.
func _trail(trail: Array,at: Vector2) -> Mesh:
	var st=G.surface(material); var count=0
	for i in range(1,trail.size()):
		var a: Array=trail[i-1]; var b: Array=trail[i]
		if a[2]!=b[2]: continue
		var pa=Vector2(a[0],a[1]); var pb=Vector2(b[0],b[1])
		if pa.distance_to(at)>700 and pb.distance_to(at)>700: continue
		var steps=maxi(1,int(pa.distance_to(pb)/2.0))
		for k in range(steps):
			if k%2==1: continue
			var p=pa.lerp(pb,(k+0.5)/steps)
			G.cube(st,Vector3(p.x,terrain.ground(p)+0.1,p.y),Vector3(1.1,0.12,1.1),Color("ffd560"))
			count+=1
	if count==0: return null
	return st.commit()
