extends RefCounted
## v0.32 Earth: a coarse climate field over the 16 km world. The baseline is a deterministic
## formula and is never saved; only what the player changed (cell deltas, atmosphere) is.
var rules: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/planet_environment.json"))
const Shape=preload("res://scripts/planet_shape.gd")
var size=64
var cell=256.0
var origin=-8192.0
var base_water=PackedFloat32Array()
var base_heat=PackedFloat32Array()
var base_food=PackedFloat32Array()
## "cx:cz" -> [water, temperature, nutrients, pollution]
var deltas: Dictionary={}
var o2=20.9
var co2=420.0
## Render bookkeeping, rebuilt from state; never saved.
var versions: Dictionary={}
var global_version=0
var revision=0
var _quant: Dictionary={}
var _warm_step=0
var _emitters: Dictionary={}
var _counts: Dictionary={}
var _seen_build=-1
var _shift=0.0
## v0.39: the timeline's climate offset (冰河期 −16 °C); constant per planet instance, never saved here.
var epoch_offset=0.0

func _init() -> void:
	size=int(rules.grid); cell=float(rules.cell_size); origin=float(rules.origin)
	o2=float(rules.baseline.o2); co2=float(rules.baseline.co2)
	base_water.resize(size*size); base_heat.resize(size*size); base_food.resize(size*size)
	for j in range(size):
		for i in range(size):
			var b=baseline(origin+(i+0.5)*cell,origin+(j+0.5)*cell)
			base_water[j*size+i]=b.x; base_heat[j*size+i]=b.y; base_food[j*size+i]=b.z

## Water falls to the east, cold rises to the north (−z), and sine noise breaks the bands up.
## Inside the start area everything is the old constant river-bend climate.
func baseline(x: float,z: float) -> Vector3:
	var b: Dictionary=rules.baseline
	var k=clampf((Vector2(x,z).length()-float(b.calm_radius))/float(b.ramp),0,1)
	var n1=sin(x/900+0.7)*cos(z/1100-0.4)+0.5*sin((x+z)/530+2.1)
	var n2=cos(x/760-1.2)*sin(z/840+0.9)+0.5*cos((x-z)/610)
	var n3=sin(x/390+z/510+0.3)
	var w=clampf(float(b.water)+k*(0.30*n2-0.22*clampf(x/5000,-1,1)),0,1)
	# v0.42: temperature follows latitude (both hemispheres), not distance north of home.
	var L: Dictionary=rules.latitude
	var lat_t=float(L.equator)-float(L.pole_drop)*pow(absf(Shape.latitude(z))/90.0,float(L.exponent))
	var t=lerpf(float(b.temperature),lat_t+5*n1,k)
	var n=clampf(float(b.nutrients)+k*(0.16*n3+0.3*(w-float(b.water))),0,1)
	return Vector3(w,t,n)

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(floori((p.x-origin)/cell),0,size-1),clampi(floori((p.y-origin)/cell),0,size-1))

func cell_center(c: Vector2i) -> Vector2:
	return Vector2(origin+(c.x+0.5)*cell,origin+(c.y+0.5)*cell)

func _key(c: Vector2i) -> String:
	return "%d:%d" % [c.x,c.y]

## Global warming from CO₂, 3 °C per doubling (compressed in time).
func warming() -> float:
	return float(rules.climate.sensitivity_c_per_doubling)*log(co2/float(rules.baseline.co2))/log(2.0)

## Crop growth factor from CO₂ fertilisation (game cap).
func co2_growth() -> float:
	return clampf(1.0+0.25*log(co2/float(rules.baseline.co2))/log(2.0),1.0,1.0+float(rules.climate.co2_growth_max))

## Effective [water, temperature, nutrients, pollution] for a cell, including warming.
func values(c: Vector2i) -> Vector4:
	var i=c.y*size+c.x; var d=deltas.get(_key(c))
	var w=base_water[i]; var t=base_heat[i]+_shift; var n=base_food[i]; var p=0.0
	if d!=null:
		w=clampf(w+float(d[0]),0,1); t+=float(d[1]); n=clampf(n+float(d[2]),0,1); p=clampf(float(d[3]),0,1)
	return Vector4(w,t,n,p)

func biome_of(v: Vector4) -> String:
	if v.y<-6.0: return "ice"
	if v.y<2.0: return "tundra"
	if v.x<0.25: return "desert"
	if v.x>0.78: return "wetland"
	if v.x>=0.45 and v.z>0.46 and v.y>5.0 and v.y<28.0: return "forest"
	return "grassland"

func biome_at(p: Vector2) -> String:
	if Shape.is_ocean(p.x,p.y) and Shape.on_surface(p): return "ocean"
	return biome_of(values(cell_of(p)))

func biome_name(id: String) -> String:
	return str(rules.biomes[id].name)

## Bilinear between cell centres, for smooth ground colours.
func blend(p: Vector2) -> Vector4:
	var fx=(p.x-origin)/cell-0.5; var fz=(p.y-origin)/cell-0.5
	var i0=floori(fx); var j0=floori(fz); var tx=fx-i0; var tz=fz-j0
	var a=values(Vector2i(clampi(i0,0,size-1),clampi(j0,0,size-1)))
	var b=values(Vector2i(clampi(i0+1,0,size-1),clampi(j0,0,size-1)))
	var c=values(Vector2i(clampi(i0,0,size-1),clampi(j0+1,0,size-1)))
	var d=values(Vector2i(clampi(i0+1,0,size-1),clampi(j0+1,0,size-1)))
	return a.lerp(b,tx).lerp(c.lerp(d,tx),tz)

## Ground colour: the season's grass shifted by dryness, wetness, richness, cold, heat and pollution.
## The untouched start area keeps the plain season colour.
func tint(v: Vector4,grass: Color) -> Color:
	var c=grass
	var dry=smoothstep(0.34,0.18,v.x); c=c.lerp(Color("d6c08a"),dry)
	c=c.lerp(Color("4f8466"),smoothstep(0.70,0.88,v.x)*0.7)
	c=c.lerp(Color("4c8a43"),clampf((v.z-0.45)*3,0,1)*(1-dry)*0.45)
	c=c.lerp(Color("eef3f4"),smoothstep(4.0,-1.0,v.y)*0.9)
	c=c.lerp(Color("c9a46a"),smoothstep(30.0,38.0,v.y)*0.5)
	return c.lerp(Color("8a8f6a"),v.w*0.8)

## What a wild site lives in. At the start area this matches the old constant wild environment.
func habitat(p: Vector2) -> Dictionary:
	var v=values(cell_of(p))
	return {"moisture":clampf(v.x*1.05,0,1),"water":v.x*0.64,"temperature":v.y,"pollution":v.w,"enclosed":false,"oxygen":0.55*(o2/float(rules.baseline.o2))}

## Local temperature shift (machines only) for the home regions; warming is added separately.
func local_heat(p: Vector2) -> float:
	var d=deltas.get(_key(cell_of(p)))
	return 0.0 if d==null else float(d[1])

func chunk_version(p: Vector2) -> int:
	var c=cell_of(p); var total=global_version*7919
	for dz in range(-1,2):
		for dx in range(-1,2): total+=int(versions.get(c+Vector2i(dx,dz),0))
	return total

## Machines by cell, recounted only when construction changes.
func _scan(construction) -> void:
	if construction==null or construction.revision==_seen_build: return
	_seen_build=construction.revision; _emitters={}; _counts={}
	for b in construction.blocks.values():
		var kind=str(b.kind)
		if not rules.emitters.has(kind): continue
		var c=cell_of(Vector2(b.x,b.z))
		if not _emitters.has(c): _emitters[c]={}
		_emitters[c][kind]=int(_emitters[c].get(kind,0))+1
		_counts[kind]=int(_counts.get(kind,0))+1

func machines() -> Dictionary:
	return _emitters

func machine_count(kind: String) -> int:
	return int(_counts.get(kind,0))

func tick(construction) -> void:
	_scan(construction)
	var caps: Dictionary=rules.caps; var climate: Dictionary=rules.climate; var e: Dictionary=rules.emitters
	var o2_target=float(rules.baseline.o2)+minf(float(caps.o2),machine_count("oxygen_tower")*float(e.oxygen_tower.o2))
	var co2_target=float(rules.baseline.co2)+minf(float(caps.co2),machine_count("co2_tower")*float(e.co2_tower.co2))
	o2+=(o2_target-o2)/float(climate.atmosphere_tau)
	co2+=(co2_target-co2)/float(climate.atmosphere_tau)
	if absf(o2-o2_target)<0.0005: o2=o2_target
	if absf(co2-co2_target)<0.01: co2=co2_target
	_shift=warming()+epoch_offset
	var targets={}
	for c in _emitters:
		var push=[0.0,0.0,0.0,0.0]
		for kind in _emitters[c]:
			var spec: Dictionary=e[kind]; var n=float(_emitters[c][kind])
			push[0]+=float(spec.get("water",0))*n; push[1]+=float(spec.get("temperature",0))*n
			push[2]+=float(spec.get("nutrients",0))*n; push[3]+=float(spec.get("pollution",0))*n
		for offset in [Vector2i.ZERO,Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var at: Vector2i=c+offset
			if at.x<0 or at.y<0 or at.x>=size or at.y>=size: continue
			var share=1.0 if offset==Vector2i.ZERO else float(climate.neighbour_share)
			var k=_key(at)
			if not targets.has(k): targets[k]=[0.0,0.0,0.0,0.0]
			for i in range(4): targets[k][i]+=push[i]*share
	var limits=[float(caps.water),float(caps.temperature),float(caps.nutrients),float(caps.pollution)]
	var tau=float(climate.local_tau)
	var keys=deltas.keys()
	for k in targets:
		if not deltas.has(k): keys.append(k)
	for k in keys:
		var d: Array=deltas.get(k,[0.0,0.0,0.0,0.0]); var goal: Array=targets.get(k,[0.0,0.0,0.0,0.0])
		var still=true
		for i in range(4):
			var aim=clampf(float(goal[i]),-limits[i],limits[i])
			d[i]=float(d[i])+(aim-float(d[i]))/tau
			if absf(d[i]-aim)<0.0005: d[i]=aim
			if absf(d[i])>0.0005 or aim!=0.0: still=false
		if still: deltas.erase(k)
		else: deltas[k]=d
		_requantise(k)
	var step=roundi(warming()*2.0)
	if step!=_warm_step: _warm_step=step; global_version+=1; revision+=1

func _requantise(k: String) -> void:
	var parts=k.split(":"); var c=Vector2i(int(parts[0]),int(parts[1]))
	var v=values(c); var q=[roundi(v.x*20),roundi((v.y-_shift)*2),roundi(v.z*20),roundi(v.w*20)]
	if q!=_quant.get(c,null):
		_quant[c]=q; versions[c]=int(versions.get(c,0))+1; revision+=1

func serialize() -> Dictionary:
	return {"version":1,"o2":o2,"co2":co2,"cells":deltas.duplicate(true)}

func _num(v,lo: float,hi: float) -> bool:
	return (v is float or v is int) and is_finite(float(v)) and float(v)>=lo and float(v)<=hi

func restore(data) -> bool:
	if not data is Dictionary or data.get("version")!=1 or not data.get("cells") is Dictionary: return false
	var caps: Dictionary=rules.caps
	if not _num(data.get("o2"),float(rules.baseline.o2)-0.01,float(rules.baseline.o2)+float(caps.o2)+0.01): return false
	if not _num(data.get("co2"),float(rules.baseline.co2)-0.1,float(rules.baseline.co2)+float(caps.co2)+0.1): return false
	if data.cells.size()>size*size: return false
	var limits=[float(caps.water),float(caps.temperature),float(caps.nutrients),float(caps.pollution)]
	var cells={}
	for k in data.cells:
		var parts=str(k).split(":")
		if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return false
		var c=Vector2i(int(parts[0]),int(parts[1]))
		if c.x<0 or c.y<0 or c.x>=size or c.y>=size or _key(c)!=k: return false
		var d=data.cells[k]
		if not d is Array or d.size()!=4: return false
		for i in range(4):
			if not _num(d[i],-limits[i]-0.0001,limits[i]+0.0001): return false
		cells[k]=[float(d[0]),float(d[1]),float(d[2]),float(d[3])]
	deltas=cells; o2=float(data.o2); co2=float(data.co2)
	versions={}; _quant={}; _seen_build=-1; _shift=warming(); _warm_step=roundi(_shift*2.0)
	global_version+=1; revision+=1
	for k in deltas: _requantise(k)
	return true

## One-line atmosphere summary for HUDs.
func atmosphere_text() -> String:
	return "O₂ %.1f%% · CO₂ %d ppm · 升温 %+.1f°C" % [o2,roundi(co2),warming()]
