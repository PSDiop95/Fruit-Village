shader_type spatial;
// Ombre « tache » (qualité Bas) : disque doux posé sur le fond du panier.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.25, 0.12, 0.05, 0.35);

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = color.rgb;
	ALPHA = color.a * (1.0 - smoothstep(0.78, 1.0, d));
}
