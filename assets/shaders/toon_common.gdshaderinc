// Toon « peint » : 3 tons fondus (tone_softness large = dégradé doux, petit =
// cel dur) + reflet rond + rim chaud + grain de peau procédural (aucune texture).
// Couleur lue dans la palette unique (UV des modèles) ; alpha palette = gloss
// (0 velours, 0.5 mat, 1 brillant ; encodé 0.25 + 0.75 * gloss).
// Inclus par toon.gdshader (TOON_RIM défini) et toon_low.gdshader (sans).
// Paramètres : data/visual.tres (appliqués par FruitModels).

render_mode diffuse_lambert, specular_disabled;

uniform sampler2D palette : source_color, filter_linear, repeat_disable;
uniform float shadow_threshold = 0.05;
uniform float light_threshold = 0.5;
uniform float shadow_tone = 0.45;
uniform float mid_tone = 0.78;
uniform float tone_softness = 0.03;
uniform vec3 shadow_tint : source_color = vec3(0.82, 0.72, 0.9);
uniform float specular_shininess = 48.0;
uniform float specular_threshold = 0.5;
uniform float specular_strength = 0.55;
uniform vec3 rim_color : source_color = vec3(1.0, 0.78, 0.45);
uniform float rim_strength = 0.35;
uniform float rim_power = 3.0;
uniform float velvet_strength = 0.45;
uniform float velvet_power = 1.6;
uniform float specular_softness = 0.02;
// Ombres portées (fruits sur le fond du panier) : ton appliqué dans l'ombre.
uniform float cast_shadow_tone = 0.55;
// Grain de peau : mouchetures fines + marbrures larges (bruit 3D, repère objet).
uniform float grain_strength = 0.0;
uniform float grain_scale = 14.0;
uniform float mottle_strength = 0.0;
uniform float mottle_scale = 2.5;

// Paramètres par instance (M2) : aucun matériau dupliqué par fruit.
instance uniform float flash : hint_range(0.0, 1.0) = 0.0;
instance uniform float gray : hint_range(0.0, 1.0) = 0.0;

varying float v_gloss;
varying vec3 v_obj;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_obj = VERTEX;
}

void fragment() {
	vec4 p = texture(palette, UV);
	vec3 c = p.rgb;
	// Marbrures douces + mouchetures sombres éparses (peau peinte).
	float mottle = noise3(v_obj * mottle_scale) - 0.5;
	float speck = smoothstep(0.72, 0.9, noise3(v_obj * grain_scale + 7.3));
	c *= 1.0 + mottle * mottle_strength - speck * grain_strength;
	v_gloss = clamp((p.a - 0.25) / 0.75, 0.0, 1.0);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * 0.85, gray);
	ALBEDO = mix(c, vec3(1.0), flash);
	ROUGHNESS = 1.0;
	vec3 emit = vec3(flash) * 0.9;
#ifdef TOON_RIM
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	emit += rim_color * pow(fres, rim_power) * rim_strength * c;
	// Velours : duvet clair sur tout le contour.
	float velvet = 1.0 - smoothstep(0.0, 0.3, v_gloss);
	emit += mix(c, vec3(1.0), 0.35) * pow(fres, velvet_power) * velvet_strength * velvet;
#endif
	EMISSION = emit;
}

void light() {
	// LIGHT_COLOR = couleur × énergie × PI (convention Godot 4) : on ramène à 1.
	vec3 lc = LIGHT_COLOR / PI;
	float lit = dot(NORMAL, LIGHT);
	float s = tone_softness;
	float t1 = smoothstep(shadow_threshold - s, shadow_threshold + s, lit);
	float t2 = smoothstep(light_threshold - s, light_threshold + s, lit);
	float tone = mix(shadow_tone, mid_tone, t1);
	tone = mix(tone, 1.0, t2);
	vec3 tint = mix(shadow_tint, vec3(1.0), t1);
	// ATTENUATION = ombre portée (lumière directionnelle) : assombrit franchement.
	float shadowed = 1.0 - clamp(ATTENUATION, 0.0, 1.0);
	tone *= mix(1.0, cast_shadow_tone, shadowed);
	t1 *= 1.0 - shadowed;
	DIFFUSE_LIGHT += lc * tone * tint;
	// Reflet spéculaire (matières satinées/brillantes uniquement).
	float shine = smoothstep(0.5, 1.0, v_gloss);
	vec3 h = normalize(VIEW + LIGHT);
	float sp = pow(max(dot(NORMAL, h), 0.0), specular_shininess);
	float hard = smoothstep(specular_threshold - specular_softness, specular_threshold + specular_softness, sp);
	SPECULAR_LIGHT += lc * hard * specular_strength * shine * t1;
}
