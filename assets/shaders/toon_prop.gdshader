shader_type spatial;
// Toon des grands props (panier, étal) : mêmes tons que les fruits, mais
// éclairage calculé ici (direction du soleil en paramètre) au lieu du pipeline
// lumière : ces objets couvrent la moitié de l'écran, chaque pixel compte.
render_mode unshaded, shadows_disabled;

uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform vec3 sun_direction = vec3(0.47, -0.47, -0.75); // sens de propagation (monde)
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.77);
uniform float sun_energy = 1.0;
uniform vec3 ambient_color : source_color = vec3(1.0, 0.91, 0.8);
uniform float ambient_energy = 0.3;
uniform float shadow_threshold = 0.05;
uniform float light_threshold = 0.5;
uniform float shadow_tone = 0.45;
uniform float mid_tone = 0.78;
uniform float tone_softness = 0.03;
uniform vec3 shadow_tint : source_color = vec3(0.82, 0.72, 0.9);
uniform float saturation = 1.0;

void fragment() {
	vec3 c = texture(palette, UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = clamp(mix(vec3(lum), c, saturation), 0.0, 1.0);
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float lit = dot(n, -normalize(sun_direction));
	float s = tone_softness;
	float t1 = smoothstep(shadow_threshold - s, shadow_threshold + s, lit);
	float t2 = smoothstep(light_threshold - s, light_threshold + s, lit);
	float tone = mix(mix(shadow_tone, mid_tone, t1), 1.0, t2);
	vec3 tint = mix(shadow_tint, vec3(1.0), t1);
	ALBEDO = c * (sun_color * sun_energy * tone * tint + ambient_color * ambient_energy);
}
