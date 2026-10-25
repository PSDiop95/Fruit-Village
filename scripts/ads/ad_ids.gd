class_name AdIds
extends RefCounted
## Identifiants AdMob, logique pure (testée, partagée par AdsManager et le
## plugin d'export fv_release) :
## - debug : TOUJOURS les identifiants de test Google ;
## - release : UNIQUEMENT les vrais identifiants de res://ads_ids.cfg
##   (non versionné). Absent, invalide ou identifiant de test → format
##   désactivé. Jamais de pub de test en production, jamais de vraie pub en debug.

const FILE := "res://ads_ids.cfg"
const SECTION := "android"
const KEYS: Array[String] = ["app_id", "rewarded_id", "interstitial_id"]
## Éditeur des identifiants d'exemple publiés par Google.
const GOOGLE_TEST_PUBLISHER := "ca-app-pub-3940256099942544"
const GOOGLE_TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"

static var _format: RegEx


static func is_test_id(v: String) -> bool:
	return v.begins_with(GOOGLE_TEST_PUBLISHER)


## Vrai identifiant : bon format (ni modèle « XXXX », ni vide) et pas de test.
static func is_real_id(v: String) -> bool:
	if _format == null:
		_format = RegEx.create_from_string("^ca-app-pub-\\d{16}[~/]\\d{10}$")
	return _format.search(v) != null and not is_test_id(v)


static func test_ids(config: AdsConfig) -> Dictionary:
	return {"app_id": config.test_app_id, "rewarded_id": config.test_rewarded_id,
		"interstitial_id": config.test_interstitial_id, "test": true}


## `cf` : contenu de ads_ids.cfg (null si absent ou illisible).
static func resolve(config: AdsConfig, debug: bool, cf: ConfigFile) -> Dictionary:
	if debug:
		return test_ids(config)
	var ids := {"test": false}
	for k in KEYS:
		var v := str(cf.get_value(SECTION, k, "")) if cf else ""
		ids[k] = v if is_real_id(v) else ""
	return ids


static func load_file(path: String = FILE) -> ConfigFile:
	if not FileAccess.file_exists(path):
		return null
	var cf := ConfigFile.new()
	return cf if cf.load(path) == OK else null
