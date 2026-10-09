extends RefCounted
## v0.33.1 测试版: shortcuts for trying features quickly. Only reachable when the export has the
## `testbuild` feature (the Android test preset) or the game runs with `--test-mode` on desktop.
## A test session always reads and writes its own save file, never the player's save.json.
## Every grant respects the same caps the save validator checks, so a test save stays loadable.
const Geology=preload("res://scripts/planet_geology.gd")
const SAVE_NAME="save_test.json"
const ELEMENT_CAP=9999
const MATERIAL_CAP=1000000
const BIOMES=["grassland","forest","wetland","desert","tundra"]

static func enabled() -> bool:
	return OS.has_feature("testbuild") or "--test-mode" in OS.get_cmdline_user_args()

static func grant_coins(s,amount: int) -> String:
	s.coins=minf(100000000.0,float(s.coins)+amount)
	return "测试：金币 +%d" % amount

static func grant_materials(s,amount: int) -> String:
	for i in range(3): s.materials[i]=mini(MATERIAL_CAP,int(s.materials[i])+amount)
	return "测试：星砂、晶露、合金片各 +%d" % amount

static func grant_elements(s,amount: int) -> String:
	for symbol in s.elements: s.element_inventory[symbol]=mini(ELEMENT_CAP,int(s.element_inventory.get(symbol,0))+amount)
	return "测试：全部%d种元素各 +%d（上限%d）" % [s.elements.size(),amount,ELEMENT_CAP]

static func grant_minerals(s,amount: int) -> String:
	var nature=s.planet.v2.nature; var cap=int(nature.rules.max_mineral_stock); var count=0
	for id in Geology.rules().materials:
		if id in ["topsoil","bedrock"]: continue
		nature.minerals[id]=mini(cap,int(nature.minerals.get(id,0))+amount); count+=1
	return "测试：%d种矿物各 +%d（上限%d）" % [count,amount,cap]

static func grant_planet_stock(s,amount: int) -> String:
	var v=s.planet.v2; var cap=int(v.field.rules.max_stock)
	for id in v.field.stock: v.field.stock[id]=mini(cap,int(v.field.stock[id])+amount)
	v.world.seeds=int(v.world.seeds)+amount; v.world.food=int(v.world.food)+amount
	return "测试：星球原料、种子、口粮各 +%d" % amount

## Buy the next `count` frontier plots, paying their real cost from granted building pieces.
static func unlock_plots(s,count: int) -> String:
	var opened=0
	for n in range(count):
		var bought=false
		for i in range(s.plots.size()):
			if s.plots[i].unlocked or not s.can_expand(i): continue
			grant_materials(s,int(s.plot_cost(i)))
			s.buy_plot(i)
			if s.plots[i].unlocked: opened+=1; bought=true; break
		if not bought: break
	return "测试：开拓了%d块地（共%d块）" % [opened,s.unlocked_plot_count()]

static func max_refinery(s) -> String:
	var r=s.refinery; var steps=0
	while r.upgrade_cost()>=0 and steps<20:
		grant_coins(s,r.upgrade_cost()); r.upgrade(s); steps+=1
	return "测试：精炼厂升到 Lv%d" % r.level

## v0.34: open 星锻岛 without its unlock conditions, with credits and XP to try every factory.
static func open_starforge(s,credits: int) -> String:
	var ind=s.industry
	if not ind.unlocked: ind.unlocked=true; ind.plots=int(ind.rules().plots.start)
	ind.credits=mini(ind.credits+credits,int(ind.rules().credits.max)); ind.gain(500)
	return "测试：星锻岛已开放 · 工业信用 +%d · 岛主经验 +500" % credits

## v0.37: Si/Ca/P elements, the new ores from the planet, and the compounds that unlock the kiln
## and foundry recipes (CaO, SiHCl₃, Si, H₃PO₄), so every v0.37 recipe can be tried at once.
static func silicon_kit(s) -> String:
	for el in ["Si","Ca","P","Na","H","Cl","S","O"]: s.element_inventory[el]=int(s.element_inventory.get(el,0))+30
	var m: Dictionary=s.planet.v2.nature.minerals
	for id in ["sand","limestone","clay","apatite"]: m[id]=int(m.get(id,0))+30
	var Industry=preload("res://scripts/industry.gd")
	for f in ["CaO","Cl3HSi","Si","H3O4P"]:
		var keys: Array=Industry._keys_for(f)
		if not keys.is_empty(): s.index_found[keys[0]]=true
	return "测试：硅钙磷原料包 · 元素各 +30，石英砂/石灰岩/黏土/磷灰石各 +30，CaO、SiHCl₃、Si、H₃PO₄ 已记入索引"

## v0.38: everything the chip fab and packaging plant need, plus the phenol and CsPbBr₃ gates.
static func chip_kit(s) -> String:
	for el in ["Cs","Pb","Br","Cl","Cu","F","Al","O","C","H","Sn"]: s.element_inventory[el]=int(s.element_inventory.get(el,0))+40
	var ind=s.industry
	for id in ["wafer","glass","duralumin","solder"]:
		ind.items[id]=mini(int(ind.items.get(id,0))+6,9999); ind._reconcile(id)
	var Industry=preload("res://scripts/industry.gd")
	for f in ["CsPbBr3","C6H6O"]:
		var keys: Array=Industry._keys_for(f)
		if not keys.is_empty(): s.index_found[keys[0]]=true
	return "测试：芯片原料包 · 元素各 +40，硅片/玻璃/硬铝/焊料各 +6，苯酚和 CsPbBr₃ 已记入索引"

## v0.35: every engineer and 博士生 reaches their service years (延毕 rolls still apply).
static func finish_service(s) -> String:
	var ind=s.industry; var n=0
	for p in s.campus.people:
		if ind._role(str(p.role)).is_empty(): continue
		var need=float(ind._role(str(p.role)).years)*ind.year_seconds()
		ind.service[str(int(p.id))]=maxf(float(ind.service.get(str(int(p.id)),0.0)),need-0.5); n+=1
	ind.service_init=true
	var notes=ind.serve(s,1.0)
	for p in s.campus.people:
		var key=str(int(p.id))
		if ind.service.has(key): ind.service[key]=maxf(float(ind.service[key]),ind.need_seconds(p))
	return "测试：%d人服务满年限%s" % [n,"（"+"；".join(notes)+"）" if not notes.is_empty() else ""]

## Island production and the refinery run as if the game had been closed for `seconds`.
static func skip_island(s,seconds: int) -> String:
	var now=int(Time.get_unix_time_from_system())
	s.saved_at=now-seconds
	var result: Dictionary=s.offline_catch_up(now)
	s.saved_at=now
	if result.is_empty(): return "测试：时间太短，未结算"
	return "测试：浮岛快进%d分钟，产出%d份、待收%d金币" % [seconds/60,int(result.units),int(result.coins)]

## The planet simulation steps for real (crops grow, animals breed, seasons change).
static func skip_planet(s,seconds: int) -> String:
	var v=s.planet.v2; var left=float(seconds)
	while left>0.0:
		var step=minf(left,60.0); v.advance(step); left-=step
	return "测试：星球快进%d天 · 现在%s" % [seconds/60,v.time_label()]

## Advance the settlement era even if its building requirements are not met yet.
static func force_era(s) -> String:
	var v=s.planet.v2; var settlement=v.settlement
	if settlement.era>=settlement.rules.eras.size()-1: return "测试：已是最后一个时代"
	var result=settlement.advance_era(v.world,v.construction,true)
	v._event(result)
	return "测试：" + result

## The cell centre of the nearest `biome` at least 1.5 km out (biomes start beyond the home area).
static func biome_spot(env,biome: String) -> Vector2:
	var best=Vector2.INF
	for j in range(env.size):
		for i in range(env.size):
			var p: Vector2=env.cell_center(Vector2i(i,j))
			if p.length()<1500 or p.length()>7600 or p.length()>=best.length(): continue
			if env.biome_of(env.values(Vector2i(i,j)))==biome: best=p
	return best
