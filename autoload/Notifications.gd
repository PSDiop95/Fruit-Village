extends Node
## Autoload Notifications : replanifie les rappels locaux au lancement, à la
## mise en arrière-plan et après chaque réclamation. Désactivables
## (réglage notifications_on) ; rien avant le déblocage de la connexion.

var backend: NotificationBackend
var clock := MetaClock.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	backend = AndroidNotifications.new() if AndroidNotifications.available() \
		else MockNotifications.new()
	add_child(backend)
	DailyRewards.claimed.connect(func(_i: int, _r: DailyRewardDef, _s: int) -> void: reschedule())
	SaveManager.setting_changed.connect(func(k: StringName, _v: Variant) -> void:
		if k == &"notifications_on":
			reschedule())
	Progression.level_up.connect(_on_level_up)
	reschedule.call_deferred()


## Déblocage du cadeau du jour : permission (Android 13+) puis premiers rappels.
func _on_level_up(_level: int, unlocks: Array[StringName], _coins: int) -> void:
	if ProgressionCore.DAILY in unlocks:
		request_permission()
		reschedule()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reschedule()


func use_backend(b: NotificationBackend) -> void:
	if backend:
		backend.queue_free()
	backend = b
	add_child(backend)


func reschedule() -> void:
	for id in [NotificationPlanner.ID_REMINDER, NotificationPlanner.ID_STREAK]:
		backend.cancel(id)
	if not bool(SaveManager.get_setting(&"notifications_on")) or not DailyRewards.is_unlocked():
		return
	var core := DailyRewards.core
	var plan := NotificationPlanner.plan(clock, DailyRewards.config,
		core.claimed_today(clock.today()), core.streak)
	for n in plan:
		backend.schedule(n["id"], n["delay"], n["title"], n["text"])


## Au déblocage de la connexion quotidienne (Android 13+ : permission).
func request_permission() -> void:
	backend.request_permission()
