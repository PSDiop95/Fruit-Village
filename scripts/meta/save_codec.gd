class_name SaveCodec
extends RefCounted
## Format de sauvegarde, migration, contrôle d'intégrité, écriture atomique.
##
## v1 (M1–M3) : JSON brut {"version": 1, best_score, best_rank, games_played, settings}.
## v2 (M4)    : 1re ligne « FV2 <checksum> », puis le JSON
##              {"version": 2, "core": {...v1...}, "systems": {nom: {...}}}.
## Le checksum porte sur le texte JSON exact (pas de re-sérialisation :
## JSON relit les entiers en flottants). Il décourage l'édition à la main ;
## ce n'est pas une protection cryptographique (le sel est dans l'APK).

const VERSION := 2
const HEADER := "FV2"
const SALT := "fruit-village/marche/2026"

enum Status { OK, MISSING, CORRUPT, TAMPERED, MIGRATED }


static func checksum(json_text: String) -> String:
	return (SALT + json_text).sha256_text().substr(0, 24)


static func encode(payload: Dictionary) -> String:
	var data := payload.duplicate()
	data["version"] = VERSION
	var json := JSON.stringify(data)
	return "%s %s\n%s" % [HEADER, checksum(json), json]


## Décode un fichier (v1 ou v2). Renvoie {"status": Status, "data": Dictionary v2}.
static func decode(text: String) -> Dictionary:
	var t := text.strip_edges(true, false)
	if t.is_empty():
		return {"status": Status.CORRUPT, "data": {}}
	if t.begins_with(HEADER):
		var nl := t.find("\n")
		if nl < 0:
			return {"status": Status.CORRUPT, "data": {}}
		var head := t.substr(0, nl).strip_edges().split(" ")
		var json := t.substr(nl + 1)
		var parsed: Variant = _parse(json)
		if not parsed is Dictionary:
			return {"status": Status.CORRUPT, "data": {}}
		if head.size() < 2 or head[1] != checksum(json):
			return {"status": Status.TAMPERED, "data": parsed}
		return {"status": Status.OK, "data": parsed}
	var raw: Variant = _parse(t)
	if not raw is Dictionary:
		return {"status": Status.CORRUPT, "data": {}}
	return {"status": Status.MIGRATED, "data": migrate(raw)}


## Migration vers v2 (actuellement : v1 → v2).
static func migrate(raw: Dictionary) -> Dictionary:
	var version := int(raw.get("version", 1))
	if version >= VERSION and raw.has("core"):
		return raw
	var core := {
		"best_score": int(raw.get("best_score", 0)),
		"best_rank": int(raw.get("best_rank", 0)),
		"games_played": int(raw.get("games_played", 0)),
		"settings": raw.get("settings", {}) if raw.get("settings", {}) is Dictionary else {},
	}
	# Les fruits déjà atteints en M1–M3 sont acquis dans l'album.
	var found: Array[int] = []
	if core["games_played"] > 0 or core["best_score"] > 0:
		for r in core["best_rank"] + 1:
			found.append(r)
	return {
		"version": VERSION,
		"core": core,
		"systems": {"collection": {"found": found}},
	}


## Écriture atomique : fichier temporaire complet, relu et vérifié, puis
## renommé par-dessus l'ancien. Un crash pendant l'écriture laisse l'ancien
## fichier intact.
static func write_atomic(path: String, text: String) -> Error:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.flush()
	f.close()
	if FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(tmp)
		return ERR_FILE_CORRUPT
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK and FileAccess.file_exists(path):
		# Certains systèmes refusent d'écraser : on remplace en deux temps.
		DirAccess.remove_absolute(path)
		err = DirAccess.rename_absolute(tmp, path)
	return err


## JSON sans message d'erreur moteur (fichier abîmé = cas prévu, pas un bug).
static func _parse(text: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null
