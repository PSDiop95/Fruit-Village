class_name Spawner
extends RefCounted
## Tirage des fruits à lâcher. Aléatoire SEEDÉ : même graine = même séquence
## (indispensable pour le futur Défi du jour). Tirage pondéré optionnel.

var _rng := RandomNumberGenerator.new()
var _ranks: Array[int] = []
var _weights := PackedFloat32Array()
var _queue: Array[int] = []
var _preview_count: int = 1


## `weights` : vide = uniforme, sinon aligné sur `droppable_ranks`.
func setup(droppable_ranks: Array[int], seed_value: int, preview_count: int = 1,
		weights := PackedFloat32Array()) -> void:
	assert(not droppable_ranks.is_empty(), "Aucun fruit lâchable")
	assert(weights.is_empty() or weights.size() == droppable_ranks.size(),
		"Poids et rangs désalignés")
	_ranks = droppable_ranks.duplicate()
	_weights = weights
	_rng.seed = seed_value
	_preview_count = maxi(preview_count, 1)
	_queue.clear()
	# fruit courant + aperçus
	for i in _preview_count + 1:
		_queue.append(_roll())


## Fruit à lâcher maintenant.
func current() -> int:
	return _queue[0]


## Fruits suivants (aperçu).
func upcoming() -> Array[int]:
	return _queue.slice(1)


## Consomme le fruit courant et renvoie son rang.
func take() -> int:
	var r: int = _queue.pop_front()
	_queue.append(_roll())
	return r


func _roll() -> int:
	if _weights.is_empty():
		return _ranks[_rng.randi_range(0, _ranks.size() - 1)]
	return _ranks[_rng.rand_weighted(_weights)]
