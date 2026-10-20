class_name FruitVisual
extends Node3D
## Rendu d'un fruit (placeholder) : sphère + visage procédural + animations
## squash & stretch. N'agit QUE sur les nœuds visuels, jamais sur la collision.
##
## Hiérarchie : FruitVisual (taille, pilotée par Fruit)
##   └ _anim (squash/stretch/respiration/tremblement, axes monde)
##       └ _body (échelle = rayon) : sphère, yeux, bouche, numéro

var config: JuiceConfig
var face := FruitFace.new()
## Corps physique suivi (null pour l'aperçu).
var body: RigidBody3D
var danger_line_y: float = INF
var danger_grace_time: float = 0.0
var rank: int = 0
var radius: float = 0.3

var _anim: Node3D
var _body: Node3D
var _mesh: MeshInstance3D
var _eyes: Array[MeshInstance3D] = []
var _highlights: Array[MeshInstance3D] = []
var _mouth: MeshInstance3D
var _number: Label3D

var _time: float = 0.0
var _breath_phase: float = 0.0
var _squash_amount: float = 0.0
var _squash_t: float = 1.0
var _pop_from: float = 1.0
var _pop_peak: float = 1.0
var _pop_t: float = 1.0
var _pop_time: float = 0.2
var _flash_t: float = 1.0
var _flash_time: float = 0.1
var _eyes_closed: bool = false
var _trembling: bool = false


func setup(cfg: JuiceConfig, seed_value: int) -> void:
	config = cfg
	face.configure(cfg, seed_value)
	face.mood_changed.connect(func(_e: int) -> void: _refresh_face())
	# Déphasage par fruit : la respiration n'est jamais synchrone.
	_breath_phase = fposmod(float(seed_value) * 0.618034, 1.0) * TAU
	_build()


func _build() -> void:
	_anim = Node3D.new()
	add_child(_anim)
	_body = Node3D.new()
	_anim.add_child(_body)
	_mesh = MeshInstance3D.new()
	_body.add_child(_mesh)

	var ex := 0.33
	var ey := 0.15
	var ez := sqrt(1.0 - ex * ex - ey * ey)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = FxMeshes.eye_mesh(config.eye_color)
		eye.position = Vector3(ex * side, ey, ez)
		_body.add_child(eye)
		_eyes.append(eye)
		var hl := MeshInstance3D.new()
		hl.mesh = FxMeshes.eye_highlight_mesh(config.eye_highlight_color)
		hl.position = Vector3(0.035, 0.045, 0.1)
		eye.add_child(hl)
		_highlights.append(hl)

	_mouth = MeshInstance3D.new()
	_mouth.position = Vector3(0, -0.28, 1.0)
	_body.add_child(_mouth)

	if config.show_rank_numbers:
		_number = Label3D.new()
		_number.pixel_size = 0.0045
		_number.font_size = 48
		_number.outline_size = 10
		_number.modulate = Color(1, 1, 1, 0.85)
		_number.position = Vector3(0, -0.62, 1.0)
		_body.add_child(_number)
	_refresh_face()


## Change l'apparence (rang / rayon / couleur). Réutilisable (aperçu).
func apply_def(p_rank: int, def: FruitDef) -> void:
	rank = p_rank
	radius = def.radius
	_mesh.mesh = FxMeshes.fruit_mesh(p_rank, def.color)
	_body.scale = Vector3.ONE * radius
	if _number:
		_number.text = str(p_rank + 1)


# ---------------------------------------------------------------- Événements

## Choc reçu par le corps (variation de vitesse en m/s).
func on_impact(speed: float) -> void:
	var k := inverse_lerp(config.impact_min_speed, config.impact_full_speed, speed)
	k = clampf(k, 0.0, 1.0)
	if k <= 0.0:
		return
	_squash_amount = maxf(k, _squash_amount if _squash_t < 1.0 else 0.0)
	_squash_t = 0.0
	face.impact(speed)


## Pop élastique : `from` → `peak` → 1 en `duration` s.
func pop(from: float, peak: float, duration: float) -> void:
	_pop_from = from
	_pop_peak = peak
	_pop_time = maxf(duration, 0.01)
	_pop_t = 0.0
	_apply_transform()


func flash(duration: float) -> void:
	_flash_time = maxf(duration, 0.01)
	_flash_t = 0.0
	_mesh.set_instance_shader_parameter(&"flash", 1.0)


func set_gray(v: float) -> void:
	_mesh.set_instance_shader_parameter(&"gray", v)


func set_joy() -> void:
	face.set_joy()


func is_squashing() -> bool:
	return _squash_t < 1.0


## Échelle appliquée au nœud animé (diagnostic / tests / captures).
func anim_scale() -> Vector3:
	return _current_scale()


# ---------------------------------------------------------------- Boucle

func _process(delta: float) -> void:
	_time += delta
	if _squash_t < 1.0:
		_squash_t = minf(_squash_t + delta / config.impact_recover_time, 1.0)
	if _pop_t < 1.0:
		_pop_t = minf(_pop_t + delta / _pop_time, 1.0)
	if _flash_t < 1.0:
		_flash_t = minf(_flash_t + delta / _flash_time, 1.0)
		_mesh.set_instance_shader_parameter(&"flash", 1.0 - _flash_t)

	var fruit := body as Fruit
	_trembling = false
	if fruit and not fruit.merging and not fruit.freeze:
		_trembling = fruit.age >= danger_grace_time and fruit.top_y() > danger_line_y
		face.set_above_line(_trembling)
	face.update(delta)
	var closed := face.eyes_closed()
	if closed != _eyes_closed:
		_refresh_face()
	_apply_transform()


func _current_scale() -> Vector3:
	var sx := 1.0
	var sy := 1.0
	# Étirement en chute
	if body and not body.freeze:
		var vy := body.linear_velocity.y
		if vy < 0.0:
			var k := clampf(-vy / config.stretch_full_speed, 0.0, 1.0)
			sx *= lerpf(1.0, config.stretch_min_x, k)
			sy *= lerpf(1.0, config.stretch_max_y, k)
	# Écrasement à l'impact puis retour élastique
	if _squash_t < 1.0:
		var a := _squash_amount * _spring_remaining(_squash_t)
		sx *= 1.0 + (config.impact_squash_x - 1.0) * a
		sy *= 1.0 + (config.impact_squash_y - 1.0) * a
	# Respiration
	var b := sin(_time * config.breath_speed + _breath_phase) * config.breath_amplitude
	sx *= 1.0 - b * 0.5
	sy *= 1.0 + b
	var p := _pop_scale()
	return Vector3(sx * p, sy * p, p)


func _apply_transform() -> void:
	if _anim == null:
		return
	# Axes monde : l'écrasement reste vertical même quand le fruit a roulé.
	var rb := global_basis.orthonormalized() if is_inside_tree() else Basis.IDENTITY
	var inv := rb.inverse()
	_anim.basis = inv * Basis.from_scale(_current_scale()) * rb
	if _trembling:
		var w := _time * config.danger_tremble_speed
		var off := Vector3(sin(w * 1.3), cos(w * 1.7), 0.0) * config.danger_tremble_amplitude
		_anim.position = inv * off / maxf(scale.x, 0.01)
	else:
		_anim.position = Vector3.ZERO


func _pop_scale() -> float:
	if _pop_t >= 1.0:
		return 1.0
	if _pop_t < 0.6:
		var u := _pop_t / 0.6
		return lerpf(_pop_from, _pop_peak, 1.0 - (1.0 - u) * (1.0 - u))
	var v := (_pop_t - 0.6) / 0.4
	return lerpf(_pop_peak, 1.0, 0.5 - 0.5 * cos(PI * v))


## Écrasement tenu sur le premier quart (lisible), puis ressort amorti
## 1 → 0 avec un léger rebond (étirement).
static func _spring_remaining(p: float) -> float:
	if p >= 1.0:
		return 0.0
	if p < 0.25:
		return 1.0
	var q := (p - 0.25) / 0.75
	return (1.0 - q) * (1.0 - q) * cos(q * PI * 1.5)


func _refresh_face() -> void:
	if _mouth == null:
		return
	var e := face.mood
	_eyes_closed = face.eyes_closed()
	_mouth.mesh = FxMeshes.mouth_mesh(e, config.mouth_color)
	var eye_scale := Vector3.ONE
	var hl_visible := true
	if _eyes_closed:
		eye_scale = Vector3(1.2, 0.15, 1.0)
		hl_visible = false
	elif e == FruitFace.Mood.SQUASHED:
		eye_scale = Vector3(1.15, 0.3, 1.0)
		hl_visible = false
	elif e == FruitFace.Mood.FEAR:
		eye_scale = Vector3(1.25, 1.3, 1.0)
	for i in _eyes.size():
		_eyes[i].scale = eye_scale
		_highlights[i].visible = hl_visible
