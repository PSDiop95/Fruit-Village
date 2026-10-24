class_name MemoryAnalytics
extends AnalyticsBackend
## Tests : garde les événements en mémoire.

var events: Array[Dictionary] = []
var collection_enabled: bool = true


func backend_name() -> String:
	return "memory"


func log_event(name: StringName, params: Dictionary) -> void:
	events.append({"name": name, "params": params})


func set_collection_enabled(enabled: bool) -> void:
	collection_enabled = enabled


func names() -> Array[StringName]:
	var out: Array[StringName] = []
	for e in events:
		out.append(e["name"])
	return out


func count(name: StringName) -> int:
	return names().count(name)


func last(name: StringName) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		if events[i]["name"] == name:
			return events[i]["params"]
	return {}
