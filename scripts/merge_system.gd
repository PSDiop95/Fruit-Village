class_name MergeSystem
extends RefCounted
## File de fusions, traitée une fois par frame physique.
## Garantit qu'un fruit ne participe qu'à UNE fusion, même en cas de contacts
## multiples simultanés (bug classique des clones Suika).
##
## Indépendant des nœuds : on manipule des identifiants (instance_id).

## Paires [id_a, id_b] (ids 64 bits : pas de Vector2i, qui tronque en 32 bits).
var _pending: Array[PackedInt64Array] = []
var _queued_ids: Dictionary = {}  # id -> true, ids déjà engagés ce tick


## Signale un contact entre deux fruits de même rang.
## Retourne true si la paire est acceptée.
func request(id_a: int, id_b: int) -> bool:
	if id_a == id_b:
		return false
	if _queued_ids.has(id_a) or _queued_ids.has(id_b):
		return false
	_queued_ids[id_a] = true
	_queued_ids[id_b] = true
	_pending.append(PackedInt64Array([mini(id_a, id_b), maxi(id_a, id_b)]))
	return true


func is_engaged(id: int) -> bool:
	return _queued_ids.has(id)


func has_pending() -> bool:
	return not _pending.is_empty()


## Vide la file et renvoie les paires à fusionner, dans l'ordre d'arrivée.
func flush() -> Array[PackedInt64Array]:
	var out := _pending.duplicate()
	_pending.clear()
	_queued_ids.clear()
	return out
