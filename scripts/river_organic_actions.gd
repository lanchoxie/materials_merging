extends RefCounted
## Single authority for aimed sample consumption and finite solution use.
static func command(state,action: String,payload: Dictionary) -> String:
	var p=state.planet; var v=p.v2; var o=v.organics
	if not v.active or v.actor.is_empty(): return "先进入第一人称，走近配料罐或种植箱"
	if v.combat.player_health<=0: return "先回营地休息"
	var token=payload.get("token")
	if not (token is int or token is float) or not is_finite(float(token)) or token!=p.shipment_serial: return "这次配料操作已处理，请重新选择"
	var target=v.Target.query(v)
	if action=="organic_apply":
		if target.get("kind")!="planter": return "这瓶只用于已播种的种植箱；不能作为饮水"
		var id=str(payload.get("id","")); var error=o.apply_error(id,str(target.key),v.field)
		if not error.is_empty(): return error
		p.shipment_serial+=1
		var result=o.apply(id,str(target.key),v.field); v.ranch.sync(v); return result
	if target.get("kind")!="mixing_tank": return "走近并瞄准配料罐；在工艺车间用木料和散石制造"
	var key=str(target.key)
	if payload.has("key") and str(payload.key)!=key: return "视线已经离开这只罐；请重新瞄准"
	if action=="organic_add":
		var batch=state.storage.batch(str(payload.get("batch_id","")))
		if batch.is_empty() or int(batch.quantity)<1: return "背包里没有这份样品"
		var reference=str(state.sandbox_reference(batch.work).get("reference_id",""))
		var error=o.input_error(key,reference,str(batch.id),v.construction)
		if not error.is_empty(): return error
		if not state.storage.take_product(str(batch.id),1): return "样品已用完"
		o.tank(key,v.construction)
		o.add_input(key,reference,batch); p.shipment_serial+=1; v.ranch.sync(v)
		return "已加入1份水样；水量增加1教学升" if reference=="water" else "已加入1份尿素；5教学克晶粒等待溶解"
	if action=="organic_bottle":
		var error=o.bottle_error(key)
		if not error.is_empty(): return error
		p.shipment_serial+=1; var result=o.bottle(key); v.ranch.sync(v); return result
	if action=="organic_drain":
		if not o.tanks.has(key): return "这只罐是空的"
		p.shipment_serial+=1; var result=o.drain(key); v.ranch.sync(v); return result
	return "未知配料操作"
