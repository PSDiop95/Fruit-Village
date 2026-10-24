class_name NotificationBackend
extends Node
## Interface des notifications locales. MockNotifications (dev, tests) ou
## AndroidNotifications (plugin « Notification Scheduler »).

func backend_name() -> String:
	return "mock"


func request_permission() -> void:
	pass


func schedule(_id: int, _delay_s: int, _title: String, _text: String) -> void:
	pass


func cancel(_id: int) -> void:
	pass
