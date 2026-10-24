class_name GameMeta
extends Node
## Pont partie → systèmes méta (aucune UI) : missions, album, analytics en
## direct ; pièces, XP, compteur de parties à la clôture (finalize).
## La clôture a lieu quand la partie est vraiment finie : offre « Continuer »
## refusée / indisponible, Rejouer, Menu. Idempotente.

signal finalized(summary: Dictionary)

var game: Game
var merges: int = 0
var combos: int = 0
var drops: int = 0
var powerups_used: int = 0
var duration: float = 0.0
var is_finalized: bool = false
## {score, max_rank, coins, xp, levels, level_coins, cause, duration, …}
var summary: Dictionary = {}


func bind(g: Game) -> void:
	game = g
	process_mode = Node.PROCESS_MODE_PAUSABLE
	game.dropped.connect(_on_dropped)
	game.merged.connect(_on_merged)
	game.powerups.used.connect(_on_powerup_used)
	Missions.refresh()
	AdsManager.notify_game_started()
	Analytics.log_event(&"game_start", {"games_played": SaveManager.games_played,
		"level": Progression.level()})


func _process(delta: float) -> void:
	if game and not game.is_over:
		duration += delta / maxf(Engine.time_scale, 0.01)


func _on_dropped(fruit: Fruit) -> void:
	drops += 1
	Collection.discover(fruit.rank)


func _on_merged(rank_created: int, _pos: Vector3, _points: int, combo: int) -> void:
	merges += 1
	Missions.report(MissionDef.Kind.MERGES)
	# Un combo = une cascade qui atteint x2 (comptée une fois).
	if combo == 2:
		combos += 1
		Missions.report(MissionDef.Kind.COMBOS)
	var rank := rank_created if rank_created >= 0 else game.catalog.max_rank() + 1
	Analytics.log_event(&"merge", {"rank": rank + 1})
	if rank_created >= 0:
		Collection.discover(rank_created)
		Missions.report(MissionDef.Kind.CREATE_RANK, 1, rank_created)


func _on_powerup_used(id: StringName, source: StringName) -> void:
	powerups_used += 1
	Missions.report(MissionDef.Kind.POWERUPS)
	Analytics.log_event(&"powerup_used", {"type": String(id), "source": String(source)})


## « Continuer » proposable ? (rewarded prête, pas encore utilisé)
func can_continue() -> bool:
	var cfg := AdsManager.config
	return game.is_over and not is_finalized and game.continues_used < cfg.continue_max_per_game \
		and AdsManager.is_rewarded_ready(AdsConfig.CONTINUE)


## Clôt la partie : pièces, XP, missions, analytics. Sans effet si la partie
## n'a pas commencé (aucun lâcher) ou si elle est déjà close.
func finalize(cause: StringName) -> Dictionary:
	if is_finalized:
		return summary
	is_finalized = true
	if drops == 0 and not game.is_over:
		summary = {}
		return summary
	var score := game.score
	var coins := Wallet.earn(Wallet.economy.coins_for_score(score), &"game")
	Missions.report(MissionDef.Kind.GAMES)
	Missions.report(MissionDef.Kind.SCORE_SINGLE, score)
	var prog := Progression.add_game(score, merges)
	if not game.is_over:
		# Partie abandonnée (menu) : comptée et enregistrée ici.
		SaveManager.record_game(score, game.max_rank_reached)
	AdsManager.notify_game_finished()
	Analytics.log_event(&"game_over", {"score": score, "max_fruit": game.max_rank_reached + 1,
		"duration": int(duration), "cause": String(cause), "merges": merges,
		"continues": game.continues_used})
	summary = {
		"score": score, "max_rank": game.max_rank_reached, "coins": coins,
		"xp": prog["xp"], "levels": prog["levels"], "level_coins": prog["coins"],
		"cause": cause, "duration": duration, "merges": merges, "combos": combos,
	}
	finalized.emit(summary)
	return summary


## « Doubler les pièces » : appelé UNIQUEMENT depuis le callback rewarded.
func grant_double_coins() -> int:
	var extra: int = int(summary.get("coins", 0)) * (Wallet.economy.double_multiplier - 1)
	summary["coins_doubled"] = true
	return Wallet.earn(extra, &"double")
