class_name UiJuice
extends RefCounted
## Petites animations d'interface partagées : boutons qui s'enfoncent et
## rebondissent, panneaux qui apparaissent en pop, respiration (bouton Jouer,
## logo), rideau de transition entre écrans. Toutes en temps réel (ignorent
## les ralentis) et actives pendant la pause.

const PRESS_SCALE := 0.9
const META := &"ui_juice_bounce"


## Rebond sur un bouton (une seule fois par bouton).
static func bounce(b: BaseButton) -> void:
	if b.has_meta(META):
		return
	b.set_meta(META, true)
	_center_pivot(b)
	b.resized.connect(_center_pivot.bind(b))
	b.button_down.connect(func() -> void: _tween_scale(b, Vector2.ONE * PRESS_SCALE, 0.06, false))
	b.button_up.connect(func() -> void: _tween_scale(b, Vector2.ONE, 0.4, true))


## Rebond sur tous les boutons sous `root`.
static func bounce_all(root: Node) -> void:
	for n in root.find_children("*", "BaseButton", true, false):
		bounce(n as BaseButton)


## Apparition : petit → grand avec dépassement, fondu.
static func pop_in(c: Control, duration := 0.28) -> void:
	_center_pivot(c)
	c.scale = Vector2.ONE * 0.75
	c.modulate.a = 0.0
	var tw := c.create_tween().set_ignore_time_scale(true).set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, duration * 0.6)


## Respiration en boucle (invite à toucher).
static func breathe(c: Control, amount := 0.05, period := 1.4) -> void:
	_center_pivot(c)
	c.resized.connect(_center_pivot.bind(c))
	var tw := c.create_tween().set_loops().set_ignore_time_scale(true)
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amount), period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Flottement vertical doux en boucle (logo).
static func float_idle(c: Control, amplitude := 12.0, period := 2.6) -> void:
	var base := c.position.y
	var tw := c.create_tween().set_loops().set_ignore_time_scale(true)
	tw.tween_property(c, "position:y", base - amplitude, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(c, "position:y", base, period * 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _center_pivot(c: Control) -> void:
	c.pivot_offset = c.size * 0.5


static func _tween_scale(c: Control, to: Vector2, t: float, elastic: bool) -> void:
	var tw := c.create_tween().set_ignore_time_scale(true)
	var p := tw.tween_property(c, "scale", to, t)
	if elastic:
		p.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Rideau plein écran : couvre aussitôt puis s'efface (changement d'écran).
class Curtain extends CanvasLayer:
	var _rect: ColorRect

	func _init() -> void:
		layer = 50
		process_mode = Node.PROCESS_MODE_ALWAYS
		_rect = ColorRect.new()
		_rect.color = Color("3a2414")
		_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rect.modulate.a = 0.0
		add_child(_rect)

	func reveal(duration := 0.4) -> void:
		_rect.modulate.a = 1.0
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_property(_rect, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT)

	func is_covering() -> bool:
		return _rect.modulate.a > 0.01
