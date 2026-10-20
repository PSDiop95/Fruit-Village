shader_type spatial;
// Placeholder M2 : couleur unie + flash blanc (fusion) + gris (game over).
// Paramètres par instance : aucun matériau dupliqué par fruit.

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.55;
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;
instance uniform float gray : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 c = albedo.rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * 0.85, gray);
	ALBEDO = mix(c, vec3(1.0), flash);
	EMISSION = vec3(flash) * 0.9;
	ROUGHNESS = roughness;
}
