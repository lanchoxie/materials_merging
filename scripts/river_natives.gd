extends RefCounted
## v0.49 Settlers: the first native tribe, 溪石部落.
## v0.54 Bronze: tech diffusion — gifting/trading Cu-bearing items pushes the tribe into the
## Bronze era, boosting their gathering and triggering a tech-revolution news event.
## v0.54 Clash: an event director fires tribal raids. While the player is away the clash resolves
## abstractly (friendship and stock loss); when the player is present raiders appear as real
## entities and the player can fight or help.
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
## v0.54 Bronze/Clash state
var era="neolithic"        # "neolithic" | "bronze"
var copper_gifts=0         # Cu-bearing items/ore the player has given or traded
var raiders: Array=[]      # when the player is present: [{x,z,task,hp,id}]
var next_raid_day=-1       # day the next raid is scheduled
var first_person_active=false  # set by planet_v2 before tick() each step
var next_warn_day=-1       # day of the pre-raid warning note (one day before the raid)
var current_faction_id=""  # id of the faction currently raiding
var _last_faction_idx=-1   # alternates between eligible factions each raid cycle
var raid_cycle=0           # counts completed raid events (used for min_cycle gating)
var pending_demand: Dictionary={}  # v0.58: {faction_id, resource, amount, deadline_day, met_news, met_friendship}

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
	# v0.70: allow ±1 height variation so the tribe can settle on gently sloped ground.
	for dx in range(-6,7):
		for dz in range(-3,5):
			var q=p+Vector2(dx,dz)
			if absi(floori(terrain.natural_height(q))-h)>1 or terrain.water_at(q) or terrain.river_cell(q): return false
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
	era="neolithic"; copper_gifts=0; raiders=[]; next_raid_day=-1; next_warn_day=-1; current_faction_id=""
	_last_faction_idx=0; raid_cycle=0; pending_demand={}

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
	# v0.54 Bronze/Clash: era progression and raid events.
	_tick_bronze()
	# `first_person_active` is set by planet_v2 before calling tick, or we default to false.
	_tick_clash(v, bool(first_person_active))

func _new_day(now: int) -> void:
	var d=now/int(rules.day_seconds)
	if d==day: return
	if day>=0:
		# v0.54 Bronze: gather bonus for the Bronze era.
		var bonus: Dictionary=rules.get("bronze",{}).get("gather_bonus",{})
		for k in rules.gather_per_day:
			var base=int(rules.gather_per_day[k])
			var extra=int(bonus.get(k,0)) if era=="bronze" else 0
			stock[k]=mini(int(rules.caps[k]),int(stock.get(k,0))+base+extra)
		stock.food=maxi(0,int(stock.food)-members.size())
		friendship=move_toward(friendship,0.0,float(rules.friendship.daily_drift))
		# v0.54 Clash: schedule the first raid once huts are done, then every N days.
		if next_raid_day<0 and built.size()>=int(rules.max_blocks):
			var interval=int(rules.get("clash",{}).get("interval_days",25))
			next_raid_day=d+interval
			next_warn_day=next_raid_day-int(rules.get("clash",{}).get("warning_days",1))
		# v0.55 Clash II: one-day raid warning note.
		if next_warn_day>=0 and d==next_warn_day:
			var factions: Array=rules.get("clash",{}).get("factions",[])
			var next_idx=(_last_faction_idx+1)%maxi(1,factions.size())
			var fname=str(factions[next_idx].get("name","外族")) if not factions.is_empty() else "外族"
			_note("侦察者回报：%s的人马明天会来袭" % fname)
			next_warn_day=-1
		# v0.58: expire an unmet demand silently when its deadline passes.
		if not pending_demand.is_empty() and d>int(pending_demand.get("deadline_day",0)):
			pending_demand={}
	day=d; gifts=0; trades=0; pottery=0

## v0.54 Bronze: check whether the tribe should enter the Bronze era.
## This fires once and then stays — era never goes backwards.
func _tick_bronze() -> void:
	if era=="bronze": return
	var B: Dictionary=rules.get("bronze",{})
	if copper_gifts>=int(B.get("trigger_trades",6)):
		era="bronze"
		_note(str(B.get("news_event","部落进入了青铜时代")))
## v0.56 Diplomacy: pick the next eligible faction (min_cycle gate), cycling through the list.
func _pick_faction() -> Dictionary:
	var factions: Array=rules.get("clash",{}).get("factions",[])
	if factions.is_empty(): return rules.get("clash",{})
	# Build the list of factions unlocked for this raid_cycle.
	var eligible: Array=[]
	for f in factions:
		if raid_cycle>=int(f.get("min_cycle",0)): eligible.append(f)
	if eligible.is_empty(): eligible=factions  # fallback: use all if none qualify
	_last_faction_idx=(_last_faction_idx+1)%eligible.size()
	current_faction_id=str(eligible[_last_faction_idx].get("id",""))
	return eligible[_last_faction_idx]

func _supply_score() -> int:
	return int(stock.get("food",0))+int(stock.get("timber",0))+int(stock.get("stone",0))

func _tick_clash(v,present: bool) -> void:
	if next_raid_day<0 or day<next_raid_day: return
	var C: Dictionary=rules.get("clash",{})
	var interval=int(C.get("interval_days",25))
	next_raid_day=day+interval
	next_warn_day=next_raid_day-int(C.get("warning_days",1))
	var faction=_pick_faction()
	if not present:
		# Abstract resolution: supply score determines how badly they are hurt.
		var score=_supply_score()
		var sd: Dictionary=C.get("supply_defense",{})
		var mult=1.0
		if score>=int(sd.get("strong_threshold",30)):
			mult=float(sd.get("strong_loss_mult",0.5))
		elif score<int(sd.get("weak_threshold",10)):
			mult=float(sd.get("weak_loss_mult",1.5))
		for k in C.get("abstract_stock_loss",{}):
			var base=int(C.abstract_stock_loss[k])
			stock[k]=maxi(0,int(stock.get(k,0))-roundi(base*mult))
		friendship=clampf(friendship+float(C.get("abstract_friendship_cost",-0.2)),-1.0,1.0)
		_note(str(faction.get("abstract_news",str(C.get("abstract_news","夜里有外族人袭击了部落")))))
		raid_cycle+=1
		# v0.58: roll for a post-raid demand event (if no demand is already pending).
		if pending_demand.is_empty():
			var de: Dictionary=faction.get("demand_event",{})
			if not de.is_empty() and randf()<float(de.get("chance",0.5)):
				pending_demand={"faction_id":current_faction_id,"resource":str(de.resource),
					"amount":int(de.amount),"deadline_day":day+int(de.days),
					"met_news":str(de.met_news),"met_friendship":float(de.met_friendship)}
				_note(str(de.news))
	else:
		# Spawn raiders as visible entities near the village.
		raiders=[]
		var count=int(faction.get("raider_count",int(C.get("raider_count",3))))
		var hp=int(faction.get("raider_health",int(C.get("raider_health",2))))
		var rname=str(faction.get("raider_name",str(C.get("raider_name","外族战士"))))
		for i in range(count):
			var angle=float(i)*TAU/float(count)+0.4
			raiders.append({"id":"raider_%d" % i,"name":rname,"x":home.x+cos(angle)*20.0,"z":home.y+sin(angle)*20.0,"task":"进攻","hp":hp})
		_note(str(faction.get("raid_news","一队外族人向村子逼近！")))

## v0.55 Clash II: a raider is struck. When the last raider falls the raid ends, the player
## gets a faction-specific trophy if their backpack has room, and friendship rises.
func strike_raider(raider_id: String, field=null) -> String:
	var C: Dictionary=rules.get("clash",{})
	for r in raiders:
		if r.id!=raider_id: continue
		r.hp=int(r.hp)-1
		if int(r.hp)<=0:
			raiders.erase(r)
			if raiders.is_empty():
				_note(str(_current_faction().get("repel_news",C.get("repel_news","你帮助部落击退了外族人"))))
				friendship=clampf(friendship+float(C.get("repel_friendship",0.25)),-1.0,1.0)
				var msg=str(_current_faction().get("repel_news",C.get("repel_news","击退了外族人"))) + " · 友好度 %d%%" % roundi(friendship*100)
				msg+=_award_trophy(field)
				current_faction_id=""
				return msg
			return "%s倒下了，还有%d人" % [r.name,raiders.size()]
	return "没有找到这个目标"

func _current_faction() -> Dictionary:
	var factions: Array=rules.get("clash",{}).get("factions",[])
	for f in factions:
		if str(f.get("id",""))==current_faction_id: return f
	return {}

func _award_trophy(field) -> String:
	if field==null: return ""
	var f=_current_faction()
	var parts=""
	var trophy=str(f.get("trophy",""))
	if trophy!="" and randf()<=float(f.get("trophy_chance",1.0)) and field.can_add(trophy,1):
		field.stock[trophy]=int(field.stock.get(trophy,0))+1; field.revision+=1
		parts+=" · 获得战斧碎片 ×1"
	# v0.58: faction-specific rare trophy (骨牙护符 / 火焰羽毛 / 铁骨臂章).
	var rare=str(f.get("rare_trophy",""))
	if rare!="" and randf()<=float(f.get("rare_trophy_chance",0.0)) and field.can_add(rare,1):
		var rname=str(field.rules.resources.get(rare,{}).get("name",rare))
		field.stock[rare]=int(field.stock.get(rare,0))+1; field.revision+=1
		parts+=" · 稀有战利品 %s ×1" % rname
	return parts

## v0.56 Diplomacy: pay tribute to end the current real raid and delay the next one.
## Only works while raiders are actually on the field. Returns a message for the player.
func negotiate_tribute(field) -> String:
	if raiders.is_empty(): return "现在没有正在进攻的外族人"
	var f=_current_faction()
	if f.is_empty(): return "现在没有正在进攻的外族人"
	var cost: Dictionary=f.get("tribute_cost",{})
	if cost.is_empty(): return "这一支人马不愿意接受进贡"
	# Check the player's backpack has enough of every required resource.
	for k in cost:
		if int(field.stock.get(k,0))<int(cost[k]):
			var rname=str(field.rules.resources.get(k,{}).get("name",k))
			return "进贡需要 %s×%d，背包里不够" % [rname,int(cost[k])]
	for k in cost:
		field.stock[k]=int(field.stock[k])-int(cost[k])
	field.revision+=1
	raiders=[]; current_faction_id=""
	_note(str(f.get("tribute_news","你送上进贡，外族人退走了")))
	# Delay the next raid by half the interval (peace bought, not free).
	var C: Dictionary=rules.get("clash",{})
	var delay=roundi(int(C.get("interval_days",25))*0.5)
	if next_raid_day>=0: next_raid_day=next_raid_day+delay
	next_warn_day=next_raid_day-int(C.get("warning_days",1))
	raid_cycle+=1
	return "%s · 下次袭击推迟约%d天" % [str(f.get("tribute_news","外族人收下进贡后退走了")),delay]

## v0.58 Faction Events: fulfill an active demand event — pay the resource to gain friendship.
## Returns a message for the player. Clears the pending demand on success.
func fulfill_demand(field) -> String:
	if pending_demand.is_empty(): return "现在没有未满足的要求"
	var res=str(pending_demand.get("resource","food"))
	var amt=int(pending_demand.get("amount",4))
	if int(field.stock.get(res,0))<amt:
		var rname=str(field.rules.resources.get(res,{}).get("name",res))
		return "需要 %s×%d，背包里不够" % [rname,amt]
	field.stock[res]=int(field.stock[res])-amt; field.revision+=1
	friendship=clampf(friendship+float(pending_demand.get("met_friendship",0.15)),-1.0,1.0)
	_note(str(pending_demand.get("met_news","你满足了外族人的要求，友好度提升")))
	pending_demand={}
	return "成功满足要求 · 友好度 %d%%（%s）" % [roundi(friendship*100),mood()]

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
	# v0.54 Bronze: gifting malachite or copper-bearing ore pushes the tribe toward the Bronze era.
	if kind=="copper":
		var B: Dictionary=rules.get("bronze",{})
		for item_id in B.get("copper_items",["malachite"]):
			var has_field=int(field.stock.get(item_id,0))>0
			var has_minerals=field.has_method("minerals") and int(field.minerals.get(item_id,0))>0
			if has_field:
				field.stock[item_id]=int(field.stock[item_id])-1; field.revision+=1
				return _thank("孔雀石×1",true)
		return "背包里没有孔雀石（去地下 −8 米附近的铜矿层采挖）"
	if int(field.stock.get("timber",0))<int(G.timber_amount): return "需要%d份木料" % int(G.timber_amount)
	field.stock.timber=int(field.stock.timber)-int(G.timber_amount); field.revision+=1
	stock.timber=mini(int(rules.caps.timber),int(stock.timber)+int(G.timber_amount))
	return _thank("木料×%d" % int(G.timber_amount))

func _thank(what: String, copper: bool=false) -> String:
	gifts+=1; friendship=clampf(friendship+float(rules.friendship.gift),-1.0,1.0)
	_note("你送来%s" % what)
	# v0.54 Bronze: copper-bearing gifts push the tribe towards the Bronze era.
	if copper: copper_gifts+=1
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
	return {"version":5,"enabled":enabled,"home":[home.x,home.y] if home!=Vector2.INF else [],"members":members.duplicate(true),"stock":stock.duplicate(),
		"friendship":friendship,"built":built.keys(),"day":day,"gifts":gifts,"trades":trades,"pottery":pottery,"news":news.duplicate(),
		"era":era,"copper_gifts":copper_gifts,"next_raid_day":next_raid_day,"next_warn_day":next_warn_day,
		"current_faction_id":current_faction_id,"last_faction_idx":_last_faction_idx,"raid_cycle":raid_cycle,
		"pending_demand":pending_demand.duplicate(true),"raiders":raiders.duplicate(true)}

static func _num(v,lo: float,hi: float,whole: bool=false) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)>=lo and float(v)<=hi and (not whole or float(v)==floor(float(v)))

## Checks the tribe and that every native block in the construction store is one of its blueprint
## cells with the right kind (no forged native blocks).
func restore(data,c) -> bool:
	if not data is Dictionary or (int(data.get("version",0)) not in [1,2,3,4,5]) or not data.get("enabled") is bool: return false
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
	era=str(data.get("era","neolithic")); copper_gifts=int(data.get("copper_gifts",0)); next_raid_day=int(data.get("next_raid_day",-1))
	next_warn_day=int(data.get("next_warn_day",-1)); current_faction_id=str(data.get("current_faction_id",""))
	_last_faction_idx=int(data.get("last_faction_idx",-1)); raid_cycle=int(data.get("raid_cycle",0))
	raiders=[]; for r in data.get("raiders",[]): if r is Dictionary: raiders.append(r.duplicate())
	var pd=data.get("pending_demand",{}); pending_demand=pd.duplicate() if pd is Dictionary else {}
	return true
