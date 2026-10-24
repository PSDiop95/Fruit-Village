class_name MockNotifications
extends NotificationBackend
## Dev / tests : garde les notifications planifiées en mémoire.

var scheduled: Dictionary = {}  # id -> {delay, title, text}


func backend_name() -> String:
	return "mock"


func schedule(id: int, delay_s: int, title: String, text: String) -> void:
	scheduled[id] = {"delay": delay_s, "title": title, "text": text}
	if OS.is_debug_build():
		print("[notif] #%d dans %d min : %s" % [id, delay_s / 60, text])


func cancel(id: int) -> void:
	scheduled.erase(id)
