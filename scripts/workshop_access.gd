extends RefCounted
## One read-only readiness summary shared by manufacturing commands and their UI.
static func status(state) -> Dictionary:
	var context=state.campus_context()
	var plots=[]; var connected=0; var assigned=0
	for building in context.buildings:
		if building.kind!="workshop": continue
		plots.append(int(building.plot))
		if building.connected: connected+=1
	for person in state.campus.people:
		if person.role=="engineer" and person.get("post","auto")=="workshop": assigned+=1
	var rate=state.campus.industrial_rate(context)
	var message="工程师已到岗" if rate>0 else "等待工程师到岗；行路、吃饭和休息不计工时"
	if plots.is_empty(): message="先在浮岛空地建造工艺车间"
	elif connected==0: message="先用小路把工艺车间连接迎客广场"
	elif assigned==0: message="先给至少一名工程师安排「车间生产」岗位"
	return {"plots":plots,"connected":connected,"assigned":assigned,"rate":rate,"ready":connected>0 and assigned>0,"message":message}

static func recipe_ids(program) -> Array:
	var result=[]
	# Construction components and ecological products share the same factory stock.
	for id in program.v2.construction.rules.recipes:
		if not program.recipe(id).is_empty(): result.append(id)
	for id in program.v2.rules.products:
		if not id.begins_with("sample_") and id not in result: result.append(id)
	return result
