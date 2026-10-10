extends SceneTree
## v0.42 蓝色星球 (user request): one big wrap-around planet instead of fixed places. Continents and
## oceans, a shallow shelf then deep sea, mountain ranges of granite with a tree line and snow,
## climate by latitude with polar ice, trees by climate, a globe texture, and no far landmarks.
const Shape=preload("res://scripts/planet_shape.gd")
const Globe=preload("res://scripts/planet_globe.gd")
const PlanetV2=preload("res://scripts/planet_v2.gd")
const Stream=preload("res://scripts/river_chunk_stream.gd")
const Geology=preload("res://scripts/planet_geology.gd")
var checks=0
var failures=[]

func check(ok: bool,msg: String) -> void:
	checks+=1
	if not ok: failures.append(msg); push_error(msg)

func _initialize() -> void:
	# --- Shape: wrap, latitude, longitude.
	check(is_equal_approx(Shape.wrap_x(8192.0+10.0),-8182.0) and is_equal_approx(Shape.wrap_x(-8200.0),8184.0),"x wraps around the 16 384 m circumference")
	check(is_equal_approx(Shape.latitude(Shape.EQUATOR),0.0) and is_equal_approx(Shape.latitude(Shape.NORTH),90.0) and is_equal_approx(Shape.latitude(Shape.SOUTH),-90.0),"equator 0°, poles ±90°")
	check(absf(Shape.latitude(Shape.z_for_latitude(-37.0))+37.0)<0.001 and absf(Shape.longitude(Shape.x_for_longitude(120.0))-120.0)<0.001,"latitude and longitude invert")
	check(Shape.coordinates(Vector2(10,15)).begins_with("北纬") and Shape.latitude(15.0)>20.0,"home sits in the northern subtropics (%s)" % Shape.coordinates(Vector2(10,15)))
	check(absf(Shape.dx(8100.0,-8100.0)-184.0)<0.01 and absf(Shape.dx(-8100.0,8100.0)+184.0)<0.01,"east–west offset takes the short way across the seam")
	# --- Continents: periodic, home on land, the seam is ocean, a sensible share of land.
	var periodic=true
	for i in range(20):
		var x=-8000.0+i*800.0; var z=-7000.0+i*700.0
		if absf(Shape.continent(x,z)-Shape.continent(x+Shape.CIRC,z))>0.0001: periodic=false
	check(periodic,"the continent field repeats exactly every circumference")
	check(not Shape.is_ocean(0,0) and not Shape.is_ocean(10,15),"home is on land")
	var seam_sea=true
	for z in range(-7000,7001,500):
		if not Shape.is_ocean(8150.0,float(z)) or not Shape.is_ocean(-8150.0,float(z)): seam_sea=false
	check(seam_sea,"the date line is open ocean all the way down")
	var land=0; var total=0
	for i in range(64):
		for j in range(48):
			total+=1
			if not Shape.is_ocean(-8192.0+(i+0.5)*256.0,Shape.NORTH+(j+0.5)*(Shape.SOUTH-Shape.NORTH)/48.0): land+=1
	check(land>total*0.28 and land<total*0.6,"28–60 %% of the surface is land (%.0f %%)" % (100.0*land/total))
	# --- Ground: sea floor, shallow shelf, deep water blocks walking, polar edge.
	var v=PlanetV2.new(); var t=v.construction.terrain
	var shore=Vector2.INF
	for i in range(1,900):
		var p=Vector2(-i*8.0,445.0)
		if Shape.is_ocean(p.x,p.y): shore=p; break
	check(shore!=Vector2.INF,"walking west from home reaches a coast")
	var shelf=shore+Vector2(-3,0); var deep=Vector2.INF
	for i in range(1,1200):
		var p=shore+Vector2(-i*8.0,0)
		if Shape.continent(p.x,p.y)<-0.3: deep=p; break
	check(t.natural_height(shelf)<0.0 and t.water_at(shelf) and not t.deep_water(shelf) and not t.blocked(shelf,[]),"the shelf is shallow, wet and wadeable (%.1f m)" % t.natural_height(shelf))
	check(t.natural_height(deep)<-3.0 and t.deep_water(deep) and t.blocked(deep,[]),"open sea is deep and blocks walking (%.1f m)" % t.natural_height(deep))
	check(v.environment.biome_at(deep)=="ocean","the open sea is the ocean biome")
	check(t.inside(Vector2(0,Shape.SOUTH-200.0)) and not t.inside(Vector2(0,Shape.SOUTH+10.0)) and not t.inside(Vector2(0,Shape.NORTH-10.0)),"the surface ends at the polar caps")
	check(t.inside(Vector2(7000,1000)) and t.inside(Vector2(-7000,-3000)),"the old 8 km disc edge is gone")
	# --- The sea is drawn, also at negative coordinates (regression: −1 was used as "no run").
	var s=Stream.new(); s.terrain=t; s.material=StandardMaterial3D.new(); s.water_material=StandardMaterial3D.new()
	var west=s._build(t.chunk_at(shore+Vector2(-40,0)))
	check(west!=null and west.get_surface_count()==2,"a sea chunk west of home has a water surface")
	var east_sea=Vector2.INF
	for i in range(1,1000):
		var p=Vector2(i*8.0,445.0)
		if Shape.is_ocean(p.x,p.y) and Shape.continent(p.x,p.y)<-0.05: east_sea=p; break
	var east=s._build(t.chunk_at(east_sea)) if east_sea!=Vector2.INF else null
	check(east!=null and east.get_surface_count()==2,"a sea chunk east of home has a water surface")
	s.free()
	# --- Mountains: tall granite ranges with a tree line, snow on top, none at home.
	var peak=Vector2.ZERO; var tallest=0.0
	for x in range(-80,81,2):
		for z in range(-72,73,2):
			var q=Vector2(x*100,z*100); var m=Shape.mountains(q.x,q.y,Shape.continent(q.x,q.y))
			if m>tallest: tallest=m; peak=q
	check(tallest>=40.0,"ranges rise above 40 m (%.0f m)" % tallest)
	check(Shape.mountains(0,0,Shape.continent(0,0))==0.0 and Shape.mountains(300,300,Shape.continent(300,300))==0.0,"no ranges around home")
	check(Geology.natural(Vector3i(0,20,0),30.0,false)=="granite" and Geology.natural(Vector3i(0,29,0),30.0,false)=="topsoil","mountain rock is granite under topsoil")
	var trees_on_range=0
	for tree in t.chunk_tree_origins(t.chunk_at(peak)):
		if Shape.mountains(tree.x,tree.y,Shape.continent(tree.x,tree.y))>20.0: trees_on_range+=1
	check(trees_on_range==0,"no trees above the tree line")
	var sea_caves=0; var range_caves=0
	for i in range(0,120,3):
		for j in range(0,120,3):
			if t.column_has_cave(int(deep.x)+i,int(deep.y)+j): sea_caves+=1
			if t.column_has_cave(int(peak.x)-60+i,int(peak.y)-60+j): range_caves+=1
	check(sea_caves==0 and range_caves>0,"caves run through the ranges, never under the sea (%d)" % range_caves)
	check(Color(Globe.color_at(v.environment,peak.x,peak.y)).get_luminance()>0.45 or tallest<34.0,"the globe paints the highest peaks pale")
	# --- Climate by latitude.
	var warm=v.environment.baseline(0.0,Shape.EQUATOR).y; var mid=v.environment.baseline(0.0,Shape.z_for_latitude(50.0)).y; var cold=v.environment.baseline(0.0,Shape.z_for_latitude(85.0)).y
	var south=v.environment.baseline(0.0,Shape.z_for_latitude(-50.0)).y
	check(warm>mid and mid>cold,"colder toward the pole (%.1f > %.1f > %.1f °C)" % [warm,mid,cold])
	check(absf(mid-south)<6.0,"both hemispheres cool alike (%.1f vs %.1f °C)" % [mid,south])
	var polar_land=Vector2.INF
	for x in range(-7000,7001,250):
		var q=Vector2(x,Shape.z_for_latitude(84.0))
		if not Shape.is_ocean(q.x,q.y): polar_land=q; break
	check(polar_land==Vector2.INF or v.environment.biome_at(polar_land) in ["ice","tundra"],"polar land is ice or tundra")
	check(v.environment.biome_name("ice")!="" and v.environment.biome_name("ocean")!="","ice and ocean biomes have names")
	# --- Trees follow the climate; none in the sea.
	var cold_spot=Vector2.INF; var warm_spot=Vector2.INF
	for x in range(-6000,6001,200):
		for lat in [62.0,8.0]:
			var q=Vector2(x,Shape.z_for_latitude(lat))
			if Shape.continent(q.x,q.y)<0.2 or q.length()<400.0: continue
			var temp=float(v.environment.values(v.environment.cell_of(q)).y)
			if temp<6.0 and cold_spot==Vector2.INF: cold_spot=q
			if temp>13.0 and warm_spot==Vector2.INF: warm_spot=q
	check(cold_spot!=Vector2.INF and v.nature.species_at(cold_spot)=="pine","cold woods are conifers")
	var warm_kinds={}
	if warm_spot!=Vector2.INF:
		for k in range(12): warm_kinds[v.nature.species_at(warm_spot+Vector2(k*3.3,k*6.6))]=true
	check(warm_kinds.has("oak") and not warm_kinds.has("pine"),"warm woods are oak and birch (%s)" % str(warm_kinds.keys()))
	check(t.chunk_tree_origins(t.chunk_at(deep)).is_empty(),"no trees grow in the sea")
	# --- No far landmarks.
	check(t.LANDMARKS.keys()==["home","homestead"],"only home and its gathering slope remain as fixed places")
	# --- Globe texture and sphere.
	var tex=Globe.equirect(v.environment)
	check(tex.get_width()==512 and tex.get_height()==256 and Globe.equirect(v.environment)==tex,"the globe texture is 512×256 and cached")
	var sea_color: Color=Globe.color_at(v.environment,deep.x,deep.y)
	check(sea_color.b>sea_color.r+0.15,"the sea is blue on the globe")
	check(Globe.sphere_point(0,90).is_equal_approx(Vector3.UP) and Globe.sphere_point(90,0).is_equal_approx(Vector3.RIGHT),"sphere points match the texture layout")
	check(Globe.sphere_mesh(1.0,StandardMaterial3D.new(),8,16).get_surface_count()==1,"the globe mesh builds")
	var flat=Globe.flat(v.environment)
	check(flat.get_width()==512,"the flat world map texture builds")
	# --- Walker wraps east–west.
	var w=v.construction.terrain
	var walker=preload("res://scripts/river_walker.gd").new(w)
	walker.position=Vector2(8195.0,1000.0); walker.step(0.0)
	check(absf(walker.position.x-(-8189.0))<0.01,"the walker wraps across the date line (%.1f)" % walker.position.x)
	if failures.is_empty(): print("GLOBE OK (%d checks)" % checks); quit(0)
	else: print("GLOBE FAILED: ",failures); quit(1)
