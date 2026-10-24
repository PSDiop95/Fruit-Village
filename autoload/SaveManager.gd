extends Node
## Sauvegarde locale (format v2, SaveCodec) : meilleur score, plus gros fruit,
## réglages, et l'état des systèmes méta (portefeuille, progression, missions…)
## qui s'enregistrent via register_system(). Écriture atomique, checksum,
## migration v1 → v2, autosave à la mise en arrière-plan.

signal setting_changed(key: StringName, value: Variant)
## Le fichier vient d'être (re)chargé : les systèmes ont reçu leur état.
signal loaded

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
	## M4 : rappels locaux (connexion, série).
	&"notifications_on": true,
	## M4 : statistiques d'usage (Analytics), en plus du consentement UMP.
	&"analytics_on": true,
	## M4 : habillage du panier (&"" = normal, &"gold" = album complet).
	&"basket_skin": "",
}

## Surchargeable (tests) pour ne jamais toucher la vraie sauvegarde joueur.
var save_path: String = DEFAULT_SAVE_PATH
var best_score: int = 0
var best_rank: int = 0
var games_played: int = 0
## Réglages joueur (M2). Clés inconnues ignorées au chargement.
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
## Résultat du dernier chargement (SaveCodec.Status).
var last_status: SaveCodec.Status = SaveCodec.Status.MISSING

var _systems: Dictionary = {}  # clé -> Object (save_state / load_state)
var _systems_data: Dictionary = {}  # clé -> Dictionary (dernier état lu)
var _save_pending: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_data()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT,
			NOTIFICATION_WM_CLOSE_REQUEST]:
		if _save_pending:
			save_data()


## Un système méta confie son état à la sauvegarde. `owner` expose
## save_state() -> Dictionary et load_state(Dictionary).
func register_system(key: String, owner: Object) -> void:
	_systems[key] = owner
	owner.load_state(_systems_data.get(key, {}))


## Sauvegarde différée (une écriture par frame au plus).
func request_save() -> void:
	if _save_pending:
		return
	_save_pending = true
	_flush_deferred.call_deferred()


func _flush_deferred() -> void:
	if _save_pending:
		save_data()


## Enregistre une fin de partie. Renvoie true si nouveau record.
## `count_game` : false quand la même partie se termine à nouveau après
## « Continuer » (une partie n'est comptée qu'une fois).
func record_game(score: int, max_rank: int, count_game: bool = true) -> bool:
	if count_game:
		games_played += 1
	var is_record := score > best_score
	best_score = maxi(best_score, score)
	best_rank = maxi(best_rank, max_rank)
	save_data()
	return is_record


## Bascule sur un autre fichier (vide l'état en mémoire puis recharge).
func use_path(path: String) -> void:
	save_path = path
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
	_save_pending = false
	var systems := {}
	for k in _systems:
		systems[k] = _systems[k].save_state()
	_systems_data = systems
	var st := {}
	for k in settings:
		st[String(k)] = settings[k]
	var text := SaveCodec.encode({
		"core": {"best_score": best_score, "best_rank": best_rank,
			"games_played": games_played, "settings": st},
		"systems": systems,
	})
	var err := SaveCodec.write_atomic(save_path, text)
	if err != OK:
		push_warning("Sauvegarde impossible (%s) : %s" % [save_path, error_string(err)])


func load_data() -> void:
	_reset_memory()
	if not FileAccess.file_exists(save_path):
		last_status = SaveCodec.Status.MISSING
		_push_to_systems()
		loaded.emit()
		return
	var res := SaveCodec.decode(FileAccess.get_file_as_string(save_path))
	last_status = res["status"]
	var data: Dictionary = res["data"]
	match last_status:
		SaveCodec.Status.CORRUPT:
			push_warning("Sauvegarde illisible : valeurs par défaut (copie en .corrupt)")
			DirAccess.copy_absolute(save_path, save_path + ".corrupt")
		SaveCodec.Status.TAMPERED:
			# Fichier modifié à la main : on garde les réglages, rien d'autre.
			push_warning("Sauvegarde modifiée hors du jeu : progression réinitialisée")
			var core: Variant = data.get("core", {})
			if core is Dictionary:
				_read_settings(core.get("settings", {}))
		_:
			_read_core(data.get("core", {}))
			var sys: Variant = data.get("systems", {})
			if sys is Dictionary:
				_systems_data = sys
	_push_to_systems()
	if last_status == SaveCodec.Status.MIGRATED:
		save_data()
	loaded.emit()


func _reset_memory() -> void:
	best_score = 0
	best_rank = 0
	games_played = 0
	settings = DEFAULT_SETTINGS.duplicate()
	_systems_data = {}


func _push_to_systems() -> void:
	for k in _systems:
		var d: Variant = _systems_data.get(k, {})
		_systems[k].load_state(d if d is Dictionary else {})


func _read_core(core: Variant) -> void:
	if not core is Dictionary:
		return
	best_score = maxi(int(core.get("best_score", 0)), 0)
	best_rank = clampi(int(core.get("best_rank", 0)), 0, 64)
	games_played = maxi(int(core.get("games_played", 0)), 0)
	_read_settings(core.get("settings", {}))


func _read_settings(saved: Variant) -> void:
	if not saved is Dictionary:
		return
	for k in DEFAULT_SETTINGS:
		if saved.has(String(k)):
			var v: Variant = saved[String(k)]
			# JSON relit les entiers en flottants : on garde le type par défaut.
			match typeof(DEFAULT_SETTINGS[k]):
				TYPE_INT: settings[k] = int(v)
				TYPE_BOOL: settings[k] = bool(v)
				TYPE_STRING: settings[k] = str(v)
				_: settings[k] = v
