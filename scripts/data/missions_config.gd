class_name MissionsConfig
extends Resource
## Missions du jour : pool pondéré, nombre actif, paliers de difficulté.

@export var active_count: int = 3
## Niveau joueur à partir duquel on passe au palier suivant ([1, 5, 9] :
## palier 0 dès niv. 1, palier 1 dès niv. 5, palier 2 dès niv. 9).
@export var tier_levels: PackedInt32Array = PackedInt32Array([1, 5, 9])
@export var double_multiplier: int = 2
@export var missions: Array[MissionDef] = []


func tier_for_level(level: int) -> int:
	var t := 0
	for i in tier_levels.size():
		if level >= tier_levels[i]:
			t = i
	return t


func get_def(id: StringName) -> MissionDef:
	for m in missions:
		if m.id == id:
			return m
	return null
