class_name AndroidNotifications
extends NotificationBackend
## Android : plugin « Notification Scheduler » (godot-mobile-plugins/
## godot-notification-scheduler, nœud NotificationScheduler). Accès
## dynamique : le projet compile sans le plugin. NON VALIDÉ sur téléphone.

const CHANNEL := "fv_daily"

var _node: Node


static func _class_path(cls: String) -> String:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls:
			return c["path"]
	return ""


static func available() -> bool:
	return OS.get_name() == "Android" and _class_path("NotificationScheduler") != ""


func backend_name() -> String:
	return "android"


func _ready() -> void:
	_node = load(_class_path("NotificationScheduler")).new()
	add_child(_node)
	var ch: Object = load(_class_path("NotificationChannel")).new()
	ch.call("set_id", CHANNEL)
	ch.call("set_name", "Rappels du marché")
	ch.call("set_description", "Récompense du jour et série")
	_node.call("create_notification_channel", ch)


func request_permission() -> void:
	if _node.has_method("has_post_notifications_permission") \
			and not _node.call("has_post_notifications_permission"):
		_node.call("request_post_notifications_permission")


func schedule(id: int, delay_s: int, title: String, text: String) -> void:
	var data: Object = load(_class_path("NotificationData")).new()
	data.call("set_id", id)
	data.call("set_channel_id", CHANNEL)
	data.call("set_title", title)
	data.call("set_content", text)
	data.call("set_small_icon_name", "ic_notification")
	data.call("set_delay", delay_s)
	_node.call("schedule", data)


func cancel(id: int) -> void:
	_node.call("cancel", id)
