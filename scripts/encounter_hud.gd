extends Control
var v
var target={}
var hit_flash=0.0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(dt: float) -> void:
	hit_flash=maxf(0,hit_flash-dt)
	queue_redraw()
func _draw() -> void:
	if v==null: return
	var font=get_theme_default_font()
	if hit_flash>0:
		var center=size*0.5
		for side in [-1,1]:
			draw_line(center+Vector2(side*7,-7),center+Vector2(side*14,-14),Color("ffd18c"),2)
			draw_line(center+Vector2(side*7,7),center+Vector2(side*14,14),Color("ffd18c"),2)
	draw_style_box(_box(),Rect2(18,120,198,54))
	draw_string(font,Vector2(30,140),"HP  %d / 100" % int(v.combat.player_health),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e5f3e9"))
	draw_rect(Rect2(30,151,170,9),Color("3b4b52")); draw_rect(Rect2(30,151,170*v.combat.player_health/100,9),Color("91d9b2"))
	if v.combat.hurt_flash>0: draw_rect(Rect2(Vector2.ZERO,size),Color(0.8,0.12,0.12,v.combat.hurt_flash*0.45))
	# v0.39 cold: felt temperature, and a frosty edge while the cold is draining health.
	var felt=float(v.combat.felt)
	if felt<8.0:
		var freezing=felt<float(v.rules.cold.threshold)
		# Beside the HP box, clear of the era goal line below it.
		draw_style_box(_box(),Rect2(226,120,270,54))
		draw_string(font,Vector2(238,140),"❄ 体感 %d °C%s" % [roundi(felt)," · 正在失温" if freezing else ""],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("bfe6ff") if freezing else Color("e5f3e9"))
		draw_string(font,Vector2(238,162),"靠近篝火、躲到屋顶下或穿保温服" if freezing else "天冷：留意篝火和屋顶",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("9fc7dd"))
		if freezing:
			var a=clampf(-felt/25.0,0.08,0.3)
			draw_rect(Rect2(Vector2.ZERO,Vector2(size.x,14)),Color(0.75,0.9,1,a)); draw_rect(Rect2(0,size.y-14,size.x,14),Color(0.75,0.9,1,a))
	if target.has("entity"):
		var e=target.entity; var x=size.x*0.5-105
		var rage=float(v.combat.records.get(e.key,{}).get("anger",0))
		draw_style_box(_box(),Rect2(x,60,210,76))
		draw_string(font,Vector2(x+12,82),str(e.name)+"  %.0f%%" % (float(e.row.get("health",1))*100),HORIZONTAL_ALIGNMENT_LEFT,185,15,Color("e5f3e9"))
		draw_rect(Rect2(x+12,95,185,10),Color("424e50")); draw_rect(Rect2(x+12,95,185*float(e.row.get("health",1)),10),Color("9ddbac"))
		draw_rect(Rect2(x+12,117,185,6),Color("424e50")); draw_rect(Rect2(x+12,117,185*rage/100,6),Color("ef9862"))
func _box() -> StyleBoxFlat:
	var s=StyleBoxFlat.new(); s.bg_color=Color(0.04,0.1,0.13,0.95); s.set_corner_radius_all(8); return s
