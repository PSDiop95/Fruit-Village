class_name RewardedSession
extends RefCounted
## Une présentation de pub rewarded. La récompense est donnée UNIQUEMENT sur
## le callback de récompense (jamais sur la fermeture) et au plus une fois.
## La fin (fermeture / échec) est signalée une seule fois avec le verdict.

var placement: StringName
var rewarded: bool = false
var finished: bool = false
var _on_reward: Callable
var _on_done: Callable


func _init(p_placement: StringName, on_reward: Callable, on_done: Callable = Callable()) -> void:
	placement = p_placement
	_on_reward = on_reward
	_on_done = on_done


## Callback de récompense du SDK.
func handle_earned() -> void:
	if finished or rewarded:
		return
	rewarded = true
	if _on_reward.is_valid():
		_on_reward.call()


## Fermeture de la pub (avant ou après la fin) : ne donne JAMAIS de récompense.
func handle_closed() -> void:
	_finish()


## Échec d'affichage : aucune récompense.
func handle_failed() -> void:
	_finish()


func _finish() -> void:
	if finished:
		return
	finished = true
	if _on_done.is_valid():
		_on_done.call(rewarded)
