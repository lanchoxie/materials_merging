extends RefCounted
## Read-only layout from the existing plot level. Entering never changes housing or inventory.
const DATA=preload("res://scripts/residence_rules.gd")
var rules: Dictionary
var kind=""
var level=1
var floor_number=1
var floors=1
var width=8.0
var depth=9.0
var spec: Dictionary={}
var fixtures: Array=[]

static func accepts(value: String) -> bool:
	return value in ["house","engineer_house","doctor_dorm","professor_apartment","academician_villa"]

func setup(plot: Dictionary, floor_index: int=1) -> void:
	rules=DATA.load_rules(); kind="engineer_house" if plot.kind=="house" else str(plot.kind)
	spec=rules.types.get(kind,{}); fixtures.clear()
	if spec.is_empty(): return
	level=clampi(int(plot.get("building_level",1)),1,int(spec.max_level))
	floors=level if spec.floors else 1; floor_number=clampi(floor_index,1,floors)
	width=float(spec.width); depth=float(spec.depth)
	if kind=="engineer_house": width+=0.6*(level-1)
	if kind=="academician_villa" and level>1: width+=1.2
	var left=-width/2+1.0; var right=width/2-1.0; var back=-depth/2+1.4
	match kind:
		"doctor_dorm":
			for side in [-1,1]:
				for row in range(2): _add("bed",Vector3(side*(width/2-0.85),0,back+row*2.5),"%d号床" % [1+row+(2 if side>0 else 0)])
			_add("desk",Vector3(0,0,back-0.4),"共享书桌")
			_add("chair",Vector3(0,0,back+0.7),"书桌椅")
			_add("cabinet",Vector3(left,0,depth/2-1.1),"储物柜")
			if level>=2: _add("snack",Vector3(right,0,depth/2-1.1),"泡面与饮水角")
			if level>=3:
				_add("sofa",Vector3(0,0,0.8),"阅读沙发")
				_add("shelf",Vector3(-1.6,0,-depth/2+0.3),"共享书架")
			if level>=4:
				_add("display",Vector3(right,0,depth/2-2.2),"毕业成果")
				_add("plant",Vector3(right,0,1.35),"休闲角绿植")
		"professor_apartment":
			for side in [-1,1]:
				_add("bed",Vector3(side*(width/2-1.1),0,back),"屏风卧区")
				_add("divider",Vector3(side*2.05,0,back-0.15),"卧室隔屏")
			_add("shelf",Vector3(0,0,-depth/2+0.3),"落地书墙")
			_add("desk",Vector3(left,0,1.1),"阅读书桌")
			_add("chair",Vector3(left,0,2.2),"阅读椅")
			_add("sofa",Vector3(right-0.5,0,0.65),"会客沙发")
			if level>=2: _add("tea",Vector3(right-0.5,0,2.0),"茶台")
			if level>=3: _add("plant",Vector3(left,0,-0.8),"窗边绿植")
			if level>=4: _add("display",Vector3(right,0,depth/2-0.75),"材料模型")
			if level>=5:
				_add("shelf",Vector3(0,0,0),"精选藏书")
				_add("display",Vector3(left,0,depth/2-0.65),"教学荣誉")
		"academician_villa":
			_add("bed",Vector3(left+0.4,0,back),"主卧大床")
			_add("divider",Vector3(left+1.6,0,back-0.15),"主卧隔屏")
			_add("shelf",Vector3(0,0,-depth/2+0.3),"私人藏书")
			_add("garden",Vector3(right-0.4,0,back),"室内庭院")
			_add("sofa",Vector3(0,0,0.1),"庭院沙发")
			_add("tea",Vector3(0,0,1.65),"石材茶几")
			_add("desk",Vector3(left+0.3,0,1.1),"研究书桌")
			_add("chair",Vector3(left+0.3,0,2.2),"书房扶手椅")
			_add("display",Vector3(right,0,1.4),"晶体收藏")
			if level>=2:
				_add("bed",Vector3(right,0,depth/2-1.4),"客房床")
				_add("display",Vector3(left,0,depth/2-0.8),"荣誉展廊")
		_:
			_add("bed",Vector3(left,0,back),"木床")
			_add("desk",Vector3(right-0.2,0,back-0.1),"工程工作台")
			_add("chair",Vector3(right-0.2,0,back+1),"工作椅")
			_add("cabinet",Vector3(left,0,0.6),"生活储物柜")
			if level>=2:
				_add("shelf",Vector3(0,0,-depth/2+0.3),"工具与手册")
				_add("plant",Vector3(right,0,0),"窗边绿植")
			if level>=3:
				_add("sofa",Vector3(0,0,1.2),"休息沙发")
				_add("display",Vector3(right,0,depth/2-0.8),"工程模型")
	if spec.floors: _add("lift",Vector3(1.3,0,-depth/2+0.4),"楼层呼叫台")
	# The entry and the central circulation path stay free at every level.
	_add("plant",Vector3(-width/2+0.42,0,-depth/2+0.42),"室内盆栽")

func _add(type: String, at: Vector3, title: String) -> void:
	var sizes={"bed":Vector3(1.25,0.82,2.1),"desk":Vector3(1.7,0.9,0.72),"chair":Vector3(0.65,1.0,0.65),"cabinet":Vector3(1.15,1.7,0.65),"sofa":Vector3(1.9,1.0,0.85),"shelf":Vector3(1.9,2.4,0.48),"snack":Vector3(1.2,1.35,0.65),"tea":Vector3(1.4,0.5,0.65),"plant":Vector3(0.5,1.1,0.5),"display":Vector3(0.9,1.55,0.6),"garden":Vector3(2.5,0.7,2.0),"divider":Vector3(0.12,2.65,2.3),"lift":Vector3(0.45,1.6,0.25)}
	var size: Vector3=sizes[type]
	fixtures.append({"id":str(fixtures.size()),"type":type,"at":at,"size":size,"title":title,"box":AABB(at-Vector3(size.x/2,0,size.z/2),size)})

func description() -> String:
	return str(spec.upgrades[level-1])
