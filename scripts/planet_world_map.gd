extends Control
## v0.33.1 世界地图: the whole 16 km Earth from above. Biomes come from the climate grid; on top are
## the river, landmarks, the player's waypoints (tap one to travel there), their buildings, the
## walked trail and where they stand now. Drag to pan, wheel or buttons to zoom.
signal travel_requested(id: String)
signal closed
const UI=preload("res://scripts/ui.gd")
const BIOME_COLORS={"tundra":Color("e4ecee"),"desert":Color("d8c48e"),"wetland":Color("4f8a74"),"forest":Color("3f7a45"),"grassland":Color("86a865")}
const SCALES=[0.042,0.25,1.0,4.0]
var state
var view
## The map itself is a clipping child, so lines and labels never spill over the frame.
var canvas: Control
var map_rect=Rect2(0,0,1120,700)
var labels: Array=[]
var center=Vector2.ZERO
var scale_px=0.25
var texture: ImageTexture
var dragging=false
var drag_moved=0.0
var info: Label
var font: Font

func setup(game_state,planet_view) -> void:
	state=game_state; view=planet_view
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP; texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	var title=UI.label("世界地图 · 约16公里",26,UI.GOLD); title.position=Vector2(40,40); add_child(title)
	info=UI.label("",14,UI.MUTED); info.position=Vector2(40,80); info.size=Vector2(1120,30); add_child(info)
	canvas=Control.new(); canvas.position=Vector2(40,120); canvas.size=map_rect.size; canvas.clip_contents=true
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; canvas.mouse_filter=Control.MOUSE_FILTER_STOP; add_child(canvas)
	canvas.draw.connect(_draw_map); canvas.gui_input.connect(_map_input)
	var side=UI.column(self,8); side.position=Vector2(1190,120); side.custom_minimum_size=Vector2(210,0)
	for row in [["全图",0],["区域 · 4公里",1],["附近 · 1公里",2],["近处 · 250米",3]]:
		var b=UI.button(row[0],_zoom_to.bind(SCALES[row[1]])); side.add_child(b)
	side.add_child(UI.button("回到我的位置",func(): center=view.observer(); _refresh()))
	side.add_child(UI.button("回到家园",func(): center=Vector2.ZERO; _refresh()))
	UI.spacer(side,10)
	side.add_child(UI.paragraph("● 金色：我的路标，点一下前往\n■ 橙色：我搭的建筑\n┅ 金色虚线：走过的路线\n▲ 青色：我现在的位置\n○ 白色：地标",13))
	UI.spacer(side,10)
	side.add_child(UI.button("关闭地图",func(): closed.emit(); queue_free(),true))
	center=view.observer(); scale_px=SCALES[1]
	_refresh()
	texture=_biome_texture()
	_describe()

func _refresh() -> void:
	queue_redraw()
	if canvas!=null: canvas.queue_redraw()

func _zoom_to(s: float) -> void:
	scale_px=s
	if s<=SCALES[0]: center=Vector2.ZERO
	_refresh()

func _describe() -> void:
	var v=state.planet.v2; var at: Vector2=view.observer()
	info.text="我在 %.0f, %.0f 米 · %s · 路标 %d 个 · 路线记录 %d 段点 · 建筑 %d 块" % [at.x,at.y,v.environment.biome_name(v.environment.biome_at(at)),v.journey.points.size(),v.journey.trail.size(),v.construction.blocks.size()]

## One pixel per climate cell, smoothed, hill-shaded from the relief and masked to the land disc.
func _biome_texture() -> ImageTexture:
	var env=state.planet.v2.environment; var image=Image.create(env.size,env.size,false,Image.FORMAT_RGB8)
	for j in range(env.size):
		for i in range(env.size):
			var c=Vector2i(i,j); var v: Vector4=env.values(c)
			var color: Color=BIOME_COLORS[env.biome_of(v)].lerp(env.tint(v,Color("86a865")),0.35)
			image.set_pixel(i,j,color)
	# Smooth the 256 m cells, then paint the sea outside the 8 km disc.
	var k=4; image.resize(env.size*k,env.size*k,Image.INTERPOLATE_CUBIC)
	var radius=float(view.terrain.rules.radius); var px=radius*2.0/(env.size*k)
	# v0.33.2: hill shading from the real relief, lit from the north-west.
	var t=view.terrain
	for j in range(env.size*k):
		for i in range(env.size*k):
			var p=Vector2(-radius+(i+0.5)*px,-radius+(j+0.5)*px)
			if p.length()>radius: image.set_pixel(i,j,Color("1d4a63")); continue
			var h=t.relief(p); var slope=(h-t.relief(p-Vector2(px,px)*0.5))/px*6.0
			var c: Color=image.get_pixel(i,j)
			image.set_pixel(i,j,(c.lightened(clampf(slope,0,0.35)) if slope>0 else c.darkened(clampf(-slope,0,0.35))).lerp(Color("eef1ec"),smoothstep(26.0,40.0,h)*0.6))
	return ImageTexture.create_from_image(image)

func to_screen(p: Vector2) -> Vector2:
	return map_rect.get_center()+(p-center)*scale_px

func to_world(s: Vector2) -> Vector2:
	return center+(s-map_rect.get_center())/scale_px

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.03,0.07,0.1,0.96))

func _draw_map() -> void:
	var v=state.planet.v2; var radius=float(view.terrain.rules.radius); labels=[]
	canvas.draw_rect(map_rect,Color("1d4a63"))
	# The land is a disc; texture covers its bounding square.
	var top_left=to_screen(Vector2(-radius,-radius)); var span=Vector2.ONE*radius*2*scale_px
	_clip_texture(Rect2(top_left,span))
	canvas.draw_arc(to_screen(Vector2.ZERO),radius*scale_px,0,TAU,96,Color("f4f1e0",0.6),2.0)
	# River: the bend at home and the long valley north and south.
	var river=PackedVector2Array()
	var step=maxf(4.0,8.0/scale_px)
	var z=-radius
	while z<=radius:
		var x=view.terrain.river_x(z)
		if Vector2(x,z).length()<radius: river.append(to_screen(Vector2(x,z)))
		z+=step
	for i in range(1,river.size()):
		if map_rect.has_point(river[i-1]) or map_rect.has_point(river[i]): canvas.draw_line(river[i-1],river[i],Color("5fb3cf"),maxf(2.0,3.0*scale_px),true)
	# Walked trail, one polyline per segment.
	var line=PackedVector2Array(); var last_segment=-1
	for row in v.journey.trail:
		if row[2]!=last_segment:
			if line.size()>1: _dashed(line)
			line=PackedVector2Array(); last_segment=row[2]
		line.append(to_screen(Vector2(row[0],row[1])))
	if line.size()>1: _dashed(line)
	# Buildings, clustered so thousands of blocks stay cheap to draw.
	var cells={}
	for b in v.construction.blocks.values(): cells[Vector2i(floori(b.x/6.0),floori(b.z/6.0))]=true
	for c in cells:
		var s=to_screen(Vector2(c)*6.0+Vector2(3,3))
		if map_rect.has_point(s): canvas.draw_rect(Rect2(s-Vector2(4,4),Vector2(8,8)),Color("f08a3c")); canvas.draw_rect(Rect2(s-Vector2(4,4),Vector2(8,8)),Color("3a2412"),false,1.0)
	for id in view.terrain.LANDMARKS:
		var mark: Dictionary=view.terrain.LANDMARKS[id]; var s=to_screen(mark.at)
		if not map_rect.has_point(s) or (id in ["home","homestead"] and scale_px<0.5 and id!="home"): continue
		canvas.draw_circle(s,5,Color("f4f1e0"),false,2.0); _text(s+Vector2(8,4),str(mark.name),13,Color("f4f1e0"))
	for id in v.journey.points:
		var row: Dictionary=v.journey.points[id]; var s=to_screen(Vector2(row.x,row.z))
		if not map_rect.has_point(s): continue
		canvas.draw_colored_polygon(PackedVector2Array([s+Vector2(0,-9),s+Vector2(7,0),s+Vector2(0,9),s+Vector2(-7,0)]),Color("f5d789"))
		_text(s+Vector2(10,5),str(row.name),14,Color("f5d789"))
	# Me.
	var me=to_screen(view.observer())
	if map_rect.has_point(me):
		var yaw: float=view.walker.yaw; var f=Vector2(-sin(yaw),-cos(yaw)); var r=Vector2(f.y,-f.x)
		canvas.draw_colored_polygon(PackedVector2Array([me+f*13,me-f*7+r*8,me-f*7-r*8]),Color("8ff0d0"))
	canvas.draw_rect(map_rect,Color("f4f1e0",0.4),false,2.0)
	var bar=100.0/scale_px
	_text(map_rect.position+Vector2(12,map_rect.size.y-12),"比例：100像素 ≈ %s" % ("%.1f公里" % (bar/1000.0) if bar>=1000 else "%.0f米" % bar),13,Color("f4f1e0"))

func _clip_texture(rect: Rect2) -> void:
	var shown=rect.intersection(map_rect)
	if shown.size.x<=0 or shown.size.y<=0: return
	var tex_size=Vector2(texture.get_size())
	var src=Rect2((shown.position-rect.position)/rect.size*tex_size,shown.size/rect.size*tex_size)
	canvas.draw_texture_rect_region(texture,shown,src)

func _dashed(points: PackedVector2Array) -> void:
	for i in range(1,points.size()):
		var a=points[i-1]; var b=points[i]
		if not map_rect.has_point(a) and not map_rect.has_point(b): continue
		canvas.draw_dashed_line(a,b,Color("f5d789"),2.0,6.0)

func _text(at: Vector2,text: String,font_size: int,color: Color) -> void:
	# Skip a label that would sit on top of one already drawn.
	for r in labels:
		if r.intersects(Rect2(at-Vector2(0,font_size),Vector2(font_size*text.length()*0.9,font_size+2))): return
	labels.append(Rect2(at-Vector2(0,font_size),Vector2(font_size*text.length()*0.9,font_size+2)))
	canvas.draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color(0,0,0,0.7))
	canvas.draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP and event.pressed: _zoom_at(event.position,1.25)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN and event.pressed: _zoom_at(event.position,0.8)
		elif event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and map_rect.has_point(event.position): dragging=true; drag_moved=0.0
			elif not event.pressed and dragging:
				dragging=false
				if drag_moved<8.0: _tap(event.position)
	elif event is InputEventMouseMotion and dragging:
		center-=event.relative/scale_px; drag_moved+=event.relative.length(); _refresh()
	elif event is InputEventScreenDrag:
		center-=event.relative/scale_px; drag_moved+=event.relative.length(); _refresh()

func _zoom_at(at: Vector2,factor: float) -> void:
	if not map_rect.has_point(at): return
	var before=to_world(at)
	scale_px=clampf(scale_px*factor,SCALES[0],SCALES[-1])
	center+=before-to_world(at); _refresh()

func _tap(at: Vector2) -> void:
	var v=state.planet.v2
	for id in v.journey.points:
		var row: Dictionary=v.journey.points[id]
		if to_screen(Vector2(row.x,row.z)).distance_to(at)<16:
			travel_requested.emit(str(id)); closed.emit(); queue_free(); return
	var p=to_world(at)
	info.text="%.0f, %.0f 米 · %s" % [p.x,p.y,v.environment.biome_name(v.environment.biome_at(p)) if p.length()<float(view.terrain.rules.radius) else "海洋"]
