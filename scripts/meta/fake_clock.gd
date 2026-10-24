class_name FakeClock
extends MetaClock
## Horloge pilotée (tests, simulation) : `advance` fait avancer l'heure murale
## ET le temps monotone ; `set_wall` ne bouge que l'heure murale (triche).

var wall: int = 1_760_000_000
var offset: int = 0
var mono: float = 0.0


func _init(start_unix: int = 1_760_000_000, utc_offset_s: int = 0) -> void:
	wall = start_unix
	offset = utc_offset_s


func now() -> int:
	return wall


func utc_offset() -> int:
	return offset


func ticks() -> float:
	return mono


func advance(seconds: float) -> void:
	wall += int(seconds)
	mono += seconds


func set_wall(unix: int) -> void:
	wall = unix


## Place l'horloge à `hour` h locale du jour local `day`.
func set_local(day: int, hour: int, minute: int = 0) -> void:
	var target := day * DAY + hour * 3600 + minute * 60 - offset
	mono += maxf(target - wall, 0.0)
	wall = target
