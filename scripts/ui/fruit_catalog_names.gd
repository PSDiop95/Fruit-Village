class_name FruitCatalogNames
extends RefCounted
## Accès rapide aux fruits du catalogue et à leurs noms affichés (UI hors partie).

const CATALOG := preload("res://data/fruits.tres")


static func def_of(rank: int) -> FruitDef:
	return (CATALOG as FruitCatalog).get_def(clampi(rank, 0, CATALOG.max_rank()))


## Nom affiché dans la langue courante (Loc).
static func name_of(rank: int) -> String:
	return Loc.fruit_name(def_of(rank).id)
