class_name CrashReporter
extends RefCounted
## V2-0 : rapports de plantage Firebase Crashlytics (plugin Godotx, singleton
## GodotxFirebaseCrashlytics, Android ; Core initialisé une seule fois par
## FirebaseBoot). Accès dynamique : le projet compile et tourne sans le plugin
## (PC, tests, iOS, APK MockAds) : tout devient sans effet.
##
## Confidentialité : collecte coupée par défaut (manifeste,
## firebase/privacy_safe_defaults) et activée seulement avec le consentement
## des statistiques (Analytics.is_allowed : UMP + réglage « Statistiques
## d'usage »). Jamais d'identifiant utilisateur, jamais de donnée personnelle
## dans les journaux ou les clés.

const SINGLETON := "GodotxFirebaseCrashlytics"
## Longueur maximale d'un message de journal.
const MAX_LOG := 200

## Singleton de remplacement (tests).
static var singleton_override: Object

var _c: Object
var _sdk_ready: bool = false
var _enabled: bool = false


static func available() -> bool:
	return singleton_override != null \
		or (FirebaseBoot.available() and Engine.has_singleton(SINGLETON))


func _init() -> void:
	if not available():
		return
	_c = singleton_override if singleton_override else Engine.get_singleton(SINGLETON)
	_c.connect("crashlytics_initialized", func(ok: bool) -> void:
		_sdk_ready = ok
		set_collection_enabled(_enabled))
	_c.connect("crashlytics_error", func(message: String) -> void:
		push_warning("Crashlytics : %s" % message.left(MAX_LOG)))
	FirebaseBoot.when_ready(func(ok: bool) -> void:
		if ok:
			_c.call("initialize"))


func is_active() -> bool:
	return _c != null and _sdk_ready and _enabled


func set_collection_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _c == null or not _sdk_ready:
		return
	# Appel direct : has_method() est faux sur un singleton Java (JNI).
	_c.call("set_crashlytics_collection_enabled", enabled)


## Trace jointe au prochain rapport (texte technique, jamais de donnée joueur).
func log_message(message: String) -> void:
	if is_active():
		_c.call("log_message", message.left(MAX_LOG))


## Contexte technique (langue, qualité…) : clés et valeurs non personnelles.
func set_key(key: String, value: Variant) -> void:
	if not is_active():
		return
	match typeof(value):
		TYPE_BOOL: _c.call("set_custom_value_bool", key, value)
		TYPE_INT: _c.call("set_custom_value_int", key, value)
		TYPE_FLOAT: _c.call("set_custom_value_float", key, value)
		_: _c.call("set_custom_value_string", key, str(value).left(MAX_LOG))


## Plantage de test : builds debug seulement (menu debug), jamais en release.
static func test_crash_allowed() -> bool:
	return OS.is_debug_build()


func test_crash() -> bool:
	if not test_crash_allowed() or _c == null or not _sdk_ready:
		return false
	_c.call("crash")
	return true
