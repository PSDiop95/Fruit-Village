class_name MobileNotifications
extends NotificationBackend
## Android et iOS : plugin « Notification Scheduler » v6 (godot-mobile-plugins/
## godot-notification-scheduler, addons/NotificationSchedulerPlugin + ios/plugins).
## iOS : canal ignoré, icône = celle de l'app ; permission demandée au
## déblocage du cadeau du jour. Android 13+ : permission POST_NOTIFICATIONS.

const CHANNEL := "fv_daily"
const SINGLETON := "NotificationSchedulerPlugin"

var _node: NotificationScheduler


static func available() -> bool:
	return OS.get_name() in ["Android", "iOS"] and Engine.has_singleton(SINGLETON)


func backend_name() -> String:
	return OS.get_name().to_lower()


func _ready() -> void:
	_node = NotificationScheduler.new()
	add_child(_node)
	_node.initialize()
	if OS.get_name() == "Android":
		_node.create_notification_channel(NotificationChannel.new()
			.set_id(CHANNEL)
			.set_name("Rappels du marché")
			.set_description("Récompense du jour et série"))


func request_permission() -> void:
	if not _node.has_post_notifications_permission():
		_node.request_post_notifications_permission()


func schedule(id: int, delay_s: int, title: String, text: String) -> void:
	_node.schedule(NotificationData.new()
		.set_id(id)
		.set_channel_id(CHANNEL)
		.set_title(title)
		.set_content(text)
		.set_small_icon_name("ic_notification")
		.set_delay(delay_s))


func cancel(id: int) -> void:
	_node.cancel(id)
