extends RefCounted
## v0.45 盾构机 (user: 金属制品太耗元素……加入盾构机): a tunnel boring machine on the voxel planet.
## It fills a 3×3 cross-section (3 cells wide, 3 tall) and bores one metre at a time: forward, diving
## one cell per metre, or climbing one cell per metre. Every solid cell it cuts goes into the mineral
## store in bulk (topsoil → 土方, quarried rock also gives 石料); harder rock takes longer; each cell
## costs battery Wh. It turns in quarter turns and backs up through open tunnel. No physics: like the
## rover it duck-types the walker for the input code (movement, running, look(), jump(), stop()).
const Geology=preload("res://scripts/planet_geology.gd")
const Field=preload("res://scripts/river_field.gd")
const FACING=[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
const GRADES={-2:"垂直向上",-1:"下潜",0:"水平",1:"上爬",2:"垂直向下"}
var cell=Vector3i.ZERO     # floor cell under the middle of the machine
var facing=0               # 0 −z, 1 +x, 2 +z, 3 −x
var grade=0                # −1 dive, 0 level, +1 climb
var busy=0.0               # seconds left in the current metre
var length=1.0
var from=Vector3.ZERO      # centre where the current metre started (animation)
var turned_from=0.0
var spin=0.0
var movement=Vector2.ZERO
var running=false
var look_yaw=0.0
var look_pitch=-0.12
var turn_latch=false
var state: Dictionary={"charge":0.0,"cap":0.0}
var rules: Dictionary={}
var haul: Dictionary={}    # mineral id (or "soil"/"stone") -> units collected this trip (1-5 a cell)
var overflow=0             # cells cut while that mineral's store was full (lost)
var cut_cells=0            # solid cells the machine has cut (haul minus stone/soil, plus overflow)
var metres=0
var message=""

func _init(spec: Dictionary) -> void:
	rules=spec

var yaw:
	get: return facing_yaw()

## Ground position of the machine (the minimap reads it like the walker's).
var position:
	get:
		var c=centre(); return Vector2(c.x,c.z)

## Same convention as the walker's yaw (forward is (−sin, −cos)).
func facing_yaw() -> float:
	return [0.0,-PI/2,PI,PI/2][facing]

func dir() -> Vector3i:
	if grade==2: return Vector3i(0,-1,0)   # shaft down
	if grade==-2: return Vector3i(0,1,0)   # shaft up
	var f=FACING[facing]; return Vector3i(f.x,0,f.y)

func side() -> Vector3i:
	var f=FACING[facing]; return Vector3i(-f.y,0,f.x)

func place(at: Vector3i,face: int) -> void:
	cell=at; facing=posmod(face,4); busy=0.0; turned_from=facing_yaw(); stop()

func stop() -> void:
	movement=Vector2.ZERO; running=false

func look(delta: Vector2,sensitivity: float) -> void:
	look_yaw=clampf(look_yaw-delta.x*sensitivity,-1.2,1.2); look_pitch=clampf(look_pitch-delta.y*sensitivity,-0.6,0.4)

## Space cycles the grade: level → dive → climb → shaft-down → shaft-up → level.
func jump() -> bool:
	grade={0:-1,-1:1,1:2,2:-2,-2:0}[grade]; message="掘进方向：%s" % GRADES[grade]
	return true

## True when boring a vertical shaft (grade ±2).
func is_shaft() -> bool:
	return grade==2 or grade==-2

func centre_of(c: Vector3i) -> Vector3:
	return Vector3(c.x,c.y+1.5,c.z)

## Where the machine is drawn now (it slides through the metre it just cut).
func centre() -> Vector3:
	if busy<=0.0: return centre_of(cell)
	return from.lerp(centre_of(cell),1.0-busy/maxf(0.01,length))

func eye() -> Vector3:
	return centre()+Vector3(0,0.4,0)

## The nine cells of the cutting face.
## Horizontal boring: 3 wide × 3 tall cross-section.
## Vertical shaft: 3×3 horizontal slab.
func section(next: Vector3i) -> Array:
	var cells=[]
	if is_shaft():
		for dx in [-1,0,1]:
			for dz in [-1,0,1]: cells.append(next+Vector3i(dx,0,dz))
	else:
		for l in [-1,0,1]:
			for h in [0,1,2]: cells.append(next+side()*l+Vector3i(0,h,0))
	return cells

## What lies in the next metre: {cells:[[cell,id]], hits, error}.
func survey(v) -> Dictionary:
	var t=v.construction.terrain; var c=v.construction
	# In shaft mode dir() already points up/down; horizontal modes add the grade offset.
	var next: Vector3i=cell+dir()+(Vector3i(0,grade,0) if not is_shaft() else Vector3i.ZERO)
	var cut=[]; var hits=0
	for x in section(next):
		var p=Vector2(x.x,x.z)
		if not t.inside(p,3): return {"error":"前方超出探索区","next":next}
		if not c.occupant(x).is_empty(): return {"error":"前方有建筑，盾构机不会挖穿它","next":next}
		var id: String=t.material(x)
		if id=="": continue
		if id=="bedrock": return {"error":"前方是基岩：换个方向，或切到「上爬」","next":next}
		if x.y>=ceili(t.height_at(p))-1 and t.blocked(p,c.obstacles):
			# Trees are cleared automatically; only buildings block the TBM.
			var nearby_trees=t.trees_near(p,1.8)
			if nearby_trees.is_empty(): return {"error":"前方地表有建筑，盾构机不会挖穿它","next":next}
			for tid in nearby_trees: v.nature.chop(tid,v.field,t)
		cut.append([x,id]); hits+=int(Geology.info(id).get("hits",3))
	# Cliff check only matters in horizontal mode; in a shaft the floor below the next cell
	# is the cell we just left (already empty), so it would falsely block shaft-up.
	if not is_shaft():
		var below: Vector3i=next+Vector3i.DOWN
		if t.material(below)=="" and c.occupant(below).is_empty(): return {"error":"前方脚下悬空，盾构机不能开出悬崖","next":next}
	return {"cells":cut,"hits":hits,"next":next,"error":""}

## Bore one metre: cut, collect, move. Returns a message.
func advance(v) -> String:
	var s=survey(v)
	if not s.error.is_empty(): return s.error
	var nature=v.nature; var t=v.construction.terrain
	var fresh=0
	for row in s.cells:
		if not nature.voxels.has(row[0]): fresh+=1
	if nature.voxels.size()+fresh>int(nature.rules.max_voxels): return "地下改造记录已满（%d格），先把一些方块放回原处" % int(nature.rules.max_voxels)
	var need=float(s.cells.size())*float(rules.wh_per_cell)
	if float(state.charge)<need: return "电量不足（需要 %.0f Wh）：回浮岛充电" % need
	state.charge=float(state.charge)-need
	var got={}
	for row in s.cells:
		nature.set_voxel(row[0],"",t)
		var kept=_collect(v,str(row[1]))
		# Full backpack never blocks digging — overflow is lost but the cell is always cleared.
		if kept!="": got[kept]=int(got.get(kept,0))+1
		# v0.68: tree loses support when its ground cell is removed → auto-fell it.
		var above_p=Vector2(row[0].x,row[0].z)
		var surface_y=ceili(t.height_at(above_p))-1
		if row[0].y>=surface_y-1:
			for tid in t.trees_near(above_p,1.2):
				var chop_msg=nature.chop(tid,v.field,t)
				if "倒下了" in chop_msg: got["timber_bonus"]=int(got.get("timber_bonus",0))+1
	if not s.cells.is_empty(): nature.touch(Vector2(s.next.x,s.next.z),t)
	from=centre(); cell=s.next; length=float(rules.base_seconds)+float(rules.seconds_per_hit)*float(s.hits); busy=length; metres+=1; cut_cells+=s.cells.size()
	if s.cells.is_empty(): return "前进1米"
	var parts=[]
	for id in got: parts.append("%s×%d" % [_name(id),int(got[id])])
	return "掘进1米 · 切下%d格%s" % [s.cells.size()," · "+"、".join(parts) if not parts.is_empty() else ""]

func _name(id: String) -> String:
	if id=="soil": return "土方"
	if id=="stone": return "石料"
	return str(Geology.info(id).get("name",id))

## One cut cell into the stores; returns what was kept ("" = lost to a full store).
## v0.50: like hand digging, a cell gives a random 1-5 (keyed by the cell, so a re-run matches),
## and the haul counts cells so the dashboard adds up.
func _collect(v,id: String) -> String:
	var nature=v.nature; var spec: Dictionary=Geology.info(id)
	nature._discover(id)
	var key="cut:%d:%d:%d" % [cell.x,cell.y,cell.z]
	if str(spec.get("yield",""))=="soil":
		var soil=mini(Field.span([1,2],Field.roll(key,1)),maxi(0,int(v.field.rules.max_stock)-int(v.field.stock.soil)))
		if soil>0: v.field.stock.soil+=soil; v.field.revision+=1; haul["soil"]=int(haul.get("soil",0))+soil
		else: overflow+=1
		return "soil"
	if id in nature.rules.get("rubble_rocks",[]):
		var stones=mini(Field.span(nature.rules.stone_yield,Field.roll(key,2)),maxi(0,int(v.field.rules.max_stock)-int(v.field.stock.stone)))
		if stones>0: v.field.stock.stone+=stones; v.field.revision+=1; haul["stone"]=int(haul.get("stone",0))+stones
	if int(nature.minerals.get(id,0))>=int(nature.rules.max_mineral_stock): overflow+=1; return ""
	var ore=mini(Field.span(nature.rules.ore_yield,Field.roll(key,3)),maxi(0,int(nature.rules.max_mineral_stock)-int(nature.minerals.get(id,0))))
	if ore<=0: overflow+=1; return ""
	nature.minerals[id]=int(nature.minerals.get(id,0))+ore; haul[id]=int(haul.get(id,0))+ore
	return id

## The ore-yield range for a plain material (topsoil is a field resource, not a mineral).
func spec_yield(id: String) -> Array:
	return [1,1] if id=="soil" else Field.span(rules.get("ore_yield",[1,5]),0.0) as Array

## Back up one metre through open tunnel (or open ground).
func reverse(v) -> String:
	var t=v.construction.terrain; var c=v.construction
	var back: Vector3i=cell-dir()
	for x in section(back):
		if t.material(x)!="" or not c.occupant(x).is_empty(): return "身后不是空隧道，不能倒车"
	var below: Vector3i=back+Vector3i.DOWN
	if t.material(below)=="" and c.occupant(below).is_empty(): return "身后脚下悬空"
	from=centre(); cell=back; length=float(rules.reverse_seconds); busy=length
	return "后退1米"

func step(dt: float,v) -> void:
	if busy>0.0:
		spin+=dt*3.0; busy=maxf(0.0,busy-dt); return
	if absf(movement.x)>0.5:
		if not turn_latch:
			turned_from=facing_yaw(); facing=posmod(facing+(1 if movement.x>0 else -1),4); turn_latch=true
			message="转向 · 朝%s" % ["北","东","南","西"][facing]
		return
	turn_latch=false
	if movement.y<-0.5: message=advance(v)
	elif movement.y>0.5: message=reverse(v)

## The next metre, for the HUD: what the cutter faces and how long it will take.
func preview(v) -> String:
	var s=survey(v)
	if not s.error.is_empty(): return s.error
	if s.cells.is_empty(): return "前方是空的 · 前进1米"
	var counts={}
	for row in s.cells: counts[str(row[1])]=int(counts.get(str(row[1]),0))+1
	var parts=[]
	for id in counts: parts.append("%s×%d" % [_name(id),int(counts[id])])
	return "前方：%s · 约%.1f秒 · %.0f Wh" % ["、".join(parts),float(rules.base_seconds)+float(rules.seconds_per_hit)*float(s.hits),float(s.cells.size())*float(rules.wh_per_cell)]

func haul_text() -> String:
	if haul.is_empty(): return "本次还没有收获"
	var parts=[]
	for id in haul: parts.append("%s×%d" % [_name(id),int(haul[id])])
	return "本次收获：%s%s" % ["、".join(parts),"（仓满丢弃 %d 格）" % overflow if overflow>0 else ""]
