class_name ComboBanner
extends Control
## Gros texte animé (« COMBO x3 ! », « BAOBAB ! ») : texte en dégradé avec
## double contour (crème puis brun), halo doré additif, rayons qui tournent.
## Pop élastique à l'entrée, tient, puis s'envole en s'effaçant. Plus le
## niveau est haut, plus le texte est gros, chaud et tremblant.
## Temps réel (ignore hit-stop et ralentis). Réglages : JuiceConfig (« Combo »).

const GRADIENT_SHADER := """
shader_type canvas_item;
// Remplissage du texte en dégradé vertical ; les contours (autres couleurs) passent tels quels.
uniform vec4 top_color : source_color = vec4(1.0, 0.95, 0.48, 1.0);
uniform vec4 bottom_color : source_color = vec4(1.0, 0.54, 0.0, 1.0);
uniform float y0 = 0.0;
uniform float y1 = 100.0;
varying float ly;
void vertex() { ly = VERTEX.y; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec4 c = COLOR;
	if (c.r > 0.97 && c.g > 0.97 && c.b > 0.97) {
		float t = clamp((ly - y0) / max(y1 - y0, 1.0), 0.0, 1.0);
		c.rgb = mix(top_color.rgb, bottom_color.rgb, t * t * (3.0 - 2.0 * t));
	}
	COLOR = c * tex;
}
"""

const W := 1080.0
const H := 440.0

var config: JuiceConfig

var _label: Label
var _settings: LabelSettings
var _mat: ShaderMaterial
var _glow: TextureRect
var _rays: Control
var _t: float = -1.0
var _hold: float = 0.6
## Position de repos (le texte s'envole depuis là).
var home := Vector2.ZERO
var _level: int = 0
var _rng := RandomNumberGenerator.new()


func setup(cfg: JuiceConfig) -> void:
	config = cfg
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W, H)
	pivot_offset = size * 0.5
	modulate.a = 0.0

	_glow = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 128
	gt.height = 64
	_glow.texture = gt
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.size = Vector2(980, 340)
	_glow.position = (size - _glow.size) * 0.5
	_glow.modulate = cfg.combo_glow_color
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)

	_rays = Control.new()
	_rays.size = size
	_rays.pivot_offset = size * 0.5
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.material = add
	_rays.draw.connect(_draw_rays)
	add_child(_rays)

	_label = Label.new()
	_label.size = size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings = LabelSettings.new()
	_settings.font = UiTheme.display_font()
	_settings.font_color = Color.WHITE
	_settings.outline_size = 18
	_settings.outline_color = cfg.combo_inner_outline
	_settings.add_stacked_outline()
	_settings.set_stacked_outline_size(0, 38)
	_settings.set_stacked_outline_color(0, cfg.combo_outer_outline)
	_settings.add_stacked_shadow()
	_settings.set_stacked_shadow_outline_size(0, 38)
	_settings.set_stacked_shadow_offset(0, Vector2(0, 12))
	_settings.set_stacked_shadow_color(0, Color(0.15, 0.05, 0.0, 0.45))
	_label.label_settings = _settings
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GRADIENT_SHADER
	_mat.shader = sh
	_label.material = _mat
	add_child(_label)
	visible = false


## Lance la bannière. `level` : 0 = normal, puis +1 par combo au-delà du minimum.
func play(text: String, font_size: int, level: int, hold: float, top: Color, bottom: Color) -> void:
	_level = level
	_hold = hold
	position = home
	var fs := int(font_size * (1.0 + config.combo_level_growth * level))
	_settings.font_size = fs
	_label.text = text
	var hot := level + config.combo_min >= config.combo_hot_level
	_mat.set_shader_parameter("top_color", top)
	_mat.set_shader_parameter("bottom_color", config.combo_hot_fill_bottom if hot else bottom)
	# Hauteur utile des glyphes autour du centre du label.
	_mat.set_shader_parameter("y0", H * 0.5 - fs * 0.42)
	_mat.set_shader_parameter("y1", H * 0.5 + fs * 0.38)
	_rays.queue_redraw()
	_t = 0.0
	visible = true
	_process(0.0)


func is_playing() -> bool:
	return _t >= 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	var dt := clampf(delta / maxf(Engine.time_scale, 0.0001), 0.0, 0.1)
	_t += dt
	var pop := 0.28
	var out := 0.28
	var total := pop + _hold + out
	if _t >= total:
		_t = -1.0
		visible = false
		modulate.a = 0.0
		return
	var s: float
	var a := 1.0
	if _t < pop:
		s = lerpf(0.25, 1.0, _elastic(_t / pop))
	elif _t < pop + _hold:
		s = 1.0 + 0.03 * sin((_t - pop) * 18.0)  # respiration
	else:
		var u := (_t - pop - _hold) / out
		s = 1.0 + 0.2 * u
		a = 1.0 - u
		position.y -= 220.0 * dt  # s'envole
	scale = Vector2.ONE * s
	modulate.a = a
	# Inclinaison qui se redresse à l'entrée, tremblement aux niveaux chauds.
	rotation = deg_to_rad(-7.0) * maxf(1.0 - _t / pop, 0.0)
	var hot := _level + config.combo_min >= config.combo_hot_level
	if hot and _t < pop + _hold:
		var j := config.combo_hot_shake
		_label.position = Vector2(_rng.randf_range(-j, j), _rng.randf_range(-j, j))
	else:
		_label.position = Vector2.ZERO
	_rays.rotation += dt * (0.8 + 0.3 * _level)
	_rays.scale = Vector2.ONE * (0.9 + 0.12 * sin(_t * 10.0))
	_glow.modulate.a = config.combo_glow_color.a * (0.85 + 0.15 * sin(_t * 14.0))


## Rayons en étoile (triangles dégradés : opaques au centre, transparents au bout).
func _draw_rays() -> void:
	var c := size * 0.5
	var n := config.combo_ray_count + _level * 2
	var col := config.combo_ray_color
	var clear := Color(col, 0.0)
	for i in n:
		var a := TAU * i / n
		var length := (300.0 if i % 2 == 0 else 200.0) * (1.0 + 0.1 * _level)
		var half := PI / n * 0.45
		var p1 := c + Vector2.from_angle(a - half) * length
		var p2 := c + Vector2.from_angle(a + half) * length
		_rays.draw_polygon(PackedVector2Array([c, p1, p2]), PackedColorArray([col, clear, clear]))


static func _elastic(p: float) -> float:
	if p <= 0.0 or p >= 1.0:
		return clampf(p, 0.0, 1.0)
	return pow(2.0, -10.0 * p) * sin((p * 10.0 - 0.75) * TAU / 3.0) + 1.0
