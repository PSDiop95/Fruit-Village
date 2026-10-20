shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
// Halo / faisceau additif (projecteur, panier illuminé) : aucune lumière dynamique.

uniform vec4 color : source_color = vec4(1.0);
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
// 0 = uniforme, 1 = dégradé vertical (faisceau), 2 = radial (halo).
uniform int falloff = 0;

void fragment() {
	float a = color.a * alpha;
	if (falloff == 1) {
		a *= mix(1.0, 0.25, UV.y);
	} else if (falloff == 2) {
		a *= 1.0 - smoothstep(0.1, 0.5, length(UV - 0.5));
	}
	ALBEDO = color.rgb * a;
}
