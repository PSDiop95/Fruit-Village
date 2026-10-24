class_name ClockGuard
extends RefCounted
## Anti-triche horloge basique. Incohérent si :
## - l'horloge murale recule sous la dernière heure vue (au-delà d'une tolérance) ;
## - pendant la session, l'horloge murale avance de plus de `forward_jump_hours`
##   au-delà du temps réellement écoulé (temps monotone).
## Conséquence voulue : pas de récompense, mais aucune pénalité.

var backward_tolerance: int = 600
var forward_jump: int = 48 * 3600
## Plus grande heure murale jamais vue (persistée).
var last_seen: int = 0
var _session_wall: int = 0
var _session_ticks: float = 0.0


func configure(cfg: DailyRewardsConfig) -> void:
	backward_tolerance = cfg.backward_tolerance_minutes * 60
	forward_jump = cfg.forward_jump_hours * 3600


func begin_session(wall: int, ticks: float) -> void:
	_session_wall = wall
	_session_ticks = ticks


func is_coherent(wall: int, ticks: float) -> bool:
	if last_seen > 0 and wall < last_seen - backward_tolerance:
		return false
	var drift := float(wall - _session_wall) - (ticks - _session_ticks)
	return drift <= forward_jump


## Mémorise l'heure vue (seulement si cohérente : une avance trichée ne doit
## pas bloquer le joueur une fois l'horloge remise à l'heure).
func mark_seen(wall: int, ticks: float) -> void:
	if is_coherent(wall, ticks):
		last_seen = maxi(last_seen, wall)
