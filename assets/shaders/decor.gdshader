shader_type spatial;
// Décor : couleur palette, éclairage plat bon marché (pas de light()), estompe
// vers la brume selon la profondeur (perspective atmosphérique simulée, sans
// post-process). Règle : le décor ne concurrence jamais les fruits.
// Ambiances (jour / coucher / nuit) : le dégradé du ciel (rampe ramp_sky,
// dernière ligne de la palette) est remplacé, le reste du décor est étalonné.
render_mode unshaded, shadows_disabled;

uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform vec3 haze_color : source_color = vec3(0.96, 0.87, 0.72);
uniform vec3 light_dir = vec3(-0.55, 0.6, 0.6);
uniform float shade_strength = 0.25;
// Ambiance
uniform bool sky_override = false;
uniform vec3 sky_top : source_color = vec3(0.16, 0.53, 0.86);
uniform vec3 sky_mid : source_color = vec3(0.42, 0.75, 0.95);
uniform vec3 sky_horizon : source_color = vec3(0.79, 0.93, 0.98);
// Ligne de la rampe du ciel dans la palette (UV.y au-delà = ciel).
uniform float sky_row_v = 0.9375;
uniform vec3 grade_mul = vec3(1.0);
uniform vec3 grade_add = vec3(0.0);
// Par instance (un plan = une instance) : 0 net, 1 fondu dans la brume.
instance uniform float fade = 0.4;
instance uniform float desaturate = 0.3;

void fragment() {
	if (sky_override && UV.y > sky_row_v) {
		float t = UV.x;
		vec3 s = t < 0.6 ? mix(sky_top, sky_mid, t / 0.6) : mix(sky_mid, sky_horizon, (t - 0.6) / 0.4);
		ALBEDO = s;
	} else {
		vec3 c = texture(palette, UV).rgb;
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, vec3(l), desaturate);
		vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float shade = 1.0 - shade_strength + shade_strength * clamp(dot(n, normalize(light_dir)), 0.0, 1.0);
		ALBEDO = mix(c * shade * grade_mul + grade_add, haze_color, fade);
	}
}
