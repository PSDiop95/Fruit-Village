extends Node
## Autoload Collection : album des fruits (logique : CollectionCore).
## Album complet : thème doré du panier débloqué et appliqué.

signal fruit_unlocked(rank: int)
signal album_completed

const GOLD_SKIN := "gold"

var catalog: FruitCatalog = preload("res://data/fruits.tres")
var lore: FruitsLore = preload("res://data/fruits_lore.tres")
var core: CollectionCore


func _ready() -> void:
	core = CollectionCore.new(catalog.count())
	SaveManager.register_system("collection", self)


func save_state() -> Dictionary:
	return core.to_dict()


func load_state(d: Dictionary) -> void:
	core.from_dict(d)


func has(rank: int) -> bool:
	return core.has(rank)


func count() -> int:
	return core.count()


func is_complete() -> bool:
	return core.is_complete()


func gold_unlocked() -> bool:
	return core.completion_claimed


## Première création d'un fruit (lâcher ou fusion).
func discover(rank: int) -> bool:
	if not core.discover(rank):
		return false
	Analytics.log_event(&"new_fruit_discovered", {"rank": rank + 1,
		"fruit": String(catalog.get_def(rank).id)})
	SaveManager.request_save()
	fruit_unlocked.emit(rank)
	if core.claim_completion():
		SaveManager.set_setting(&"basket_skin", GOLD_SKIN)
		album_completed.emit()
	return true
