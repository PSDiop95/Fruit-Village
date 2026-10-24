class_name MockAdOverlay
extends CanvasLayer
## Écran plein « pub simulée » (MockAds) : compte à rebours, croix de
## fermeture. Fermer avant la fin = pas de récompense.

signal finished(completed: bool)

var _left: float = 3.0
var _kind: StringName
var _label: Label
var _close: Button
var _done: bool = false


func run(kind: StringName, seconds: float) -> void:
	_kind = kind
	_left = seconds
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 30)
	center.add_child(box)
	var t := Label.new()
	t.text = "PUB SIMULÉE\n(%s)" % ("vidéo récompensée" if kind == AdProvider.REWARDED else "interstitiel")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(t)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 44)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	box.add_child(_label)
	_close = Button.new()
	_close.text = "✕"
	_close.theme_type_variation = &"ButtonCream"
	_close.position = Vector2(1080 - 170, 60)
	_close.size = Vector2(110, 110)
	_close.add_theme_font_size_override("font_size", 56)
	_close.pressed.connect(_on_close)
	root.add_child(_close)
	_update_label()


func _process(delta: float) -> void:
	if _done:
		return
	_left = maxf(_left - delta / maxf(Engine.time_scale, 0.01), 0.0)
	_update_label()


func _update_label() -> void:
	if _left > 0.0:
		_label.text = "Récompense dans %d s" % ceili(_left) if _kind == AdProvider.REWARDED \
			else "Fermeture possible dans %d s" % ceili(_left)
	else:
		_label.text = "Récompense obtenue ! Ferme la pub." if _kind == AdProvider.REWARDED \
			else "Tu peux fermer la pub."


func _on_close() -> void:
	if _done:
		return
	if _kind == AdProvider.INTERSTITIAL and _left > 0.0:
		return
	_done = true
	finished.emit(_left <= 0.0)
