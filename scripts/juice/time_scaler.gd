class_name TimeScaler
extends RefCounted
## Hit-stops et ralentis superposables. L'échelle effective est la plus lente
## des demandes actives ; sans demande, elle revient TOUJOURS à 1.
## Les durées sont en temps réel (indépendantes de Engine.time_scale).

var enabled: bool = true

var _requests: Array[Vector2] = []  # x = échelle, y = temps réel restant


## Demande `scale` pendant `duration` secondes réelles.
func request(scale: float, duration: float) -> void:
	if not enabled or duration <= 0.0:
		return
	_requests.append(Vector2(clampf(scale, 0.01, 1.0), duration))


func update(real_delta: float) -> float:
	for i in range(_requests.size() - 1, -1, -1):
		_requests[i].y -= real_delta
		if _requests[i].y <= 0.0:
			_requests.remove_at(i)
	return current_scale()


func current_scale() -> float:
	var s := 1.0
	for r in _requests:
		s = minf(s, r.x)
	return s


func is_active() -> bool:
	return not _requests.is_empty()


func clear() -> void:
	_requests.clear()
