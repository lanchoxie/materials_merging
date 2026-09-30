shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;
// v0.25 reactor chamber: faint glass with a bright fresnel rim and a slow rising shimmer.

uniform vec4 tint : source_color = vec4(0.66, 0.92, 0.90, 1.0);
uniform float base_alpha = 0.08;
uniform float rim_alpha = 0.45;
uniform float glow = 0.0;

varying float height;

void vertex() {
	height = VERTEX.y;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - facing, 2.5);
	float shimmer = smoothstep(0.92, 1.0, sin(height * 5.0 - TIME * 1.6) * 0.5 + 0.5) * 0.12;
	ALBEDO = mix(tint.rgb, vec3(1.0), rim * 0.5) * (1.0 + glow * 0.6);
	ALPHA = clamp(base_alpha + rim * rim_alpha + shimmer + glow * 0.06, 0.0, 0.9);
}
