class_name FruitCatalog
extends Resource
## Liste ordonnée des fruits, du plus petit (rang 0) au plus gros.

@export var fruits: Array[FruitDef] = []
## Points pour la fusion de deux fruits du rang max (Moment Baobab).
@export var top_merge_points: int = 500


func count() -> int:
	return fruits.size()


func get_def(rank: int) -> FruitDef:
	assert(rank >= 0 and rank < fruits.size(), "Rang de fruit invalide : %d" % rank)
	return fruits[rank]


func max_rank() -> int:
	return fruits.size() - 1


func is_top(rank: int) -> bool:
	return rank == max_rank()


func droppable_ranks() -> Array[int]:
	var out: Array[int] = []
	for i in fruits.size():
		if fruits[i].droppable:
			out.append(i)
	return out


## Poids de tirage, alignés sur droppable_ranks().
func droppable_weights() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in fruits.size():
		if fruits[i].droppable:
			out.append(maxf(fruits[i].spawn_weight, 0.0))
	return out


## Points gagnés par la fusion de deux fruits de rang `rank`.
func merge_points(rank: int) -> int:
	if is_top(rank):
		return top_merge_points
	return fruits[rank + 1].points
