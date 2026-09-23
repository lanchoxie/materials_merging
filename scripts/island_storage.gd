extends RefCounted
## Inventory owns item counts and immutable product batches, never the wallet or scene.
const MAX_BATCHES=512
var batches: Array=[]
var decorations: Dictionary={}
var consumables: Dictionary={}
var cupboards: Dictionary={}
var finds: Dictionary={}
var unlocked: Array=[]

func batch(id: String) -> Dictionary:
	for item in batches:
		if item.id==id: return item
	return {}

func can_add(id: String, quantity: int) -> bool:
	var item=batch(id)
	return quantity>=0 and (not item.is_empty() or batches.size()<MAX_BATCHES) and int(item.get("quantity",0))+quantity<=1000000

func add_product(snapshot: Dictionary, quantity: int) -> bool:
	if quantity<=0: return true
	if not can_add(str(snapshot.id),quantity): return false
	var item=batch(str(snapshot.id))
	if item.is_empty():
		item=snapshot.duplicate(true); item.quantity=0; batches.append(item)
	item.quantity=int(item.quantity)+quantity
	return true

func take_product(id: String, quantity: int) -> bool:
	var item=batch(id)
	if quantity<=0 or int(item.get("quantity",0))<quantity: return false
	item.quantity=int(item.quantity)-quantity
	if int(item.quantity)==0: batches.erase(item)
	return true

func cupboard(plot: int) -> Dictionary:
	return cupboards.get(str(plot),{})

func food_count(plot: int) -> int:
	var count=0
	for n in cupboard(plot).values(): count+=int(n)
	return count

func deposit_food(plot: int, kind: String, quantity: int, capacity: int) -> bool:
	if quantity<=0 or int(consumables.get(kind,0))<quantity or food_count(plot)+quantity>capacity: return false
	var shelf=cupboard(plot).duplicate()
	shelf[kind]=int(shelf.get(kind,0))+quantity; cupboards[str(plot)]=shelf
	consumables[kind]=int(consumables[kind])-quantity
	return true

func eat(plot: int) -> String:
	var shelf=cupboard(plot)
	for kind in ["noodles","cola"]:
		if int(shelf.get(kind,0))>0:
			shelf[kind]=int(shelf[kind])-1; return kind
	return ""

func serialize() -> Dictionary:
	return {"batches":batches.duplicate(true),"decorations":decorations.duplicate(),"consumables":consumables.duplicate(),"cupboards":cupboards.duplicate(true),"finds":finds.duplicate(),"unlocked":unlocked.duplicate()}

static func count_ok(n) -> bool:
	return (n is int or n is float) and is_finite(float(n)) and float(n)==floor(float(n)) and n>=0 and n<=1000000

static func counts_ok(values, allowed: Array) -> bool:
	if not values is Dictionary: return false
	for key in values:
		if key not in allowed or not count_ok(values[key]): return false
	return true

func restore(data, props: Array, food: Array, plots: Array) -> bool:
	if not data is Dictionary or not data.get("batches") is Array or data.batches.size()>MAX_BATCHES: return false
	var seen={}
	for item in data.batches:
		if not item is Dictionary: return false
		for field in ["id","name","formula","reference"]:
			if not item.get(field) is String or item[field].length()>120: return false
		if item.id.is_empty() or seen.has(item.id) or not count_ok(item.get("quantity")) or item.quantity==0: return false
		if not (item.get("quality") is float or item.get("quality") is int) or not is_finite(float(item.quality)) or item.quality<0 or item.quality>1: return false
		if not item.get("work") is Dictionary: return false
		seen[item.id]=true
	if not counts_ok(data.get("decorations"),props) or not counts_ok(data.get("consumables"),food): return false
	if not data.get("cupboards") is Dictionary or data.cupboards.size()>plots.size(): return false
	for key in data.cupboards:
		if not str(key).is_valid_int() or int(key)<0 or int(key)>=plots.size() or plots[int(key)].kind!="doctor_dorm": return false
		if not counts_ok(data.cupboards[key],food): return false
	if not data.get("finds") is Dictionary or data.finds.size()>plots.size(): return false
	for key in data.finds:
		if not str(key).is_valid_int() or int(key)<0 or int(key)>=plots.size() or not plots[int(key)].unlocked: return false
		if data.finds[key] not in props and data.finds[key]!="collected": return false
	if not data.get("unlocked") is Array: return false
	for key in data.unlocked:
		if key not in props: return false
	batches=data.batches.duplicate(true); decorations=data.decorations.duplicate(); consumables=data.consumables.duplicate()
	cupboards=data.cupboards.duplicate(true); finds=data.finds.duplicate(); unlocked=data.unlocked.duplicate()
	for item in batches: item.quantity=int(item.quantity)
	for table in [decorations,consumables]:
		for key in table: table[key]=int(table[key])
	for shelf in cupboards.values():
		for key in shelf: shelf[key]=int(shelf[key])
	return true
