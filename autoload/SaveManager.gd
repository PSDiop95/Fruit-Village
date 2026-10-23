extends Node
## Sauvegarde locale : meilleur score, plus gros fruit atteint, réglages joueur.

signal setting_changed(key: StringName, value: Variant)

const DEFAULT_SAVE_PATH := "user://save.json"
const DEFAULT_SETTINGS := {
	&"reduced_effects": false,
	&"music_on": true,
	&"sfx_on": true,
	&"vibration_on": true,
	## -1 = automatique (VisualQuality.detect), sinon JuiceConfig.Quality.
	&"quality": -1,
	## -1 = selon l'heure locale (Ambiances.resolve), sinon index dans data/ambiances.
	&"ambiance": -1,
}

## Surchargeable (tests) pour ne jamais toucher la vraie sauvegarde joueur.
var save_path: String = DEFAULT_SAVE_PATH
var best_score: int = 0
var best_rank: int = 0
var games_played: int = 0
## Réglages joueur (M2). Clés inconnues ignorées au chargement.
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()


func _ready() -> void:
	load_data()


## Enregistre une fin de partie. Renvoie true si nouveau record.
func record_game(score: int, max_rank: int) -> bool:
	games_played += 1
	var is_record := score > best_score
	best_score = maxi(best_score, score)
	best_rank = maxi(best_rank, max_rank)
	save_data()
	return is_record


## Bascule sur un autre fichier (vide l'état en mémoire puis recharge).
func use_path(path: String) -> void:
	save_path = path
	best_score = 0
	best_rank = 0
	games_played = 0
	settings = DEFAULT_SETTINGS.duplicate()
	load_data()


func get_setting(key: StringName) -> Variant:
	return settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: StringName, value: Variant) -> void:
	if settings.get(key) == value:
		return
	settings[key] = value
	save_data()
	setting_changed.emit(key, value)


func save_data() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Sauvegarde impossible : %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify({
		"version": 1,
		"best_score": best_score,
		"best_rank": best_rank,
		"games_played": games_played,
		"settings": settings,
	}))


func load_data() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		best_score = int(data.get("best_score", 0))
		best_rank = int(data.get("best_rank", 0))
		games_played = int(data.get("games_played", 0))
		var saved: Variant = data.get("settings", {})
		if saved is Dictionary:
			for k in DEFAULT_SETTINGS:
				if saved.has(String(k)):
					var v: Variant = saved[String(k)]
					# JSON relit les entiers en flottants : on garde le type par défaut.
					settings[k] = int(v) if DEFAULT_SETTINGS[k] is int else v
