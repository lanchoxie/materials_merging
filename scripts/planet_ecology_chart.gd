extends Control
## A small observation trace in game units; no scientific scale claims.
var samples: Array=[]
var site="microbe"
var selected=-1
var fish_total=24.0
func _ready() -> void:
	custom_minimum_size=Vector2(0,112); mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var area=Rect2(5,8,maxf(1,size.x-10),94)
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	for fraction in [0.0,0.5,1.0]:
		var y=area.end.y-area.size.y*fraction; draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color("334952"),1)
	if samples.size()<2: return
	for kind in ["oxygen","life"]:
		var points=PackedVector2Array()
		for i in range(samples.size()):
			var r=samples[i].regions[site]
			var value=float(r.oxygen) if kind=="oxygen" else (float(r.sensitive) if site=="microbe" else float(r.bay)/fish_total*100.0)
			points.append(Vector2(area.position.x+float(i)/(samples.size()-1)*area.size.x,area.end.y-value/100.0*area.size.y))
		draw_polyline(points,Color("ffd18c") if kind=="oxygen" else Color("a5efd1"),2.0,true)
	if selected>=0 and selected<samples.size():
		var x=area.position.x+float(selected)/(samples.size()-1)*area.size.x; draw_line(Vector2(x,area.position.y),Vector2(x,area.end.y),Color("eaf2ed"),1)
func _background() -> StyleBoxFlat:
	var s=StyleBoxFlat.new(); s.bg_color=Color("10202b"); s.set_corner_radius_all(8); return s
