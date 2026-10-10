extends RefCounted
## v0.42 地球仪: the whole planet painted from the same functions as the ground — continents and
## sea depth (planet_shape), mountains, biomes and temperature from the climate field, polar ice.
## One colour function; an equirectangular image for the globe and an x/z image for the map.
const Shape=preload("res://scripts/planet_shape.gd")
const BIOME_COLORS={"tundra":Color("dfe8ea"),"desert":Color("d6c38c"),"wetland":Color("4f8a74"),"forest":Color("3d7a44"),"grassland":Color("86a865"),"ice":Color("f4f8fa"),"ocean":Color("2c6d8f")}
static var _cache: Dictionary={}

static func color_at(env,x: float,z: float) -> Color:
	var cont=Shape.continent(x,z)
	if cont<0.0:
		var deep=smoothstep(0.0,0.6,-cont)
		var sea=Color("3d8fb0").lerp(Color("1b4d6e"),deep)
		if absf(Shape.latitude(z))>74.0: sea=sea.lerp(Color("e8f1f4"),smoothstep(74.0,82.0,absf(Shape.latitude(z))))
		return sea
	var v: Vector4=env.blend(Vector2(x,z))
	var c: Color=BIOME_COLORS.get(env.biome_of(v),Color("86a865"))
	if cont<0.1: c=c.lerp(Color("d9c9a0"),1.0-cont/0.1)
	var m=Shape.mountains(x,z,cont)
	if m>0.0:
		c=c.lerp(Color("8a8378"),clampf(m/40.0,0.0,0.75))
		if m>=34.0: c=c.lerp(Color("f2f5f6"),0.8)
	return c

## Equirectangular texture (longitude across, latitude down), cached per size and climate offset.
static func equirect(env,w: int=256,h: int=128) -> ImageTexture:
	var key="eq:%d:%d:%.1f" % [w,h,float(env.epoch_offset)]
	if _cache.has(key): return _cache[key]
	var image=Image.create(w,h,false,Image.FORMAT_RGB8)
	for j in range(h):
		var lat=90.0-(j+0.5)/h*180.0; var z=Shape.z_for_latitude(lat)
		for i in range(w):
			var lon=-180.0+(i+0.5)/w*360.0
			image.set_pixel(i,j,color_at(env,Shape.x_for_longitude(lon),z))
	# Cubic upsampling smooths the 64 m texels without paying for four times the samples.
	image.resize(w*2,h*2,Image.INTERPOLATE_CUBIC)
	var tex=ImageTexture.create_from_image(image); _cache[key]=tex
	return tex

## The flat map: x from −8192 to 8192 across, z from the north cap to the south cap down.
static func flat(env,w: int=256,h: int=240) -> ImageTexture:
	var key="flat:%d:%d:%.1f" % [w,h,float(env.epoch_offset)]
	if _cache.has(key): return _cache[key]
	var image=Image.create(w,h,false,Image.FORMAT_RGB8)
	for j in range(h):
		var z=Shape.NORTH+(j+0.5)/h*(Shape.SOUTH-Shape.NORTH)
		for i in range(w):
			image.set_pixel(i,j,color_at(env,-Shape.HALF+(i+0.5)/w*Shape.CIRC,z))
	image.resize(w*2,h*2,Image.INTERPOLATE_CUBIC)
	var tex=ImageTexture.create_from_image(image); _cache[key]=tex
	return tex

## A unit-sphere point for a longitude/latitude, matching the UVs of `sphere_mesh`.
static func sphere_point(lon: float,lat: float,radius: float=1.0) -> Vector3:
	var a=deg_to_rad(lon); var b=deg_to_rad(lat)
	return Vector3(cos(b)*sin(a),sin(b),cos(b)*cos(a))*radius

static func sphere_mesh(radius: float,material: Material,rings: int=48,segments: int=96) -> ArrayMesh:
	var st=SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); st.set_material(material)
	for r in range(rings):
		for s in range(segments):
			var corners=[[r,s],[r,s+1],[r+1,s+1],[r+1,s]]
			var pts=[]; var uvs=[]
			for c in corners:
				var lat=90.0-float(c[0])/rings*180.0; var lon=-180.0+float(c[1])/segments*360.0
				pts.append(sphere_point(lon,lat,radius)); uvs.append(Vector2(float(c[1])/segments,float(c[0])/rings))
			for idx in [0,1,2,0,2,3]:
				st.set_uv(uvs[idx]); st.set_normal(pts[idx].normalized()); st.add_vertex(pts[idx])
	return st.commit()
