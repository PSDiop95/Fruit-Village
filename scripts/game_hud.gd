class_name GameHud
extends CanvasLayer
## HUD final (M3) : score en gros chiffres (compteur roulant), record, bouton
## pause, bulle « Suivant » avec le vrai modèle 3D, barre « prochain fruit
## jamais atteint », jauge de danger, menu pause, écran de fin.
## Combos / bandeaux : Juice.

## L'écran de fin ou la pause demande le retour au titre.
signal menu_requested

var _game: Game
var _cfg: JuiceConfig
var _root: Control
var _score: Label
var _best: Label
var _next: Label
var _next_thumb: FruitThumb
var _goal_label: Label
var _goal_bar: ProgressBar
var _danger: ProgressBar
var _pause_button: Button
var _pause_dim: ColorRect
var _pause_panel: PanelContainer
var _settings: SettingsPanel
var _over_dim: ColorRect
var _over_panel: PanelContainer
var _over_label: Label
var _over_thumb: FruitThumb
var _target_score: int = 0
var _shown_score: float = 0.0
var _roll_speed: float = 0.0
var _pulse_tween: Tween
var _over_title: String = ""
var _over_biggest: String = ""
var _over_roll: float = -1.0
var _over_score: int = 0
var _goal_rank: int = -1


func bind(game: Game) -> void:
	_game = game
	_cfg = game.juice_config
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	game.score_changed.connect(_on_score)
	game.game_over.connect(_on_game_over)
	game.fruit_discovered.connect(func(_r: int) -> void: _refresh_goal())
	_score.text = "0"
	_best.text = "Record : %d" % SaveManager.best_score
	_refresh_goal()


func _build() -> void:
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# --- Bandeau haut : score | pause | suivant
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 36
	top.offset_right = -36
	top.offset_top = 40
	top.add_theme_constant_override("separation", 20)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)

	var score_pill := PanelContainer.new()
	score_pill.theme_type_variation = &"Pill"
	score_pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	score_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(score_pill)
	var sbox := VBoxContainer.new()
	sbox.add_theme_constant_override("separation", -10)
	score_pill.add_child(sbox)
	_score = Label.new()
	_score.theme_type_variation = &"LabelBig"
	sbox.add_child(_score)
	_best = Label.new()
	_best.theme_type_variation = &"LabelSmall"
	sbox.add_child(_best)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)

	_pause_button = Button.new()
	_pause_button.icon = _pause_icon()
	_pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_button.theme_type_variation = &"ButtonRound"
	_pause_button.custom_minimum_size = Vector2(120, 120)
	_pause_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_pause_button.pressed.connect(open_pause)
	top.add_child(_pause_button)

	var next_box := VBoxContainer.new()
	next_box.add_theme_constant_override("separation", 0)
	next_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(next_box)
	var bubble := PanelContainer.new()
	bubble.theme_type_variation = &"Pill"
	bubble.custom_minimum_size = Vector2(180, 180)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	next_box.add_child(bubble)
	var bstack := VBoxContainer.new()
	bstack.add_theme_constant_override("separation", -6)
	bubble.add_child(bstack)
	var nt := Label.new()
	nt.text = "Suivant"
	nt.theme_type_variation = &"LabelSmall"
	nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bstack.add_child(nt)
	_next_thumb = FruitThumb.new()
	_next_thumb.custom_minimum_size = Vector2(120, 120)
	_next_thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bstack.add_child(_next_thumb)
	_next = Label.new()
	_next.theme_type_variation = &"LabelSmall"
	_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_box.add_child(_next)

	# --- Objectif : prochain fruit jamais atteint
	var goal := VBoxContainer.new()
	goal.set_anchors_preset(Control.PRESET_TOP_WIDE)
	goal.offset_top = 300
	goal.offset_left = 150
	goal.offset_right = -150
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(goal)
	_goal_label = Label.new()
	_goal_label.theme_type_variation = &"LabelSmall"
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.add_theme_color_override("font_color", UiTheme.INK)
	_goal_label.add_theme_color_override("font_outline_color", UiTheme.CREAM)
	_goal_label.add_theme_constant_override("outline_size", 10)
	goal.add_child(_goal_label)
	_goal_bar = ProgressBar.new()
	_goal_bar.show_percentage = false
	_goal_bar.custom_minimum_size = Vector2(0, 26)
	_goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal.add_child(_goal_bar)

	_danger = ProgressBar.new()
	_danger.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_danger.offset_top = 380
	_danger.offset_bottom = 396
	_danger.offset_left = 150
	_danger.offset_right = -150
	_danger.show_percentage = false
	_danger.max_value = 1.0
	_danger.modulate = Color(1, 0.25, 0.2)
	_danger.visible = false
	_danger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_danger)

	# Pause et fin de partie : construits à la première ouverture (partie plus
	# rapide à lancer, aucun SubViewport inutile pendant le jeu).


## Icône pause dessinée (deux barres arrondies) : indépendante de la police.
static func _pause_icon() -> ImageTexture:
	var s := 56
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var in_bar := false
			for bx in [12, 32]:
				var cx := clampf(x, bx + 6, bx + 6)
				var cy := clampf(y, 14, s - 14)
				if Vector2(x, y).distance_to(Vector2(cx, cy)) <= 6.5:
					in_bar = true
			img.set_pixel(x, y, UiTheme.INK if in_bar else Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)


func _dim() -> ColorRect:
	var d := ColorRect.new()
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.color = Color(0.12, 0.07, 0.03, 0.6)
	d.visible = false
	_root.add_child(d)
	return d


## Panneau centré à l'écran (CenterContainer plein écran, visible avec le panneau).
func _centered_panel(width: float) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(width, 0)
	p.visible = false
	center.add_child(p)
	return p


func _button(text: String, variation: StringName, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(520, 136)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	return b


func _build_pause() -> void:
	if _pause_panel:
		return
	_pause_dim = _dim()
	_pause_panel = _centered_panel(720)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 30)
	_pause_panel.add_child(box)
	var t := Label.new()
	t.text = "Pause"
	t.theme_type_variation = &"LabelTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	box.add_child(WaxBand.new())
	box.add_child(_button("Reprendre", &"ButtonGreen", close_pause))
	box.add_child(_button("Réglages", &"Button", open_settings))
	box.add_child(_button("Menu", &"ButtonBlue", func() -> void:
		close_pause()
		menu_requested.emit()))


func _build_game_over() -> void:
	if _over_panel:
		return
	_over_dim = _dim()
	_over_panel = _centered_panel(800)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	_over_panel.add_child(box)
	box.add_child(WaxBand.new())
	_over_label = Label.new()
	_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_over_label.add_theme_font_size_override("font_size", 54)
	box.add_child(_over_label)
	_over_thumb = FruitThumb.new()
	_over_thumb.custom_minimum_size = Vector2(220, 220)
	_over_thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_over_thumb)
	box.add_child(_button("Rejouer", &"ButtonGreen", func() -> void: _game.restart()))
	box.add_child(_button("Menu", &"ButtonBlue", func() -> void: menu_requested.emit()))


# ---------------------------------------------------------------- Pause / réglages

func is_paused() -> bool:
	return (_pause_panel != null and _pause_panel.visible) or _settings != null


func open_pause() -> void:
	_build_pause()
	if _game.is_over or _pause_panel.visible:
		return
	get_tree().paused = true
	_pause_dim.visible = true
	_pause_panel.visible = true


func close_pause() -> void:
	if _settings:
		_settings.close()
	if _pause_panel:
		_pause_dim.visible = false
		_pause_panel.visible = false
	get_tree().paused = false


func open_settings() -> SettingsPanel:
	if _settings:
		return _settings
	_build_pause()
	_pause_panel.visible = false
	_settings = SettingsPanel.new()
	_root.add_child(SettingsPanel.centered(_settings))
	_settings.quality_changed.connect(func(q: int) -> void: _game.set_quality(VisualQuality.resolve(q)))
	_settings.closed.connect(func() -> void:
		_settings = null
		if _pause_dim.visible:
			_pause_panel.visible = true)
	return _settings


func _notification(what: int) -> void:
	# Mise en pause automatique quand l'appli passe en arrière-plan.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _game and not _game.is_over:
		open_pause()


# ---------------------------------------------------------------- Infos de partie

func set_next(rank: int, def: FruitDef) -> void:
	if _next == null:
		return
	_next.text = def.display_name
	if _next_thumb.current_rank() != rank:
		_next_thumb.set_fruit(rank)
		_next_thumb.pop()


func set_danger(ratio: float) -> void:
	if _danger == null:
		return
	_danger.visible = ratio > 0.01
	_danger.value = ratio


## Objectif visible : le prochain fruit jamais atteint (record + 1).
func _refresh_goal() -> void:
	var cat := _game.catalog
	var best := maxi(SaveManager.best_rank, _game.max_rank_reached)
	var target := mini(best + 1, cat.max_rank())
	_goal_rank = target
	if best >= cat.max_rank():
		_goal_label.text = "Prochain : fais pousser un Baobab !"
	else:
		_goal_label.text = "Prochain : atteins %s !" % _with_article(cat.get_def(target).display_name)
	_goal_bar.max_value = float(target)
	_goal_bar.value = float(_game.max_rank_reached)


static func _with_article(name: String) -> String:
	var fem := ["Goyave", "Mangue", "Papaye", "Noix de coco"]
	if name in fem:
		return "la " + name
	if name in ["Ananas"]:
		return "l'" + name
	return "le " + name


## Score affiché = valeur qui roule vers le vrai score (interpolation).
func displayed_score() -> int:
	return int(round(_shown_score))


func _on_score(s: int) -> void:
	_target_score = s
	_roll_speed = maxf((s - _shown_score) / maxf(_cfg.score_roll_time, 0.01), 1.0)
	_best.text = "Record : %d" % maxi(SaveManager.best_score, s)
	_goal_bar.value = float(_game.max_rank_reached)
	# Pulse à chaque gain
	if _pulse_tween:
		_pulse_tween.kill()
	_score.pivot_offset = Vector2(0, _score.size.y * 0.5)
	_score.scale = Vector2.ONE * _cfg.score_pulse_scale
	_pulse_tween = create_tween().set_ignore_time_scale(true)
	_pulse_tween.tween_property(_score, "scale", Vector2.ONE, _cfg.score_pulse_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _cfg == null:
		return
	# Temps réel : le compteur ne ralentit pas pendant hit-stop / ralentis.
	var dt := delta / maxf(Engine.time_scale, 0.01)
	if _shown_score < _target_score:
		_shown_score = minf(_shown_score + _roll_speed * dt, _target_score)
		_score.text = str(displayed_score())
	if _over_roll >= 0.0 and _over_roll < 1.0:
		_over_roll = minf(_over_roll + dt / maxf(_cfg.game_over_score_roll_time, 0.01), 1.0)
		var k := 1.0 - pow(1.0 - _over_roll, 3.0)
		_set_over_text(int(round(_over_score * k)))


func _set_over_text(shown: int) -> void:
	_over_label.text = "%s\nScore : %d\nPlus gros fruit : %s" % [_over_title, shown, _over_biggest]


func _on_game_over(score: int, max_rank: int, is_record: bool) -> void:
	_build_game_over()
	_over_biggest = _game.catalog.get_def(max_rank).display_name
	_over_title = "NOUVEAU RECORD !" if is_record else "Le panier déborde !"
	_over_score = score
	_target_score = score
	_shown_score = score
	_score.text = str(score)
	_over_thumb.set_fruit(max_rank)
	_set_over_text(0)
	_over_dim.visible = true
	_over_panel.visible = true
	_danger.visible = false
	_pause_button.visible = false
	# Le panneau glisse depuis le bas, puis le score défile.
	await get_tree().process_frame
	var slide := 1400.0
	var rest := _over_panel.position.y
	_over_panel.position.y = rest + slide
	_over_dim.modulate.a = 0.0
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_interval(_cfg.game_over_panel_delay)
	tw.tween_property(_over_dim, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(_over_panel, "position:y", rest, _cfg.game_over_panel_slide_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _over_roll = 0.0)
