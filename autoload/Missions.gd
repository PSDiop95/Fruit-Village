extends Node
## Autoload Missions : 3 missions du jour (logique : MissionsCore).
## Renouvelées à minuit (heure locale) : vérifié au lancement, au retour au
## premier plan et chaque minute. Progression seulement une fois débloquées.

signal changed
signal mission_completed(index: int)

var config: MissionsConfig = preload("res://data/missions.tres")
var core: MissionsCore
var clock := MetaClock.new()
var _timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	core = MissionsCore.new(config, randi())
	core.progressed.connect(func(_i: int) -> void:
		SaveManager.request_save()
		changed.emit())
	core.completed.connect(_on_completed)
	core.renewed.connect(func() -> void:
		SaveManager.request_save()
		changed.emit())
	SaveManager.register_system("missions", self)
	_timer = Timer.new()
	_timer.wait_time = 60.0
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		refresh()


func save_state() -> Dictionary:
	return core.to_dict()


func load_state(d: Dictionary) -> void:
	var seed_before := core.player_seed
	core.from_dict(d)
	if d.is_empty():
		core.player_seed = seed_before
	changed.emit()


func use_clock(c: MetaClock) -> void:
	clock = c
	refresh()


func is_unlocked() -> bool:
	return Progression.is_unlocked(ProgressionCore.MISSIONS)


## Nouveau jour → nouvelles missions.
func refresh() -> void:
	if core and is_unlocked():
		core.refresh(clock.today(), Progression.level())


func active() -> Array[Dictionary]:
	return core.active if is_unlocked() else ([] as Array[Dictionary])


func report(kind: MissionDef.Kind, value: int = 1, rank: int = -1) -> void:
	if not is_unlocked():
		return
	refresh()
	core.on_event(kind, value, rank)


func can_claim(index: int) -> bool:
	return is_unlocked() and core.can_claim(index)


func claimable_count() -> int:
	return core.claimable_count() if is_unlocked() else 0


## Réclame la récompense ; `doubled` uniquement sur callback rewarded.
func claim(index: int, doubled: bool = false) -> int:
	var coins := core.claim(index, doubled)
	if coins > 0:
		Wallet.earn(coins, &"mission")
		SaveManager.request_save()
		changed.emit()
	return coins


## Texte affiché d'une mission (« Atteins 2 mangues »).
func describe(index: int) -> String:
	var def := core.def_of(index)
	if def == null:
		return ""
	var target := int(core.active[index]["target"])
	if def.kind == MissionDef.Kind.CREATE_RANK:
		var n := FruitCatalogNames.name_of(def.rank).to_lower()
		if target > 1 and not n.ends_with("s"):
			n += "s"
		return def.text % [target, n]
	return def.text % target


func _on_completed(index: int) -> void:
	Analytics.log_event(&"mission_completed", {"mission": core.active[index]["id"]})
	mission_completed.emit(index)
