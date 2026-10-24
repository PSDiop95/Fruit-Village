class_name InterstitialPolicy
extends RefCounted
## Règles de fréquence de l'interstitiel (pures, horloge injectée).
## Uniquement entre deux parties ; au plus 1 toutes les N parties ET N s ;
## jamais avant la Ne partie de la vie du joueur ; jamais juste après un
## rewarded ; jamais pendant les premières secondes de la session.
## Temps : secondes unix (float) fournies par l'appelant.

var config: AdsConfig
## Parties terminées depuis l'installation (persisté).
var lifetime_games: int = 0
## Parties terminées depuis le dernier interstitiel (persisté).
var games_since_last: int = 0
## Dernier interstitiel affiché (persisté).
var last_shown: float = -1e12
var last_rewarded: float = -1e12
var session_start: float = 0.0
## Un rewarded a été vu depuis la dernière fin de partie.
var rewarded_since_game_end: bool = false


func _init(p_config: AdsConfig) -> void:
	config = p_config
	games_since_last = config.interstitial_min_games_between


func begin_session(now: float) -> void:
	session_start = now
	rewarded_since_game_end = false


func on_game_finished() -> void:
	lifetime_games += 1
	games_since_last += 1


func on_rewarded_shown(now: float) -> void:
	last_rewarded = now
	rewarded_since_game_end = true


func on_interstitial_shown(now: float) -> void:
	last_shown = now
	games_since_last = 0


## Raison du refus ("" = autorisé).
func block_reason(now: float) -> String:
	if not config.interstitial_enabled:
		return "disabled"
	if lifetime_games < config.interstitial_min_lifetime_games:
		return "too_early_lifetime"
	if now - session_start < config.interstitial_session_grace_seconds:
		return "session_grace"
	if games_since_last < config.interstitial_min_games_between:
		return "games_between"
	if now - last_shown < config.interstitial_min_seconds_between:
		return "seconds_between"
	if rewarded_since_game_end or now - last_rewarded < config.interstitial_after_rewarded_seconds:
		return "after_rewarded"
	return ""


func can_show(now: float) -> bool:
	return block_reason(now).is_empty()


## Entre deux parties : la fenêtre « après rewarded » se referme au lancement
## de la partie suivante.
func on_game_started() -> void:
	rewarded_since_game_end = false


func to_dict() -> Dictionary:
	return {"lifetime_games": lifetime_games, "games_since_last": games_since_last,
		"last_shown": last_shown}


func from_dict(d: Dictionary) -> void:
	lifetime_games = maxi(int(d.get("lifetime_games", 0)), 0)
	games_since_last = maxi(int(d.get("games_since_last", config.interstitial_min_games_between)), 0)
	last_shown = float(d.get("last_shown", -1e12))
