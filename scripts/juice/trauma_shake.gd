class_name TraumaShake
extends RefCounted
## Screen shake « trauma » : le trauma décroît linéairement, le décalage
## varie en trauma² (petits chocs discrets, gros chocs francs).

var enabled: bool = true
var max_offset: float = 0.35
var decay: float = 1.6
var frequency: float = 22.0
var trauma: float = 0.0

var _t: float = 0.0


func configure(cfg: JuiceConfig) -> void:
	max_offset = cfg.shake_max_offset
	decay = cfg.shake_decay
	frequency = cfg.shake_frequency


func add(amount: float) -> void:
	if enabled:
		trauma = clampf(trauma + amount, 0.0, 1.0)


## Avance de `delta` secondes réelles et renvoie le décalage caméra (m).
func update(delta: float) -> Vector2:
	if not enabled:
		trauma = 0.0
	trauma = maxf(trauma - decay * delta, 0.0)
	_t += delta
	if trauma <= 0.0:
		return Vector2.ZERO
	var k := trauma * trauma * max_offset
	var w := _t * frequency
	# Bruit pseudo-aléatoire déterministe (somme de sinus incommensurables).
	return Vector2(sin(w * 1.0) * 0.6 + sin(w * 2.31 + 1.7) * 0.4,
		sin(w * 1.37 + 0.5) * 0.6 + sin(w * 2.73 + 2.9) * 0.4) * k
