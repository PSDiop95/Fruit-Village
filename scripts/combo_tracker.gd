class_name ComboTracker
extends RefCounted
## Combos : fusions enchaînées à moins de `window` secondes → x2, x3…

var window: float = 1.5
var max_multiplier: int = 8

var _count: int = 0
var _last_time: float = -INF


func configure(window_s: float, max_mult: int) -> void:
	window = window_s
	max_multiplier = max_mult


## Enregistre une fusion à l'instant `now` (secondes) et renvoie le multiplicateur.
func register(now: float) -> int:
	if now - _last_time <= window:
		_count += 1
	else:
		_count = 1
	_last_time = now
	return multiplier()


func multiplier() -> int:
	return clampi(_count, 1, max_multiplier)


## Le combo est-il encore actif à l'instant `now` ?
func is_active(now: float) -> bool:
	return _count > 1 and now - _last_time <= window


func reset() -> void:
	_count = 0
	_last_time = -INF
