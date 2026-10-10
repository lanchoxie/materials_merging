extends RefCounted
## v0.42 蓝色星球: the planet's shape. The surface is a locally flat block world that wraps
## east–west (circumference 16 384 m) and runs from the north polar cap (z −7600) to the south
## polar cap (z +7600); the equator lies at z +2600, so home sits near 23°N. Continents come
## from noise that is exactly periodic in longitude, and the date-line seam is always deep ocean,
## so crossing it is seamless. All functions are pure and static (same inputs, same world).
const CIRC=16384.0
const HALF=8192.0
const NORTH=-7600.0
const SOUTH=7600.0
const EQUATOR=2600.0
const SEA_LEVEL=0.2

static func wrap_x(x: float) -> float:
	return fposmod(x+HALF,CIRC)-HALF

## Shortest east–west offset from a to b on the wrapped surface.
static func dx(a: float,b: float) -> float:
	return wrap_x(b-a)

static func latitude(z: float) -> float:
	if z<=EQUATOR: return clampf((EQUATOR-z)/(EQUATOR-NORTH)*90.0,0.0,90.0)
	return -clampf((z-EQUATOR)/(SOUTH-EQUATOR)*90.0,0.0,90.0)

static func longitude(x: float) -> float:
	return wrap_x(x)/HALF*180.0

static func z_for_latitude(lat: float) -> float:
	return EQUATOR-lat/90.0*(EQUATOR-NORTH) if lat>=0.0 else EQUATOR-lat/90.0*(SOUTH-EQUATOR)

static func x_for_longitude(lon: float) -> float:
	return lon/180.0*HALF

static func on_surface(p: Vector2,margin: float=0.0) -> bool:
	return p.y>=NORTH+60.0+margin and p.y<=SOUTH-60.0-margin

## Continent field: > 0 is land. Periodic in x (whole-number harmonics of the circumference).
static func continent(x: float,z: float) -> float:
	x=wrap_x(x)
	var t=x/CIRC*TAU
	var n=0.55*sin(t+0.7+z*0.00031)+0.38*sin(t*3.0-1.1+z*0.0007)+0.26*cos(t*5.0+2.0-z*0.0011)
	n+=0.20*sin(z*0.0009+cos(t*2.0)*1.5)+0.12*sin(t*11.0+z*0.0021)+0.07*cos(t*23.0-z*0.0043)
	n-=0.10
	# Home stays on a continent; the date line is open ocean.
	var home=Vector2(x,z).length()
	n+=1.1*(1.0-smoothstep(900.0,3600.0,home))
	n-=1.8*smoothstep(6800.0,7900.0,absf(x))
	return n

static func is_ocean(x: float,z: float) -> bool:
	return continent(x,z)<0.0

## Sea floor depth below sea level (metres, positive): a wadeable shelf at the shore, then
## deeper away from the coast.
static func ocean_depth(c: float) -> float:
	return 0.5+3.0*smoothstep(0.0,0.08,-c)+14.5*smoothstep(0.05,0.6,-c)

## 0 on the shoreline, 1 a little inland: beaches and low coasts.
static func coast(c: float) -> float:
	return smoothstep(0.0,0.10,c)

## Mountain ranges inside continents, kept away from home. Ridged folds, up to ~55 m.
static func mountains(x: float,z: float,c: float) -> float:
	x=wrap_x(x)
	var t=x/CIRC*TAU
	var fold=1.0-absf(sin(t*4.0+z*0.0013+sin(z*0.0005)*2.0)*cos(z*0.0021-cos(t*3.0)*1.4))
	var range_mask=smoothstep(0.18,0.5,c)*smoothstep(1500.0,3200.0,Vector2(x,z).length())
	return floor(60.0*pow(fold,5.0)*range_mask)

## 「北纬23.1° 东经0.1°」 for a ground position.
static func coordinates(p: Vector2) -> String:
	var lat=latitude(p.y); var lon=longitude(p.x)
	return "%s%.1f° %s%.1f°" % ["北纬" if lat>=0.0 else "南纬",absf(lat),"东经" if lon>=0.0 else "西经",absf(lon)]

static func polar(z: float) -> float:
	return smoothstep(68.0,80.0,absf(latitude(z)))
