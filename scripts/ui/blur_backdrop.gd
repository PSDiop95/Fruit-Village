class_name BlurBackdrop
extends ColorRect
## Voile plein écran qui floute et assombrit ce qui est derrière (réglages,
## pause, fin de partie). Flou : 13 échantillons de l'écran (mipmaps), fondu
## d'apparition. Fonctionne sur les renderers Mobile et Compatibility.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 2.6;
uniform float radius = 0.012;
uniform vec4 tint : source_color = vec4(0.16, 0.09, 0.04, 0.42);
uniform float amount = 1.0;
const vec2 TAPS[12] = vec2[](
	vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.7, 0.7), vec2(-0.7, 0.7), vec2(0.7, -0.7), vec2(-0.7, -0.7),
	vec2(0.4, 0.15), vec2(-0.4, -0.15), vec2(0.15, -0.4), vec2(-0.15, 0.4));
void fragment() {
	float lod = blur * amount;
	vec2 r = vec2(radius * amount) * vec2(1.0, SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y);
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb * 2.0;
	for (int i = 0; i < 12; i++) {
		c += textureLod(screen_tex, SCREEN_UV + TAPS[i] * r, lod).rgb;
	}
	c /= 14.0;
	c = mix(c, tint.rgb, tint.a * amount);
	COLOR = vec4(c, 1.0);
}
"""

static var _shader: Shader

var _mat: ShaderMaterial
var _tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # le voile bloque les touches derrière
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	material = _mat
	set_amount(0.0)


## 0 = transparent (net), 1 = flou et assombri.
func set_amount(a: float) -> void:
	_mat.set_shader_parameter("amount", a)
	# Sous ~0 : le voile ne recopie même plus l'écran.
	self_modulate.a = 1.0 if a > 0.001 else 0.0


func amount() -> float:
	return _mat.get_shader_parameter("amount")


func fade_in(duration := 0.3) -> void:
	visible = true
	_fade(1.0, duration)


func fade_out(duration := 0.2) -> void:
	_fade(0.0, duration)
	_tween.tween_callback(func() -> void: visible = false)


func _fade(to: float, duration: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_method(set_amount, amount(), to, duration).set_trans(Tween.TRANS_SINE)
