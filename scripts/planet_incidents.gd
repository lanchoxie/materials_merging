extends RefCounted
## v0.36 incidents: storms, floods and droughts on Earth. A deterministic director rolls once per
## planet day (same save, same weather), announces each incident a day ahead, runs it for 1–3 days
## and then writes what happened to the 年鉴. Preparation (shelter, levees, irrigation) is measured
## from what the player actually built, and scales the damage down. Rules: data/planet_incidents.json.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_incidents.json"))
var pending: Dictionary={}   # {kind, at (elapsed when it starts), days}
var active: Dictionary={}    # {kind, until, prepared, crop_loss, health_loss, start}
var history: Array=[]        # [{kind, day, prepared, crop_loss, health_loss, text}]
var weathered=0              # incidents met with at least half preparation (pays 岛主 XP)
var pipes=0                  # PVC irrigation lines laid on the planet
var last_end=-1              # day index when the last incident ended
var last_roll=-1             # day index already rolled
var revision=0

func kind_info(kind: String) -> Dictionary:
	return rules.kinds.get(kind,{})

static func _hash01(a: int,b: int) -> float:
	var h: int=(a*73856093)^(b*19349663)^0x2545F491
	h=(h^(h>>13))*1274126177
	return float(posmod(h^(h>>16),100003))/100003.0

## Called every planet second (after the regions).
func step(v) -> void:
	var ds=float(v.rules.clock.day_seconds); var now=int(v.world.elapsed); var day=int(now/ds)
	if not active.is_empty():
		_hurt(v)
		if now>=int(active.until): _finish(v,day)
		return
	if not pending.is_empty():
		if now>=int(pending.at): _start(v)
		return
	if now%int(ds)!=0 or day==last_roll: return
	last_roll=day
	if day<int(rules.first_day) or (last_end>=0 and day-last_end<int(rules.cooldown_days)): return
	var kinds=v.settlement.incident_kinds().filter(func(k): return v.season() in kind_info(k).get("seasons",[]))
	if kinds.is_empty() or _hash01(day,17)>=v.settlement.incident_chance(): return
	var kind=str(kinds[int(_hash01(day,29)*kinds.size())%kinds.size()])
	warn(v,kind)

## Announce `kind` to start after the warning period (also used by the 测试版 panel).
func warn(v,kind: String,warning: float=-1.0) -> String:
	if not active.is_empty() or not pending.is_empty(): return "已经有一场天气事件"
	var info=kind_info(kind)
	if info.is_empty(): return "没有这种天气事件"
	var day=int(float(v.world.elapsed)/float(v.rules.clock.day_seconds))
	var span: Array=info.days; var days=int(span[0])+int(_hash01(day,43)*(int(span[1])-int(span[0])+1))
	pending={"kind":kind,"at":int(v.world.elapsed)+int(rules.warning_seconds if warning<0 else warning),"days":days}
	v._event(str(info.warn)); revision+=1
	return str(info.warn)

func _start(v) -> void:
	var kind=str(pending.kind); var info=kind_info(kind)
	active={"kind":kind,"until":int(pending.at)+int(pending.days)*int(v.rules.clock.day_seconds),"prepared":preparation(v,kind),"crop_loss":0.0,"health_loss":0.0,"start":int(pending.at)}
	pending={}; revision+=1
	v._event("%s（准备度 %d%%）" % [info.start,roundi(float(active.prepared)*100)])

func _finish(v,day: int) -> void:
	var kind=str(active.kind); var info=kind_info(kind); var p=float(active.prepared)
	var lines=[]
	if float(active.crop_loss)>0.001: lines.append("作物生长共损失 %d%%" % roundi(float(active.crop_loss)*100))
	if float(active.health_loss)>0.001: lines.append("居民健康共下降 %d%%" % roundi(float(active.health_loss)*100))
	if kind=="flood":
		# Real floodplains: receding water leaves fertile silt on the flooded land.
		for id in info.regions: v.world.regions[id].nutrients=minf(1.0,float(v.world.regions[id].nutrients)+float(info.silt))
		lines.append("退水后留下肥沃的淤泥：湿地与河岸养分 +%d%%" % roundi(float(info.silt)*100))
	var good=p>=0.5
	if good: weathered+=1
	var text="%s结束 · 准备度 %d%%%s · %s" % [info.name,roundi(p*100),"，稳住了" if good else "",("；".join(lines) if not lines.is_empty() else "没有损失")]
	history.push_front({"kind":kind,"day":day,"prepared":p,"crop_loss":float(active.crop_loss),"health_loss":float(active.health_loss),"text":text})
	if history.size()>int(rules.max_history): history.pop_back()
	active={}; last_end=day; revision+=1
	v._event(text)

## 0..1 from what the player actually built; never from a stored flag.
func preparation(v,kind: String) -> float:
	match kind:
		"storm": return clampf(float(v.construction.shelter_cells(v.settlement.center(),v.settlement.rules.radius))/float(rules.shelter_full),0,1)
		"flood": return clampf(float(levee_blocks(v))/float(rules.levee.full),0,1)
		"drought": return clampf(float(v.environment.machine_count("sprinkler")+pipes)/float(rules.irrigation_full),0,1)
	return 0.0

## Built blocks along the home stretch of the river, 3–9 m from the water line.
func levee_blocks(v) -> int:
	var t=v.construction.terrain; var L: Dictionary=rules.levee; var n=0
	for b in v.construction.blocks.values():
		var d=absf(float(b.x)-t.river_x(float(b.z)))
		if absf(float(b.z))<=float(L.span) and d>=float(L.near) and d<=float(L.far): n+=1
	return n

## Per-region weather for this second: extra rain, evaporation factor, crop loss.
func region_mods(id: String) -> Dictionary:
	var mods={"rain":0.0,"evaporation":1.0,"crop_loss":0.0,"flood":false}
	if active.is_empty(): return mods
	var info=kind_info(str(active.kind)); var harm=1.0-float(active.prepared)
	match str(active.kind):
		"storm":
			mods.rain=float(info.rain); mods.crop_loss=float(info.crop_loss)*harm
		"flood":
			if id in info.regions: mods.flood=true; mods.crop_loss=float(info.crop_loss)*harm
		"drought":
			mods.rain=-1.0; mods.evaporation=1.0+(float(info.evaporation)-1.0)*harm*(1.0-minf(1.0,float(pipes)*float(rules.pipe.cut)))
	return mods

func record_crop_loss(amount: float) -> void:
	if not active.is_empty(): active.crop_loss=float(active.crop_loss)+amount

func _hurt(v) -> void:
	if str(active.kind)!="storm": return
	var loss=float(kind_info("storm").health)*(1.0-float(active.prepared))
	if loss<=0.0 or v.settlement.people.is_empty(): return
	for p in v.settlement.people: p.health=clampf(float(p.health)-loss,0,1)
	active.health_loss=float(active.health_loss)+loss

## Visual weather for the view: {dark, rain, haze}, eased in during the warning hour.
func sky(v) -> Dictionary:
	if not active.is_empty(): return kind_info(str(active.kind)).sky
	if not pending.is_empty():
		var left=float(int(pending.at)-int(v.world.elapsed)); var k=clampf(1.0-left/float(rules.warning_seconds),0,1)*0.4
		var s: Dictionary=kind_info(str(pending.kind)).sky
		return {"dark":float(s.dark)*k,"rain":0.0,"haze":float(s.haze)*k}
	return {"dark":0.0,"rain":0.0,"haze":0.0}

func status_line(v) -> String:
	if not active.is_empty():
		var info=kind_info(str(active.kind)); var left=int(active.until)-int(v.world.elapsed)
		return "%s进行中 · 还剩%d秒 · 准备度 %d%%" % [info.name,left,roundi(float(active.prepared)*100)]
	if not pending.is_empty():
		var info=kind_info(str(pending.kind)); var left=int(pending.at)-int(v.world.elapsed)
		return "预警：%s · %d秒后到来 · 现在准备度 %d%%" % [info.name,left,roundi(preparation(v,str(pending.kind))*100)]
	return ""

func lay_pipe() -> String:
	if pipes>=int(rules.pipe.max): return "河湾已经铺满%d条灌溉管" % int(rules.pipe.max)
	pipes+=1; revision+=1
	return "铺设了一条 PVC 灌溉管（%d/%d）：干旱时蒸发减少 %d%%，也计入干旱准备度" % [pipes,int(rules.pipe.max),roundi(float(rules.pipe.cut)*100)]

func serialize() -> Dictionary:
	return {"version":1,"pending":pending.duplicate(),"active":active.duplicate(),"history":history.duplicate(true),"weathered":weathered,"pipes":pipes,"last_end":last_end,"last_roll":last_roll}

static func _num(x,lo: float,hi: float,whole: bool=false) -> bool:
	return (x is int or x is float) and is_finite(float(x)) and float(x)>=lo and float(x)<=hi and (not whole or float(x)==floor(float(x)))

func restore(data,elapsed: int) -> bool:
	if not data is Dictionary or data.get("version")!=1: return false
	for k in ["pending","active"]:
		if not data.get(k) is Dictionary: return false
	if not data.get("history") is Array or data.history.size()>int(rules.max_history): return false
	if not _num(data.get("weathered"),0,1e9,true) or not _num(data.get("pipes"),0,float(rules.pipe.max),true): return false
	if not _num(data.get("last_end"),-1,1e9,true) or not _num(data.get("last_roll"),-1,1e9,true): return false
	if not data.pending.is_empty() and (not rules.kinds.has(data.pending.get("kind")) or not _num(data.pending.get("at"),0,elapsed+float(rules.warning_seconds)+1,true) or not _num(data.pending.get("days"),1,9,true)): return false
	if not data.active.is_empty():
		var a=data.active
		if not rules.kinds.has(a.get("kind")) or not _num(a.get("until"),0,elapsed+9*86400,true) or not _num(a.get("start"),0,1e12,true): return false
		if not _num(a.get("prepared"),0,1) or not _num(a.get("crop_loss"),0,100) or not _num(a.get("health_loss"),0,100): return false
	if not data.pending.is_empty() and not data.active.is_empty(): return false
	for h in data.history:
		if not h is Dictionary or not rules.kinds.has(h.get("kind")) or not _num(h.get("day"),0,1e9,true) or not _num(h.get("prepared"),0,1): return false
		if not h.get("text") is String or h.text.length()>240 or not _num(h.get("crop_loss"),0,100) or not _num(h.get("health_loss"),0,100): return false
	pending=data.pending.duplicate(); active=data.active.duplicate(); history=data.history.duplicate(true)
	for k in ["at","days"]:
		if pending.has(k): pending[k]=int(pending[k])
	for k in ["until","start"]:
		if active.has(k): active[k]=int(active[k])
	weathered=int(data.weathered); pipes=int(data.pipes); last_end=int(data.last_end); last_roll=int(data.last_roll); revision+=1
	return true
