extends Control
## v0.33.1 世界地图, v0.42 the whole wrap-around planet: east–west repeats, north–south runs from
## cap to cap, with a latitude/longitude grid. On top are the river, home, the player's waypoints (tap one to travel there), their buildings, the
## walked trail and where they stand now. Drag to pan, wheel or buttons to zoom.
signal travel_requested(id: String)
signal closed
const UI=preload("res://scripts/ui.gd")
const Globe=preload("res://scripts/planet_globe.gd")
const Shape=preload("res://scripts/planet_shape.gd")
const SCALES=[0.046,0.25,1.0,4.0]
var state
var view
## The map itself is a clipping child, so lines and labels never spill over the frame.
var canvas: Control
var map_rect=Rect2(0,0,1120,700)
var labels: Array=[]
var center=Vector2.ZERO
var scale_px=0.25
var texture: ImageTexture
var detail: ImageTexture
var detail_rect=Rect2()
var dragging=false
var drag_moved=0.0
var info: Label
var font: Font

func setup(game_state,planet_view) -> void:
	state=game_state; view=planet_view
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter=Control.MOUSE_FILTER_STOP; texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	font=preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	var title=UI.label("世界地图 · 蓝色星球 · 环绕一圈约16公里",26,UI.GOLD); title.position=Vector2(40,40); add_child(title)
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
	side.add_child(UI.paragraph("● 金色：我的路标，点一下前往\n■ 橙色：我搭的建筑\n┅ 金色虚线：走过的路线\n▲ 青色：我现在的位置\n○ 白色：起始河湾\n细线：每30°经纬线，粗线为赤道\n左右边缘相连：一直向东会从西边回来",13))
	UI.spacer(side,10)
	side.add_child(UI.button("关闭地图",func(): closed.emit(); queue_free(),true))
	center=view.observer(); scale_px=SCALES[1]
	texture=_biome_texture()
	_refresh(); _refresh_detail()
	_describe()

func _refresh() -> void:
	center=Vector2(Shape.wrap_x(center.x),clampf(center.y,Shape.NORTH,Shape.SOUTH))
	queue_redraw()
	if canvas!=null: canvas.queue_redraw()

func _zoom_to(s: float) -> void:
	scale_px=s
	if s<=SCALES[0]: center=Vector2(0,(Shape.NORTH+Shape.SOUTH)*0.5)
	_refresh(); _refresh_detail()

func _describe() -> void:
	var v=state.planet.v2; var at: Vector2=view.observer()
	info.text="我在 %s · %s · 路标 %d 个 · 路线记录 %d 段点 · 建筑 %d 块" % [Shape.coordinates(at),v.environment.biome_name(v.environment.biome_at(at)),v.journey.points.size(),v.journey.trail.size(),v.construction.blocks.size()]

## v0.42: the whole planet from the globe painter (cached), plus a sharper patch around the view
## when zoomed in. Both come from the same colour function as the ground.
func _biome_texture() -> ImageTexture:
	return Globe.flat(state.planet.v2.environment)

func _refresh_detail() -> void:
	detail=null
	if scale_px<SCALES[1]: return
	var half=map_rect.size*0.5/scale_px*1.2
	var w=160; var h=100; var env=state.planet.v2.environment
	var image=Image.create(w,h,false,Image.FORMAT_RGB8)
	for j in range(h):
		for i in range(w):
			var p=center-half+Vector2((i+0.5)/w*half.x*2.0,(j+0.5)/h*half.y*2.0)
			image.set_pixel(i,j,Globe.color_at(env,Shape.wrap_x(p.x),clampf(p.y,Shape.NORTH,Shape.SOUTH)))
	detail=ImageTexture.create_from_image(image); detail_rect=Rect2(center-half,half*2.0)

## East–west distances wrap, so a point is drawn on whichever side of the view is nearer.
func to_screen(p: Vector2) -> Vector2:
	return map_rect.get_center()+Vector2(Shape.dx(center.x,p.x),p.y-center.y)*scale_px

func to_world(s: Vector2) -> Vector2:
	return center+(s-map_rect.get_center())/scale_px

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.03,0.07,0.1,0.96))

func _draw_map() -> void:
	var v=state.planet.v2; labels=[]
	canvas.draw_rect(map_rect,Color("0f2433"))
	# The planet strip, repeated east and west so the seam never shows.
	var base=map_rect.get_center()+Vector2(-Shape.HALF-center.x,Shape.NORTH-center.y)*scale_px
	var span=Vector2(Shape.CIRC,Shape.SOUTH-Shape.NORTH)*scale_px
	for k in [-1,0,1]: _clip_texture(texture,Rect2(base+Vector2(span.x*k,0),span))
	if detail!=null:
		var local=Rect2(map_rect.get_center()+(detail_rect.position-center)*scale_px,detail_rect.size*scale_px)
		_clip_texture(detail,local)
	# Latitude and longitude every 30°.
	for lat in [-60,-30,0,30,60]:
		var y=to_screen(Vector2(center.x,Shape.z_for_latitude(lat))).y
		if y>map_rect.position.y and y<map_rect.end.y:
			canvas.draw_line(Vector2(map_rect.position.x,y),Vector2(map_rect.end.x,y),Color("f4f1e0",0.45 if lat==0 else 0.18),2.0 if lat==0 else 1.0)
			_text(Vector2(map_rect.position.x+8,y-4),"赤道" if lat==0 else "%s%d°" % ["北纬" if lat>0 else "南纬",absi(lat)],12,Color("f4f1e0"))
	for lon in range(-180,180,30):
		var x=to_screen(Vector2(Shape.x_for_longitude(lon),center.y)).x
		if x>map_rect.position.x and x<map_rect.end.x: canvas.draw_line(Vector2(x,map_rect.position.y),Vector2(x,map_rect.end.y),Color("f4f1e0",0.18),1.0)
	# River: the bend at home and the valley north and south, wherever it crosses land.
	var step=maxf(4.0,8.0/scale_px)
	var top=to_world(map_rect.position).y; var bottom=to_world(map_rect.end).y
	var z=maxf(top,Shape.NORTH); var last=Vector2.INF
	while z<=minf(bottom,Shape.SOUTH):
		var x=view.terrain.river_x(z); var s=to_screen(Vector2(x,z))
		if Shape.continent(x,z,view.terrain.profile)>0.03:
			if last!=Vector2.INF and (map_rect.has_point(last) or map_rect.has_point(s)): canvas.draw_line(last,s,Color("5fb3cf"),maxf(2.0,3.0*scale_px),true)
			last=s
		else: last=Vector2.INF
		z+=step
	# Walked trail, one polyline per segment.
	var line=PackedVector2Array(); var last_segment=-1
	for row in v.journey.trail:
		if row[2]!=last_segment:
			if line.size()>1: _dashed(line)
			line=PackedVector2Array(); last_segment=row[2]
		var s=to_screen(Vector2(row[0],row[1]))
		# A step across the wrapped edge starts a new piece instead of a line across the map.
		if line.size()>0 and absf(s.x-line[line.size()-1].x)>map_rect.size.x*0.5:
			if line.size()>1: _dashed(line)
			line=PackedVector2Array()
		line.append(s)
	if line.size()>1: _dashed(line)
	# Buildings, clustered so thousands of blocks stay cheap to draw.
	var cells={}
	for b in v.construction.blocks.values(): cells[Vector2i(floori(b.x/6.0),floori(b.z/6.0))]=true
	for c in cells:
		var s=to_screen(Vector2(c)*6.0+Vector2(3,3))
		if map_rect.has_point(s): canvas.draw_rect(Rect2(s-Vector2(4,4),Vector2(8,8)),Color("f08a3c")); canvas.draw_rect(Rect2(s-Vector2(4,4),Vector2(8,8)),Color("3a2412"),false,1.0)
	for id in view.terrain.LANDMARKS:
		var mark: Dictionary=view.terrain.LANDMARKS[id]; var s=to_screen(mark.at)
		if not map_rect.has_point(s) or id!="home": continue
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

func _clip_texture(tex: Texture2D,rect: Rect2) -> void:
	var shown=rect.intersection(map_rect)
	if shown.size.x<=0 or shown.size.y<=0: return
	var tex_size=Vector2(tex.get_size())
	var src=Rect2((shown.position-rect.position)/rect.size*tex_size,shown.size/rect.size*tex_size)
	canvas.draw_texture_rect_region(tex,shown,src)

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
				else: _refresh_detail(); _refresh()
	elif event is InputEventMouseMotion and dragging:
		center-=event.relative/scale_px; drag_moved+=event.relative.length(); _refresh()
	elif event is InputEventScreenDrag:
		center-=event.relative/scale_px; drag_moved+=event.relative.length(); _refresh()

func _zoom_at(at: Vector2,factor: float) -> void:
	if not map_rect.has_point(at): return
	var before=to_world(at)
	scale_px=clampf(scale_px*factor,SCALES[0],SCALES[-1])
	center+=before-to_world(at); _refresh(); _refresh_detail()

func _tap(at: Vector2) -> void:
	var v=state.planet.v2
	for id in v.journey.points:
		var row: Dictionary=v.journey.points[id]
		if to_screen(Vector2(row.x,row.z)).distance_to(at)<16:
			travel_requested.emit(str(id)); closed.emit(); queue_free(); return
	var p=to_world(at)
	p.x=Shape.wrap_x(p.x)
	info.text="%s · %s" % [Shape.coordinates(p),v.environment.biome_name(v.environment.biome_at(p)) if Shape.on_surface(p) else "极地冰盖"]
