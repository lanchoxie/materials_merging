extends Control
## Plot computed samples without inventing interpolation data.
var values: Array = []
var caption: String = ""
var unit: String = ""

func setup(samples: Array, title: String, units: String) -> void:
	values = samples
	caption = title
	unit = units
	custom_minimum_size = Vector2(400,232)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_redraw()

func _draw() -> void:
	var font = get_theme_default_font()
	draw_style_box(preload("res://scripts/ui.gd").style(Color("10232c")),Rect2(Vector2.ZERO,size))
	draw_string(font,Vector2(16,27),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("a5efd1"))
	if values.size()<2: return
	var low = float(values[0][1])
	var high = low
	for sample in values:
		low=minf(low,float(sample[1]))
		high=maxf(high,float(sample[1]))
	var x0 = float(values.front()[0])
	var x1 = float(values.back()[0])
	var area = Rect2(92,52,maxf(100,size.x-118),116)
	draw_string(font,Vector2(12,57),"%.4f" % high,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("94abb0"))
	draw_string(font,Vector2(12,170),"%.4f" % low,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("94abb0"))
	draw_string(font,Vector2(16,217),unit,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("94abb0"))
	for fraction in [0.0,0.5,1.0]:
		var y=area.position.y+fraction*area.size.y
		draw_line(Vector2(area.position.x,y),Vector2(area.end.x,y),Color("334952"))
	var line: PackedVector2Array=[]
	for sample in values:
		line.append(Vector2(area.position.x+(float(sample[0])-x0)/maxf(x1-x0,0.00000001)*area.size.x,area.end.y-(float(sample[1])-low)/maxf(high-low,0.00000001)*area.size.y))
	draw_polyline(line,Color("a5efd1"),2.5,true)
	draw_string(font,Vector2(area.position.x,194),"%.2f" % x0,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("94abb0"))
	draw_string(font,Vector2(area.end.x-48,194),"%.2f" % x1,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("94abb0"))
