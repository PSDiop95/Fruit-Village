extends Node
## Autoload Wallet : pièces et stock de power-ups (logique : WalletCore).

signal coins_changed(coins: int, delta: int, reason: StringName)
signal stock_changed(id: StringName, count: int)

var economy: EconomyConfig = preload("res://data/economy.tres")
var powerups: PowerupsConfig = preload("res://data/powerups.tres")
var core := WalletCore.new()


func _ready() -> void:
	core.max_balance = economy.max_balance
	core.coins_changed.connect(func(c: int, d: int, r: StringName) -> void:
		SaveManager.request_save()
		coins_changed.emit(c, d, r))
	core.stock_changed.connect(func(id: StringName, n: int) -> void:
		SaveManager.request_save()
		stock_changed.emit(id, n))
	SaveManager.register_system("wallet", self)


func save_state() -> Dictionary:
	return core.to_dict()


func load_state(d: Dictionary) -> void:
	if d.is_empty():
		core.from_dict({"coins": economy.starting_coins})
	else:
		core.from_dict(d)
	coins_changed.emit(core.coins, 0, &"load")


func coins() -> int:
	return core.coins


func earn(amount: int, reason: StringName = &"") -> int:
	return core.earn(amount, reason)


func spend(amount: int, reason: StringName = &"") -> bool:
	return core.spend(amount, reason)


func can_afford(amount: int) -> bool:
	return core.can_afford(amount)


func stock_of(id: StringName) -> int:
	return core.stock_of(id)


func add_stock(id: StringName, count: int = 1) -> void:
	core.add_stock(id, count)


func use_stock(id: StringName) -> bool:
	return core.use_stock(id)


## Achète une unité du power-up `id` au prix de powerups.tres.
func buy_powerup(id: StringName) -> bool:
	var def := powerups.get_def(id)
	return def != null and core.buy(id, def.price)
