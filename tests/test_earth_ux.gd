extends SceneTree
## v0.33.1 Earth usability: the walked trail and its save, the 公共仓库 quick deposit, and the
## 微缩器 survey that drives its aim prompt and box preview.
const State=preload("res://scripts/lab_state.gd")
const Journey=preload("res://scripts/river_journey.gd")
const Mini=preload("res://scripts/river_miniatures.gd")
const Actions=preload("res://scripts/river_ranch_actions.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	var s=State.new(); var v=s.planet.v2; v.active=true
	# --- Trail: points every 8 m, a jump starts a new segment, the save round-trips and is checked.
	var j=v.journey
	check(not j.track(Vector2(0,0)) or j.trail.size()==1,"the first point is recorded")
	check(not j.track(Vector2(3,0)),"a short step adds nothing")
	check(j.track(Vector2(9,0)) and j.trail.size()==2 and j.trail[1][2]==0,"walking on adds a point in the same segment")
	check(j.track(Vector2(400,0)) and j.trail[2][2]==1,"a fast-travel jump starts a new segment")
	for i in range(Journey.TRAIL_MAX+50): j.track(Vector2((i%600)*9-2700,(i/600)*12))
	check(j.trail.size()<=Journey.TRAIL_MAX,"the trail is thinned instead of growing forever (%d)" % j.trail.size())
	var again=Journey.new()
	check(again.restore(j.serialize(),v.construction.terrain) and again.trail==j.trail and again.segment==j.segment,"the trail survives a save")
	var bad=j.serialize(); bad.trail=[1,2]
	check(not Journey.new().restore(bad,v.construction.terrain),"a broken trail is rejected")
	var old={"version":1,"serial":1,"points":{}}
	check(Journey.new().restore(old,v.construction.terrain),"saves from before v0.33.1 (no trail) still load")
	# --- 公共仓库: E stores up to 5 food from the pack, rations first.
	v.world.food=3; v.field.stock.grain=4; v.field.stock.fruit=2
	var said=Actions.stock_up(s)
	check(v.ranch.depot.ration==3 and v.ranch.depot.grain==2 and v.world.food==0 and v.field.stock.grain==2,"quick deposit takes 口粮 first, then 谷穗, 5 in all: "+said)
	check(v.settlement.stored_food()==5,"the era checklist sees the stored food")
	v.field.stock.grain=0; v.field.stock.fruit=0
	check(Actions.stock_up(s).begins_with("背包里没有"),"an empty pack explains where food comes from")
	# --- 微缩器: survey a small build without changing it.
	var c=v.construction
	for dy in range(3):
		var y=c.base(Vector3i(20,0,30))+dy
		c.blocks[c.key(Vector3i(20,y,30))]={"x":20,"y":y,"z":30,"kind":"block","source":"t"}
	c.sources["t"]={"product":{"id":1,"recipe":"field_wall","recipe_version":1,"source_batch":"test"},"remaining":0}
	var key=c.blocks.keys()[0]; var count=c.blocks.size()
	var found=Mini.survey(c,{"type":"block","key":key})
	check(found.error.is_empty() and found.chosen.size()==3 and c.blocks.size()==count,"survey finds the 3-block build and leaves it in place")
	check(not Mini.survey(c,{}).error.is_empty(),"aiming at nothing explains what the 微缩器 is for")
	check(Mini.pack(c,{"type":"block","key":key}).begins_with("作品已装入") and c.blocks.size()==count-3,"packing still works through the survey")
	if failures.is_empty(): print("EARTH UX OK (%d checks)" % checks); quit(0)
	else: print("EARTH UX FAILED: ",failures); quit(1)
