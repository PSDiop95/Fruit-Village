class_name DebugMenu
extends CanvasLayer
## Menu debug (F1 ou appui long à 3 doigts) : forcer un Baobab, un combo,
## un nouveau fruit, basculer effets réduits / FPS.

var game: Game
var juice: Juice

var _panel: PanelContainer
var _reduced_btn: Button
var _fps_btn: Button
var _touches: Dictionary = {}  # index -> true
var _press_time: float = 0.0
var _long_press_done: bool = false


func bind(p_game: Game, p_juice: Juice) -> void:
	game = p_game
	juice = p_juice
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.05, 0.92)
	sb.set_corner_radius_all(24)
	sb.set_content_margin_all(30)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -380
	_panel.offset_right = 380
	_panel.offset_top = -480
	_panel.offset_bottom = 480
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "DEBUG (F1)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)
	_button(box, "Forcer un Baobab", force_baobab)
	_button(box, "Forcer un combo", force_combo)
	_button(box, "Forcer un nouveau fruit", force_discovery)
	_reduced_btn = _button(box, "", func() -> void:
		juice.set_reduced(not juice.reduced)
		_refresh())
	_fps_btn = _button(box, "", func() -> void:
		juice.set_show_fps(not juice.show_fps)
		_refresh())
	_button(box, "Fermer", toggle)
	_refresh()


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 110)
	b.add_theme_font_size_override("font_size", 40)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _refresh() -> void:
	_reduced_btn.text = "Effets réduits : %s" % ("OUI" if juice.reduced else "non")
	_fps_btn.text = "Afficher FPS : %s" % ("OUI" if juice.show_fps else "non")


func is_open() -> bool:
	return _panel.visible


func toggle() -> void:
	_panel.visible = not _panel.visible
	_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		toggle()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
		else:
			_touches.erase(event.index)
		if _touches.size() < 3:
			_press_time = 0.0
			_long_press_done = false


func _process(delta: float) -> void:
	if _touches.size() >= 3 and not _long_press_done:
		_press_time += delta / maxf(Engine.time_scale, 0.01)
		if _press_time >= juice.config.debug_long_press_time:
			_long_press_done = true
			toggle()


# ---------------------------------------------------------------- Commandes

## Deux Pains de singe qui se chevauchent au-dessus du panier → vraie fusion.
func force_baobab() -> void:
	var top := game.catalog.max_rank()
	var r := game.catalog.get_def(top).radius
	var y := game.config.spawn_y + r * 0.5
	game.spawn_fruit(top, Vector3(-r * 0.6, y, 0))
	game.spawn_fruit(top, Vector3(r * 0.6, y, 0))


## Paires de fruits qui fusionnent à la suite (< fenêtre de combo) → x2, x3, x4.
func force_combo(pairs: int = 4, rank: int = 0) -> void:
	var r := game.catalog.get_def(rank).radius
	var xs := [-2.0, 2.0, -0.8, 0.8, 0.0]
	for i in pairs:
		if i > 0:
			await get_tree().create_timer(0.22, true, false, true).timeout
		if not is_instance_valid(game) or game.is_over:
			return
		var x: float = xs[i % xs.size()]
		game.spawn_fruit(rank, Vector3(x - r * 0.6, game.config.spawn_y, 0))
		game.spawn_fruit(rank, Vector3(x + r * 0.6, game.config.spawn_y, 0))


## Paire du rang juste sous le prochain fruit jamais atteint → « Nouveau : X ! ».
func force_discovery() -> void:
	var target := clampi(maxi(SaveManager.best_rank, game.max_rank_reached) + 1,
		1, game.catalog.max_rank())
	var r := game.catalog.get_def(target - 1).radius
	var y := game.config.spawn_y
	game.spawn_fruit(target - 1, Vector3(-r * 0.6, y, 0))
	game.spawn_fruit(target - 1, Vector3(r * 0.6, y, 0))
