class_name GameHud
extends CanvasLayer
## HUD placeholder : score (compteur roulant), record, fruit suivant, danger,
## écran de fin (glisse, score qui défile). Combos / bandeaux : Juice.

var _game: Game
var _score: Label
var _best: Label
var _next: Label
var _next_badge: FruitBadge
var _danger: ProgressBar
var _over_dim: ColorRect
var _over_panel: PanelContainer
var _over_label: Label
var _cfg: JuiceConfig
var _target_score: int = 0
var _shown_score: float = 0.0
var _roll_speed: float = 0.0
var _pulse_tween: Tween
var _over_box: VBoxContainer
var _over_title: String = ""
var _over_biggest: String = ""
var _over_roll: float = -1.0
var _over_score: int = 0


func bind(game: Game) -> void:
	_game = game
	_cfg = game.juice_config
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	game.score_changed.connect(_on_score)
	game.game_over.connect(_on_game_over)
	_score.text = "0"
	_best.text = "Record : %d" % SaveManager.best_score


func _label(size: int, color := Color("3b2314")) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = 10
	ls.outline_color = Color(1, 1, 1, 0.85)
	l.label_settings = ls
	return l


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 40
	top.offset_right = -40
	top.offset_top = 50
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(left)
	_score = _label(84)
	left.add_child(_score)
	_best = _label(40, Color("6d4c2f"))
	left.add_child(_best)

	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_child(right)
	var nt := _label(36, Color("6d4c2f"))
	nt.text = "Suivant"
	nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(nt)
	_next_badge = FruitBadge.new()
	_next_badge.custom_minimum_size = Vector2(110, 110)
	_next_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(_next_badge)
	_next = _label(34)
	_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_next)

	_danger = ProgressBar.new()
	_danger.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_danger.offset_top = 300
	_danger.offset_bottom = 316
	_danger.offset_left = 120
	_danger.offset_right = -120
	_danger.show_percentage = false
	_danger.max_value = 1.0
	_danger.modulate = Color(1, 0.2, 0.2)
	_danger.visible = false
	root.add_child(_danger)

	_over_dim = ColorRect.new()
	_over_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_dim.color = Color(0.12, 0.07, 0.03, 0.6)
	_over_dim.visible = false
	root.add_child(_over_dim)

	_over_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff3df")
	sb.set_corner_radius_all(36)
	sb.set_content_margin_all(40)
	sb.border_color = Color("a0522d")
	sb.set_border_width_all(8)
	_over_panel.add_theme_stylebox_override("panel", sb)
	_over_panel.set_anchors_preset(Control.PRESET_CENTER)
	_over_panel.offset_left = -380
	_over_panel.offset_right = 380
	_over_panel.offset_top = -320
	_over_panel.offset_bottom = 320
	_over_panel.visible = false
	root.add_child(_over_panel)
	var box := VBoxContainer.new()
	_over_box = box
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 40)
	_over_panel.add_child(box)
	_over_label = _label(56)
	_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_over_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_over_label)
	var again := Button.new()
	again.text = "Rejouer"
	again.custom_minimum_size = Vector2(420, 130)
	again.add_theme_font_size_override("font_size", 56)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "focus"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color("2e7d32") if state != "pressed" else Color("1b5e20")
		bs.set_corner_radius_all(65)
		again.add_theme_stylebox_override(state, bs)
	again.add_theme_color_override("font_color", Color.WHITE)
	again.add_theme_color_override("font_hover_color", Color.WHITE)
	again.pressed.connect(func() -> void: _game.restart())
	box.add_child(again)


func set_next(rank: int, def: FruitDef) -> void:
	if _next == null:
		return
	_next.text = def.display_name
	_next_badge.color = def.color
	_next_badge.number = rank + 1


func set_danger(ratio: float) -> void:
	if _danger == null:
		return
	_danger.visible = ratio > 0.01
	_danger.value = ratio


## Score affiché = valeur qui roule vers le vrai score (interpolation).
func displayed_score() -> int:
	return int(round(_shown_score))


func _on_score(s: int) -> void:
	_target_score = s
	_roll_speed = maxf((s - _shown_score) / maxf(_cfg.score_roll_time, 0.01), 1.0)
	_best.text = "Record : %d" % maxi(SaveManager.best_score, s)
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
	_over_biggest = _game.catalog.get_def(max_rank).display_name
	_over_title = "NOUVEAU RECORD !" if is_record else "Le panier déborde !"
	_over_score = score
	_target_score = score
	_shown_score = score
	_score.text = str(score)
	_set_over_text(0)
	_over_dim.visible = true
	_over_panel.visible = true
	_danger.visible = false
	# Le panneau glisse depuis le bas, puis le score défile.
	var slide := 1400.0
	_over_panel.offset_top += slide
	_over_panel.offset_bottom += slide
	_over_dim.modulate.a = 0.0
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_interval(_cfg.game_over_panel_delay)
	tw.tween_property(_over_dim, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(_over_panel, "offset_top", _over_panel.offset_top - slide,
		_cfg.game_over_panel_slide_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_over_panel, "offset_bottom", _over_panel.offset_bottom - slide,
		_cfg.game_over_panel_slide_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _over_roll = 0.0)
