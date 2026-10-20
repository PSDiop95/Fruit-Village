shader_type canvas_item;
// Vignette rouge de danger : transparente au centre, colorée sur les bords.

uniform vec4 tint : source_color = vec4(0.85, 0.05, 0.05, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float inner = 0.35;
uniform float outer = 0.95;

void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.0, 1.25);
	float v = smoothstep(inner, outer, length(d) * 1.6);
	COLOR = vec4(tint.rgb, tint.a * v * intensity);
}
