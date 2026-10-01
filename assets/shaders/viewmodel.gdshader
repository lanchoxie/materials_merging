shader_type spatial;
// v0.33 first-person view model: lit vertex colours, depth squashed toward the near plane so the
// hands sort correctly among their own parts and always draw in front of the world.
// Godot 4.3+ uses reversed depth on every renderer, so the near plane is at z = w.
render_mode cull_back, shadows_disabled;
uniform float glow : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	POSITION.z = mix(POSITION.z, POSITION.w, 0.9);
}

void fragment() {
	ALBEDO = COLOR.rgb * (1.0 - glow * 0.7);
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
	EMISSION = COLOR.rgb * glow;
}
