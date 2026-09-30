shader_type spatial;
// v0.25 foliage: leafy material that sways in a gentle breeze. World height above the island
// surface decides how much a vertex moves, so it works batched or not and trunks stay put.

uniform vec4 albedo : source_color = vec4(0.44, 0.67, 0.55, 1.0);
uniform float sway = 0.04;
uniform float ground = 0.3;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float weight = smoothstep(ground, ground + 1.0, world.y);
	float t = TIME * 1.3 + world.x * 0.45 + world.z * 0.3;
	vec3 push = vec3(sin(t) + sin(t * 2.3) * 0.3, 0.0, cos(t * 0.8) * 0.6) * sway * weight;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(push, 0.0)).xyz;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.68;
}
