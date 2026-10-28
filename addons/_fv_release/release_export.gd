@tool
extends EditorExportPlugin
## Export Android et iOS de Fruit Village (règles : AdIds) :
## - debug : App ID de test Google (manifeste / Info.plist), ads_ids.cfg
##   jamais embarqué ;
## - release : App ID réel lu dans ads_ids.cfg (section de la plateforme) et
##   ads_ids.cfg embarqué ; identifiants absents ou de test → erreur d'export.
## Le vrai App ID n'est jamais écrit dans project.godot (versionné) : il est
## posé en mémoire le temps de l'export puis remis à sa valeur d'origine.
## iOS : le plugin AdMob lit l'App ID dans SON _export_begin ; ce plugin doit
## donc être chargé AVANT lui. L'éditeur trie [editor_plugins] par ordre
## alphabétique : d'où le nom de dossier « _fv_release » (testé).

const APP_ID_SETTINGS := {
	AdIds.ANDROID: "admob/general/android/app_id",
	AdIds.IOS: "admob/general/ios/app_id",
}
const TEST_APP_IDS := {
	AdIds.ANDROID: AdIds.GOOGLE_TEST_APP_ID,
	AdIds.IOS: AdIds.GOOGLE_TEST_IOS_APP_ID,
}

var _debug: bool = true
var _platform: String = ""  # "" = export non concerné
var _saved_app_id: Variant = null


func _get_name() -> String:
	return "FruitVillageRelease"


func _export_begin(features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
	_platform = AdIds.IOS if features.has("ios") else (AdIds.ANDROID if features.has("android") else "")
	_debug = is_debug
	if _platform.is_empty():
		return
	var setting: String = APP_ID_SETTINGS[_platform]
	_saved_app_id = ProjectSettings.get_setting(setting, null)
	if is_debug:
		ProjectSettings.set_setting(setting, TEST_APP_IDS[_platform])
		return
	var cf := AdIds.load_file()
	var app_id := str(cf.get_value(_platform, "app_id", "")) if cf else ""
	for k in AdIds.KEYS:
		var v := str(cf.get_value(_platform, k, "")) if cf else ""
		if not AdIds.is_real_id(v):
			push_error("FV_RELEASE: ads_ids.cfg [%s] : '%s' absent, modèle ou identifiant de test"
				% [_platform, k])
	# Valeur brute même invalide : les contrôles de build refusent alors le
	# paquet (jamais d'App ID de test glissé en production).
	ProjectSettings.set_setting(setting, app_id)


## Permissions ajoutées par les SDK et inutiles au jeu, retirées à la fusion
## des manifestes (justification : docs/m5_rapport.md).
const REMOVED_PERMISSIONS: Array[String] = [
	"android.permission.READ_BASIC_PHONE_STATE",  # SDK pub : facultative
	"android.permission.FOREGROUND_SERVICE",  # WorkManager : aucun service au premier plan
	"android.permission.ACCESS_ADSERVICES_AD_ID",  # Firebase : Privacy Sandbox, non utilisé
	"android.permission.ACCESS_ADSERVICES_ATTRIBUTION",  # idem
	"android.permission.AD_ID",  # nom erroné du plugin AdMob ; la vraie est com.google.android.gms.permission.AD_ID
	"android.permission.SCHEDULE_EXACT_ALARM",  # rappels : heure approximative suffit (déclaration Play évitée)
	"android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",  # rappels : jamais demandé (politique Play)
]


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid or platform.get_os_name() == "iOS"


func _get_android_manifest_element_contents(_platform_arg: EditorExportPlatform, _debug_arg: bool) -> String:
	var lines := PackedStringArray()
	for p in REMOVED_PERMISSIONS:
		lines.append('    <uses-permission android:name="%s" tools:node="remove" />' % p)
	return "\n".join(lines) + "\n"


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if not _platform.is_empty() and _debug and path == AdIds.FILE:
		skip()


func _export_end() -> void:
	if not _platform.is_empty() and _saved_app_id != null:
		ProjectSettings.set_setting(APP_ID_SETTINGS[_platform], _saved_app_id)
	_saved_app_id = null
	_platform = ""
