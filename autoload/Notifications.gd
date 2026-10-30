extends Node
## Autoload Notifications : replanifie les rappels locaux au lancement, à la
## mise en arrière-plan et après chaque réclamation. Désactivables
## (réglage notifications_on) ; rien avant le déblocage de la connexion.
## Push (FCM) : même permission, demandée au même moment (FirebasePush).

var backend: NotificationBackend
## Notifications push (FCM), null sans le plugin Firebase Messaging.
var push: FirebasePush
var clock := MetaClock.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	backend = MobileNotifications.new() if MobileNotifications.available() \
		else MockNotifications.new()
	add_child(backend)
	if FirebasePush.available():
		use_push(FirebasePush.new())
	DailyRewards.claimed.connect(func(_i: int, _r: DailyRewardDef, _s: int) -> void: reschedule())
	SaveManager.setting_changed.connect(func(k: StringName, _v: Variant) -> void:
		if k == &"notifications_on":
			reschedule())
	Progression.level_up.connect(_on_level_up)
	reschedule.call_deferred()
	# Permission déjà demandée (cadeau débloqué) : réenregistre l'appareil pour
	# le push à chaque lancement (sans nouvelle fenêtre).
	if DailyRewards.is_unlocked():
		_register_push.call_deferred()


## Déblocage du cadeau du jour : permission (Android 13+, iOS) puis premiers rappels.
func _on_level_up(_level: int, unlocks: Array[StringName], _coins: int) -> void:
	if ProgressionCore.DAILY in unlocks:
		request_permission()
		reschedule()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reschedule()


func use_push(p: FirebasePush) -> void:
	if push:
		push.queue_free()
	push = p
	add_child(push)


func _register_push() -> void:
	if push and bool(SaveManager.get_setting(&"notifications_on")):
		push.request_permission()


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


## Au déblocage de la connexion quotidienne (Android 13+ et iOS : permission).
func request_permission() -> void:
	backend.request_permission()
	_register_push()
