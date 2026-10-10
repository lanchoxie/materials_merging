extends RefCounted
## v0.43 星锻岛 first person: the surface the shared walker (river_walker.gd) asks about. The deck
## plots are walkable; factories block by their plinth, decorations by their tile footprint (paths
## and flat beds do not). Same toy scale as island Ⅰ's walk, so the factories tower over you.
const Town=preload("res://scripts/island_town.gd")
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_exploration.json"))
var industry
var parcels={}
var obstacles: Array=[]
const BODY_RADIUS=0.09
## Half the side of a factory's plinth (models stand on a 2.6 m footing in a 3 m plot).
const PLINTH=1.32

func setup(ind) -> void:
	industry=ind
	rules.eye_height=0.6; rules.body_height=0.68; rules.player_radius=BODY_RADIUS
	rules.walk_speed=1.5; rules.run_speed=2.4; rules.jump_speed=2.6
	rules.step_height=0.32; rules.gravity=12.0
	parcels.clear(); obstacles.clear()
	for i in range(ind.plots):
		var c: Vector2i=ind.cell(i); parcels[c]=true
		var at: Vector3=ind.plot_center(i)
		if ind.buildings.has(str(i)): obstacles.append(Rect2(Vector2(at.x,at.z)-Vector2(PLINTH,PLINTH),Vector2(PLINTH,PLINTH)*2.0))
	for row in ind.decorations():
		var kind=str(row.item.kind)
		if str(Town.info(kind).get("category",""))=="path" or kind in ["park","garden","flower_bed"]: continue
		var at: Vector3=ind.plot_center(int(row.plot))
		obstacles.append(tile_rect(Vector2(at.x,at.z),Town.item_rect(row.item)))

static func tile_rect(base: Vector2, r: Rect2i) -> Rect2:
	var t=Town.tile()
	return Rect2(base+Vector2(-1.5,-1.5)+Vector2(r.position)*t+Vector2(0.02,0.02),Vector2(r.size)*t-Vector2(0.04,0.04))

## The deck cell under a ground point (plot centres sit at (c-1.5)·3 m).
static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x/3.0+2.0),floori(p.y/3.0+2.0))

## Tile (0..11, 0..11) inside the plot under a ground point.
static func tile_of(p: Vector2) -> Vector2i:
	var c=cell_of(p); var local=p-Vector2((c.x-1.5)*3.0,(c.y-1.5)*3.0)
	return Town.tile_at(Vector3(local.x,0,local.y))

## Start beside the trade hub (the airship dock) or else the first empty plot, else plot 1's edge.
func spawn(_region: String) -> Vector2:
	for i in range(industry.plots):
		if not industry.buildings.has(str(i)):
			var at: Vector3=industry.plot_center(i); return Vector2(at.x,at.z)+Vector2(0.4,0.6)
	var a: Vector3=industry.plot_center(0)
	return Vector2(a.x,a.z)+Vector2(0,PLINTH+0.1)

func inside(p: Vector2,_margin: float=0) -> bool:
	return parcels.has(cell_of(p))

func water_at(_p: Vector2) -> bool:
	return false

func overlaps(_p: Vector2,_feet: float,_height: float) -> bool:
	return false

func ground(_p: Vector2) -> float:
	return 0.0

func height_at(p: Vector2) -> float: return ground(p)
func river_x(_z: float) -> float: return 100000

func blocked(p: Vector2,_barriers: Array=[]) -> bool:
	var r=BODY_RADIUS
	for offset in [Vector2.ZERO,Vector2(r,0),Vector2(-r,0),Vector2(0,r),Vector2(0,-r)]:
		if not inside(p+offset): return true
	for rect in obstacles:
		if rect.grow(r).has_point(p): return true
	return false
