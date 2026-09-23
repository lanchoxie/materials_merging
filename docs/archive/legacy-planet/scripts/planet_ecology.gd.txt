extends RefCounted
## Deterministic one-second teaching model. No island inventory, rendering or RNG.
const Thermal=preload("res://scripts/planet_thermal.gd")
var thermal=Thermal.new()
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_ecology.json"))

func fresh(at: int=0) -> Dictionary:
	var regions={}
	for id in ["microbe","fish"]:
		regions[id]={"oxygen":float(rules[id].initial_oxygen),"device":false,"enabled":true,"flow":1.0,"gas":0.0,"energy":0.0,"loaded":0.0,"used":0.0,"flags":[]}
	for r in regions.values(): thermal.initialize_region(r)
	regions.microbe.merge({"sensitive":float(rules.microbe.initial_sensitive),"tolerant":float(rules.microbe.initial_tolerant),"refuge":float(rules.microbe.initial_refuge),"sealed":true})
	regions.fish.merge({"bay":float(rules.fish.initial_bay),"outer":float(rules.fish.initial_outer),"dead":0.0,"stress":0,"gate_open":true})
	var result={"model":rules.model,"thermal_model":thermal.lab.data.thermal_game.model,"regions":regions,"history":[]}
	_record(result,at)
	return result

func can_deploy(eco: Dictionary,site: String,recipe: String) -> bool:
	if not eco.regions.has(site): return false
	var r=eco.regions[site]
	if thermal.lab.is_component(recipe): return r.device and r.component.get("recipe","")!=recipe and thermal.lab.fits(recipe,site)
	if recipe=="oxygen_station": return not r.device
	if recipe=="oxygen_cartridge": return r.device and r.gas<=0 and r.energy<=0
	return false

func deploy(eco: Dictionary,site: String,recipe: String,component: Dictionary={}) -> void:
	var r=eco.regions[site]
	if thermal.lab.is_component(recipe): r.component=component.duplicate(true)
	elif recipe=="oxygen_station": r.device=true
	elif recipe=="oxygen_cartridge":
		r.gas=float(rules.device.cartridge_units); r.energy=r.gas; r.loaded=float(r.loaded)+r.gas
		r.flags.erase("empty")

func control(eco: Dictionary,site: String,action: String) -> String:
	if not eco.regions.has(site): return "请选择生态区域"
	var r=eco.regions[site]; var name=str(rules[site].name)
	match action:
		"power":
			if not r.device: return "先放置供氧器"
			r.enabled=not r.enabled; return "%s · 供氧%s" % [name,"开启" if r.enabled else "关闭"]
		"flow":
			if not r.device: return "先放置供氧器"
			var i=rules.device.flows.find(float(r.flow)); r.flow=float(rules.device.flows[(i+1)%rules.device.flows.size()])
			return "%s · 流量调整为%s倍" % [name,str(r.flow)]
		"refuge":
			if site!="microbe": return "这个区域没有厌氧避难池"
			r.sealed=not r.sealed; return "厌氧避难池已%s" % ("隔离" if r.sealed else "接通主池")
		"gate":
			if site!="fish": return "这个区域没有外湾通道"
			r.gate_open=not r.gate_open; return "鱼湾与外湾的通道已%s" % ("开放" if r.gate_open else "关闭")
	return "未知生态操作"

func _once(r: Dictionary,flag: String,message: String,messages: Array) -> void:
	if flag not in r.flags: r.flags.append(flag); messages.append(message)

func step(eco: Dictionary,at: int) -> Array:
	var messages=[]
	for id in ["microbe","fish"]:
		var r=eco.regions[id]; var run=thermal.step(r); var dose=float(run.dose)
		if run.stopped: messages.append(str(rules[id].name)+"：热负载触发保护，暂缓供氧；冷却后自动恢复。")
		if run.resumed: messages.append(str(rules[id].name)+"：设备冷却完毕，恢复供氧。")
		if dose>0:
			r.gas-=dose; r.energy-=dose; r.used+=dose
			if r.gas<=0: _once(r,"empty",str(rules[id].name)+"：氧气与动力补给耗尽，供氧器停机。",messages)
		r.oxygen=clampf(float(r.oxygen)+dose*float(rules.device.transfer_per_unit)-float(rules[id].oxygen_sink),0,100)
	var m=eco.regions.microbe; var mr=rules.microbe
	var damage=maxf(0,float(m.oxygen)-float(mr.stress_above))*float(mr.damage_rate)
	if damage>0:
		m.sensitive=maxf(0,m.sensitive-damage)
		if not m.sealed: m.refuge=maxf(0,m.refuge-damage*float(mr.refuge_damage_ratio))
		m.tolerant=minf(100-m.sensitive,m.tolerant+float(mr.tolerant_growth))
		_once(m,"exposed","厌氧池：局部氧暴露增加，敏感菌毯开始退缩；耐受群体占据空位。",messages)
	else:
		m.tolerant=maxf(0,m.tolerant-float(mr.tolerant_decline))
		if m.sensitive>0 or (m.refuge>0 and not m.sealed):
			m.sensitive=minf(100-m.tolerant,m.sensitive+float(mr.recovery_rate))
			if "decline" in m.flags and m.sensitive>=float(mr.recovery_observation_above): _once(m,"recovered","厌氧池：氧暴露降低，幸存菌毯逐渐恢复；不是凭空复活。",messages)
	if m.sealed and m.refuge>0: m.refuge=minf(float(mr.refuge_capacity),m.refuge+float(mr.refuge_growth))
	if m.sensitive<float(mr.decline_observation_below): _once(m,"decline","厌氧池：敏感菌毯覆盖已明显缩小；隔离避难池可保留幸存群落。",messages)
	if m.sensitive==0 and m.refuge==0: _once(m,"extinct","厌氧池：主池与避难池的敏感群落均已消失，停止供氧也不会自动重生。",messages)
	var f=eco.regions.fish; var fr=rules.fish
	if f.gate_open and f.oxygen<float(fr.leave_below) and f.bay>0:
		var moving=minf(float(fr.leave_rate),f.bay); f.bay-=moving; f.outer+=moving
		_once(f,"leave","鱼湾：低氧驱使鱼群沿开放通道游向外湾；迁移不等于死亡。",messages)
	elif f.gate_open and f.oxygen>float(fr.return_above) and f.outer>0:
		var moving=minf(float(fr.return_rate),f.outer); f.outer-=moving; f.bay+=moving
		_once(f,"return","鱼湾：氧条件改善，外湾已有鱼群逐渐回游；食物与温盐条件在本实验中保持适宜。",messages)
	f.stress=mini(int(fr.stress_seconds),int(f.stress)+1) if f.oxygen<float(fr.lethal_below) and f.bay>0 else maxi(0,int(f.stress)-2)
	if int(f.stress)>=int(fr.stress_seconds):
		var loss=minf(float(fr.death_rate),f.bay); f.bay-=loss; f.dead+=loss
		_once(f,"mortality","鱼湾：持续低氧造成滞留鱼群损失；开放通道与及时供氧能降低后续损失。",messages)
	# Reconcile the closed cohort ledger instead of accumulating migration roundoff.
	var living=float(fr.initial_bay)+float(fr.initial_outer)-float(f.dead)
	f.bay=clampf(f.bay,0,living); f.outer=living-f.bay
	if at%int(rules.history.every_seconds)==0: _record(eco,at)
	return messages

func _record(eco: Dictionary,at: int) -> void:
	eco.history.append({"at":at,"regions":eco.regions.duplicate(true)})
	while eco.history.size()>int(rules.history.limit): eco.history.pop_front()

func _num(value,lo: float,hi: float,integer: bool=false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=lo and value<=hi and (not integer or floor(float(value))==float(value))

func valid(eco,at: int,legacy: bool=false) -> bool:
	if not eco is Dictionary or eco.get("model")!=rules.model or not eco.get("regions") is Dictionary or eco.regions.size()!=2: return false
	if legacy:
		if eco.has("thermal_model"): return false
	elif eco.get("thermal_model")!=thermal.lab.data.thermal_game.model: return false
	for id in ["microbe","fish"]:
		var r=eco.regions.get(id)
		if not r is Dictionary or not _num(r.get("oxygen"),0,100): return false
		if legacy:
			for key in ["component","heat","cooling","trips"]:
				if r.has(key): return false
		elif not thermal.valid(r): return false
		elif not r.component.is_empty() and not thermal.lab.fits(str(r.component.recipe),id): return false
		for key in ["device","enabled"]:
			if not r.get(key) is bool: return false
		if not _num(r.get("flow"),0.5,2.0) or r.flow not in rules.device.flows: return false
		for key in ["gas","energy"]:
			if not _num(r.get(key),0,float(rules.device.cartridge_units)): return false
		for key in ["loaded","used"]:
			if not _num(r.get(key),0,1000000000): return false
		if not is_equal_approx(float(r.loaded)-float(r.used),float(r.gas)) or r.gas!=r.energy: return false
		if not r.device and (r.loaded!=0 or r.used!=0): return false
		if not r.get("flags") is Array or r.flags.size()>8: return false
		var seen=[]
		for flag in r.flags:
			if flag not in ["empty","exposed","decline","recovered","extinct","leave","return","mortality"] or flag in seen: return false
			seen.append(flag)
	var m=eco.regions.microbe; var f=eco.regions.fish
	for key in ["sensitive","tolerant"]:
		if not _num(m.get(key),0,100): return false
	if m.sensitive+m.tolerant>100.000001 or not _num(m.get("refuge"),0,float(rules.microbe.refuge_capacity)) or not m.get("sealed") is bool: return false
	var total=float(rules.fish.initial_bay)+float(rules.fish.initial_outer)
	for key in ["bay","outer","dead"]:
		if not _num(f.get(key),0,total): return false
	if not is_equal_approx(f.bay+f.outer+f.dead,total) or not _num(f.get("stress"),0,int(rules.fish.stress_seconds),true) or not f.get("gate_open") is bool: return false
	if not eco.get("history") is Array or eco.history.size()>int(rules.history.limit): return false
	var last=-1
	for h in eco.history:
		if not h is Dictionary or not _num(h.get("at"),last+1,at,true): return false
		last=int(h.at)
		var slice={"model":rules.model,"regions":h.get("regions"),"history":[]}
		if not legacy: slice.thermal_model=eco.thermal_model
		if not valid(slice,int(h.at),legacy): return false
	return true

func migrate_thermal(eco: Dictionary) -> void:
	eco.thermal_model=thermal.lab.data.thermal_game.model
	for r in eco.regions.values(): thermal.initialize_region(r)
	for h in eco.history:
		for r in h.regions.values(): thermal.initialize_region(r)

func canonical(value) -> String:
	if value is Dictionary:
		var keys=value.keys(); keys.sort(); var parts=[]
		for key in keys: parts.append(str(key)+":"+canonical(value[key]))
		return "{"+",".join(parts)+"}"
	if value is Array:
		var parts=[]
		for item in value: parts.append(canonical(item))
		return "["+",".join(parts)+"]"
	if value is int or value is float: return "%.6f" % float(value)
	return str(value)
