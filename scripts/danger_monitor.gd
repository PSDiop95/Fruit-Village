class_name DangerMonitor
extends RefCounted
## Suit le temps passé par chaque fruit au-dessus de la ligne de danger.

enum State { SAFE, WARNING, GAME_OVER }

var warn_time: float = 1.0
var game_over_time: float = 2.0

var _time_above: Dictionary = {}  # id -> secondes


func configure(warn_s: float, game_over_s: float) -> void:
	warn_time = warn_s
	game_over_time = game_over_s


## `above_ids` : fruits actuellement (et légitimement) au-dessus de la ligne.
func update(above_ids: Array[int], delta: float) -> State:
	var next: Dictionary = {}
	var worst: float = 0.0
	for id in above_ids:
		var t: float = _time_above.get(id, 0.0) + delta
		next[id] = t
		worst = maxf(worst, t)
	_time_above = next
	if worst >= game_over_time:
		return State.GAME_OVER
	if worst >= warn_time:
		return State.WARNING
	return State.SAFE


## Progression 0..1 vers le game over (pour l'UI).
func max_ratio() -> float:
	var worst: float = 0.0
	for t in _time_above.values():
		worst = maxf(worst, t)
	return clampf(worst / game_over_time, 0.0, 1.0)


func reset() -> void:
	_time_above.clear()
