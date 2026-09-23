extends RefCounted
## One aim query for prompts and authoritative interactions, with terrain/block occlusion.
static func query(v) -> Dictionary:
	var actor: Dictionary=v.actor
	if actor.is_empty() or not actor.get("eye") is Vector3 or not actor.get("direction") is Vector3: return {}
	var eye: Vector3=actor.eye; var direction: Vector3=actor.direction
	if not eye.is_finite() or not direction.is_finite() or direction.length()<0.01: return {}
	direction=direction.normalized()
	var c=v.construction; var reach=float(v.field.rules.reach); var limit=reach; var best={}
	var hit: Dictionary=c.trace(eye,direction)
	if hit.has("point"):
		limit=eye.distance_to(hit.point)+0.05
		if str(hit.get("hit","")).is_empty() and hit.has("target"): best={"type":"terrain","name":"地面","point":hit.point,"distance":limit}
		if not str(hit.get("hit","")).is_empty():
			var b: Dictionary=c.blocks[hit.hit]
			best={"type":"block","key":hit.hit,"kind":b.kind,"name":c.rules.kinds[b.kind].name,"distance":limit,"point":hit.point}
	# Occlusion from tree trunks is evaluated at the same geometry as walking.
	var at=Vector2(eye.x,eye.z); var chunk=c.terrain.chunk_at(at)
	for dz in range(-1,2):
		for dx in range(-1,2):
			for tree in c.terrain.tree_records(chunk+Vector2i(dx,dz)):
				var p=Vector2(tree.x,tree.z)
				if tree.cut or at.distance_to(p)>reach+0.4: continue
				var base=Vector3(p.x,c.terrain.ground(p),p.y)
				var height=float(v.nature.rules.species[tree.species].height)*(0.25+tree.growth*0.75)
				var d=_distance(AABB(base-Vector3(0.23,0,0.23),Vector3(0.46,height,0.46)),eye,direction)
				if d>=0 and d<=limit+(0.4 if hit.get("blocked",false) else 0.0) and d<=reach:
					limit=d; best={"type":"tree","tree_id":tree.id,"growth":tree.growth,"name":v.nature.rules.species[tree.species].name,"distance":d,"point":eye+direction*d}
	for key in v.field.gardens:
		var b=c.blocks[key]; var height=0.1+v.field.gardens[key].growth*0.8
		var base=Vector3(b.x-0.48,b.y+0.98,b.z-0.48)
		var d=_distance(AABB(base,Vector3(0.96,height,0.96)),eye,direction)
		if d>=0 and d<limit: limit=d; best={"type":"block","key":key,"kind":"planter","name":"种植箱","distance":d,"point":eye+direction*d}
	for n in v.field.nodes(at,reach+1):
		var center=Vector3(n.x,n.y,n.z); var size=Vector3(1.1,0.85,1.1)
		var d=_distance(AABB(center-Vector3(0.55,0,0.55),size),eye,direction)
		if d>=0 and d<limit:
			limit=d; best={"type":"resource","node":n,"name":v.field.rules.resources[n.kind].node,"distance":d,"point":eye+direction*d}
	for id in v.world.regions:
		var r=v.world.regions[id]; var center: Vector3=c.terrain.CENTERS[id]
		for recipe in r.buildings:
			var barriers=c.terrain.building_barriers({id:{"buildings":{recipe:true},"enclosed":r.enclosed}})
			for rect in barriers:
				var base=Vector3(rect.position.x,c.terrain.ground(rect.get_center()),rect.position.y)
				var d=_distance(AABB(base,Vector3(rect.size.x,1.0,rect.size.y)).grow(0.06),eye,direction)
				if d>=0 and d<=limit+0.3 and d<=reach:
					limit=d; best={"type":"facility","recipe":recipe,"region":id,"name":v.rules.products[recipe].name,"distance":d,"point":eye+direction*d}
	for e in v.combat.entities(v):
		var position=Vector3(e.position.x,c.terrain.ground(e.position),e.position.y)
		if e.fish: position.y=0.18+v.world.regions[e.region].water*0.15
		var box=AABB(position-Vector3(0.3,0.05,0.4),Vector3(0.6,e.height,0.8))
		if actor.has("entity_hitboxes"):
			if not actor.entity_hitboxes.has(e.key): continue
			box=actor.entity_hitboxes[e.key]
		elif e.position.distance_to(at)>reach+1: continue
		var d=_distance(box,eye,direction)
		if d>=0 and d<limit and d<=reach:
			limit=d; best={"type":"animal" if e.type=="animal" else "creature","entity":e,"region":e.get("region",""),"id":e.id,"fish":e.fish,"health":e.row.get("health",1),"hunger":e.row.get("hunger",0),"name":e.name,"distance":d,"point":eye+direction*d}
	return best

static func _distance(box: AABB,eye: Vector3,direction: Vector3) -> float:
	var point=box.intersects_ray(eye,direction)
	return -1 if point==null else eye.distance_to(point)

static func prompt(v,target: Dictionary) -> String:
	if target.is_empty(): return "瞄准枯枝、散石、纤维草、果丛或种植箱 · E 操作"
	var text="%s · %.1f米" % [target.name,target.distance]
	match target.type:
		"resource":
			var left=v.field.remaining(target.node.id,int(v.world.elapsed))
			if left>0: return text+" · 恢复中 %d秒" % left
			var spec=v.field.rules.resources[target.node.kind]
			return text+" · E 采集 %d/%d" % [int(v.field.changed.get(target.node.id,{}).get("hits",0)),spec.hits]
		"block":
			if target.kind=="mixing_tank": return text+" · E 查看配料 / 背包拿起有机物或水样加料"
			if target.kind in ["trough","feeder"]:
				var f=v.ranch.facility(target.key,target.kind); var spec=v.ranch.rules.facilities[target.kind]
				return text+" · 储料%d/%d · %s" % [f.stock,spec.capacity,"装备水样补充" if target.kind=="trough" else "装备谷穗补充"]
			if target.kind=="planter":
				var plot=v.field.gardens.get(target.key,{})
				if plot.is_empty(): return text+" · 装备种子播种"
				return text+" · 生长%.0f%% / 湿度%.0f%% · %s" % [plot.growth*100,plot.moisture*100,"E 收获" if plot.growth>=1 else ("需要浇水" if plot.moisture<0.25 else ("叶尖受损，停止追加肥料" if v.organics.injury(target.key)>0.15 else ("补肥生长中" if v.organics.growth_factor(target.key)>1 else "正在生长")))]
			return text+" · 装备拆卸锤可收回"
		"creature": return text+" · 血量%.0f%% · %s" % [target.health*100,v.combat.reaction(target.entity)]
		"animal": return text+" · 健康%.0f%% · %s" % [target.health*100,"观察水质与溶氧" if target.fish else "装备野果喂食"]
		"facility": return text+(" · E 开关围栏" if target.recipe=="frame_bundle" else " · 背包补充相应运行材料")
		"tree": return text+(" · 装备斧头砍伐，掉落木料与树种" if target.growth>=0.99 else " · 生长%.0f%% · 水样可以浇灌" % (target.growth*100))
		"terrain": return text+" · 铲子挖土 / 土方填高 / 树种种植"
	return text
