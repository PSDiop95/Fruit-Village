extends Node
## Autoload DailyRewards : calendrier 7 jours, série, bouclier, anti-triche
## horloge (logique : DailyRewardsCore + ClockGuard).

signal changed
signal claimed(day_index: int, reward: DailyRewardDef, streak: int)

var config: DailyRewardsConfig = preload("res://data/daily_rewards.tres")
var core: DailyRewardsCore
var clock := MetaClock.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	core = DailyRewardsCore.new(config)
	core.guard.begin_session(clock.now(), clock.ticks())
	SaveManager.register_system("daily", self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		changed.emit()


func save_state() -> Dictionary:
	if core.guard:
		core.guard.mark_seen(clock.now(), clock.ticks())
	return core.to_dict()


func load_state(d: Dictionary) -> void:
	core.from_dict(d)
	changed.emit()


func use_clock(c: MetaClock) -> void:
	clock = c
	core.guard.begin_session(clock.now(), clock.ticks())
	changed.emit()


func is_unlocked() -> bool:
	return Progression.is_unlocked(ProgressionCore.DAILY)


func coherent() -> bool:
	return core.guard.is_coherent(clock.now(), clock.ticks())


func status() -> Dictionary:
	return core.status(clock.today(), coherent())


func can_claim() -> bool:
	return is_unlocked() and bool(status()["can_claim"])


## Réclame la case du jour. `use_shield` uniquement après le callback rewarded.
func claim(use_shield: bool = false) -> DailyRewardDef:
	if not is_unlocked():
		return null
	var st := status()
	var reward := core.claim(clock.today(), coherent(), use_shield)
	if reward == null:
		return null
	var index: int = st["day_index_with_shield"] if use_shield else st["day_index"]
	if reward.coins > 0:
		Wallet.earn(reward.coins, &"daily")
	if reward.powerup != &"" and reward.powerup_count > 0:
		Wallet.add_stock(reward.powerup, reward.powerup_count)
	Analytics.log_event(&"daily_claimed", {"day": index + 1, "streak": core.streak,
		"shield": use_shield})
	SaveManager.request_save()
	claimed.emit(index, reward, core.streak)
	changed.emit()
	return reward
