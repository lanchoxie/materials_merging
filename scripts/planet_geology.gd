extends RefCounted
## Deterministic geology: which natural material fills a 1 m cell. Pure functions of the cell and
## the column top, so nothing here is saved; only player edits are (see river_nature.gd voxels).
static var data: Dictionary={}

static func rules() -> Dictionary:
	if data.is_empty(): data=JSON.parse_string(FileAccess.get_file_as_string("res://data/minerals.json"))
	return data

static func info(id: String) -> Dictionary:
	return rules().materials.get(id,{})

static func bedrock_y() -> int:
	return int(rules().bedrock_y)

## Stable pseudo-random value in [0,1) for a coarse ore cell.
static func _hash(a: int,b: int,c: int,salt: int) -> float:
	var h: int=(a*73856093)^(b*19349663)^(c*83492791)^(salt*2654435761)
	h=(h^(h>>13))*1274126177
	h=h^(h>>16)
	return float(posmod(h,1000003))/1000003.0

static func _blob(c: Vector3i,size: Vector3i,salt: int,chance: float) -> bool:
	return _hash(floori(float(c.x)/size.x),floori(float(c.y)/size.y),floori(float(c.z)/size.z),salt)<chance

## top: the natural column top (metres). river: true for the river bed columns.
static func natural(c: Vector3i,top: float,river: bool) -> String:
	if c.y<=bedrock_y(): return "bedrock"
	var depth=ceili(top)-1-c.y
	if river and depth<2: return "sand"
	if depth==0: return "topsoil"
	# v0.42: mountain ranges are granite under a thin soil.
	if c.y>=12: return "granite"
	if depth<=2 and c.y>-6:
		if _blob(c,Vector3i(3,2,3),11,0.05): return "gibbsite"
		return "sand" if _hash(floori(c.x/6.0),0,floori(c.z/6.0),7)<0.3 else "clay"
	if c.y>-12:
		if c.y>-8 and _blob(c,Vector3i(3,2,3),21,0.045): return "malachite"
		if _blob(c,Vector3i(4,3,4),31,0.05):
			return "sulfur" if _hash(c.x,c.y,c.z,33)<0.12 else "halite"
		if c.y<=-4 and c.y>=-7 and _blob(c,Vector3i(6,1,6),41,0.16): return "coal"
		if _blob(c,Vector3i(2,3,2),51,0.035): return "galena"
		if _blob(c,Vector3i(2,3,2),61,0.035): return "fluorite"
		# v0.37: sedimentary phosphorite, the phosphorus ore (Ca₅(PO₄)₃F).
		if c.y<=-6 and _blob(c,Vector3i(3,2,3),121,0.04): return "apatite"
		return "limestone"
	if c.y>-22:
		if c.y<-17 and _blob(c,Vector3i(2,2,2),71,0.012): return "pollucite"
		if _blob(c,Vector3i(2,3,2),81,0.04): return "spodumene"
		if _blob(c,Vector3i(3,2,3),91,0.045): return "cassiterite"
		if _blob(c,Vector3i(3,3,3),101,0.05): return "hematite"
		return "granite"
	if _blob(c,Vector3i(3,3,3),111,0.06): return "hematite"
	return "basalt"

static func describe(id: String) -> String:
	var m=info(id)
	if m.is_empty(): return "未知物质"
	var lines=[str(m.name)+("  "+str(m.formula) if str(m.formula)!="" else "")]
	var kind={"mineral":"矿物","rock":"岩石","mixture":"混合物"}.get(str(m.kind),"")
	lines.append(kind+" · "+str(m.components))
	var el=[]
	for symbol in m.elements: el.append(symbol)
	if not el.is_empty(): lines.append("组成元素："+" ".join(el)+("（混合物中的主要矿物）" if m.kind!="mineral" else ""))
	if str(m.mohs)!="": lines.append("莫氏硬度 "+str(m.mohs))
	lines.append("产状："+str(m.layer))
	return "\n".join(lines)

## Two-line version for the HUD message bar.
static func summary(id: String) -> String:
	var m=info(id)
	if m.is_empty(): return "未知物质"
	var head=str(m.name)+("  "+str(m.formula) if str(m.formula)!="" else "")
	var bits=[str(m.components)]
	if str(m.mohs)!="": bits.append("莫氏硬度 "+str(m.mohs))
	bits.append(str(m.layer))
	return head+"
"+" · ".join(bits)
