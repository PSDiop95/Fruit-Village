class_name PowerupBar
extends Control
## Barre de power-ups, dans le style du HUD M3 : anneau bois à lianes avec
## l'icône peinte du power-up (PowerupDef.icon, sinon pictogramme texte),
## pastille rouge de stock, pastille crème dessous (nom, prix, délai,
## « ▶ Pub », « Niv. 3 »). En bas de l'écran, dans la bande que la caméra
## réserve sous le panier (GameConfig.bottom_ui_band_px).
## Visible dès le début : verrouillée (« Niv. 3 ») tant que le niveau n'est pas
## atteint ; un tap explique le déblocage.
## Stock vide → offre (pièces / pub). Pilon : bandeau de visée + Annuler.

const RING := "res://assets/ui/hud/next_ring.png"
## Débord de la pastille sous l'anneau (px).
const PILL_BELOW := 24.0
const RING_MIN := 118.0
const RING_MAX := 160.0
## Rafraîchissement de l'état des boutons (fruits présents, rang, délai).
const REFRESH_EVERY := 0.2

var controller: PowerupController
## Parent des fenêtres (offre) ; par défaut le parent de la barre.
var modal_host: Control
var buttons: Dictionary = {}  # id -> TextureButton
var offer: Control
var aim_overlay: Control
var _row: HBoxContainer
var _glyphs: Dictionary = {}
var _stock_labels: Dictionary = {}
var _info_pills: Dictionary = {}
var _coin_icons: Dictionary = {}
var _refresh_left: float = 0.0
var _ring_size: float = 130.0


func bind(c: PowerupController) -> void:
	controller = c
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring_size = _layout_ring_size()
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 26)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	for def in c.config.powerups:
		_row.add_child(_make_button(def))
	_place_row()
	get_viewport().size_changed.connect(_place_row)
	c.changed.connect(refresh)
	c.aim_started.connect(_show_aim)
	c.aim_ended.connect(_hide_aim)
	AdsManager.availability_changed.connect(refresh)
	Progression.xp_changed.connect(_on_xp_changed)
	refresh()


func _on_xp_changed(_x: int, _l: int) -> void:
	refresh()


## Bande du bas réservée par la caméra (px du canevas) : 0 en 16:9.
func _band_px(canvas: Vector2) -> float:
	var gc := controller.game.config
	var w := gc.basket_inner_width + gc.wall_thickness * 2.0 + gc.camera_side_margin
	return Game.bottom_band_world(gc, canvas.y / maxf(canvas.x, 1.0)) * canvas.x / w


func _layout_ring_size() -> float:
	var canvas := get_viewport().get_visible_rect().size
	return clampf(_band_px(canvas) - PILL_BELOW - 40.0, RING_MIN, RING_MAX)


## En bas de l'écran : centrée dans la bande réservée (écrans allongés), sinon
## posée sur la frise du bas du cadre (16:9).
func _place_row() -> void:
	var canvas := get_viewport().get_visible_rect().size
	var band := _band_px(canvas)
	_row.size = Vector2(1080.0, _ring_size)
	var y := canvas.y - _ring_size - PILL_BELOW - 10.0
	if band > _ring_size + PILL_BELOW:
		y = canvas.y - band * 0.5 - (_ring_size + PILL_BELOW) * 0.5
	_row.position = Vector2(0, y)


func _make_button(def: PowerupDef) -> Control:
	var s := _ring_size
	var b := TextureButton.new()
	b.texture_normal = def.icon if def.icon else load(RING)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(s, s)
	b.pivot_offset = Vector2(s, s) * 0.5
	b.tooltip_text = def.description
	b.button_down.connect(_press.bind(b, 0.88))
	b.button_up.connect(_press.bind(b, 1.0))
	b.pressed.connect(_on_pressed.bind(def.id))
	# Pictogramme : texte bois (police d'affichage, crème cerné d'encre).
	var g := GameHud._wood_label(int(s * 0.46), def.color.lightened(0.45), 12)
	g.text = def.glyph
	g.position = Vector2(0, -s * 0.02)
	g.size = Vector2(s, s)
	b.add_child(g)
	g.visible = def.icon == null
	_glyphs[def.id] = g
	var stock := MetaUi.badge("0")
	stock.position = Vector2(s - 50, -10)
	b.add_child(stock)
	_stock_labels[def.id] = stock
	# Pastille crème à cheval sur le bas de l'anneau (comme le nom sous « Suivant »).
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"Pill"
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _small_pill())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	var coin := MetaUi.coin_icon(30)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	_coin_icons[def.id] = coin
	var l := MetaUi.label("", int(clampf(s * 0.21, 26, 34)), UiTheme.INK, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(l)
	b.add_child(pill)
	pill.resized.connect(func() -> void:
		pill.position = Vector2((s - pill.size.x) * 0.5, s - pill.size.y * 0.55))
	_info_pills[def.id] = l
	buttons[def.id] = b
	return b


static func _small_pill() -> StyleBox:
	var sb := (UiTheme.get_theme().get_stylebox("panel", "Pill") as StyleBoxFlat).duplicate()
	sb.set_border_width_all(4)
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 0
	sb.content_margin_bottom = 2
	return sb


func _press(b: Control, target: float) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	if target < 1.0:
		tw.tween_property(b, "scale", Vector2.ONE * target, 0.06)
	else:
		tw.tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC) \
			.set_ease(Tween.EASE_OUT)


func refresh() -> void:
	if controller == null:
		return
	visible = not controller.game.is_over and not controller.aiming
	var unlocked := controller.is_unlocked()
	for id in buttons:
		var b: TextureButton = buttons[id]
		var def := controller.config.get_def(id)
		var stock := Wallet.stock_of(id)
		var usable := unlocked and controller.can_apply(id)
		var free_ad := unlocked and stock == 0 and controller.can_use_with_ad(id)
		var affordable := stock > 0 or Wallet.can_afford(def.price) or free_ad
		b.disabled = unlocked and not usable
		b.modulate = Color.WHITE if usable and affordable else Color(0.62, 0.6, 0.58, 1.0)
		var stock_l: Label = _stock_labels[id]
		stock_l.visible = unlocked and stock > 0
		stock_l.text = str(stock)
		var info: Label = _info_pills[id]
		var cd := controller.cooldown_left(id)
		# Pièce seulement devant un prix (maquette : « [pièce] 300 »).
		(_coin_icons[id] as Control).visible = unlocked and cd <= 0.0 and stock == 0 and not free_ad
		if not unlocked:
			info.text = "Niv. %d" % Progression.unlock_level(ProgressionCore.POWERUPS)
		elif cd > 0.0:
			info.text = "%d s" % ceili(cd)
		elif stock > 0:
			info.text = def.display_name
		elif free_ad:
			info.text = "%s Pub" % MetaUi.AD_GLYPH
		else:
			info.text = "%d" % def.price


func _process(delta: float) -> void:
	_refresh_left -= delta
	if controller and _refresh_left <= 0.0:
		_refresh_left = REFRESH_EVERY
		refresh()


func _on_pressed(id: StringName) -> void:
	if not controller.is_unlocked():
		_explain_locked()
	elif Wallet.stock_of(id) > 0:
		controller.use(id)
	else:
		open_offer(id)


func _modal(title: String) -> MetaModal:
	var was_paused := get_tree().paused
	get_tree().paused = true
	var m := MetaModal.new(title, 860.0)
	(modal_host if modal_host else get_parent()).add_child(m)
	m.closed.connect(func() -> void: get_tree().paused = was_paused)
	return m


func _explain_locked() -> MetaModal:
	var m := _modal("Power-ups")
	var l := MetaUi.label("Secouer, Pilon, Échange, Agrandir : débloqués au niveau %d.\nUn de chaque offert !"
		% Progression.unlock_level(ProgressionCore.POWERUPS), 42)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.body.add_child(l)
	m.body.add_child(MetaUi.button("OK", &"ButtonGreen", Vector2(360, 116), m.close, 48))
	offer = m
	return m


## Stock vide : acheter en pièces, ou gratuit via pub (si le placement existe
## et qu'une pub est prête). Le jeu est en pause pendant l'offre.
func open_offer(id: StringName) -> MetaModal:
	var def := controller.config.get_def(id)
	var m := _modal(def.display_name)
	offer = m
	var d := MetaUi.label(def.description, 42)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(620, 0)
	m.body.add_child(d)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.body.add_child(row)
	row.add_child(MetaUi.label("Tu as  ", 40))
	row.add_child(MetaUi.coin_pill(Wallet.coins(), 40))
	var buy := MetaUi.button("Acheter  %d" % def.price, &"ButtonGreen", Vector2(560, 116), func() -> void:
		m.close()
		controller.buy_and_use(id), 46)
	buy.disabled = not Wallet.can_afford(def.price)
	m.body.add_child(buy)
	if controller.ad_placement(id) != &"" and AdsManager.is_rewarded_ready(controller.ad_placement(id)):
		AdsManager.offer(controller.ad_placement(id))
		m.body.add_child(MetaUi.ad_button("Gratuit avec une pub", Vector2(640, 116), func() -> void:
			m.close()
			controller.use_with_ad(id), 44))
	return m


# ---------------------------------------------------------------- Visée (pilon)

func _show_aim() -> void:
	aim_overlay = Control.new()
	aim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	aim_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	aim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	get_parent().add_child(aim_overlay)
	var tint := ColorRect.new()
	tint.color = Color(0.1, 0.05, 0.0, 0.25)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_overlay.add_child(tint)
	var banner := MetaUi.outlined("Touche un fruit à écraser", 56, UiTheme.CREAM, 14)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(0, _row.position.y + _ring_size * 0.3)
	banner.size = Vector2(1080, 80)
	aim_overlay.add_child(banner)
	UiJuice.breathe(banner, 0.05, 1.0)
	var cancel := MetaUi.button("Annuler", &"ButtonCream", Vector2(360, 112), controller.cancel_aim, 44)
	cancel.position = Vector2(540 - 180, get_viewport_rect().size.y - 150)
	aim_overlay.add_child(cancel)
	aim_overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			controller.pick(e.position))


func _hide_aim() -> void:
	if aim_overlay:
		aim_overlay.queue_free()
		aim_overlay = null
	refresh()
