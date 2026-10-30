class_name FirebaseAnalytics
extends AnalyticsBackend
## Production : Firebase Analytics via le plugin Godotx Firebase
## (github.com/godot-x/firebase, singleton GodotxFirebaseAnalytics ; Core
## initialisé une seule fois par FirebaseBoot). Accès dynamique : le projet
## compile sans le plugin.
## Paramètres envoyés en texte/nombre ; événements perdus tant que le SDK
## n'est pas initialisé (pas de file : volume négligeable au lancement).

const ANALYTICS := "GodotxFirebaseAnalytics"

var _fa: Object
var _sdk_ready: bool = false
var _enabled: bool = false


static func available() -> bool:
	return FirebaseBoot.available() and Engine.has_singleton(ANALYTICS)


func _init() -> void:
	if not available():
		return
	_fa = Engine.get_singleton(ANALYTICS)
	if _fa.has_signal("analytics_initialized"):
		_fa.connect("analytics_initialized", func(ok: bool) -> void:
			_sdk_ready = ok
			set_collection_enabled(_enabled))
	FirebaseBoot.when_ready(func(ok: bool) -> void:
		if ok:
			_fa.call("initialize"))


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
