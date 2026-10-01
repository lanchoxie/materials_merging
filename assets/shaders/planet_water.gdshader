shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
// v0.33 planet water: vertex-coloured (pollution tints come through COLOR), flowing ripples along
// the river, a sky-tinted fresnel rim and sun glints. Slightly see-through so fish read underneath.

uniform float flow = 1.0;
uniform vec4 sky_tint : source_color = vec4(0.78, 0.9, 0.95, 1.0);
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float t = TIME * flow;
	vec3 base = COLOR.rgb * vec3(0.6, 0.76, 0.84);
	vec3 up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float streak = 0.0;
	if (up.y > 0.5) {
		float a = p.x * 3.1 + p.y * 0.7 + t * 1.7;
		float b = p.y * 2.3 - t * 2.6 + p.x * 1.3;
		float w = sin(a) * 0.5 + sin(b) * 0.35 + sin((p.x - p.y) * 5.3 + t * 3.1) * 0.15;
		streak = smoothstep(0.55, 0.95, w);
		vec3 n = normalize(vec3(cos(a) * 0.1 + cos(b) * 0.05, 1.0, cos(b) * 0.12));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	} else {
		base *= 0.8;
	}
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(base, sky_tint.rgb, fres * 0.45) + vec3(streak * 0.1);
	ALPHA = mix(0.8, 0.95, fres);
	ROUGHNESS = 0.16;
	SPECULAR = 0.55;
}
