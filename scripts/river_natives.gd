extends RefCounted
## v0.49 Settlers (notes/06-planets.md L4 "Living natives"): the first native tribe, 溪石部落.
## They settle a flat spot a few hundred metres from home and build two huts block by block with
## the same block kit as the player (wood walls, fibre roofs, a stone campfire). Their blocks live in
## the construction store with the source "native:tribe" (so collision, shelter, rendering and the
## campfire's warmth all just work) but have their own cap and ledger: every one must be a cell of
## the tribe's blueprint. A block the player takes away is noticed, costs friendship and is rebuilt.
## Each game day they gather and eat; the player can talk, give gifts and trade with the chief.
const Shape=preload("res://scripts/planet_shape.gd")
const SOURCE="native:tribe"
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/river_natives.json"))
var enabled=false
var home=Vector2.INF
var members: Array=[]      # {id, name, role, title, x, z, task}
var stock: Dictionary={}
var friendship=0.0
var built: Dictionary={}   # block keys the tribe has built (missing ones were taken)
var job: Dictionary={}     # the builder's job: {cell, kind, left}
var day=-1
var gifts=0
var trades=0
var pottery=0
var news: Array=[]         # recent tribe news, newest last (≤ 8)
var _blueprint: Array=[]
var _plan_clock=0.0

static func is_native(b: Dictionary) -> bool:
	return str(b.get("source",""))==SOURCE

# --- Where they live --------------------------------------------------------------------------
## A deterministic flat spot on land: spiral out from search_start until a 15×9 m footprint is level.
## The spot never changes for a given planet, so it is found once and cached.
static var _home_cache: Dictionary={}
static func find_home(terrain) -> Vector2:
	var cache_key=str(terrain.profile.get("name","earth"))
	if _home_cache.has(cache_key): return _home_cache[cache_key]
	var spot=_search(terrain); _home_cache[cache_key]=spot
	return spot

static func _search(terrain) -> Vector2:
	var R: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/river_natives.json"))
	var start=Vector2(float(R.tribe.search_start[0]),float(R.tribe.search_start[1])); var step=float(R.tribe.search_step)
	for ring in range(int(R.tribe.search_rings)):
		var count=1 if ring==0 else ring*8
		for k in range(count):
			var p=(start+Vector2.from_angle(k*TAU/count)*ring*step).round()
			if _level(terrain,p): return p
	return start

static func _level(terrain,p: Vector2) -> bool:
	if not terrain.inside(p,40) or absf(p.x-terrain.river_x(p.y))<30.0: return false
	var h=floori(terrain.natural_height(p))
	if terrain.natural_height(p)<0.45: return false   # sea and shore are below 0.3
	# Corners first: most candidates fail there, before the full footprint scan.
	for q in [p+Vector2(-7,-4),p+Vector2(7,-4),p+Vector2(-7,5),p+Vector2(7,5)]:
		if floori(terrain.natural_height(q))!=h: return false
	for dx in range(-7,8):
		for dz in range(-4,6):
			var q=p+Vector2(dx,dz)
			if floori(terrain.natural_height(q))!=h or terrain.water_at(q) or terrain.river_cell(q) or terrain.blocked(q,[]): return false
	return true

## Every cell they mean to build, bottom-up: per hut a ring of walls with a doorway at the front,
## 9 roof cells, then a campfire in front. On half-metre ground (the floor sits 0.5 m up the first
## wall cell) the walls get a third course, a lintel over the doorway, so there is headroom inside.
func blueprint(c) -> Array:
	if not _blueprint.is_empty(): return _blueprint
	var base=c.base(Vector3i(roundi(home.x),0,roundi(home.y)))
	var tall=false
	for dx in range(-7,8):
		for dz in range(-4,6):
			if fposmod(c.terrain.natural_height(home+Vector2(dx,dz)),1.0)>0.25: tall=true
	var layers=3 if tall else 2
	for hut in rules.huts:
		var o=Vector2i(roundi(home.x)+int(hut[0]),roundi(home.y)+int(hut[1]))
		for layer in range(layers):
			for dz in [-1,0,1]:
				for dx in [-1,0,1]:
					if dx==0 and dz==0: continue
					if dx==0 and dz==1 and layer<2: continue   # the doorway (two cells high)
					_blueprint.append(_cell(c,o.x+dx,base+layer,o.y+dz,"block"))
		for dz in [-1,0,1]:
			for dx in [-1,0,1]: _blueprint.append(_cell(c,o.x+dx,base+layers,o.y+dz,"roof"))
		_blueprint.append(_cell(c,o.x,base,o.y+3,"campfire"))
	return _blueprint

func _cell(c,x: int,y: int,z: int,kind: String) -> Dictionary:
	return {"key":c.key(Vector3i(x,y,z)),"x":x,"y":y,"z":z,"kind":kind}

func setup(c) -> void:
	home=find_home(c.terrain); _blueprint=[]
	members=[]
	for m in rules.members:
		var a=float(int(m.id))*1.7
		members.append({"id":int(m.id),"name":str(m.name),"role":str(m.role),"title":str(m.title),"x":home.x+cos(a)*3.0,"z":home.y+2.0+sin(a)*1.5,"task":"安家"})
	stock={}
	for k in rules.start_stock: stock[k]=int(rules.start_stock[k])
	friendship=0.0; built={}; job={}; day=-1; gifts=0; trades=0; pottery=0; news=["%s来到河湾附近，准备在这里安家" % rules.tribe.name]

func _note(text: String) -> void:
	news.append(text)
	while news.size()>8: news.pop_front()

# --- Simulation (1 Hz from planet_v2._step) -----------------------------------------------------
func tick(v) -> void:
	if not enabled: return
	if home==Vector2.INF: setup(v.construction)
	var c=v.construction; var now=int(v.world.elapsed)
	_new_day(now)
	_check_removed(c)
	_build(v)
	_wander(now)

func _new_day(now: int) -> void:
	var d=now/int(rules.day_seconds)
	if d==day: return
	if day>=0:
		for k in rules.gather_per_day: stock[k]=mini(int(rules.caps[k]),int(stock.get(k,0))+int(rules.gather_per_day[k]))
		stock.food=maxi(0,int(stock.food)-members.size())
		friendship=move_toward(friendship,0.0,float(rules.friendship.daily_drift))
	day=d; gifts=0; trades=0; pottery=0

## A block they built is gone: someone took it. Friendship drops; it goes back on the build list.
func _check_removed(c) -> void:
	for key in built.keys():
		if c.blocks.has(key) and is_native(c.blocks[key]): continue
		built.erase(key)
		friendship=clampf(friendship+float(rules.friendship.removed_block),-1.0,1.0)
		_note("有人拆走了部落的构件，%s皱起了眉头——他们会补上" % members[0].name)

func missing(c) -> Array:
	var out=[]
	for cell in blueprint(c):
		var b: Dictionary=c.blocks.get(cell.key,{})
		if b.is_empty(): out.append(cell)
	return out

func _builder() -> Dictionary:
	for m in members:
		if m.role=="builder": return m
	return members[0]

func _afford(kind: String) -> bool:
	var cost: Dictionary=rules.costs[kind]
	for k in cost:
		if int(stock.get(k,0))<int(cost[k]): return false
	return true

## The builder walks to the next missing cell (bottom-up), works on it, and sets the block.
func _build(v) -> void:
	var c=v.construction; var b=_builder()
	if job.is_empty():
		_plan_clock+=1.0
		if _plan_clock<float(rules.plan_seconds): b.task="歇息"; return
		_plan_clock=0.0
		var native_count=0
		for x in c.blocks.values(): native_count+=1 if is_native(x) else 0
		if native_count>=int(rules.max_blocks): return
		for cell in missing(c):
			if not _afford(cell.kind): b.task="等材料"; continue
			job={"cell":cell,"left":float(rules.build_seconds)}; break
		if job.is_empty(): b.task="看护村子" if missing(c).is_empty() else b.task; return
	var cell: Dictionary=job.cell; var at=Vector2(float(cell.x),float(cell.z))+Vector2(0.0,1.6)
	var here=Vector2(float(b.x),float(b.z))
	if here.distance_to(at)>float(rules.reach):
		var step=(at-here).limit_length(float(rules.walk_speed)); b.x=float(b.x)+step.x; b.z=float(b.z)+step.y; b.task="搬运"+("木料" if cell.kind!="campfire" else "石块")
		return
	b.task="搭建"; job.left=float(job.left)-1.0
	if float(job.left)>0.0: return
	if c.blocks.has(cell.key): job={}; return
	var error=c.place_error(Vector3i(int(cell.x),int(cell.y),int(cell.z)),{"feet":Vector3(-99999,-999,-99999),"eye":Vector3(cell.x,cell.y,cell.z)},false,str(cell.kind))
	if not error.is_empty():
		_note("%s想在(%d,%d)搭%s，但%s" % [b.name,int(cell.x),int(cell.z),c.rules.kinds[cell.kind].name,error]); job={}; _plan_clock=-20.0; return
	var cost: Dictionary=rules.costs[cell.kind]
	for k in cost: stock[k]=int(stock[k])-int(cost[k])
	c.blocks[cell.key]={"x":int(cell.x),"y":int(cell.y),"z":int(cell.z),"kind":str(cell.kind),"source":SOURCE}; c.revision+=1
	built[cell.key]=true; job={}
	if missing(c).is_empty(): _note("%s的两座小屋都盖好了" % rules.tribe.name)

## Gatherers go out and come back; the chief keeps to the campfire. (Visual only.)
func _wander(now: int) -> void:
	for m in members:
		if m.role=="builder": continue
		var goal=home+Vector2(0,4.5)
		if m.role=="gatherer":
			var a=float(now)/40.0+float(int(m.id))*2.1
			goal=home+Vector2(cos(a)*14.0,sin(a)*10.0); m.task="采集"
		else: m.task="守着篝火"
		var here=Vector2(float(m.x),float(m.z)); var step=(goal-here).limit_length(float(rules.walk_speed)*0.7)
		m.x=float(m.x)+step.x; m.z=float(m.z)+step.y

# --- The player ---------------------------------------------------------------------------------
func chief() -> Dictionary:
	return members[0] if not members.is_empty() else {}

func mood() -> String:
	if friendship>=0.6: return "亲近"
	if friendship>=0.2: return "友好"
	if friendship>-0.2: return "观望"
	return "戒备"

func gift(field,kind: String) -> String:
	var G: Dictionary=rules.gift
	if gifts>=int(G.per_day): return "今天已经送过%d次礼，部落记着你的好意" % int(G.per_day)
	if kind=="food":
		for id in G.food:
			if int(field.stock.get(id,0))>=int(G.food_amount):
				field.stock[id]=int(field.stock[id])-int(G.food_amount); field.revision+=1
				stock.food=mini(int(rules.caps.food),int(stock.food)+int(G.food_amount)*2)
				return _thank("%s×%d" % [field.rules.resources[id].name,int(G.food_amount)])
		return "背包里没有可送的食物（谷穗、野果或烤肉各%d份）" % int(G.food_amount)
	if int(field.stock.get("timber",0))<int(G.timber_amount): return "需要%d份木料" % int(G.timber_amount)
	field.stock.timber=int(field.stock.timber)-int(G.timber_amount); field.revision+=1
	stock.timber=mini(int(rules.caps.timber),int(stock.timber)+int(G.timber_amount))
	return _thank("木料×%d" % int(G.timber_amount))

func _thank(what: String) -> String:
	gifts+=1; friendship=clampf(friendship+float(rules.friendship.gift),-1.0,1.0)
	_note("你送来%s" % what)
	var back=""
	if friendship>=float(rules.friendship.gift_back) and pottery<int(rules.pottery.per_day): back="pottery"
	return "%s收下了%s · 友好度 %d%%（%s）" % [chief().get("name","族长"),what,roundi(friendship*100),mood()]+("" if back=="" else " · 回赠一只部落陶罐")

## A gift back for good friends: one pottery per day (the caller puts it into the backpack).
func take_pottery(field) -> bool:
	if friendship<float(rules.friendship.gift_back) or pottery>=int(rules.pottery.per_day): return false
	if not field.can_add("pottery",1): return false
	field.stock.pottery=int(field.stock.get("pottery",0))+1; field.revision+=1; pottery+=1
	return true

func trade(field) -> String:
	var T: Dictionary=rules.trade
	if friendship<float(rules.friendship.trade_min): return "部落还在戒备，不愿意交易"
	if trades>=int(T.per_day): return "今天的猎物已经换完了，明天再来"
	for k in T.give:
		if int(field.stock.get(k,0))<int(T.give[k]): return "交易需要 木料×%d、纤维×%d" % [int(T.give.timber),int(T.give.fiber)]
	for k in T.get:
		if not field.can_add(k,int(T.get[k])): return "背包里放不下了"
	for k in T.give: field.stock[k]=int(field.stock[k])-int(T.give[k])
	for k in T.get: field.stock[k]=int(field.stock.get(k,0))+int(T.get[k])
	field.revision+=1; trades+=1
	stock.timber=mini(int(rules.caps.timber),int(stock.timber)+int(T.give.timber))
	_note("和你换了一次猎物")
	return "用木料和纤维换到了生肉×%d（篝火旁烤熟）" % int(T.get.meat)

func attacked(member: Dictionary) -> String:
	friendship=clampf(friendship+float(rules.friendship.attacked),-1.0,1.0)
	_note("有人对%s动手" % member.get("name","部落成员"))
	return "%s躲开了，部落的人都在看着你 · 友好度 %d%%（%s）" % [member.get("name","部落成员"),roundi(friendship*100),mood()]

# --- Save -----------------------------------------------------------------------------------------
func serialize() -> Dictionary:
	return {"version":1,"enabled":enabled,"home":[home.x,home.y] if home!=Vector2.INF else [],"members":members.duplicate(true),"stock":stock.duplicate(),
		"friendship":friendship,"built":built.keys(),"day":day,"gifts":gifts,"trades":trades,"pottery":pottery,"news":news.duplicate()}

static func _num(v,lo: float,hi: float,whole: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)>=lo and float(v)<=hi and (not whole or float(v)==floor(float(v)))

## Checks the tribe and that every native block in the construction store is one of its blueprint
## cells with the right kind (no forged native blocks).
func restore(data,c) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("enabled") is bool: return false
	var spot=data.get("home",[])
	if not spot is Array or (spot.size()!=0 and spot.size()!=2): return false
	var at=Vector2.INF
	if spot.size()==2:
		if not _num(spot[0],-8192,8192) or not _num(spot[1],-7600,7600): return false
		at=Vector2(float(spot[0]),float(spot[1]))
		if at!=find_home(c.terrain): return false
	if not data.get("members") is Array or data.members.size()>rules.members.size(): return false
	for m in data.members:
		if not m is Dictionary or not _num(m.get("id"),1,rules.members.size(),true) or not _num(m.get("x"),-8300,8300) or not _num(m.get("z"),-7700,7700) or not m.get("task") is String or str(m.task).length()>20: return false
	if not data.get("stock") is Dictionary: return false
	for k in rules.caps:
		if not _num(data.stock.get(k,0),0,int(rules.caps[k]),true): return false
	if not _num(data.get("friendship"),-1,1) or not data.get("built") is Array or data.built.size()>int(rules.max_blocks): return false
	for k in ["day","gifts","trades","pottery"]:
		if not _num(data.get(k),-1,1e9,true): return false
	if not data.get("news") is Array or data.news.size()>8: return false
	for line in data.news:
		if not line is String or line.length()>120: return false
	# Native blocks must be blueprint cells.
	var old_home=home; home=at; _blueprint=[]
	var cells={}
	if at!=Vector2.INF:
		for cell in blueprint(c): cells[cell.key]=cell.kind
	for key in c.blocks:
		var b: Dictionary=c.blocks[key]
		if is_native(b) and str(cells.get(key,""))!=str(b.kind): home=old_home; _blueprint=[]; return false
	enabled=data.enabled; members=[]
	for m in data.members:
		var spec: Dictionary=rules.members[int(m.id)-1]
		members.append({"id":int(m.id),"name":str(spec.name),"role":str(spec.role),"title":str(spec.title),"x":float(m.x),"z":float(m.z),"task":str(m.task)})
	stock={}
	for k in rules.caps: stock[k]=int(data.stock.get(k,0))
	friendship=float(data.friendship); built={}
	for key in data.built:
		if cells.has(str(key)): built[str(key)]=true
	day=int(data.day); gifts=int(data.gifts); trades=int(data.trades); pottery=int(data.pottery); news=data.news.duplicate(); job={}
	return true
