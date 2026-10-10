shader_type spatial;
render_mode cull_back, specular_disabled;
// v0.47 far terrain seen from the plane, with the planet's curvature: every vertex drops by
// d² / 2R below the flat world, where d is its distance from the viewer and R the planet radius
// (16 384 m circumference → R ≈ 2607.6 m). At 1 km the ground is ~190 m below the flat plane,
// so the horizon really bends away from a high flight. Colours come baked per vertex.

uniform vec3 origin = vec3(0.0);
uniform float radius = 2607.6;

varying vec3 tint;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 d = world.xz - origin.xz;
	VERTEX.y -= dot(d, d) / (2.0 * radius);
	tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = tint;
	ROUGHNESS = 0.95;
}
