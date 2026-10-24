class_name SettingsPanel
extends PanelContainer
## Réglages : carte simple (crème, arrondie, ombre douce) posée sur un voile
## flou. En-tête titre + bouton fermer ; section « Son » (interrupteurs),
## section « Affichage » (effets réduits, qualité et ambiance en contrôles
## segmentés : choix actif = bouton orange peint).
## Chaque changement est sauvegardé tout de suite (SaveManager.set_setting).

signal closed
## Qualité choisie (déjà sauvegardée) : la partie en cours l'applique.
signal quality_changed(setting: int)

const SOUND_TOGGLES := [
	[&"music_on", "Musique"],
	[&"sfx_on", "Sons"],
	[&"vibration_on", "Vibrations"],
]
const DISPLAY_TOGGLES := [
	[&"reduced_effects", "Effets réduits"],
]
## M4 : rappels locaux et statistiques d'usage.
const PRIVACY_TOGGLES := [
	[&"notifications_on", "Rappels quotidiens"],
	[&"analytics_on", "Statistiques d'usage"],
]
const QUALITY_CHOICES := [VisualQuality.AUTO, JuiceConfig.Quality.LOW, JuiceConfig.Quality.MEDIUM,
	JuiceConfig.Quality.HIGH]
const WIDTH := 900.0

var toggles: Dictionary = {}  # clé -> CheckButton
var quality_buttons: Array[Button] = []
var ambiance_buttons: Array[Button] = []
var close_button: Button
var x_button: Button
var consent_button: Button
var privacy_button: Button
var privacy_toggles: Dictionary = {}  # clé -> CheckButton (M4)


func _ready() -> void:
	theme = UiTheme.get_theme()
	theme_type_variation = &"PanelCard"
	custom_minimum_size = Vector2(WIDTH, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	add_child(box)

	# En-tête : titre à gauche, fermer à droite.
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "Réglages"
	title.theme_type_variation = &"LabelTitle"
	title.add_theme_font_size_override("font_size", 76)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	x_button = Button.new()
	x_button.text = "×"
	x_button.theme_type_variation = &"ButtonCream"
	x_button.add_theme_font_size_override("font_size", 64)
	x_button.custom_minimum_size = Vector2(112, 112)
	x_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	x_button.pressed.connect(close)
	head.add_child(x_button)

	var sound := _section(box, "Son")
	for t in SOUND_TOGGLES:
		_toggle(sound, t[0], t[1])
	var display := _section(box, "Affichage")
	for t in DISPLAY_TOGGLES:
		_toggle(display, t[0], t[1])
	_caption(display, "Qualité")
	var labels: Array[String] = []
	for q in QUALITY_CHOICES:
		labels.append(VisualQuality.label(q))
	quality_buttons = _segmented(display, labels, QUALITY_CHOICES, &"quality",
		func(v: int) -> void: _set_quality(v))
	_caption(display, "Ambiance")
	var amb_labels: Array[String] = ["Auto"]
	var amb_values := [Ambiances.AUTO]
	var amb := Ambiances.load_default()
	for i in amb.list.size():
		amb_labels.append(amb.list[i].short_name)
		amb_values.append(i)
	ambiance_buttons = _segmented(display, amb_labels, amb_values, &"ambiance",
		func(v: int) -> void: SaveManager.set_setting(&"ambiance", v))

	var privacy := _section(box, "Vie privée")
	for t in PRIVACY_TOGGLES:
		_toggle(privacy, t[0], t[1], privacy_toggles)
	# Consentement + politique côte à côte (la carte doit tenir en 9:16).
	var links := HBoxContainer.new()
	links.add_theme_constant_override("separation", 12)
	privacy.add_child(links)
	if AdsManager.privacy_options_required():
		consent_button = _link_button("Consentement", AdsManager.show_privacy_options)
		links.add_child(consent_button)
	privacy_button = _link_button("Confidentialité",
		func() -> void: OS.shell_open(AdsManager.config.privacy_policy_url))
	links.add_child(privacy_button)

	close_button = Button.new()
	close_button.text = "OK"
	close_button.theme_type_variation = &"ButtonGreen"
	close_button.custom_minimum_size = Vector2(420, 120)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	box.add_child(close_button)
	UiJuice.bounce_all(self)


func _link_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"ButtonCream"
	b.add_theme_font_size_override("font_size", 38)
	b.custom_minimum_size = Vector2(0, 100)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


## Section : titre discret + fond un ton plus sombre.
func _section(parent: Container, label: String) -> VBoxContainer:
	_caption(parent, label.to_upper())
	var p := PanelContainer.new()
	p.theme_type_variation = &"PanelSection"
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


func _caption(parent: Container, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"LabelCaption"
	parent.add_child(l)


func _toggle(parent: Container, key: StringName, label: String, into: Variant = null) -> void:
	var cb := CheckButton.new()
	cb.text = label
	cb.button_pressed = bool(SaveManager.get_setting(key))
	cb.custom_minimum_size = Vector2(0, 92)
	cb.toggled.connect(func(on: bool) -> void: SaveManager.set_setting(key, on))
	parent.add_child(cb)
	var target: Dictionary = toggles if into == null else into
	target[key] = cb


## Contrôle segmenté sur fond de section : le choix actif est le bouton orange.
func _segmented(parent: Container, labels: Array[String], values: Array, key: StringName,
		on_pick: Callable) -> Array[Button]:
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.CARD
	sb.set_corner_radius_all(999)
	sb.set_content_margin_all(6)
	bg.add_theme_stylebox_override("panel", sb)
	parent.add_child(bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	bg.add_child(row)
	var group := ButtonGroup.new()
	var out: Array[Button] = []
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 104)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: int = values[i]
		b.set_meta(&"value", v)
		b.button_pressed = int(SaveManager.get_setting(key)) == v
		b.pressed.connect(func() -> void:
			on_pick.call(v)
			_refresh_segments(out, key))
		row.add_child(b)
		out.append(b)
	_refresh_segments(out, key)
	return out


func _refresh_segments(buttons: Array[Button], key: StringName) -> void:
	var cur := int(SaveManager.get_setting(key))
	for b in buttons:
		var on := int(b.get_meta(&"value")) == cur
		b.theme_type_variation = &"Button" if on else &"ButtonSegment"
		b.add_theme_font_size_override("font_size", 36)


func _set_quality(setting: int) -> void:
	SaveManager.set_setting(&"quality", setting)
	quality_changed.emit(setting)


func close() -> void:
	closed.emit()
	# Le CenterContainer d'accueil (et son voile éventuel) part avec le panneau.
	if get_parent() is CenterContainer and get_parent().get_child_count() == 1:
		var wrapper := get_parent().get_parent()
		if wrapper and wrapper.has_meta(&"settings_wrapper"):
			wrapper.queue_free()
		else:
			get_parent().queue_free()
	else:
		queue_free()


## Enveloppe le panneau dans un CenterContainer plein écran (à ajouter à l'UI),
## avec un voile flou si `blur` (écran titre ; en partie, la pause a déjà le sien).
static func centered(panel: SettingsPanel, blur := false) -> Control:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(panel)
	if not blur:
		return c
	var w := Control.new()
	w.set_meta(&"settings_wrapper", true)
	w.set_anchors_preset(Control.PRESET_FULL_RECT)
	var b := BlurBackdrop.new()
	w.add_child(b)
	b.fade_in()
	w.add_child(c)
	return w
