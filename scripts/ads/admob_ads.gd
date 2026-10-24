class_name AdMobAds
extends AdProvider
## Production Android : Google AdMob + consentement UMP via le plugin
## « Godot AdMob » de Poing Studios (github.com/poingstudios/godot-admob-plugin,
## v5.x, addons/admob). Accès dynamique aux classes du plugin : le projet
## compile et les tests tournent sans le plugin installé.
##
## Ordre imposé : consentement UMP → MobileAds.initialize() → chargements.
## Les identifiants viennent d'AdsManager (tests Google en debug).

const ANDROID_SINGLETON := "PoingGodotAdMob"
## UMP (énums du plugin) : ConsentStatus / PrivacyOptionsRequirementStatus.
const CONSENT_NOT_REQUIRED := 1
const CONSENT_REQUIRED := 2
const CONSENT_OBTAINED := 3
const PRIVACY_OPTIONS_REQUIRED := 2

var _ids: Dictionary = {}
var _info: Object
var _initialized: bool = false
var _ads: Dictionary = {}  # kind -> objet pub du plugin
var _keep: Array = []  # callbacks du plugin (gardés en vie)
var _presenting: StringName = &""


static func _class_path(cls: String) -> String:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls:
			return c["path"]
	return ""


## Vrai seulement si la bibliothèque Android du plugin est dans l'APK
## (singleton natif) : un APK exporté sans Gradle retombe sur MockAds.
static func available() -> bool:
	return Engine.has_singleton(ANDROID_SINGLETON) and _class_path("MobileAds") != "" \
		and _class_path("RewardedAdLoader") != ""


static func _script(cls: String) -> Script:
	var p := _class_path(cls)
	return load(p) if p != "" else null


func _new(cls: String) -> Object:
	var s := _script(cls)
	var o: Object = s.new() if s else null
	if o:
		_keep.append(o)
	return o


func provider_name() -> String:
	return "admob"


# ---------------------------------------------------------------- Consentement

func _ump() -> Object:
	return _script("UserMessagingPlatform")


## Instance propre de ConsentInformation (ses méthodes passent par le
## singleton natif partagé ; évite de lire une variable statique du plugin).
func _consent_info() -> Object:
	if _info == null:
		_info = _new("ConsentInformation")
	return _info


func start(config: AdsConfig, ids: Dictionary) -> void:
	_ids = ids
	var info := _consent_info()
	var params := _new("ConsentRequestParameters")
	if info == null or params == null:
		_finish_consent()
		return
	params.set("tag_for_under_age_of_consent", false)
	# Debug : zone EEE simulée sur les appareils de test (formulaire RGPD).
	if OS.is_debug_build() and config and config.ump_debug_eea \
			and not config.ump_test_device_ids.is_empty():
		var dbg := _new("ConsentDebugSettings")
		if dbg:
			dbg.set("debug_geography", 1)  # DebugGeography.Values.EEA
			var ids_arr: Array[String] = []
			for d in config.ump_test_device_ids:
				ids_arr.append(d)
			dbg.set("test_device_hashed_ids", ids_arr)
			params.set("consent_debug_settings", dbg)
	info.call("update", params, _on_info_updated, _on_info_failed)


func _on_info_updated() -> void:
	var info := _consent_info()
	if info.call("get_is_consent_form_available"):
		_ump().call("load_consent_form", _on_form_loaded, _on_form_failed)
	else:
		_finish_consent()


func _on_info_failed(_err: Variant) -> void:
	# Google : tenter quand même can_request_ads (consentement d'une session passée).
	_finish_consent()


func _on_form_loaded(form: Object) -> void:
	_keep.append(form)
	var info := _consent_info()
	var required := CONSENT_REQUIRED
	if int(info.call("get_consent_status")) == required:
		form.call("show", func(_e: Variant) -> void: _finish_consent())
	else:
		_finish_consent()


func _on_form_failed(_err: Variant) -> void:
	_finish_consent()


func _can_request_ads() -> bool:
	var info := _consent_info()
	if info == null:
		return true
	for m in ["get_can_request_ads", "can_request_ads"]:
		if info.has_method(m):
			return bool(info.call(m))
	var status := int(info.call("get_consent_status"))
	return status == CONSENT_NOT_REQUIRED or status == CONSENT_OBTAINED


func _finish_consent() -> void:
	var can := _can_request_ads()
	if can and not _initialized:
		_initialized = true
		var mobile_ads := _script("MobileAds")
		if mobile_ads:
			mobile_ads.call("initialize")
	consent_resolved.emit.call_deferred(can, can)


func privacy_options_required() -> bool:
	var info := _consent_info()
	if info and info.has_method("get_privacy_options_requirement_status"):
		return int(info.call("get_privacy_options_requirement_status")) == PRIVACY_OPTIONS_REQUIRED
	return info != null


func show_privacy_options() -> void:
	var ump := _ump()
	if ump == null:
		return
	# Méthode statique du plugin v5.1 (has_method() est faux sur une ressource
	# Script, d'où l'appel direct).
	ump.call("show_privacy_options_form", func(_e: Variant = null) -> void: _finish_consent())


# ---------------------------------------------------------------- Pubs

func load_ad(kind: StringName) -> void:
	if not _initialized or _ads.has(kind):
		return
	var rewarded := kind == REWARDED
	var cb := _new("RewardedAdLoadCallback" if rewarded else "InterstitialAdLoadCallback")
	var loader := _new("RewardedAdLoader" if rewarded else "InterstitialAdLoader")
	if cb == null or loader == null:
		load_failed.emit(kind, "plugin AdMob incomplet")
		return
	cb.set("on_ad_loaded", func(ad: Object) -> void:
		_ads[kind] = ad
		_attach(ad, kind)
		loaded.emit(kind))
	cb.set("on_ad_failed_to_load", func(err: Object) -> void:
		load_failed.emit(kind, str(err.get("message")) if err else "?"))
	var unit: String = _ids.get("rewarded_id" if rewarded else "interstitial_id", "")
	loader.call("load", unit, _new("AdRequest"), cb)


func _attach(ad: Object, kind: StringName) -> void:
	var fs := _new("FullScreenContentCallback")
	if fs == null:
		return
	fs.set("on_ad_showed_full_screen_content", func() -> void:
		_presenting = kind
		opened.emit(kind))
	fs.set("on_ad_dismissed_full_screen_content", func() -> void:
		_presenting = &""
		_destroy(kind)
		closed.emit(kind))
	fs.set("on_ad_failed_to_show_full_screen_content", func(err: Object) -> void:
		_presenting = &""
		_destroy(kind)
		show_failed.emit(kind, str(err.get("message")) if err else "?"))
	ad.set("full_screen_content_callback", fs)


func _destroy(kind: StringName) -> void:
	var ad: Object = _ads.get(kind)
	_ads.erase(kind)
	if ad and ad.has_method("destroy"):
		ad.call("destroy")


func is_loaded(kind: StringName) -> bool:
	return _ads.has(kind)


func is_presenting() -> bool:
	return _presenting != &""


func show_ad(kind: StringName) -> void:
	var ad: Object = _ads.get(kind)
	if ad == null:
		show_failed.emit(kind, "not loaded")
		return
	if kind == REWARDED:
		var listener := _new("OnUserEarnedRewardListener")
		listener.set("on_user_earned_reward", func(_item: Variant) -> void: earned.emit())
		ad.call("show", listener)
	else:
		ad.call("show")
