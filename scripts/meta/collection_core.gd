class_name CollectionCore
extends RefCounted
## Album des fruits : un fruit est débloqué à sa première création (lâcher ou
## fusion). Album complet = récompense spéciale (thème doré du panier).

var total: int = 11
var completion_claimed: bool = false
var _found: Dictionary = {}  # rang -> true


func _init(p_total: int = 11) -> void:
	total = p_total


## Renvoie true si le fruit vient d'être découvert pour la première fois.
func discover(rank: int) -> bool:
	if rank < 0 or rank >= total or _found.has(rank):
		return false
	_found[rank] = true
	return true


func has(rank: int) -> bool:
	return _found.has(rank)


func count() -> int:
	return _found.size()


func is_complete() -> bool:
	return count() >= total


## Réclame la récompense d'album complet (une seule fois).
func claim_completion() -> bool:
	if not is_complete() or completion_claimed:
		return false
	completion_claimed = true
	return true


func to_dict() -> Dictionary:
	var ranks: Array[int] = []
	for r in _found:
		ranks.append(int(r))
	ranks.sort()
	return {"found": ranks, "completion_claimed": completion_claimed}


func from_dict(d: Dictionary) -> void:
	_found.clear()
	var ranks: Variant = d.get("found", [])
	if ranks is Array:
		for r in ranks:
			var i := int(r)
			if i >= 0 and i < total:
				_found[i] = true
	completion_claimed = bool(d.get("completion_claimed", false)) and is_complete()
