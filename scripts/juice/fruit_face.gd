class_name FruitFace
extends RefCounted
## Machine à états de l'expression d'un fruit, séparée du rendu (testable).
##
## Priorités : JOIE (fusion, définitive) > ÉCRASÉ (temporaire) > PEUR > NEUTRE.

enum Mood { NEUTRAL, SQUASHED, FEAR, JOY }

signal mood_changed(mood: Mood)

var squashed_min_speed: float = 6.0
var squashed_time: float = 0.3
var blink_min_interval: float = 2.0
var blink_max_interval: float = 6.0
var blink_duration: float = 0.12

var mood: Mood = Mood.NEUTRAL

var _above_line: bool = false
var _joy: bool = false
var _squash_left: float = 0.0
var _blink_left: float = 0.0
var _next_blink: float = 0.0
var _rng := RandomNumberGenerator.new()


func configure(cfg: JuiceConfig, seed_value: int = 0) -> void:
	squashed_min_speed = cfg.face_squashed_min_speed
	squashed_time = cfg.face_squashed_time
	blink_min_interval = cfg.blink_min_interval
	blink_max_interval = cfg.blink_max_interval
	blink_duration = cfg.blink_duration
	_rng.seed = seed_value
	_next_blink = _roll_blink()


## Choc : au-delà de `squashed_min_speed`, grimace pendant `squashed_time`.
func impact(speed: float) -> void:
	if speed >= squashed_min_speed:
		_squash_left = squashed_time
		_refresh()


func set_above_line(above: bool) -> void:
	if above != _above_line:
		_above_line = above
		_refresh()


## Juste avant la fusion : yeux fermés de joie (état final du fruit).
func set_joy() -> void:
	_joy = true
	_refresh()


func update(delta: float) -> void:
	if _squash_left > 0.0:
		_squash_left -= delta
		if _squash_left <= 0.0:
			_squash_left = 0.0
			_refresh()
	if _blink_left > 0.0:
		_blink_left -= delta
	else:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_blink_left = blink_duration
			_next_blink = _roll_blink()


## Yeux fermés (clignement), hors expressions qui imposent les yeux.
func is_blinking() -> bool:
	return _blink_left > 0.0 and mood == Mood.NEUTRAL


func eyes_closed() -> bool:
	return mood == Mood.JOY or is_blinking()


func _roll_blink() -> float:
	return _rng.randf_range(blink_min_interval, blink_max_interval)


func _refresh() -> void:
	var e := Mood.NEUTRAL
	if _joy:
		e = Mood.JOY
	elif _squash_left > 0.0:
		e = Mood.SQUASHED
	elif _above_line:
		e = Mood.FEAR
	if e != mood:
		mood = e
		mood_changed.emit(e)
