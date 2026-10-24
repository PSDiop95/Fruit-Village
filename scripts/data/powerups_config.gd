class_name PowerupsConfig
extends Resource
## Power-ups en partie : définitions, prix, paramètres d'effet.

const SHAKE := &"shake"
const PESTLE := &"pestle"
const SWAP := &"swap"
const GROW := &"grow"

@export var powerups: Array[PowerupDef] = []

@export_group("Secouer")
## Délai minimal entre deux secousses (s).
@export var shake_cooldown: float = 20.0
## Impulsion horizontale max par fruit (m/s, × masse).
@export var shake_horizontal: float = 2.2
## Impulsion verticale (m/s, × masse) : décolle les fruits sans les éjecter.
@export var shake_vertical: float = 3.0

@export_group("Agrandir")
## Rang maximal atteint par « Agrandir » (0 = Sidem ; 5 = Goyave, 6e fruit).
@export var grow_max_rank: int = 5


func get_def(id: StringName) -> PowerupDef:
	for p in powerups:
		if p.id == id:
			return p
	return null


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in powerups:
		out.append(p.id)
	return out


func cheapest_price() -> int:
	var best := 1 << 30
	for p in powerups:
		best = mini(best, p.price)
	return best
