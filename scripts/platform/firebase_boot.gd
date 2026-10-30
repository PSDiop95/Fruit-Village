class_name FirebaseBoot
extends RefCounted
## Initialisation UNIQUE de Firebase Core (plugin Godotx, singleton
## GodotxFirebaseCore), partagée par Analytics et Messaging : un second
## initialize() configure deux fois l'app par défaut (plantage sur iOS).
## Les modules attendent le résultat via when_ready().

const CORE := "GodotxFirebaseCore"

enum State { IDLE, PENDING, READY, FAILED }

static var state: State = State.IDLE
## Singleton de remplacement (tests).
static var core_override: Object
static var _waiters: Array[Callable] = []


static func available() -> bool:
	return core_override != null or Engine.has_singleton(CORE)


## `callback(ok: bool)` : appelé une fois Core prêt (tout de suite s'il l'est).
static func when_ready(callback: Callable) -> void:
	match state:
		State.READY:
			callback.call(true)
		State.FAILED:
			callback.call(false)
		_:
			_waiters.append(callback)
			if state == State.IDLE:
				_start()


static func _start() -> void:
	state = State.PENDING
	var core: Object = core_override if core_override else Engine.get_singleton(CORE)
	core.connect("core_initialized", func(ok: bool) -> void: _finish(ok), CONNECT_ONE_SHOT)
	core.call("initialize")


static func _finish(ok: bool) -> void:
	state = State.READY if ok else State.FAILED
	var waiters := _waiters.duplicate()
	_waiters.clear()
	for cb in waiters:
		if cb.is_valid():
			cb.call(ok)


## Tests : état initial.
static func reset() -> void:
	state = State.IDLE
	core_override = null
	_waiters.clear()
