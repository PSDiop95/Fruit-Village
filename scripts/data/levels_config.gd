class_name LevelsConfig
extends Resource
## Niveau joueur (XP) et déblocages progressifs.

## XP cumulée pour atteindre le niveau i + 2 (index 0 = niveau 2).
## Au-delà de la liste : + xp_step_after par niveau.
@export var xp_thresholds: PackedInt32Array = PackedInt32Array([60, 160, 320, 540, 820])
@export var xp_step_after: int = 350
## Le palier grandit de N XP à chaque niveau au-delà de la liste.
@export var xp_step_growth: int = 0

@export_group("Gain d'XP par partie")
@export var xp_per_game: int = 20
## XP par tranche de 100 points de score.
@export var xp_per_100_points: float = 2.0
@export var xp_per_merge: float = 0.5
## Plafond d'XP par partie (anti-farm).
@export var xp_max_per_game: int = 200

@export_group("Récompense de niveau")
@export var level_up_coins: int = 50

@export_group("Déblocages (niveau)")
@export var missions_level: int = 2
@export var powerups_level: int = 3
@export var daily_level: int = 4
@export var album_level: int = 5


## XP cumulée nécessaire pour être au niveau `level` (niveau 1 = 0).
func xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	var i := level - 2
	if i < xp_thresholds.size():
		return xp_thresholds[i]
	var last := xp_thresholds[xp_thresholds.size() - 1] if not xp_thresholds.is_empty() else 0
	var k := i - xp_thresholds.size() + 1
	# Somme des paliers croissants : step, step + g, step + 2g…
	return last + k * xp_step_after + xp_step_growth * k * (k - 1) / 2


func xp_for_game(score: int, merges: int) -> int:
	var xp := xp_per_game + int(score / 100.0 * xp_per_100_points) + int(merges * xp_per_merge)
	return clampi(xp, 0, xp_max_per_game)
