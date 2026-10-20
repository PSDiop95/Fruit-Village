shader_type spatial;
// Décor : couleur palette, éclairage plat bon marché (pas de light()), estompe
// vers la brume selon la profondeur (perspective atmosphérique simulée, sans
// post-process). Règle : le décor ne concurrence jamais les fruits.
render_mode unshaded, shadows_disabled;

uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform vec3 haze_color : source_color = vec3(0.96, 0.87, 0.72);
uniform vec3 light_dir = vec3(-0.55, 0.6, 0.6);
uniform float shade_strength = 0.25;
// Par instance (un plan = une instance) : 0 net, 1 fondu dans la brume.
instance uniform float fade = 0.4;
instance uniform float desaturate = 0.3;

void fragment() {
	vec3 c = texture(palette, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l), desaturate);
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float shade = 1.0 - shade_strength + shade_strength * clamp(dot(n, normalize(light_dir)), 0.0, 1.0);
	ALBEDO = mix(c * shade, haze_color, fade);
}
