@tool
extends EditorExportPlugin
## Export Android de Fruit Village (règles : AdIds) :
## - debug : App ID de test Google dans le manifeste, ads_ids.cfg jamais
##   embarqué ;
## - release : App ID réel lu dans ads_ids.cfg (manifeste) et ads_ids.cfg
##   embarqué ; identifiants absents ou de test → erreur d'export.
## Le vrai App ID n'est jamais écrit dans project.godot (versionné) : il est
## posé en mémoire le temps de l'export puis remis à sa valeur d'origine.

const APP_ID_SETTING := "admob/general/android/app_id"

var _debug: bool = true
var _android: bool = false
var _saved_app_id: Variant = null


func _get_name() -> String:
	return "FruitVillageRelease"


func _export_begin(features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
	_android = features.has("android")
	_debug = is_debug
	if not _android:
		return
	_saved_app_id = ProjectSettings.get_setting(APP_ID_SETTING, null)
	if is_debug:
		ProjectSettings.set_setting(APP_ID_SETTING, AdIds.GOOGLE_TEST_APP_ID)
		return
	var cf := AdIds.load_file()
	var app_id := str(cf.get_value(AdIds.SECTION, "app_id", "")) if cf else ""
	for k in AdIds.KEYS:
		var v := str(cf.get_value(AdIds.SECTION, k, "")) if cf else ""
		if not AdIds.is_real_id(v):
			push_error("FV_RELEASE: ads_ids.cfg : '%s' absent, modèle ou identifiant de test" % k)
	# Valeur brute même invalide : tools/build_release.sh refuse alors l'AAB
	# (jamais d'App ID de test glissé en production).
	ProjectSettings.set_setting(APP_ID_SETTING, app_id)


## Permissions ajoutées par les SDK et inutiles au jeu, retirées à la fusion
## des manifestes (justification : docs/m5_rapport.md).
const REMOVED_PERMISSIONS: Array[String] = [
	"android.permission.READ_BASIC_PHONE_STATE",  # SDK pub : facultative
	"android.permission.FOREGROUND_SERVICE",  # WorkManager : aucun service au premier plan
	"android.permission.ACCESS_ADSERVICES_AD_ID",  # Firebase : Privacy Sandbox, non utilisé
	"android.permission.ACCESS_ADSERVICES_ATTRIBUTION",  # idem
	"android.permission.AD_ID",  # nom erroné du plugin AdMob ; la vraie est com.google.android.gms.permission.AD_ID
]


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid


func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	var lines := PackedStringArray()
	for p in REMOVED_PERMISSIONS:
		lines.append('    <uses-permission android:name="%s" tools:node="remove" />' % p)
	return "\n".join(lines) + "\n"


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if _android and _debug and path == AdIds.FILE:
		skip()


func _export_end() -> void:
	if _android and _saved_app_id != null:
		ProjectSettings.set_setting(APP_ID_SETTING, _saved_app_id)
	_saved_app_id = null
	_android = false
