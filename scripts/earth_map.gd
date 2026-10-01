extends Control
## v0.32 地球环境图: the whole 16 km world from the climate field. Display only.
const UI=preload("res://scripts/ui.gd")
const Terrain=preload("res://scripts/river_terrain.gd")
const CHANNELS={"biome":"群系","water":"水分","temperature":"温度","nutrients":"营养","pollution":"污染"}
const MACHINE_COLORS={"sprinkler":"6fd3ff","oxygen_tower":"e8fbff","co2_tower":"ff9a5a","fertilizer_spreader":"ffd75a"}
var env
var locate: Callable
var channel="biome"
var texture: ImageTexture
var seen=-1
var shares={}
var map_rect=Rect2(16,52,500,500)
var stats: Label
var here: Label
var buttons={}
var clock=0.0

func setup(environment,position_source: Callable) -> void:
	env=environment; locate=position_source
	mouse_filter=Control.MOUSE_FILTER_STOP; texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var title=UI.label("地球环境图 · 约16公里",20,UI.MINT); title.position=Vector2(18,12); add_child(title)
	var bar=UI.row(self,6); bar.position=Vector2(530,52)
	for id in CHANNELS:
		var b=UI.button(CHANNELS[id],_pick.bind(id)); b.custom_minimum_size=Vector2(70,40); b.add_theme_font_size_override("font_size",14); bar.add_child(b); buttons[id]=b
	stats=UI.paragraph("",15,UI.TEXT); stats.position=Vector2(532,104); stats.size=Vector2(380,250); add_child(stats)
	here=UI.paragraph("",15,UI.GOLD); here.position=Vector2(532,372); here.size=Vector2(380,110); add_child(here)
	var close=UI.button("关闭地图",func(): hide()); close.position=Vector2(780,506); close.size=Vector2(130,48); add_child(close)
	_rebuild(); _locate()

func _pick(id: String) -> void:
	channel=id; seen=-1; _rebuild()

func _ramp(v: Vector4) -> Color:
	match channel:
		"water": return Color("c9a46a").lerp(Color("2f86c9"),v.x)
		"temperature":
			var t=clampf((v.y+15.0)/55.0,0,1)
			return Color("3d6fd6").lerp(Color("f2f2ee"),t*2) if t<0.5 else Color("f2f2ee").lerp(Color("d6443d"),t*2-1)
		"nutrients": return Color("bfae8c").lerp(Color("2f7a3c"),v.z)
		"pollution": return Color("86b06a").lerp(Color("7a4a8a"),clampf(v.w*3,0,1))
	return Color(str(env.rules.biomes[env.biome_of(v)].color))

func _rebuild() -> void:
	if env==null: return
	seen=int(env.revision)
	var image=Image.create(env.size,env.size,false,Image.FORMAT_RGBA8); shares={}
	var radius=-env.origin
	for j in range(env.size):
		for i in range(env.size):
			var c=Vector2i(i,j)
			if env.cell_center(c).length()>radius: image.set_pixel(i,j,Color(0,0,0,0)); continue
			var v: Vector4=env.values(c); var b=env.biome_of(v)
			shares[b]=int(shares.get(b,0))+1
			image.set_pixel(i,j,_ramp(v))
	texture=ImageTexture.create_from_image(image)
	for id in buttons: buttons[id].modulate=UI.MINT if id==channel else Color.WHITE
	_text(); queue_redraw()

func _text() -> void:
	var total=0
	for b in shares: total+=int(shares[b])
	var rows=[env.atmosphere_text()]
	var parts=[]
	for b in env.rules.biomes:
		parts.append("%s %d%%" % [env.biome_name(b),roundi(100.0*int(shares.get(b,0))/maxf(1,total))])
	rows.append(" · ".join(parts))
	rows.append("")
	for kind in env.rules.emitters:
		var spec: Dictionary=env.rules.emitters[kind]
		rows.append("%s ×%d · %s" % [spec.name,env.machine_count(kind),spec.summary])
	stats.text="\n".join(rows)

func _process(dt: float) -> void:
	if not visible or env==null: return
	clock+=dt
	if clock<0.25: return
	clock=0.0
	if int(env.revision)!=seen: _rebuild()
	else: _text()
	_locate(); queue_redraw()

func _locate() -> void:
	var at: Vector2=locate.call() if locate.is_valid() else Vector2.ZERO
	var v: Vector4=env.values(env.cell_of(at))
	here.text="你在：%s · %.0f, %.0f米\n水分 %.0f%% · %.1f°C · 营养 %.0f%% · 污染 %.0f%%" % [env.biome_name(env.biome_of(v)),at.x,at.y,v.x*100,v.y,v.z*100,v.w*100]

func _to_map(p: Vector2) -> Vector2:
	return map_rect.position+(p-Vector2(env.origin,env.origin))/(env.cell*env.size)*map_rect.size

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.04,0.08,0.11,0.94))
	draw_rect(Rect2(Vector2.ZERO,size),Color("7ee0c9"),false,2)
	if texture==null: return
	draw_circle(map_rect.get_center(),map_rect.size.x*0.5+3,Color("17323d"))
	draw_texture_rect(texture,map_rect,false)
	var font=get_theme_default_font()
	draw_string(font,map_rect.position+Vector2(map_rect.size.x*0.5-8,18),"北",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f2f2ee"))
	for id in Terrain.LANDMARKS:
		var spot: Vector2=Terrain.LANDMARKS[id].at
		if spot.length()<400: continue
		var m=_to_map(spot); draw_circle(m,3,Color("f5d789"))
		draw_string(font,m+Vector2(6,4),str(Terrain.LANDMARKS[id].name),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f5d789"))
	draw_circle(_to_map(Vector2.ZERO),4,Color("f5d789"))
	draw_string(font,_to_map(Vector2.ZERO)+Vector2(6,4),"河湾",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f5d789"))
	var machines: Dictionary=env.machines()
	for c in machines:
		var m=_to_map(env.cell_center(c)); var k=0
		for kind in machines[c]:
			draw_rect(Rect2(m+Vector2(-4+k*5,-4),Vector2(7,7)),Color(MACHINE_COLORS.get(kind,"ffffff"))); k+=1
	var at: Vector2=locate.call() if locate.is_valid() else Vector2.ZERO
	var me=_to_map(at)
	draw_circle(me,7,Color("ffffff")); draw_circle(me,4,Color("e2524b"))
	var y=map_rect.end.y-8
	if channel=="biome":
		var x=530.0
		for b in env.rules.biomes:
			draw_rect(Rect2(Vector2(x,y-12),Vector2(14,14)),Color(str(env.rules.biomes[b].color)))
			draw_string(font,Vector2(x+18,y),env.biome_name(b),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("dfe9e6")); x+=48
