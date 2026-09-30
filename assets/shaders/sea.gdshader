shader_type spatial;
render_mode specular_schlick_ggx;
// v0.25 stylized sea: deep → shallow by distance to the island (baked mask), drifting foam
// rings along the shore, soft ripple glints. Cheap enough for the compatibility renderer.

uniform vec4 deep_color : source_color = vec4(0.11, 0.34, 0.44, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.45, 0.79, 0.77, 1.0);
uniform vec4 foam_color : source_color = vec4(0.93, 0.98, 0.95, 1.0);
uniform sampler2D shore_mask : filter_linear, repeat_disable;
uniform vec4 mask_rect = vec4(-30.0, -30.0, 60.0, 60.0); // world x, z, width, depth
uniform float use_mask = 1.0;
uniform float night = 0.0;

varying vec3 world_pos;

float ripple(vec2 p, float t) {
	return sin(p.x * 0.9 + t * 0.8) * 0.5 + sin(p.y * 1.3 - t * 0.6) * 0.3 + sin((p.x + p.y) * 2.1 + t * 1.3) * 0.2;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (world_pos.xz - mask_rect.xy) / mask_rect.zw;
	float near = use_mask * texture(shore_mask, uv).r;
	float w = ripple(world_pos.xz * 1.7, TIME * 1.2);
	vec3 base = mix(deep_color.rgb, shallow_color.rgb, smoothstep(0.0, 0.85, near));
	// Foam: two drifting rings hugging the shore, broken up by the ripple field.
	float band = fract(near * 3.2 - TIME * 0.12);
	float foam = smoothstep(0.86, 0.97, band) * smoothstep(0.15, 0.55, near);
	foam += smoothstep(0.9, 0.97, near) * 0.8;
	foam *= 0.55 + 0.45 * smoothstep(-0.2, 0.6, w);
	// Glints on the open sea; moonlit and softer at night.
	float glint = smoothstep(0.82, 0.98, w) * (1.0 - near) * 0.18;
	vec3 color = base + vec3(glint);
	color = mix(color, foam_color.rgb * mix(1.0, 0.6, night), clamp(foam, 0.0, 1.0));
	ALBEDO = color;
	ROUGHNESS = 0.6;
	SPECULAR = 0.2;
	EMISSION = color * night * 0.12;
}
