class_name GameHud
extends CanvasLayer
## HUD final (M3) : score en gros chiffres (compteur roulant), record, bouton
## pause, bulle « Suivant » avec le vrai modèle 3D, barre « prochain fruit
## jamais atteint », jauge de danger, menu pause, écran de fin.
## Combos / bandeaux : Juice.

## L'écran de fin ou la pause demande le retour au titre.
signal menu_requested

const HUD_DIR := "res://assets/ui/hud/"
const SCORE_GOLD := Color("ffc93a")

var _game: Game
var _cfg: JuiceConfig
var _root: Control
var _score: Label
var _best: Label
var _star: TextureRect
var _next: Label
var _next_thumb: FruitThumb
var _goal_label: Label
var _goal_bar: ProgressBar
var _danger: ProgressBar
var _pause_button: TextureButton
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

	# --- Bandeau haut : planche du score | bouton pause | anneau « Suivant »
	# (éléments peints : assets/ui/hud/, découpés par tools/prepare_ui_art.gd)
	var plank := _texture_rect(HUD_DIR + "score_plank.png", Rect2(14, 28, 500, 254))
	_root.add_child(plank)
	var star := _texture_rect(HUD_DIR + "star.png", Rect2(46, 52, 146, 146))
	star.pivot_offset = Vector2(73, 73)
	plank.add_child(star)
	_star = star
	_score = _wood_label(104, SCORE_GOLD, 22)
	_score.position = Vector2(196, 34)
	_score.size = Vector2(290, 130)
	plank.add_child(_score)
	_best = _wood_label(40, UiTheme.CREAM, 12)
	_best.position = Vector2(150, 166)
	_best.size = Vector2(340, 56)
	plank.add_child(_best)

	_pause_button = TextureButton.new()
	_pause_button.texture_normal = load(HUD_DIR + "pause.png")
	_pause_button.ignore_texture_size = true
	_pause_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_pause_button.position = Vector2(1080 - 432, 46)
	_pause_button.size = Vector2(150, 150)
	_pause_button.pivot_offset = Vector2(75, 75)
	_pause_button.button_down.connect(func() -> void: _press_bounce(_pause_button, 0.88))
	_pause_button.button_up.connect(func() -> void: _press_bounce(_pause_button, 1.0))
	_pause_button.pressed.connect(open_pause)
	_root.add_child(_pause_button)

	var ring := _texture_rect(HUD_DIR + "next_ring.png", Rect2(1080 - 262, 58, 236, 215))
	_root.add_child(ring)
	_next_thumb = FruitThumb.new()
	_next_thumb.position = Vector2(48, 38)
	_next_thumb.size = Vector2(140, 140)
	ring.add_child(_next_thumb)
	var nt := _wood_label(42, UiTheme.CREAM, 12)
	nt.text = "Suivant"
	nt.position = Vector2(-20, -54)
	nt.size = Vector2(276, 60)
	ring.add_child(nt)
	_next = _wood_label(40, Color.WHITE, 12)
	_next.position = Vector2(-20, 200)
	_next.size = Vector2(276, 56)
	ring.add_child(_next)

	# --- Objectif : prochain fruit jamais atteint
	var goal := VBoxContainer.new()
	goal.set_anchors_preset(Control.PRESET_TOP_WIDE)
	goal.offset_top = 322
	goal.offset_left = 250
	goal.offset_right = -150
	goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(goal)
	_goal_label = Label.new()
	_goal_label.theme_type_variation = &"LabelSmall"
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.add_theme_color_override("font_color", UiTheme.CREAM)
	_goal_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	_goal_label.add_theme_constant_override("outline_size", 14)
	goal.add_child(_goal_label)
	_goal_bar = ProgressBar.new()
	_goal_bar.show_percentage = false
	_goal_bar.custom_minimum_size = Vector2(0, 26)
	_goal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal.add_child(_goal_bar)

	_danger = ProgressBar.new()
	_danger.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_danger.offset_top = 402
	_danger.offset_bottom = 418
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


func _texture_rect(path: String, r: Rect2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = r.position
	t.size = r.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Texte « bois » : police d'affichage, contour brun épais, ombre portée.
static func _wood_label(font_size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = UiTheme.display_font()
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = UiTheme.INK
	ls.shadow_size = 0
	ls.shadow_color = Color(0.1, 0.05, 0.02, 0.45)
	ls.shadow_offset = Vector2(0, font_size * 0.06)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Bouton qui s'enfonce puis rebondit (élastique).
func _press_bounce(c: Control, target: float) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	if target < 1.0:
		tw.tween_property(c, "scale", Vector2.ONE * target, 0.06)
	else:
		tw.tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC) \
			.set_ease(Tween.EASE_OUT)


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
	_score.pivot_offset = _score.size * 0.5
	_score.scale = Vector2.ONE * _cfg.score_pulse_scale
	_star.scale = Vector2.ONE * (_cfg.score_pulse_scale + 0.1)
	_star.rotation = -0.35
	_pulse_tween = create_tween().set_ignore_time_scale(true).set_parallel()
	_pulse_tween.tween_property(_score, "scale", Vector2.ONE, _cfg.score_pulse_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_star, "scale", Vector2.ONE, _cfg.score_pulse_time * 2.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(_star, "rotation", 0.0, _cfg.score_pulse_time * 2.5) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


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
