extends Node
## Autoload Progression : XP, niveau, déblocages (logique : ProgressionCore).
## Récompense de niveau : pièces + cadeaux de déblocage des power-ups.

signal xp_changed(xp: int, level: int)
signal level_up(level: int, unlocks: Array[StringName], coins: int)

var config: LevelsConfig = preload("res://data/levels.tres")
var core: ProgressionCore


func _ready() -> void:
	core = ProgressionCore.new(config)
	SaveManager.register_system("progression", self)


func save_state() -> Dictionary:
	return core.to_dict()


func load_state(d: Dictionary) -> void:
	core.from_dict(d)
	xp_changed.emit(core.xp, core.level)


func level() -> int:
	return core.level


func is_unlocked(feature: StringName) -> bool:
	return core.is_unlocked(feature)


func unlock_level(feature: StringName) -> int:
	return core.unlock_level(feature)


## XP de fin de partie. Renvoie {"xp": int, "levels": Array[int], "coins": int}.
func add_game(score: int, merges: int) -> Dictionary:
	var xp := config.xp_for_game(score, merges)
	return add_xp(xp)


func add_xp(amount: int) -> Dictionary:
	var levels := core.add_xp(amount)
	var coins := 0
	for lv in levels:
		var unlocks := core.unlocks_at(lv)
		var c := Wallet.earn(config.level_up_coins, &"level_up")
		coins += c
		if ProgressionCore.POWERUPS in unlocks:
			for p in Wallet.powerups.powerups:
				Wallet.add_stock(p.id, p.unlock_gift)
		Analytics.log_event(&"level_up", {"level": lv})
		level_up.emit(lv, unlocks, c)
	SaveManager.request_save()
	xp_changed.emit(core.xp, core.level)
	return {"xp": amount, "levels": levels, "coins": coins}
