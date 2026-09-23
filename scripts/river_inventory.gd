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
	result["food"]=_item("food","粮仓饲料","supplies","food",int(v.world.food),"收获和野外采集进入粮仓，圈养动物与居民按需取食。",{})
	for id in v.field.stock:
		var spec=v.field.rules.resources[id]; var key="raw:"+str(id)
		if int(v.field.stock[id])<=0 and key not in slots: continue
		var action={"type":"feed","resource":id} if id in ["fruit","grain"] else ({"type":"fill"} if id=="soil" else {})
		result[key]=_item(key,spec.name,"raw",spec.icon,int(v.field.stock[id]),"从河湾采集或收获，回浮岛仍在同一背包中。"+("瞄准地面填高一格；消耗1份土方，可用铲子挖回。" if id=="soil" else ("瞄准小兽可喂食，也可送入粮仓。" if not action.is_empty() else "到工艺车间加工成建材，无需购买标准供料。")),action)
	for species in v.nature.seeds:
		var spec=v.nature.rules.species[species]; var key="tree:"+str(species)
		if v.nature.seeds[species]>0 or key in slots: result[key]=_item(key,spec.seed,"trees","seed",int(v.nature.seeds[species]),"种在空地长成"+str(spec.name)+"；用水样或标准水箱浇灌可加快生长。",{"type":"tree_plant","species":species})
	for id in c.miniatures:
		var box=c.miniatures[id]; var key="mini:"+str(id)
		result[key]=_item(key,box.name,"miniatures","crate",1,"%d块构件组成的作品。%s" % [box.blocks.size(),"已摆在浮岛展台，先收回才能展开" if box.plot>=0 else "可返回浮岛的作品展台摆放，或瞄准星球空地展开。"],{"type":"mini_unfold","id":id})
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
			quantity=c.available(str(construction.kind),p.products,recipe_id)
			description="数量按可放置的块数显示；每包%d块，拆除返还原包。\n" % int(construction.units)+description
			action={"type":"build","kind":construction.kind,"recipe":recipe_id}
		elif v.rules.products.has(recipe_id): action={"type":"product","recipe":recipe_id}
		else: description+="\n此成品的星球用途尚未开放，继续保存在浮岛仓库。"
		var key="recipe:"+recipe_id
		if quantity>0 or key in slots:
			result[key]=_item(key,str(spec.get("name",recipe_id)),category,icon,quantity,description,action)
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
	return {"version":1,"slots":slots.duplicate(),"selected":selected}

func restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("slots") is Array or data.slots.size()!=int(rules.slots): return false
	var n=data.get("selected")
	if not (n is int or n is float) or not is_finite(float(n)) or n!=floor(n) or n<0 or n>=int(rules.slots): return false
	var seen={}
	for id in data.slots:
		if not id is String or id.length()>160: return false
		if id.is_empty(): continue
		if seen.has(id): return false
		if not (id.begins_with("recipe:") or id.begins_with("sample:") or id.begins_with("raw:") or id.begins_with("tree:") or id.begins_with("mini:") or id=="seed:grain" or id=="food" or (id.begins_with("tool:") and rules.tools.has(id.trim_prefix("tool:")))): return false
		seen[id]=true
	slots=data.slots.duplicate(); selected=int(n)
	return true
