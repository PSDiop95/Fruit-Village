class_name BlurBackdrop
extends ColorRect
## Voile plein écran qui floute et assombrit ce qui est derrière (réglages,
## pause, fin de partie), avec fondu d'apparition.
## Perf (Galaxy A23 : le flou « live » divisait le FPS par 2) : à l'ouverture,
## UNE capture de la dernière image affichée, réduite au 1/DOWNSCALE (Lanczos),
## puis lissée par quelques lectures de cette petite texture. Derrière un voile
## la scène est figée (pause, fin, menus) : la capture suffit.
## Sans image (rendu headless) : voile teinté seul.

const DOWNSCALE := 12
const SHADER := """
shader_type canvas_item;
uniform sampler2D snap : filter_linear, repeat_disable;
uniform bool has_snap = false;
uniform vec2 texel = vec2(0.01);
uniform vec4 tint : source_color = vec4(0.16, 0.09, 0.04, 0.42);
uniform float amount = 1.0;
void fragment() {
	vec3 c = tint.rgb;
	if (has_snap) {
		vec2 uv = SCREEN_UV;
		c = texture(snap, uv).rgb * 2.0;
		c += texture(snap, uv + vec2(texel.x, 0.0)).rgb;
		c += texture(snap, uv - vec2(texel.x, 0.0)).rgb;
		c += texture(snap, uv + vec2(0.0, texel.y)).rgb;
		c += texture(snap, uv - vec2(0.0, texel.y)).rgb;
		c /= 6.0;
		c = mix(c, tint.rgb, tint.a);
		COLOR = vec4(c, amount);
	} else {
		COLOR = vec4(c, tint.a * amount);
	}
}
"""

static var _shader: Shader
## Voiles opaques affichés (le rendu 3D reprend quand il n'y en a plus).
static var _opaque_count: int = 0

var _mat: ShaderMaterial
var _tween: Tween
var _amount: float = 0.0
var _capture_pending: bool = false
var _hiding_3d: bool = false


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


func _enter_tree() -> void:
	if _capture_pending:
		capture()


## Capture la dernière image affichée (donc SANS le panneau qui s'ouvre
## pendant cette frame) comme fond flou. Hors de l'arbre : à l'entrée.
func capture() -> void:
	if not is_inside_tree():
		_capture_pending = true
		return
	_capture_pending = false
	if DisplayServer.get_name() == "headless":
		_mat.set_shader_parameter("has_snap", false)
		return
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_mat.set_shader_parameter("has_snap", false)
		return
	var w := maxi(img.get_width() / DOWNSCALE, 1)
	var h := maxi(img.get_height() / DOWNSCALE, 1)
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	_mat.set_shader_parameter("snap", ImageTexture.create_from_image(img))
	_mat.set_shader_parameter("texel", Vector2(1.5 / w, 1.5 / h))
	_mat.set_shader_parameter("has_snap", true)


## 0 = transparent (net), 1 = flou et assombri.
func set_amount(a: float) -> void:
	_amount = a
	_mat.set_shader_parameter("amount", a)
	self_modulate.a = 1.0 if a > 0.001 else 0.0
	_set_hiding_3d(a >= 0.999 and bool(_mat.get_shader_parameter("has_snap")) and is_visible_in_tree())


## Voile opaque sur une capture : la 3D cachée dessous n'est plus rendue.
func _set_hiding_3d(on: bool) -> void:
	if on == _hiding_3d or not is_inside_tree():
		return
	_hiding_3d = on
	_opaque_count += 1 if on else -1
	get_viewport().disable_3d = _opaque_count > 0


func _exit_tree() -> void:
	_set_hiding_3d(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_set_hiding_3d(false)


func amount() -> float:
	return _amount


func fade_in(duration := 0.3) -> void:
	if not visible or _amount <= 0.001:
		capture()
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
