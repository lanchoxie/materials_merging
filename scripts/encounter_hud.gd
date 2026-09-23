extends Control
var v
var target={}
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_dt: float) -> void:
	queue_redraw()
func _draw() -> void:
	if v==null: return
	var font=ThemeDB.fallback_font
	draw_style_box(_box(),Rect2(18,88,198,54))
	draw_string(font,Vector2(30,108),"HP  %d / 100" % int(v.combat.player_health),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("e5f3e9"))
	draw_rect(Rect2(30,119,170,9),Color("3b4b52")); draw_rect(Rect2(30,119,170*v.combat.player_health/100,9),Color("91d9b2"))
	if v.combat.hurt_flash>0: draw_rect(Rect2(Vector2.ZERO,size),Color(0.8,0.12,0.12,v.combat.hurt_flash*0.45))
	if target.has("entity"):
		var e=target.entity; var x=size.x*0.5-105
		var rage=float(v.combat.records.get(e.key,{}).get("anger",0))
		draw_style_box(_box(),Rect2(x,60,210,57))
		draw_rect(Rect2(x+12,78,185,10),Color("424e50")); draw_rect(Rect2(x+12,78,185*float(e.row.get("health",1)),10),Color("9ddbac"))
		draw_rect(Rect2(x+12,98,185,6),Color("424e50")); draw_rect(Rect2(x+12,98,185*rage/100,6),Color("ef9862"))
func _box() -> StyleBoxFlat:
	var s=StyleBoxFlat.new(); s.bg_color=Color(0.04,0.1,0.13,0.85); s.set_corner_radius_all(8); return s
