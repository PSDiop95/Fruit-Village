extends Node
## Autoload Analytics : façade d'envoi d'événements.
## Respect du consentement : rien n'est envoyé tant que le consentement n'est
## pas connu, ni s'il est refusé (UMP) ou si le joueur coupe les statistiques
## dans les réglages. Les événements refusés sont perdus (pas de file).

## Événements tentés (envoyés ou non) : debug, tests.
signal event_logged(name: StringName, params: Dictionary, sent: bool)

var backend: AnalyticsBackend
## Consentement publicitaire/statistiques connu et accordé (fourni par AdsManager).
var consent_granted: bool = false


func _ready() -> void:
	if FirebaseAnalytics.available():
		backend = FirebaseAnalytics.new()
	elif OS.is_debug_build():
		backend = ConsoleAnalytics.new()
	else:
		backend = AnalyticsBackend.new()
	SaveManager.setting_changed.connect(func(k: StringName, _v: Variant) -> void:
		if k == &"analytics_on":
			_apply())
	_apply()


func use_backend(b: AnalyticsBackend) -> void:
	backend = b
	_apply()


func set_consent(granted: bool) -> void:
	consent_granted = granted
	_apply()


func is_allowed() -> bool:
	return consent_granted and bool(SaveManager.get_setting(&"analytics_on"))


func _apply() -> void:
	if backend:
		backend.set_collection_enabled(is_allowed())


func log_event(name: StringName, params: Dictionary = {}) -> void:
	var sent := is_allowed() and backend != null
	if sent:
		backend.log_event(name, params)
	event_logged.emit(name, params, sent)
