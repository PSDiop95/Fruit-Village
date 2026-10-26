class_name Main
extends Node
## Point d'entrée : écran titre ↔ partie. Le titre s'affiche sur le décor du
## marché (sans partie) ; « Jouer » instancie Game, « Menu » revient au titre.

const GAME_SCENE := "res://scenes/Game.tscn"

var title: TitleScreen
var game: Game
var _backdrop: Node3D
var curtain := UiJuice.Curtain.new()


func _ready() -> void:
	ScreenFit.apply(get_window())
	add_child(curtain)
	Wallet.coins_changed.connect(_on_coins_changed)
	if _needs_loading_screen():
		var loading := LoadingScreen.new()
		add_child(loading)
		loading.finished.connect(func() -> void:
			loading.queue_free()
			show_title(), CONNECT_ONE_SHOT)
	else:
		show_title()


## Écran de chargement au premier démarrage du jeu (pas en headless — tests —
## ni sous un script SceneTree d'outil — captures —, ni au retour au menu).
static var _loaded_once: bool = false


func _needs_loading_screen() -> bool:
	if _loaded_once or DisplayServer.get_name() == "headless" \
			or Engine.get_main_loop().get_script() != null:
		return false
	_loaded_once = true
	return true


## Pièces gagnées (fin de partie, Doubler, missions, cadeau, niveau) : son.
func _on_coins_changed(_coins: int, delta: int, reason: StringName) -> void:
	if delta <= 0 or reason == &"load":
		return
	var cfg: JuiceConfig = load("res://data/juice.tres")
	if cfg.sounds and cfg.sounds.coins:
		Audio.play_limited(&"coins", cfg.coins_max_per_second, cfg.sounds.coins, cfg.coins_volume_db)


func show_title() -> void:
	_free_game()
	_backdrop = _make_backdrop()
	add_child(_backdrop)
	title = TitleScreen.new()
	add_child(title)
	title.play_pressed.connect(start_game)
	curtain.reveal()


func start_game() -> void:
	if title:
		title.queue_free()
		title = null
	if _backdrop:
		_backdrop.queue_free()
		_backdrop = null
	_free_game()
	var cfg: JuiceConfig = load("res://data/juice.tres")
	if cfg.sounds and cfg.sounds.play:
		Audio.play(cfg.sounds.play, cfg.play_volume_db)
	game = (load(GAME_SCENE) as PackedScene).instantiate()
	game.restart_requested.connect(_replay, CONNECT_DEFERRED)
	game.menu_requested.connect(show_title, CONNECT_DEFERRED)
	add_child(game)
	curtain.reveal()


## Rejouer : seul moment où un interstitiel peut passer (entre deux parties),
## si InterstitialPolicy l'autorise. La partie suivante démarre à sa fermeture.
func _replay() -> void:
	if not AdsManager.try_interstitial(start_game):
		start_game()


func _free_game() -> void:
	get_tree().paused = false
	if game:
		game.queue_free()
		game = null


## Décor du titre : marché + panier vide, caméra du jeu.
func _make_backdrop() -> Node3D:
	var root := Node3D.new()
	root.name = "TitleBackdrop"
	var cfg: GameConfig = load("res://data/game_config.tres")
	var market := MarketScene.new()
	root.add_child(market)
	var vc: VisualConfig = load("res://data/visual.tres")
	# Même qualité qu'en partie (détection auto ou réglage joueur).
	var q := VisualQuality.resolve(int(SaveManager.get_setting(&"quality")))
	FruitModels.set_quality(q)
	VisualQuality.apply_viewport(get_viewport(), q, vc)
	market.setup(vc, cfg)
	market.follow_ambiance_setting()
	# La mascotte attend sur le cadre et salue à l'arrivée.
	var mascot := Mascot.create(load("res://data/visual.tres"), load("res://data/juice.tres"))
	if mascot:
		root.add_child(mascot)
		# Méthode liée (pas de lambda) : déconnectée si la mascotte est libérée.
		get_tree().create_timer(0.6).timeout.connect(mascot.react.bind(Mascot.Mood.CHEER, 1.0))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = cfg.basket_inner_width + cfg.wall_thickness * 2.0 + cfg.camera_side_margin
	var vs := get_viewport().get_visible_rect().size
	cam.position = Vector3(0, Game.camera_center_y(cfg, vs.y / maxf(vs.x, 1.0)), 20)
	root.add_child(cam)
	cam.current = true
	return root
