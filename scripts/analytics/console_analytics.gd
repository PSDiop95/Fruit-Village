class_name ConsoleAnalytics
extends AnalyticsBackend
## Développement : chaque événement est écrit dans la console.


func backend_name() -> String:
	return "console"


func log_event(name: StringName, params: Dictionary) -> void:
	print("[analytics] %s %s" % [name, JSON.stringify(params)])
