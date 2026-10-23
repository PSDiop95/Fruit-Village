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
	add_child(curtain)
	show_title()


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
	game = (load(GAME_SCENE) as PackedScene).instantiate()
	game.restart_requested.connect(start_game, CONNECT_DEFERRED)
	game.menu_requested.connect(show_title, CONNECT_DEFERRED)
	add_child(game)
	curtain.reveal()


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
	market.setup(load("res://data/visual.tres"), cfg)
	market.follow_ambiance_setting()
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = cfg.basket_inner_width + cfg.wall_thickness * 2.0 + cfg.camera_side_margin
	var vs := get_viewport().get_visible_rect().size
	cam.position = Vector3(0, Game.camera_center_y(cfg, vs.y / maxf(vs.x, 1.0)), 20)
	root.add_child(cam)
	cam.current = true
	return root
