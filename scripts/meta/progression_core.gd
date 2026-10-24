class_name ProgressionCore
extends RefCounted
## XP et niveau joueur ; déblocages progressifs (onboarding).

const MISSIONS := &"missions"
const POWERUPS := &"powerups"
const DAILY := &"daily"
const ALBUM := &"album"

var config: LevelsConfig
var xp: int = 0
var level: int = 1


func _init(p_config: LevelsConfig) -> void:
	config = p_config


func level_for_xp(total: int) -> int:
	var lv := 1
	while total >= config.xp_for_level(lv + 1) and lv < 999:
		lv += 1
	return lv


## Ajoute de l'XP ; renvoie la liste des niveaux nouvellement atteints.
func add_xp(amount: int) -> Array[int]:
	var reached: Array[int] = []
	if amount <= 0:
		return reached
	xp += amount
	var target := level_for_xp(xp)
	while level < target:
		level += 1
		reached.append(level)
	return reached


## Progression 0..1 dans le niveau courant.
func progress_ratio() -> float:
	var lo := config.xp_for_level(level)
	var hi := config.xp_for_level(level + 1)
	return clampf(float(xp - lo) / maxf(hi - lo, 1), 0.0, 1.0)


func xp_to_next() -> int:
	return config.xp_for_level(level + 1) - xp


func unlock_level(feature: StringName) -> int:
	match feature:
		MISSIONS: return config.missions_level
		POWERUPS: return config.powerups_level
		DAILY: return config.daily_level
		ALBUM: return config.album_level
	return 1


func is_unlocked(feature: StringName) -> bool:
	return level >= unlock_level(feature)


## Fonctionnalités débloquées exactement au niveau `lv`.
func unlocks_at(lv: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for f in [MISSIONS, POWERUPS, DAILY, ALBUM]:
		if unlock_level(f) == lv:
			out.append(f)
	return out


func to_dict() -> Dictionary:
	return {"xp": xp}


func from_dict(d: Dictionary) -> void:
	xp = maxi(int(d.get("xp", 0)), 0)
	level = level_for_xp(xp)
