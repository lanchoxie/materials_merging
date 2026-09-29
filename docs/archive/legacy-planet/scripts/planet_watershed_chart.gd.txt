extends Control
var samples: Array=[]
var site="estuary"
var selected=-1
func _ready() -> void:
	custom_minimum_size=Vector2(0,112); mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var area=Rect2(5,8,maxf(1,size.x-10),94)
	draw_rect(Rect2(Vector2.ZERO,size),Color("10202b"))
	for f in [0.0,0.5,1.0]: draw_line(Vector2(area.position.x,area.end.y-area.size.y*f),Vector2(area.end.x,area.end.y-area.size.y*f),Color("334952"),1)
	if samples.size()<2: return
	var palette={"oxygen":"ffd18c","algae":"a5efd1","detritus":"c69b78"}
	for key in palette:
		var points=PackedVector2Array()
		for i in range(samples.size()):
			var r=samples[i].state.regions[site]; var scale=100.0 if key=="oxygen" else 40.0
			points.append(Vector2(area.position.x+float(i)/(samples.size()-1)*area.size.x,area.end.y-clampf(float(r[key])/scale,0,1)*area.size.y))
		draw_polyline(points,Color(palette[key]),2.0,true)
	if selected>=0:
		var x=area.position.x+float(selected)/(samples.size()-1)*area.size.x; draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),Color("eaf2ed"),1)
