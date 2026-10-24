class_name AnalyticsBackend
extends RefCounted
## Interface d'envoi d'événements. Implémentations : ConsoleAnalytics (dev),
## FirebaseAnalytics (prod, plugin Godotx Firebase), MemoryAnalytics (tests).


func backend_name() -> String:
	return "none"


func log_event(_name: StringName, _params: Dictionary) -> void:
	pass


## Consentement : collecte activée / désactivée côté SDK.
func set_collection_enabled(_enabled: bool) -> void:
	pass
