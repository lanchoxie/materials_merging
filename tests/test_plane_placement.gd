extends SceneTree
## Regression: unbounded aircraft placement must terminate on ARM and find the
## actual highest surface, including buildings, terrain edits and cave mouths.
const Construction=preload("res://scripts/river_construction.gd")
const Nature=preload("res://scripts/river_nature.gd")
const Craft=preload("res://scripts/planet_plane.gd")
const Industry=preload("res://scripts/industry.gd")
var checks=0
var failures=[]

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func _initialize() -> void:
	var c=Construction.new(); var t=c.terrain
	var p=Vector2(14,16); var x=int(p.x); var z=int(p.y)
	var ground=t.ground(p); var roof_y=ceili(ground)+5
	var roof={"x":x,"y":roof_y,"z":z,"kind":"slab_wood","source":"test"}
	c.blocks[c.key(Vector3i(x,roof_y,z))]=roof
	var roof_top=roof_y+0.5
	check(is_equal_approx(c.floor_at(p,INF),roof_top),"unbounded placement finds the roof instead of skipping buildings")
	check(is_equal_approx(c.floor_at(p,1.0e30),roof_top),"a huge finite ceiling also finds the roof without scanning empty sky")
	check(is_equal_approx(c.floor_at(p,roof_top-0.1),ground),"a ceiling below the roof still finds the ground")
	var plane=Craft.new(Industry.rules().plane); plane.terrain=t; plane.construction=c
	plane.place(p,0.0)
	check(is_finite(plane.altitude) and is_equal_approx(plane.altitude,roof_top),"the real plane.place path parks on the roof")
	c.blocks.clear(); plane.place(p,0.0)
	check(is_equal_approx(plane.altitude,maxf(ground,Craft.Shape.SEA_LEVEL)),"repeated placement on bare ground stays finite")
	# A floating filled cell: unrestricted search finds it, a lower ceiling ignores it.
	var n=Nature.new(); t.nature=n
	var added_y=ceili(ground)+3
	n.columns[Vector2i(x,z)]={added_y:true}; n.voxels[Vector3i(x,added_y,z)]="granite"
	check(is_equal_approx(t.floor_below(x,z,INF),added_y+1.0),"unbounded terrain search includes filled cells")
	check(is_equal_approx(t.floor_below(x,z,1.0e30),added_y+1.0),"huge terrain ceiling is bounded by the column top")
	check(is_equal_approx(t.floor_below(x,z,added_y-0.1),ground),"search below a filled cell still reaches ground")
	plane.place(p,0.0)
	check(is_equal_approx(plane.altitude,added_y+1.0),"the plane rests on edited terrain")
	# A dug-out surface must not return the old natural height or bedrock.
	n.columns.clear(); n.voxels.clear()
	var dug_y=ceili(ground)-1
	n.columns[Vector2i(x,z)]={dug_y:true}; n.voxels[Vector3i(x,dug_y,z)]=""
	check(is_equal_approx(t.floor_below(x,z,INF),t.top_at(x,z)),"unbounded search finds the bottom of a dug surface")
	check(t.floor_below(x,z,NAN)==-INF and t.floor_below(x,z,-INF)==-INF,"invalid terrain ceilings never reach integer conversion")
	check(t.floor_below(x,z,-1.0e30)==-INF,"a ceiling below bedrock has no standing surface")
	check(c.floor_at(p,NAN)==-INF and c.floor_at(p,-INF)==-INF,"invalid building ceilings return no surface")
	check(c.floor_at(Vector2.INF,INF)==-INF,"invalid positions never reach integer conversion")
	# Real cave columns exercise the previously unbounded terrain while-loop.
	t.nature=null
	var cave=Vector2i(99999,0)
	for cx in range(300,1500,3):
		for cz in range(-900,900,9):
			if t.column_has_cave(cx,cz): cave=Vector2i(cx,cz); break
		if cave.x!=99999: break
	check(cave.x!=99999,"a real cave column exists for this regression")
	if cave.x!=99999:
		check(is_equal_approx(t.floor_below(cave.x,cave.y,INF),t.top_at(cave.x,cave.y)),"unbounded cave search returns the actual surface")
		check(is_equal_approx(t.floor_below(cave.x,cave.y,1.0e30),t.top_at(cave.x,cave.y)),"huge cave search returns without traversing empty sky")
	print("PLANE PLACEMENT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
