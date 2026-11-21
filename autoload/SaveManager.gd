extends Node
## Sauvegarde locale (format v2, SaveCodec) : meilleur score, plus gros fruit,
## réglages, et l'état des systèmes méta (portefeuille, progression, missions…)
## qui s'enregistrent via register_system(). Écriture atomique, checksum,
## migration v1 → v2, autosave à la mise en arrière-plan.

signal setting_changed(key: StringName, value: Variant)
## Le fichier vient d'être (re)chargé : les systèmes ont reçu leur état.
signal loaded
## V2-0 (TD-10) : sauvegarde illisible, modifiée ou d'une version plus récente.
## Émis après le chargement (différé) : `status` détecté, `recovery` appliqué.
signal integrity_issue(status: SaveCodec.Status, recovery: Recovery)

## NONE : rien à récupérer. BACKUP : copie de secours (.bak) rechargée.
## SALVAGED : données suspectes nettoyées et conservées (pas de copie valable).
## RESET : rien de récupérable (fichier conservé en quarantaine).
enum Recovery { NONE, BACKUP, SALVAGED, RESET }
## Copies de quarantaine gardées par type (au-delà : écritures suspendues
## plutôt qu'effacer une copie).
const MAX_QUARANTINE := 20

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
	## V2-0 : langue choisie (LocaleCore.AUTO = "" : langue du système, sinon français).
	&"language": "",
}

## Surchargeable (tests) pour ne jamais toucher la vraie sauvegarde joueur.
var save_path: String = DEFAULT_SAVE_PATH
var best_score: int = 0
var best_rank: int = 0
var games_played: int = 0
## Réglages joueur (M2). Clés inconnues conservées telles quelles (V2-0).
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
## Résultat du dernier chargement (SaveCodec.Status) : ce qui a été détecté.
var last_status: SaveCodec.Status = SaveCodec.Status.MISSING
## V2-0 (TD-10) : ce qui a été fait pour récupérer la progression.
var recovery: Recovery = Recovery.NONE
## V2-0 : écritures suspendues (copie du fichier suspect impossible à
## sécuriser) : le fichier d'origine n'est jamais écrasé.
var writes_blocked: bool = false

var _systems: Dictionary = {}  # clé -> Object (save_state / load_state)
## Dernier état connu de CHAQUE section lue ou écrite, enregistrée ou non
## (V2-0, TD-14 : une section inconnue est réécrite telle quelle).
var _systems_data: Dictionary = {}
var _extra_settings: Dictionary = {}  # réglages inconnus (version plus récente)
var _extra_core: Dictionary = {}  # champs inconnus de "core"
var _extra_top: Dictionary = {}  # champs inconnus à la racine
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
## Règles (docs/phase_v2/v2_0/04_SAVE_SYSTEM_RULES.md) : clé stable et unique,
## enregistrement dans _ready() de l'autoload (même si la fonction est
## désactivée), jamais renommée ni supprimée sans règle de migration
## (SaveCodec.migrate). Enregistrement tardif possible : la section lue au
## démarrage est conservée jusque-là et lui est remise.
func register_system(key: String, owner: Object) -> void:
	_systems[key] = owner
	var d: Variant = _systems_data.get(key, {})
	owner.load_state(d if d is Dictionary else {})


## Retire un système (module déchargé, tests). Sa section reste dans la
## sauvegarde, avec son dernier état connu.
func unregister_system(key: String) -> void:
	if _systems.has(key):
		_systems_data[key] = _systems[key].save_state()
		_systems.erase(key)


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
	if writes_blocked:
		push_warning("Sauvegarde suspendue : fichier d'origine conservé (voir integrity_issue)")
		return
	# Toutes les sections connues (y compris celles d'aucun système enregistré)
	# sont réécrites ; les systèmes enregistrés fournissent leur état à jour.
	var systems := _systems_data.duplicate(true)
	for k in _systems:
		systems[k] = _systems[k].save_state()
	_systems_data = systems
	var st := _extra_settings.duplicate(true)
	for k in settings:
		st[String(k)] = settings[k]
	var core := _extra_core.duplicate(true)
	core["best_score"] = best_score
	core["best_rank"] = best_rank
	core["games_played"] = games_played
	core["settings"] = st
	var payload := _extra_top.duplicate(true)
	payload["core"] = core
	payload["systems"] = systems
	var text := SaveCodec.encode(payload)
	var err := SaveCodec.write_atomic(save_path, text)
	if err != OK:
		push_warning("Sauvegarde impossible (%s) : %s" % [save_path, error_string(err)])
		return
	# Copie de secours = dernier état écrit et vérifié par le jeu.
	err = SaveCodec.write_atomic(backup_path(), text)
	if err != OK:
		push_warning("Copie de secours impossible : %s" % error_string(err))


func backup_path() -> String:
	return save_path + ".bak"


func load_data() -> void:
	_reset_memory()
	recovery = Recovery.NONE
	writes_blocked = false
	var main := _decode_file(save_path)
	last_status = main["status"]
	var data: Dictionary = main["data"]
	match last_status:
		SaveCodec.Status.OK:
			_apply(data)
		SaveCodec.Status.MIGRATED:
			# Ancien format : copie gardée avant la réécriture en v2.
			_secure_copy("v1")
			_apply(data)
		SaveCodec.Status.MISSING:
			_recover_from_backup({})
		SaveCodec.Status.CORRUPT:
			push_warning("Sauvegarde illisible : copie en quarantaine, récupération")
			_secure_copy("corrupt")
			if not _recover_from_backup({}):
				recovery = Recovery.RESET
		SaveCodec.Status.TAMPERED:
			push_warning("Sauvegarde modifiée hors du jeu : copie en quarantaine, récupération")
			_secure_copy("tampered")
			if not _recover_from_backup(data):
				_salvage(data)
		SaveCodec.Status.FUTURE:
			push_warning("Sauvegarde d'une version plus récente : copie conservée")
			_secure_copy("future")
			_salvage(data)
	_push_to_systems()
	if last_status == SaveCodec.Status.MIGRATED or recovery in [Recovery.BACKUP, Recovery.SALVAGED]:
		save_data()
	if last_status in [SaveCodec.Status.CORRUPT, SaveCodec.Status.TAMPERED,
			SaveCodec.Status.FUTURE] or recovery != Recovery.NONE:
		_report.call_deferred(last_status, recovery)
	loaded.emit()


## Signal + statistique anonyme (état seulement, aucune donnée de la sauvegarde).
func _report(status: SaveCodec.Status, rec: Recovery) -> void:
	integrity_issue.emit(status, rec)
	var analytics := get_node_or_null(^"/root/Analytics")
	if analytics:
		analytics.log_event(&"save_recovery", {"status": SaveCodec.Status.keys()[status],
			"recovery": Recovery.keys()[rec], "blocked": writes_blocked})


static func _decode_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": SaveCodec.Status.MISSING, "data": {}}
	return SaveCodec.decode(FileAccess.get_file_as_string(path))


## Recharge la copie de secours si elle est intègre. `suspect` : données du
## fichier principal dont on reporte les champs restrictifs (récompenses déjà
## prises). Une copie de secours invalide est mise en quarantaine.
func _recover_from_backup(suspect: Dictionary) -> bool:
	var bak := _decode_file(backup_path())
	match bak["status"]:
		SaveCodec.Status.OK, SaveCodec.Status.MIGRATED:
			var data: Dictionary = bak["data"]
			if not suspect.is_empty():
				data = SaveRecovery.fence(data, suspect)
			_apply(data)
			recovery = Recovery.BACKUP
			return true
		SaveCodec.Status.MISSING:
			return false
		_:
			_secure_copy("bak-invalid", backup_path())
			return false


## Pas de copie de secours valable : la progression suspecte est gardée,
## nettoyée (SaveRecovery.salvage), jamais remise à zéro en silence.
func _salvage(data: Dictionary) -> void:
	var economy: Resource = load("res://data/economy.tres")
	var start := int(economy.get("starting_coins")) if economy else 0
	var res := SaveRecovery.salvage(data, start)
	if not (res["issues"] as Array).is_empty():
		push_warning("Sauvegarde suspecte : champs corrigés %s" % [res["issues"]])
	_apply(res["data"])
	recovery = Recovery.SALVAGED


## Copie de quarantaine vérifiée de `src` (défaut : fichier principal).
## Échec = écritures suspendues : on n'écrase jamais l'unique copie.
func _secure_copy(kind: String, src: String = "") -> bool:
	var from := save_path if src.is_empty() else src
	if not FileAccess.file_exists(from):
		return true
	var content := FileAccess.get_file_as_bytes(from)
	for i in MAX_QUARANTINE:
		var dst := "%s.%s" % [save_path, kind] if i == 0 else "%s.%s-%d" % [save_path, kind, i + 1]
		if FileAccess.file_exists(dst):
			if FileAccess.get_file_as_bytes(dst) == content:
				return true  # déjà en lieu sûr
			continue
		if DirAccess.copy_absolute(from, dst) == OK and FileAccess.get_file_as_bytes(dst) == content:
			return true
		break
	push_warning("Copie de quarantaine impossible : écritures suspendues")
	writes_blocked = true
	return false


## Fichiers d'un chemin de sauvegarde (principal, secours, temporaires,
## quarantaines). Outils et tests uniquement : le jeu n'efface jamais rien.
static func files_for(path: String) -> PackedStringArray:
	var out := PackedStringArray([path])
	var base := path.get_file() + "."
	for f in DirAccess.get_files_at(path.get_base_dir()):
		if f.begins_with(base):
			out.append(path.get_base_dir().path_join(f))
	return out


static func erase_files(path: String) -> void:
	for f in files_for(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))


func _apply(data: Dictionary) -> void:
	_read_core(data.get("core", {}))
	var sys: Variant = data.get("systems", {})
	if sys is Dictionary:
		_systems_data = (sys as Dictionary).duplicate(true)
	for k in data:
		if not k in ["core", "systems", "version"]:
			_extra_top[k] = data[k]


func _reset_memory() -> void:
	best_score = 0
	best_rank = 0
	games_played = 0
	settings = DEFAULT_SETTINGS.duplicate()
	_systems_data = {}
	_extra_settings = {}
	_extra_core = {}
	_extra_top = {}


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
	for k in core:
		if not k in ["best_score", "best_rank", "games_played", "settings"]:
			_extra_core[k] = core[k]


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
	for k in saved:
		if not StringName(k) in DEFAULT_SETTINGS:
			_extra_settings[k] = saved[k]
