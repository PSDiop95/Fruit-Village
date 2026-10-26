class_name AdIds
extends RefCounted
## Identifiants AdMob, logique pure (testée, partagée par AdsManager et le
## plugin d'export _fv_release) :
## - debug : TOUJOURS les identifiants de test Google ;
## - release : UNIQUEMENT les vrais identifiants de res://ads_ids.cfg
##   (non versionné). Absent, invalide ou identifiant de test → format
##   désactivé. Jamais de pub de test en production, jamais de vraie pub en debug.
## Une section par plateforme dans ads_ids.cfg : [android], [ios].

const FILE := "res://ads_ids.cfg"
const ANDROID := "android"
const IOS := "ios"
const SECTION := ANDROID  # compatibilité : section Android
const KEYS: Array[String] = ["app_id", "rewarded_id", "interstitial_id"]
## Éditeur des identifiants d'exemple publiés par Google.
const GOOGLE_TEST_PUBLISHER := "ca-app-pub-3940256099942544"
const GOOGLE_TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const GOOGLE_TEST_IOS_APP_ID := "ca-app-pub-3940256099942544~1458002511"

static var _format: RegEx


static func is_test_id(v: String) -> bool:
	return v.begins_with(GOOGLE_TEST_PUBLISHER)


## Vrai identifiant : bon format (ni modèle « XXXX », ni vide) et pas de test.
static func is_real_id(v: String) -> bool:
	if _format == null:
		_format = RegEx.create_from_string("^ca-app-pub-\\d{16}[~/]\\d{10}$")
	return _format.search(v) != null and not is_test_id(v)


## Plateforme de l'appareil courant (section de ads_ids.cfg).
static func current_platform() -> String:
	return IOS if OS.get_name() == "iOS" else ANDROID


static func test_ids(config: AdsConfig, platform: String = ANDROID) -> Dictionary:
	if platform == IOS:
		return {"app_id": config.test_ios_app_id, "rewarded_id": config.test_ios_rewarded_id,
			"interstitial_id": config.test_ios_interstitial_id, "test": true}
	return {"app_id": config.test_app_id, "rewarded_id": config.test_rewarded_id,
		"interstitial_id": config.test_interstitial_id, "test": true}


## `cf` : contenu de ads_ids.cfg (null si absent ou illisible).
static func resolve(config: AdsConfig, debug: bool, cf: ConfigFile,
		platform: String = ANDROID) -> Dictionary:
	if debug:
		return test_ids(config, platform)
	var ids := {"test": false}
	for k in KEYS:
		var v := str(cf.get_value(platform, k, "")) if cf else ""
		ids[k] = v if is_real_id(v) else ""
	return ids


static func load_file(path: String = FILE) -> ConfigFile:
	if not FileAccess.file_exists(path):
		return null
	var cf := ConfigFile.new()
	return cf if cf.load(path) == OK else null
