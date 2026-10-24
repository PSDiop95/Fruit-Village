class_name PowerupController
extends Node
## Power-ups en partie (Secouer, Pilon, Échange, Agrandir) : disponibilité,
## stock / achat en pièces / rewarded, et application via Game (les fusions
## qui en découlent passent par le MergeSystem M1, aucun raccourci).
## Pilon : mode visée (jeu en pause, choix d'un fruit, annulable).

signal changed
signal used(id: StringName, source: StringName)
signal aim_started
signal aim_ended

var config: PowerupsConfig = preload("res://data/powerups.tres")
var game: Game
var aiming: bool = false
## Temps de jeu (Game._time) à partir duquel « Secouer » est de nouveau possible.
var shake_ready_at: float = -INF
var _aim_source: StringName = &"coins"
var _was_paused: bool = false


func bind(g: Game) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_ALWAYS
	Wallet.stock_changed.connect(_on_stock_changed)
	Wallet.coins_changed.connect(_on_coins_changed)


func _on_stock_changed(_id: StringName, _n: int) -> void:
	changed.emit()


func _on_coins_changed(_c: int, _d: int, _r: StringName) -> void:
	changed.emit()


func is_unlocked() -> bool:
	return Progression.is_unlocked(ProgressionCore.POWERUPS)


func cooldown_left(id: StringName) -> float:
	if id != PowerupsConfig.SHAKE or game == null:
		return 0.0
	return maxf(shake_ready_at - game._time, 0.0)


## Le power-up peut-il s'appliquer maintenant (indépendamment du paiement) ?
func can_apply(id: StringName) -> bool:
	if game == null or game.is_over or aiming or not is_unlocked() or get_tree().paused:
		return false
	match id:
		PowerupsConfig.SHAKE:
			return cooldown_left(id) <= 0.0 and not game.fruits().is_empty()
		PowerupsConfig.PESTLE:
			return not game.fruits().is_empty()
		PowerupsConfig.SWAP:
			return true
		PowerupsConfig.GROW:
			return game.spawner.current() < config.grow_max_rank
	return false


## Utilise une unité du stock.
func use(id: StringName) -> bool:
	if not can_apply(id) or Wallet.stock_of(id) <= 0:
		return false
	if id == PowerupsConfig.PESTLE:
		_start_aim(&"coins")
		return true
	Wallet.use_stock(id)
	_apply(id)
	used.emit(id, &"coins")
	changed.emit()
	return true


## Achète une unité en pièces puis l'utilise.
func buy_and_use(id: StringName) -> bool:
	if not can_apply(id) or not Wallet.buy_powerup(id):
		return false
	return use(id)


## Placement rewarded qui offre ce power-up (ou &"").
func ad_placement(id: StringName) -> StringName:
	var def := config.get_def(id)
	return def.rewarded_placement if def else &""


func can_use_with_ad(id: StringName) -> bool:
	var p := ad_placement(id)
	return p != &"" and can_apply(id) and AdsManager.is_rewarded_ready(p)


## Version gratuite via rewarded : le droit est accordé sur le callback de
## récompense, l'effet s'applique à la reprise du jeu.
func use_with_ad(id: StringName) -> bool:
	if not can_use_with_ad(id):
		return false
	var granted := [false]
	return AdsManager.show_rewarded(ad_placement(id), func() -> void: granted[0] = true,
		func(_rewarded: bool) -> void:
			if granted[0] and game and not game.is_over:
				_apply(id)
				used.emit(id, &"ad")
			changed.emit())


func _apply(id: StringName) -> void:
	match id:
		PowerupsConfig.SHAKE:
			game.shake_basket(config.shake_horizontal, config.shake_vertical)
			shake_ready_at = game._time + config.shake_cooldown
		PowerupsConfig.SWAP:
			game.swap_current()
		PowerupsConfig.GROW:
			game.grow_current(config.grow_max_rank)


# ---------------------------------------------------------------- Pilon

func _start_aim(source: StringName) -> void:
	aiming = true
	_aim_source = source
	_was_paused = get_tree().paused
	get_tree().paused = true
	aim_started.emit()
	changed.emit()


## Touche pendant la visée. true si un fruit a été écrasé.
func pick(screen_pos: Vector2) -> bool:
	if not aiming:
		return false
	var f := game.fruit_at_screen(screen_pos)
	if f == null:
		return false
	_end_aim()
	Wallet.use_stock(PowerupsConfig.PESTLE)
	game.remove_fruit(f, &"pestle")
	used.emit(PowerupsConfig.PESTLE, _aim_source)
	changed.emit()
	return true


func cancel_aim() -> void:
	if aiming:
		_end_aim()
		changed.emit()


func _end_aim() -> void:
	aiming = false
	get_tree().paused = _was_paused
	aim_ended.emit()
