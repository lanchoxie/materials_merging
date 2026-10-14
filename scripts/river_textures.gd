extends RefCounted
## v0.50 (user: 矿物质最好有好看的纹理): a tiny procedural texture atlas for the planet's blocks.
## Every material gets its own 16×16 tile of greyscale detail — speckled granite, banded sandstone,
## flecked ore — which multiplies the per-cell vertex colour, so a vein finally reads as rock rather
## than a flat block of paint. Tile 0 stays pure white, so every other mesh in the game (buildings,
## trees, animals, the player's own blocks) keeps sampling white at UV (0,0) and looks exactly as it
## did. Built once, in code: no art files, no import step, no load hitch.
const SIZE=16
const COLS=8
const ROWS=8
static var _texture: ImageTexture
static var _slots: Dictionary={}

## Tile index per material id (0 = plain white, so unknown ids are safe).
static func slots() -> Dictionary:
	if _slots.is_empty():
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/minerals.json"))
		var n=1
		for id in data.materials:
			if n>=COLS*ROWS: break
			_slots[id]=n; n+=1
	return _slots

static func atlas() -> ImageTexture:
	if _texture!=null: return _texture
	var img=Image.create(COLS*SIZE,ROWS*SIZE,false,Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/minerals.json"))
	var table=slots()
	for id in table:
		var spec: Dictionary=data.materials.get(id,{})
		_paint(img,int(table[id]),str(spec.get("kind","mixture")),id)
	_texture=ImageTexture.create_from_image(img)
	return _texture

## The UV of a material's tile's top-left corner (faces span exactly one tile).
static func uv(id: String) -> Vector2:
	var slot=int(slots().get(id,0))
	return Vector2(float(slot%COLS)/float(COLS),float(slot/COLS)/float(ROWS))

static func span() -> Vector2:
	return Vector2(1.0/float(COLS),1.0/float(ROWS))

## Grey speckle, banding or flecks around white: albedo = vertex colour × this.
static func _paint(img: Image,slot: int,kind: String,seed_key: String) -> void:
	var rng=RandomNumberGenerator.new(); rng.seed=hash(seed_key)
	var ox=(slot%COLS)*SIZE; var oy=(slot/COLS)*SIZE
	var put=func(x: int,y: int,v: float) -> void:
		if x<0 or y<0 or x>=SIZE or y>=SIZE: return
		var g=clampf(v,0.55,1.45)
		img.set_pixel(ox+x,oy+y,Color(g,g,g,1.0))
	match kind:
		"rock":
			# Coarse mineral grains with a few darker cracks: granite, limestone, basalt, coal.
			for i in range(34):
				var w=2+rng.randi_range(0,2); var h=2+rng.randi_range(0,1)
				var tone=1.0+rng.randf_range(-0.22,0.22)
				for x in range(w):
					for y in range(h): put.call(rng.randi_range(0,SIZE-1)+x,rng.randi_range(0,SIZE-1)+y,tone)
			for i in range(2):
				var px=rng.randi_range(2,SIZE-4)
				for y in range(SIZE): put.call(px+int(sin(float(y)*0.7)*1.2),y,0.78)
		"mineral":
			# Elongated crystals: bright flecks with a dark edge, so ore sparkles.
			for i in range(11):
				var px=rng.randi_range(1,SIZE-3); var py=rng.randi_range(1,SIZE-5); var len=rng.randi_range(3,6)
				var dx=1 if rng.randf()<0.5 else -1
				for k in range(len):
					put.call(px+dx*k*0.5,py+k,1.0+rng.randf_range(0.06,0.30))
					put.call(px+dx*k*0.5+1,py+k,0.80)
		_:
			# Soft blotches for soil, clay, sand and other mixtures.
			for i in range(22):
				var tone=1.0+rng.randf_range(-0.14,0.14); var r=rng.randi_range(1,3)
				var cx=rng.randi_range(0,SIZE-1); var cy=rng.randi_range(0,SIZE-1)
				for x in range(-r,r+1):
					for y in range(-r,r+1):
						if x*x+y*y<=r*r: put.call(cx+x,cy+y,tone)
