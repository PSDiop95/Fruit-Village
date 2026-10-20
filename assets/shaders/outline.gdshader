shader_type spatial;
// Contour par coque inversée : la face arrière est extrudée puis dessinée unie.
// Caméra orthographique : épaisseur monde = épaisseur écran constante.
render_mode unshaded, cull_front, shadows_disabled;

uniform float outline_width = 0.035;
uniform vec4 outline_color : source_color = vec4(0.227, 0.141, 0.078, 1.0);
// 1 = extrusion radiale (depuis l'origine du modèle), 0 = le long des normales.
// Par instance : réglé par fruit (VisualConfig.outline_normal_ids).
instance uniform float outline_radial = 1.0;

void vertex() {
	vec3 dir = normalize(mix(NORMAL, normalize(VERTEX + vec3(1e-5)), outline_radial));
	// Compense l'échelle du nœud (rayon, squash) pour garder l'épaisseur monde.
	float sc = length(MODEL_MATRIX[0].xyz);
	VERTEX += dir * outline_width / max(sc, 1e-4);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
