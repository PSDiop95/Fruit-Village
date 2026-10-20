class_name TitleScreen
extends CanvasLayer
## Écran titre : logo (placeholder texte « Merge Marché »), bouton Jouer,
## plus gros fruit atteint (miniature 3D), réglages.

signal play_pressed

var play_button: Button
var settings_button: Button
var best_thumb: FruitThumb
var _root: Control
var _settings: SettingsPanel


func _ready() -> void:
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 60
	col.offset_right = -60
	col.offset_top = 260
	col.offset_bottom = -160
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_theme_constant_override("separation", 34)
	_root.add_child(col)

	# Logo placeholder : titre en deux lignes sur un cartouche crème + frise wax.
	var logo := PanelContainer.new()
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(logo)
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", -24)
	logo.add_child(lbox)
	for word in ["Merge", "Marché"]:
		var l := Label.new()
		l.text = word
		l.theme_type_variation = &"LabelTitle"
		l.add_theme_font_size_override("font_size", 150)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbox.add_child(l)
	var band := WaxBand.new()
	band.custom_minimum_size = Vector2(560, 40)
	lbox.add_child(band)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var best := PanelContainer.new()
	best.theme_type_variation = &"Pill"
	best.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(best)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 18)
	best.add_child(brow)
	best_thumb = FruitThumb.new()
	best_thumb.custom_minimum_size = Vector2(150, 150)
	brow.add_child(best_thumb)
	var btxt := Label.new()
	btxt.text = "Plus gros fruit :\n%s" % FruitCatalogNames.name_of(SaveManager.best_rank)
	btxt.add_theme_font_size_override("font_size", 42)
	btxt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brow.add_child(btxt)
	best_thumb.set_fruit(SaveManager.best_rank)

	play_button = Button.new()
	play_button.text = "Jouer"
	play_button.theme_type_variation = &"ButtonGreen"
	play_button.add_theme_font_size_override("font_size", 78)
	play_button.custom_minimum_size = Vector2(620, 180)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.pressed.connect(func() -> void: play_pressed.emit())
	col.add_child(play_button)

	settings_button = Button.new()
	settings_button.text = "Réglages"
	settings_button.custom_minimum_size = Vector2(480, 130)
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_button.pressed.connect(open_settings)
	col.add_child(settings_button)


func open_settings() -> SettingsPanel:
	if _settings == null:
		_settings = SettingsPanel.new()
		_root.add_child(SettingsPanel.centered(_settings))
		_settings.closed.connect(func() -> void: _settings = null)
	return _settings


func settings_open() -> bool:
	return _settings != null
