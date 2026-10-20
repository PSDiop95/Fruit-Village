class_name NodePool
extends RefCounted
## Pool d'effets préchauffé. Si tout est occupé, on recycle le plus ancien :
## aucune instanciation pendant la partie.
##
## Les nœuds doivent exposer `tick(delta: float) -> bool` (false = terminé).

## Nombre total de nœuds créés (doit rester égal à la taille après préchauffage).
var created: int = 0

var _free: Array[Node] = []
var _active: Array[Node] = []


func _init(parent: Node, factory: Callable, count: int) -> void:
	for i in maxi(count, 1):
		var n: Node = factory.call()
		created += 1
		n.set("visible", false)
		parent.add_child(n)
		_free.append(n)


func acquire() -> Node:
	var n: Node
	if _free.is_empty():
		n = _active.pop_front()
	else:
		n = _free.pop_back()
	_active.append(n)
	n.set("visible", true)
	return n


func release(n: Node) -> void:
	var i := _active.find(n)
	if i == -1:
		return
	_active.remove_at(i)
	n.set("visible", false)
	_free.append(n)


func tick(delta: float) -> void:
	for i in range(_active.size() - 1, -1, -1):
		var n := _active[i]
		if not n.tick(delta):
			_active.remove_at(i)
			n.set("visible", false)
			_free.append(n)


func all() -> Array[Node]:
	return _free + _active


func active_count() -> int:
	return _active.size()


func size() -> int:
	return _free.size() + _active.size()
