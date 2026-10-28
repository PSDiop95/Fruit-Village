class_name TitleScreen
extends CanvasLayer
## Écran titre : logo Fruit Village en haut ; dans le cadre du panier (3D, même
## cadrage que la partie) : pastille « Plus gros fruit », Jouer, Réglages,
## centrés. Boutons peints (thème : ButtonGreenBig / ButtonOrangeBig / PillBest).

signal play_pressed

const LOGO := "res://assets/branding/fruit-village-logo.png"
## Largeurs (px, écran 1080 de large) des éléments du menu.
const MENU_WIDTH := 660.0
const PLAY_SIZE := Vector2(640, 230)
const SETTINGS_SIZE := Vector2(500, 190)
const PILL_SIZE := Vector2(620, 200)

var play_button: Button
var settings_button: Button
var best_thumb: FruitThumb
var best_name: Label
var logo: TextureRect
var menu: VBoxContainer
## M4 : pièces / niveau, accès Missions / Cadeau du jour / Album.
var coins_pill: PanelContainer
var level_label: Label
var level_bar: ProgressBar
var feature_buttons: Dictionary = {}  # ProgressionCore.* -> Button
var panel: MetaModal
var _root: Control
var _settings: SettingsPanel
var _badges: Dictionary = {}


func _ready() -> void:
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	ScreenFit.fit_to_safe(_root)
	var basket := basket_screen_rect(ScreenFit.safe_rect(get_viewport()).size)

	# Logo : centré dans la bande de ciel au-dessus du cadre.
	logo = TextureRect.new()
	logo.texture = load(LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := 40.0
	var h := clampf(basket.position.y - 150.0 - top, 360.0, 760.0)
	logo.position = Vector2(540.0 - h * 0.5, top + maxf(basket.position.y - 150.0 - top - h, 0.0) * 0.5)
	logo.size = Vector2(h, h)
	_root.add_child(logo)
	UiJuice.pop_in(logo, 0.5)

	# Menu : centré dans l'intérieur du panier.
	menu = VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 44)
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.position = basket.position
	menu.size = basket.size
	_root.add_child(menu)

	menu.add_child(_status_row())
	menu.add_child(_best_pill())

	play_button = Button.new()
	play_button.text = "Jouer"
	play_button.theme_type_variation = &"ButtonGreenBig"
	play_button.custom_minimum_size = PLAY_SIZE
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.pressed.connect(func() -> void: play_pressed.emit())
	menu.add_child(play_button)

	settings_button = Button.new()
	settings_button.text = "Réglages"
	settings_button.theme_type_variation = &"ButtonOrangeBig"
	settings_button.custom_minimum_size = SETTINGS_SIZE
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	settings_button.pressed.connect(open_settings)
	menu.add_child(settings_button)
	menu.add_child(_feature_row())

	# Jouer respire (invite à toucher) : pas de rebond d'appui sur ce bouton.
	play_button.set_meta(UiJuice.META, true)
	UiJuice.bounce_all(_root)
	UiJuice.breathe(play_button)

	# Méthodes (pas de lambdas) : déconnectées d'office quand l'écran est libéré.
	Wallet.coins_changed.connect(_on_coins_changed)
	Progression.xp_changed.connect(_on_xp_changed)
	Missions.changed.connect(refresh_meta)
	DailyRewards.changed.connect(refresh_meta)
	refresh_meta()
	# Cadeau du jour disponible : la fenêtre s'ouvre d'elle-même à l'arrivée.
	if DailyRewards.can_claim():
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if is_inside_tree() and panel == null and _settings == null:
				open_feature(ProgressionCore.DAILY))


# ---------------------------------------------------------------- M4 : méta

## Pastille crème M3 : pièces | niveau + barre d'XP.
func _status_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coins_pill = MetaUi.coin_pill(Wallet.coins(), 48)
	row.add_child(coins_pill)
	var lv := PanelContainer.new()
	lv.theme_type_variation = &"Pill"
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lv)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	lv.add_child(col)
	level_label = MetaUi.label("", 44, UiTheme.INK, true)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(level_label)
	level_bar = MetaUi.progress_bar(18, UiTheme.WAX_YELLOW)
	level_bar.custom_minimum_size = Vector2(200, 18)
	level_bar.max_value = 1.0
	col.add_child(level_bar)
	return row


## Missions / Cadeau du jour / Album : boutons crème peints ; verrouillés
## (« Niv. N ») tant que le niveau n'est pas atteint ; pastille rouge si
## quelque chose est à réclamer.
func _feature_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	for f in [[ProgressionCore.MISSIONS, "Missions"], [ProgressionCore.DAILY, "Cadeau"],
			[ProgressionCore.ALBUM, "Album"]]:
		var b := MetaUi.button(f[1], &"ButtonCream", Vector2(250, 112), open_feature.bind(f[0]), 40)
		row.add_child(b)
		feature_buttons[f[0]] = b
		var badge := MetaUi.badge("!")
		badge.position = Vector2(250 - 44, -16)
		badge.visible = false
		b.add_child(badge)
		_badges[f[0]] = badge
	return row


func _on_coins_changed(_c: int, _d: int, _r: StringName) -> void:
	refresh_meta()


func _on_xp_changed(_x: int, _l: int) -> void:
	refresh_meta()


func refresh_meta() -> void:
	if coins_pill == null:
		return
	MetaUi.set_pill_amount(coins_pill, Wallet.coins())
	level_label.text = "Niveau %d" % Progression.level()
	level_bar.value = Progression.core.progress_ratio()
	var names := {ProgressionCore.MISSIONS: "Missions", ProgressionCore.DAILY: "Cadeau",
		ProgressionCore.ALBUM: "Album"}
	for f in feature_buttons:
		var b: Button = feature_buttons[f]
		var open := Progression.is_unlocked(f)
		b.text = names[f] if open else "Niv. %d" % Progression.unlock_level(f)
		b.modulate = Color.WHITE if open else Color(1, 1, 1, 0.6)
	_badges[ProgressionCore.MISSIONS].visible = Missions.claimable_count() > 0
	_badges[ProgressionCore.DAILY].visible = DailyRewards.can_claim()


## Ouvre Missions / Cadeau / Album (fenêtre « verrouillé » sinon).
func open_feature(f: StringName) -> MetaModal:
	if panel:
		panel.close()
	if not Progression.is_unlocked(f):
		panel = MetaModal.new(MetaUi.feature_name(f), 820.0)
		var l := MetaUi.label("Débloqué au niveau %d.\nJoue des parties pour gagner de l'XP !" %
			Progression.unlock_level(f), 44)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.body.add_child(l)
	else:
		match f:
			ProgressionCore.MISSIONS: panel = MissionsPanel.new()
			ProgressionCore.DAILY: panel = DailyPanel.new()
			_: panel = AlbumPanel.new()
	_root.add_child(panel)
	panel.closed.connect(func() -> void:
		panel = null
		refresh_meta())
	return panel


## Pastille crème : miniature 3D dans le médaillon, texte à droite.
func _best_pill() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = PILL_SIZE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PillBest"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	for line in [["Plus gros fruit :", 38], [FruitCatalogNames.name_of(SaveManager.best_rank), 60]]:
		var l := Label.new()
		l.text = line[0]
		l.add_theme_font_override("font", UiTheme.display_font())
		l.add_theme_font_size_override("font_size", line[1])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
	best_name = col.get_child(1)
	# Médaillon de la texture (UiTheme.PILL_SRC) mis à l'échelle de la pastille.
	var k := PILL_SIZE.y / UiTheme.PILL_SRC.h
	var c: Vector2 = UiTheme.PILL_SRC.inset * k
	var r: float = UiTheme.PILL_SRC.inset_r * k * 0.95
	best_thumb = FruitThumb.new()
	best_thumb.position = c - Vector2(r, r)
	best_thumb.size = Vector2(r, r) * 2.0
	holder.add_child(best_thumb)
	best_thumb.set_fruit(SaveManager.best_rank)
	return holder


## Intérieur du panier à l'écran (px du canevas 1080 de large), même cadrage
## que la caméra de la partie (Game.camera_center_y).
static func basket_screen_rect(canvas: Vector2) -> Rect2:
	var cfg: GameConfig = load("res://data/game_config.tres")
	var world_w := cfg.basket_inner_width + cfg.wall_thickness * 2.0 + cfg.camera_side_margin
	var ppm := canvas.x / world_w
	var center_y := Game.camera_center_y(cfg, canvas.y / maxf(canvas.x, 1.0))
	var half := cfg.basket_inner_width * 0.5
	var top := canvas.y * 0.5 - (cfg.basket_height - center_y) * ppm
	var bottom := canvas.y * 0.5 + center_y * ppm
	return Rect2(canvas.x * 0.5 - half * ppm, top, half * 2.0 * ppm, bottom - top)


func open_settings() -> SettingsPanel:
	if _settings == null:
		_settings = SettingsPanel.new()
		_root.add_child(SettingsPanel.centered(_settings, true))
		UiJuice.pop_in(_settings)
		_settings.closed.connect(func() -> void: _settings = null)
	return _settings


func settings_open() -> bool:
	return _settings != null
