class_name FruitsLore
extends Resource
## Textes de l'album des fruits, alignés sur FruitCatalog (index = rang).

@export var entries: Array[FruitLore] = []
## Lien du store (partage).
@export var store_url: String = "https://play.google.com/store/apps/details?id=com.fruitvillage.game"


func get_entry(rank: int) -> FruitLore:
	if rank < 0 or rank >= entries.size():
		return null
	return entries[rank]
