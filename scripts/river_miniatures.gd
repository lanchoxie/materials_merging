extends RefCounted
## Owns no inventory: packed cells stay in Construction's finite source ledger.
## The connected build the aimed block belongs to, without changing anything. Used for the aim
## prompt and the box preview as well as for packing. `error` is empty when it can be packed.
static func survey(c,target: Dictionary) -> Dictionary:
	if target.get("type")!="block": return {"error":"微缩器 · 瞄准你自己搭的建筑（构件、屋顶、种植箱、光伏），E 把整座装盒带回浮岛"}
	if c.miniatures.size()>=16: return {"error":"展示盒已满，先展开一个作品"}
	var chosen={}; var queue=[str(target.key)]; var index=0
	while index<queue.size():
		var k=queue[index]; index+=1
		if chosen.has(k): continue
		if chosen.size()>=64: return {"error":"一盒最多收纳64块；先用拆卸锤拆开作品之间的连接"}
		if c.occupied.has(k): return {"error":"先收获作品里种植箱的作物"}
		chosen[k]=c.blocks[k]
		for n in c.neighbors(c.cell(c.blocks[k])):
			var next=c.key(n)
			if c.blocks.has(next) and not chosen.has(next): queue.append(next)
	var low=Vector3i(99999,99999,99999); var high=-low
	for b in chosen.values(): low=low.min(c.cell(b)); high=high.max(c.cell(b))
	var result={"error":"","chosen":chosen,"low":low,"high":high}
	if (high-low).x>7 or (high-low).y>7 or (high-low).z>7: result.error="作品超过8×8×8的微缩盒（%d×%d×%d），先拆小一些" % [(high-low).x+1,(high-low).y+1,(high-low).z+1]; return result
	var rest=c.blocks.duplicate()
	for k in chosen: rest.erase(k)
	if not c.connected(rest): result.error="这件作品还支撑着其他建筑，请先拆开连接"
	return result

static func pack(c,target: Dictionary) -> String:
	var found=survey(c,target)
	if not found.error.is_empty(): return found.error
	var chosen: Dictionary=found.chosen; var low: Vector3i=found.low
	var rest=c.blocks.duplicate()
	for k in chosen: rest.erase(k)
	var cells=[]
	for b in chosen.values():
		var copy=b.duplicate(); var at=c.cell(b)-low; copy.x=at.x; copy.y=at.y; copy.z=at.z; cells.append(copy)
	var id=str(c.miniature_serial); c.miniature_serial+=1
	c.miniatures[id]={"id":id,"name":"河湾作品 #"+id,"blocks":cells,"plot":-1}
	c.blocks=rest; c.revision+=1
	return "作品已装入微缩盒 · %d块。回浮岛背包的‘河湾作品’中摆放，原地已经腾空。" % cells.size()

static func unfold(c,id: String,actor: Dictionary) -> String:
	if not c.miniatures.has(id): return "背包中没有这件作品"
	var item=c.miniatures[id]
	if item.plot!=-1: return "先从浮岛展台收回作品"
	if actor.is_empty(): return "进入星球第一人称后再展开"
	var hit=c.trace(actor.eye,actor.direction)
	if hit.is_empty() or not hit.has("target"): return "瞄准附近的空地"
	if c.blocks.size()+item.blocks.size()>int(c.rules.max_blocks): return "这里的建筑数量已经到上限"
	var offset: Vector3i=hit.target; var next=c.blocks.duplicate()
	for b in item.blocks:
		var pos=c.cell(b)+offset; var error=c.place_error(pos,actor)
		# Validate support for the complete assembly below, not cell insertion order.
		if not error.is_empty() and error!="构件需要连接地面或已有建筑": return error
		var k=c.key(pos)
		if next.has(k): return "这里的空间不够展开作品"
		var copy=b.duplicate(); copy.x=pos.x; copy.y=pos.y; copy.z=pos.z; next[k]=copy
	if not c.connected(next): return "底座需要完整落地，换一块平整地面"
	c.blocks=next; c.miniatures.erase(id); c.revision+=1
	return "作品已展开，保留每一块原材料的来源"

static func exhibit(c,id: String,plot: int,plots: Array) -> String:
	if not c.miniatures.has(id): return "找不到这件作品"
	# -2: on a v0.27 courtyard pedestal, which owns the take-back.
	if int(c.miniatures[id].plot)==-2: return "这件作品在庭院展台上，请在浮岛地块的物品列表里收回"
	if plot<0: c.miniatures[id].plot=-1; c.revision+=1; return "作品已从展台收回背包"
	if plot>=plots.size() or not plots[plot].unlocked or plots[plot].kind=="plaza": return "选择已开拓的浮岛地块，迎客广场保持通行"
	for other in c.miniatures.values():
		if other.id!=id and other.plot==plot: return "这个地块已有作品展台，换一块地"
	c.miniatures[id].plot=plot; c.revision+=1
	return "作品摆上了浮岛展台；可以进入第一人称走近欣赏"
