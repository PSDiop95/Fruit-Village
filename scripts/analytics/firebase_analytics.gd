class_name FirebaseAnalytics
extends AnalyticsBackend
## Production : Firebase Analytics via le plugin Godotx Firebase
## (github.com/godot-x/firebase, singletons GodotxFirebaseCore /
## GodotxFirebaseAnalytics). Accès dynamique : le projet compile sans le plugin.
## Paramètres envoyés en texte/nombre ; événements perdus tant que le SDK
## n'est pas initialisé (pas de file : volume négligeable au lancement).

const CORE := "GodotxFirebaseCore"
const ANALYTICS := "GodotxFirebaseAnalytics"

var _core: Object
var _fa: Object
var _sdk_ready: bool = false
var _enabled: bool = false


static func available() -> bool:
	return Engine.has_singleton(CORE) and Engine.has_singleton(ANALYTICS)


func _init() -> void:
	if not available():
		return
	_core = Engine.get_singleton(CORE)
	_fa = Engine.get_singleton(ANALYTICS)
	if _fa.has_signal("analytics_initialized"):
		_fa.connect("analytics_initialized", func(ok: bool) -> void:
			_sdk_ready = ok
			set_collection_enabled(_enabled))
	if _core.has_signal("core_initialized"):
		_core.connect("core_initialized", func(ok: bool) -> void:
			if ok:
				_fa.call("initialize"))
	_core.call("initialize")


func backend_name() -> String:
	return "firebase"


func log_event(name: StringName, params: Dictionary) -> void:
	if not _sdk_ready or not _enabled:
		return
	_fa.call("log_event", String(name), params)


func set_collection_enabled(enabled: bool) -> void:
	_enabled = enabled
	if _fa == null or not _sdk_ready:
		return
	# Appels directs : has_method() est faux sur un singleton Java (JNI) même
	# quand la méthode existe (vérifié sur Galaxy A23).
	var state := "granted" if enabled else "denied"
	_fa.call("set_consent", {"analytics_storage": state, "ad_storage": state,
		"ad_user_data": state, "ad_personalization": state})
	_fa.call("set_analytics_collection_enabled", enabled)
