class_name FruitCatalogNames
extends RefCounted
## Accès rapide aux noms affichés des fruits (UI hors partie).

const CATALOG := preload("res://data/fruits.tres")


static func name_of(rank: int) -> String:
	return (CATALOG as FruitCatalog).get_def(clampi(rank, 0, CATALOG.max_rank())).display_name
