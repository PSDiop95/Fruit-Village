class_name GameOverScreen
extends Control
## Écran de fin : voile flou, carte de résultats (ruban titre, plus gros fruit
## sur rayons tournants, gros score qui défile, tampon « NOUVEAU RECORD »,
## pastilles de stats), puis Rejouer (respire) et Menu.
## Chorégraphie en temps réel : carte → ruban → fruit → score → tampon → stats → boutons.

signal replay_pressed
signal menu_pressed

const CARD_WIDTH := 900.0
const SCORE_GOLD := Color("ffc93a")

var cfg: JuiceConfig
var card: PanelContainer
var replay_button: Button
var menu_button: Button
var score_label: Label
var stamp: Label

var _blur: BlurBackdrop
var _ribbon: PanelContainer
var _ribbon_label: Label
var _thumb: FruitThumb
var _rays: Control
var _fruit_name: Label
var _best_label: Label
var _chips: Array[PanelContainer] = []
var _chip_values: Array[Label] = []
var _score: int = 0
var _roll: float = -1.0
var _record: bool = false


func setup(p_cfg: JuiceConfig) -> void:
	cfg = p_cfg
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_blur = BlurBackdrop.new()
	add_child(_blur)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	card = PanelContainer.new()
	card.theme_type_variation = &"PanelCard"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)

	# Vitrine : rayons + plus gros fruit + nom
	var show := Control.new()
	show.custom_minimum_size = Vector2(0, 290)
	show.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(show)
	_rays = Control.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.draw.connect(_draw_rays)
	show.add_child(_rays)
	_thumb = FruitThumb.new()
	_thumb.size = Vector2(250, 250)
	show.add_child(_thumb)
	show.resized.connect(func() -> void:
		var c := show.size * 0.5 + Vector2(0, 14)
		_thumb.position = c - _thumb.size * 0.5
		_rays.size = Vector2(560, 560)
		_rays.pivot_offset = _rays.size * 0.5
		_rays.position = c - _rays.size * 0.5)
	var cap := Label.new()
	cap.text = "PLUS GROS FRUIT"
	cap.theme_type_variation = &"LabelCaption"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(cap)
	_fruit_name = Label.new()
	_fruit_name.add_theme_font_override("font", UiTheme.display_font())
	_fruit_name.add_theme_font_size_override("font_size", 58)
	_fruit_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_fruit_name)

	# Score
	var score_box := Control.new()
	score_box.custom_minimum_size = Vector2(0, 170)
	score_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(score_box)
	score_label = _big_label(150, SCORE_GOLD, 26)
	score_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	score_box.add_child(score_label)
	stamp = _big_label(44, Color.WHITE, 12)
	stamp.text = "NOUVEAU RECORD !"
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.WAX_RED
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(5)
	sb.border_color = Color.WHITE
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 4
	sb.content_margin_bottom = 8
	stamp.add_theme_stylebox_override("normal", sb)
	stamp.visible = false
	score_box.add_child(stamp)
	score_box.resized.connect(func() -> void:
		stamp.size = stamp.get_combined_minimum_size()
		stamp.pivot_offset = stamp.size * 0.5
		stamp.position = Vector2(score_box.size.x - stamp.size.x + 10, -28))
	_best_label = Label.new()
	_best_label.theme_type_variation = &"LabelCaption"
	_best_label.add_theme_font_size_override("font_size", 36)
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_best_label)

	# Stats
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 16)
	box.add_child(stats)
	for title in ["Fusions", "Combo max", "Durée"]:
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"PanelSection"
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(chip)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -6)
		chip.add_child(v)
		var t := Label.new()
		t.text = title
		t.theme_type_variation = &"LabelCaption"
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var val := Label.new()
		val.add_theme_font_override("font", UiTheme.display_font())
		val.add_theme_font_size_override("font_size", 54)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(val)
		_chips.append(chip)
		_chip_values.append(val)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	box.add_child(spacer)
	replay_button = Button.new()
	replay_button.text = "Rejouer"
	replay_button.theme_type_variation = &"ButtonGreenBig"
	replay_button.add_theme_font_size_override("font_size", 84)
	replay_button.custom_minimum_size = Vector2(600, 200)
	replay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	replay_button.pressed.connect(func() -> void: replay_pressed.emit())
	box.add_child(replay_button)
	menu_button = Button.new()
	menu_button.text = "Menu"
	menu_button.theme_type_variation = &"ButtonCream"
	menu_button.custom_minimum_size = Vector2(340, 112)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	box.add_child(menu_button)

	# Ruban : à cheval sur le haut de la carte (placé à chaque redimensionnement).
	_ribbon = PanelContainer.new()
	_ribbon.theme_type_variation = &"PanelRibbon"
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ribbon)
	_ribbon_label = _big_label(64, UiTheme.BUTTON_TEXT, 16)
	_ribbon.add_child(_ribbon_label)
	card.resized.connect(_place_ribbon)
	card.item_rect_changed.connect(_place_ribbon)
	replay_button.set_meta(UiJuice.META, true)
	UiJuice.bounce_all(self)
	visible = false


func _big_label(size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = UiTheme.display_font()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = UiTheme.INK
	ls.shadow_size = 0
	ls.shadow_color = Color(0, 0, 0, 0.3)
	ls.shadow_offset = Vector2(0, size * 0.05)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _place_ribbon() -> void:
	_ribbon.size = _ribbon.get_combined_minimum_size()
	_ribbon.pivot_offset = _ribbon.size * 0.5
	var r := card.get_global_rect()
	_ribbon.global_position = Vector2(r.get_center().x - _ribbon.size.x * 0.5, r.position.y - _ribbon.size.y * 0.55)


## Affiche les résultats et lance la chorégraphie.
func show_results(score: int, rank: int, def: FruitDef, is_record: bool, best: int,
		merges: int, best_combo: int, seconds: float) -> void:
	_score = score
	_record = is_record
	_ribbon_label.text = "Bravo !" if is_record else "Le panier déborde !"
	(_ribbon.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = \
		Color("e8a800") if is_record else UiTheme.WAX_ORANGE
	_thumb.set_fruit(rank)
	_fruit_name.text = def.display_name
	_best_label.text = "Record : %d" % maxi(best, score)
	_chip_values[0].text = str(merges)
	_chip_values[1].text = "x%d" % maxi(best_combo, 1)
	_chip_values[2].text = "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
	score_label.text = "0"
	stamp.visible = false
	visible = true
	_play_intro()


func _play_intro() -> void:
	var d := cfg.game_over_panel_delay
	_blur.set_amount(0.0)
	_blur.visible = true
	card.modulate.a = 0.0
	_ribbon.modulate.a = 0.0
	_rays.modulate.a = 0.0
	for c in _chips:
		c.modulate.a = 0.0
	replay_button.modulate.a = 0.0
	menu_button.modulate.a = 0.0
	await get_tree().process_frame
	_place_ribbon()
	var rest := card.position.y
	card.position.y = rest + 500.0
	card.scale = Vector2.ONE * 0.9
	card.pivot_offset = card.size * 0.5
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_interval(d)
	tw.tween_callback(func() -> void: _blur.fade_in(0.35))
	# Carte qui monte et se pose
	tw.tween_property(card, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(card, "position:y", rest, cfg.game_over_panel_slide_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "scale", Vector2.ONE, cfg.game_over_panel_slide_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Ruban qui tombe et rebondit
	tw.tween_callback(func() -> void:
		_place_ribbon()
		_ribbon.scale = Vector2.ONE * 1.6
		_ribbon.rotation = -0.12)
	tw.tween_property(_ribbon, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(_ribbon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_ribbon, "rotation", 0.0, 0.35).set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)
	# Fruit : pop + rayons
	tw.tween_callback(func() -> void: _thumb.pop())
	tw.parallel().tween_property(_rays, "modulate:a", 1.0, 0.3)
	# Score qui défile (dans _process), puis tampon record
	tw.tween_callback(func() -> void: _roll = 0.0)
	tw.tween_interval(cfg.game_over_score_roll_time)
	tw.tween_callback(_stamp_record)
	# Stats en cascade, puis boutons
	for c in _chips:
		tw.tween_callback(func() -> void:
			c.pivot_offset = c.size * 0.5
			c.scale = Vector2.ONE * 0.6)
		tw.tween_property(c, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	tw.tween_property(replay_button, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(menu_button, "modulate:a", 1.0, 0.15)
	tw.tween_callback(func() -> void: UiJuice.breathe(replay_button, 0.04, 1.2))


func _stamp_record() -> void:
	if not _record:
		return
	stamp.visible = true
	stamp.scale = Vector2.ONE * 2.4
	stamp.rotation = 0.0
	stamp.modulate.a = 0.0
	var tw := create_tween().set_ignore_time_scale(true).set_parallel()
	tw.tween_property(stamp, "modulate:a", 1.0, 0.08)
	tw.tween_property(stamp, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(stamp, "rotation", deg_to_rad(-10.0), 0.25).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func displayed_score() -> int:
	return int(score_label.text) if score_label.text.is_valid_int() else 0


func _process(delta: float) -> void:
	if not visible:
		return
	var dt := clampf(delta / maxf(Engine.time_scale, 0.0001), 0.0, 0.1)
	_rays.rotation += dt * 0.35
	if _roll >= 0.0 and _roll < 1.0:
		_roll = minf(_roll + dt / maxf(cfg.game_over_score_roll_time, 0.01), 1.0)
		var k := 1.0 - pow(1.0 - _roll, 3.0)
		score_label.text = str(int(round(_score * k)))
		score_label.scale = Vector2.ONE * (1.0 + 0.06 * sin(_roll * PI))
		score_label.pivot_offset = score_label.size * 0.5


## Rayons de soleil doux derrière le fruit (triangles dégradés).
func _draw_rays() -> void:
	var c := _rays.size * 0.5
	var n := 16
	var col := Color(1.0, 0.78, 0.3, 0.55)
	var clear := Color(col, 0.0)
	for i in n:
		var a := TAU * i / n
		var half := PI / n * 0.5
		var length := c.x
		_rays.draw_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - half) * length,
			c + Vector2.from_angle(a + half) * length]), PackedColorArray([col, clear, clear]))
	_rays.draw_circle(c, 130.0, Color(1.0, 0.92, 0.7, 0.6))
