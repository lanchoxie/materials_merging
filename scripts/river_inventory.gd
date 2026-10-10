extends RefCounted
## Inventory is a projection of existing ledgers. Only shortcut references are saved here.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/river_inventory.json"))
var slots: Array=[]
var selected=0
var sample_cache={}

func _init() -> void:
	slots=rules.defaults.duplicate()

func entries(state) -> Dictionary:
	var result={}; var p=state.planet; var v=p.v2; var c=v.construction
	for id in rules.tools:
		var spec=rules.tools[id]
		result["tool:"+id]=_item("tool:"+id,spec.name,"tools",spec.icon,-1,spec.description,{"type":id})
	result["seed:grain"]=_item("seed:grain","混合种子","supplies","seed",int(v.world.seeds),"装备到快捷栏，瞄准空种植箱按 E 播谷物。水样或标准水箱可单独浇这一箱；成熟后用采集手套收获留种。上帝视角保留区域播种。",{"type":"plant","crop":"grain"})
	result["food"]=_item("food","口粮","supplies","food",int(v.world.food),"收获和野外采集会变成口粮放在背包里。走到营地的「公共仓库」按E存进去，居民才会去吃。动物使用谷穗、野果和设施补给。",{})
	for id in v.field.stock:
		var spec=v.field.rules.resources[id]; var key="raw:"+str(id)
		if int(v.field.stock[id])<=0 and key not in slots: continue
		var action={"type":"feed","resource":id} if id in ["fruit","grain"] else ({"type":"fill"} if id=="soil" else {})
		# v0.41.2: cooked food is eaten from the hotbar; raw meat waits for a campfire.
		var food: Dictionary=v.field.rules.cooking.foods.get(id,{})
		if not food.is_empty() and id!="fruit": action={"type":"eat","resource":id}
		var text="从河湾采集或收获，回浮岛仍在同一背包中。"+("瞄准地面填高一格；消耗1份土方，可用采掘镐挖回。" if id=="soil" else ("瞄准小兽可喂食，也可送入粮仓；饿了也能直接吃（回血 %d）。" % int(food.get("heal",0)) if id=="fruit" else ("E 吃下：回血 %d，暖身 +%d °C %d 秒。" % [int(food.heal),int(food.warmth),int(food.seconds)] if not food.is_empty() else ("走到篝火旁烤熟再吃。" if id=="meat" else "到工艺车间加工成建材，无需购买标准供料。"))))
		result[key]=_item(key,spec.name,"raw",spec.icon,int(v.field.stock[id]),text,action)
	for id in v.nature.minerals:
		var spec=v.nature.Geology.info(str(id)); var key="rock:"+str(id)
		if int(v.nature.minerals[id])<=0 and key not in slots: continue
		result[key]=_item(key,str(spec.name),"minerals","rock",int(v.nature.minerals[id]),"%s
采掘镐从地下挖出的真实矿物方块。拿起后瞄准地面或岩壁的一个面按 E 放置；后续版本可在浮岛精炼成元素。" % v.nature.Geology.describe(str(id)),{"type":"place_rock","mineral":id})
		result[key].color=str(spec.color)
	for species in v.nature.seeds:
		var spec=v.nature.rules.species[species]; var key="tree:"+str(species)
		if v.nature.seeds[species]>0 or key in slots: result[key]=_item(key,spec.seed,"trees","seed",int(v.nature.seeds[species]),"种在空地长成"+str(spec.name)+"；用水样或标准水箱浇灌可加快生长。",{"type":"tree_plant","species":species})
	for id in c.miniatures:
		var box=c.miniatures[id]; var key="mini:"+str(id)
		result[key]=_item(key,box.name,"miniatures","crate",1,"%d块构件组成的作品。%s" % [box.blocks.size(),"复刻的展示模型，只能摆在浮岛展台上" if box.get("replica",false) else "已摆在浮岛展台，先收回才能展开" if int(box.plot)!=-1 else "可返回浮岛的作品展台摆放，或瞄准星球空地展开。"],{"type":"mini_unfold","id":id})
	for recipe_id in p.recipe_ids():
		var spec=p.recipe(recipe_id); var construction=c.rules.recipes.get(recipe_id,{})
		var quantity=0
		for product in p.products:
			if product.recipe==recipe_id: quantity+=1
		var action={}; var category="products"; var icon="crate"
		var description=str(spec.get("description",""))
		if not construction.is_empty():
			category="components"; icon="solar" if construction.kind=="solar" else "block"
			if construction.kind in ["floor","roof","fence","planter"]: icon=construction.kind
			if c.rules.kinds[construction.kind].get("machine",false):
				icon="machine"; description="地球环境设备：放在地面后持续改变周围约256米的环境或全球大气，拆回后逐渐恢复。
"+description
			quantity=c.available(str(construction.kind),p.products,recipe_id)
			description="可放置构件：每包%d块，数量按块显示。绿色预览可以落下，红色预览需换位置；拆除返还原包。\n" % int(construction.units)+description
			action={"type":"build","kind":construction.kind,"recipe":recipe_id}
		elif v.rules.products.has(recipe_id): action={"type":"product","recipe":recipe_id}
		else: description+="\n此成品的星球用途尚未开放，继续保存在浮岛仓库。"
		var key="recipe:"+recipe_id
		if quantity>0 or key in slots:
			result[key]=_item(key,str(spec.get("name",recipe_id)),category,icon,quantity,description,action)
			if icon=="machine": result[key].color=str(c.rules.kinds[construction.kind].color)
	for id in v.organics.bottles:
		var bottle=v.organics.bottles[id]; var key="solution:"+str(id)
		var ref=v.organics.substance(bottle); var name=v.organics.substance_name(ref)
		var use="瞄准已播种的种植箱按 E 施肥；重复施用会累积。" if ref=="urea" else "配水实验留样，未开放生物用途。"
		result[key]=_item(key,"%s溶液 #%s" % [name,id],"products","sample",1,"250教学mL · %.2f g/L\n这瓶含%.2f教学克%s。%s瞄准空罐或同种配料罐按 E 可倒回再稀释；不能作饮水或饲料。" % [bottle.mass_g/bottle.water_l,bottle.mass_g,name,use],{"type":"organic_solution","id":id,"reference":ref})
	var live_batches={}
	for batch in state.storage.batches:
		var key="sample:"+str(batch.id)
		live_batches[key]=true
		if int(batch.quantity)<1 and key not in slots: continue
		# Recognition can inspect a full molecular graph. Reuse it while the immutable
		# batch structure is unchanged; quantity refreshes must not repeat the analysis.
		var stamp=var_to_str(batch.work)
		if sample_cache.get(key,{}).get("stamp","")!=stamp:
			sample_cache[key]={"stamp":stamp,"ref":str(state.sandbox_reference(batch.work).get("reference_id",""))}
		var ref=str(sample_cache[key].ref)
		var rule=v.rules.products.get("sample_"+ref,{})
		var description="批次 %s · 保留这份结构的来源与身份。\n" % str(batch.id)
		description+=str(rule.description) if not rule.is_empty() else "尚未定义该样品的星球用途；可留在浮岛用于研究或订单。"
		var action={} if rule.is_empty() else {"type":"sample","batch_id":str(batch.id),"reference":ref}
		if v.organics.rules.references.has(ref):
			description="批次 %s · %s\n%s\n拿起后瞄准配料罐加料；1份对应5教学克。" % [batch.id,v.organics.substance_name(ref),v.organics.rules.references[ref].gameplay.description]
			action={"type":"organic_sample","batch_id":str(batch.id),"reference":ref}
		result[key]=_item(key,str(batch.formula),"samples","sample",int(batch.quantity),description,action)
	for key in sample_cache.keys():
		if not live_batches.has(key): sample_cache.erase(key)
	return result

func _item(id: String,title: String,category: String,icon: String,quantity: int,description: String,action: Dictionary) -> Dictionary:
	return {"id":id,"name":title,"category":category,"icon":icon,"quantity":quantity,"description":description,"action":action}

func missing(id: String) -> Dictionary:
	return _item(id,"已用完","samples","sample",0,"这个快捷引用的库存已用完。可移除快捷键，或补充原批次；不会自动改用其他样品。",{})

func bind_slot(index: int,id: String,items: Dictionary) -> bool:
	if index<0 or index>=slots.size() or (not id.is_empty() and not items.has(id)): return false
	# Move an existing shortcut, not its underlying stock. There is only one binding per item.
	var previous=slots.find(id) if not id.is_empty() else -1
	if previous>=0 and previous!=index: slots[previous]=slots[index]
	slots[index]=id; selected=index
	return true

func serialize() -> Dictionary:
	return {"version":2,"slots":slots.duplicate(),"selected":selected}

func restore(data) -> bool:
	if not data is Dictionary or data.get("version") not in [1,2,1.0,2.0] or not data.get("slots") is Array or data.slots.size()!=int(rules.slots): return false
	var n=data.get("selected")
	if not (n is int or n is float) or not is_finite(float(n)) or n!=floor(n) or n<0 or n>=int(rules.slots): return false
	var seen={}
	for id in data.slots:
		if not id is String or id.length()>160: return false
		if id.is_empty(): continue
		if seen.has(id): return false
		if not (id.begins_with("solution:") or id.begins_with("recipe:") or id.begins_with("sample:") or id.begins_with("raw:") or id.begins_with("tree:") or id.begins_with("mini:") or id.begins_with("rock:") or id=="seed:grain" or id=="food" or (id.begins_with("tool:") and rules.tools.has(id.trim_prefix("tool:")))): return false
		seen[id]=true
	slots=data.slots.duplicate(); selected=int(n)
	# v0.26: hand the new pick and analyser to pre-Bedrock hotbars once, in free slots only.
	if int(data.version)==1:
		for tool in ["tool:dig","tool:scan"]:
			var free=slots.find("")
			if tool not in slots and free>=0: slots[free]=tool
	return true
