class_name SettingsPanel
extends PanelContainer
## Réglages : musique, sons, vibrations, effets réduits, qualité visuelle, ambiance.
## Chaque changement est sauvegardé tout de suite (SaveManager.set_setting).

signal closed
## Qualité choisie (déjà sauvegardée) : la partie en cours l'applique.
signal quality_changed(setting: int)

const TOGGLES := [
	[&"music_on", "Musique"],
	[&"sfx_on", "Sons"],
	[&"vibration_on", "Vibrations"],
	[&"reduced_effects", "Effets réduits"],
]
const QUALITY_CHOICES := [VisualQuality.AUTO, JuiceConfig.Quality.LOW, JuiceConfig.Quality.MEDIUM,
	JuiceConfig.Quality.HIGH]

var toggles: Dictionary = {}  # clé -> CheckButton
var quality_buttons: Array[Button] = []
var ambiance_buttons: Array[Button] = []
var close_button: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	custom_minimum_size = Vector2(960, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title := Label.new()
	title.text = "Réglages"
	title.theme_type_variation = &"LabelTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(WaxBand.new())
	for t in TOGGLES:
		var cb := CheckButton.new()
		cb.text = t[1]
		cb.button_pressed = bool(SaveManager.get_setting(t[0]))
		cb.custom_minimum_size = Vector2(0, 110)
		var key: StringName = t[0]
		cb.toggled.connect(func(on: bool) -> void: SaveManager.set_setting(key, on))
		box.add_child(cb)
		toggles[key] = cb
	var ql := Label.new()
	ql.text = "Qualité"
	box.add_child(ql)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var group := ButtonGroup.new()
	for q in QUALITY_CHOICES:
		var b := Button.new()
		b.text = VisualQuality.label(q)
		b.toggle_mode = true
		b.button_group = group
		b.theme_type_variation = &"ButtonCream"
		b.add_theme_font_size_override("font_size", 36)
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = int(SaveManager.get_setting(&"quality")) == q
		var setting: int = q
		b.pressed.connect(func() -> void: _set_quality(setting))
		row.add_child(b)
		quality_buttons.append(b)
	_refresh_quality_style()
	_build_ambiance_row(box)
	close_button = Button.new()
	close_button.text = "OK"
	close_button.theme_type_variation = &"ButtonGreen"
	close_button.custom_minimum_size = Vector2(380, 130)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	box.add_child(close_button)
	UiJuice.bounce_all(self)


## Ambiance du marché : Auto (heure locale), puis chaque ambiance de data/ambiances.tres.
func _build_ambiance_row(box: VBoxContainer) -> void:
	var al := Label.new()
	al.text = "Ambiance"
	box.add_child(al)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var labels := ["Auto"]
	var values := [Ambiances.AUTO]
	var amb := Ambiances.load_default()
	for i in amb.list.size():
		labels.append(amb.list[i].short_name)
		values.append(i)
	var group := ButtonGroup.new()
	for i in labels.size():
		var b := Button.new()
		b.text = labels[i]
		b.toggle_mode = true
		b.button_group = group
		b.add_theme_font_size_override("font_size", 36)
		b.custom_minimum_size = Vector2(0, 110)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: int = values[i]
		b.set_meta(&"value", v)
		b.button_pressed = int(SaveManager.get_setting(&"ambiance")) == v
		b.pressed.connect(func() -> void:
			SaveManager.set_setting(&"ambiance", v)
			_refresh_ambiance_style())
		row.add_child(b)
		ambiance_buttons.append(b)
	_refresh_ambiance_style()


func _refresh_ambiance_style() -> void:
	var cur := int(SaveManager.get_setting(&"ambiance"))
	for b in ambiance_buttons:
		b.theme_type_variation = &"Button" if int(b.get_meta(&"value")) == cur else &"ButtonCream"


func _set_quality(setting: int) -> void:
	SaveManager.set_setting(&"quality", setting)
	_refresh_quality_style()
	quality_changed.emit(setting)


## Bouton actif en orange, les autres en bleu nuit.
func _refresh_quality_style() -> void:
	var cur := int(SaveManager.get_setting(&"quality"))
	for i in quality_buttons.size():
		quality_buttons[i].theme_type_variation = &"Button" if QUALITY_CHOICES[i] == cur else &"ButtonCream"


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
## avec un voile sombre si `dim`.
static func centered(panel: SettingsPanel, dim := false) -> Control:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(panel)
	if not dim:
		return c
	# Voile sombre derrière le panneau (écran titre).
	var w := Control.new()
	w.set_meta(&"settings_wrapper", true)
	w.set_anchors_preset(Control.PRESET_FULL_RECT)
	var d := ColorRect.new()
	d.color = Color(0.12, 0.07, 0.03, 0.6)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	w.add_child(d)
	w.add_child(c)
	return w
