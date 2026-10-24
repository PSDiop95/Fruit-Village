class_name FruitVisual
extends Node3D
## Rendu d'un fruit : modèle 3D toon (M3, repli sphère M2) + visage procédural
## + animations squash & stretch. N'agit QUE sur les nœuds visuels, jamais sur
## la collision.
##
## Hiérarchie : FruitVisual (taille, pilotée par Fruit)
##   └ _anim (squash/stretch/respiration/tremblement, axes monde)
##       └ _body (échelle = rayon, unités normalisées)
##           ├ _mesh (modèle en mètres, échelle 1/rayon) · _halo
##           └ _face (ancre « face_anchor » du modèle) : yeux, bouche, numéro

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
var _face: Node3D
var _halo: MeshInstance3D
## Ombre « tache » (qualité Bas) : hors hiérarchie animée, posée sur le fond.
var _blob: MeshInstance3D
## Rendu regroupé (partie) : visage et ombre dessinés par FruitBatcher.
var _batcher: FruitBatcher
## Visage complet (yeux + reflets + bouche) en un seul mesh par expression.
var _face_mesh: MeshInstance3D
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
## Regard (yeux + bouche décalés vers une cible, puis retour au centre).
var _look := Vector2.ZERO
var _look_target := Vector2.ZERO
var _look_left: float = 0.0
## Arrivée de l'aperçu : tombe de `_drop_h` m et rebondit.
var _drop_h: float = 0.0
var _drop_t: float = 1.0
var _drop_time: float = 0.25


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
	_face = Node3D.new()
	_body.add_child(_face)

	# Repère du visage : origine = point de surface avant (z = 0), comme sur
	# une sphère unité dont le visage est centré en (0, 0, 1). 1 draw call.
	_face_mesh = MeshInstance3D.new()
	_face_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face.add_child(_face_mesh)

	if config.show_rank_numbers:
		_number = Label3D.new()
		_number.pixel_size = 0.0045
		_number.font_size = 48
		_number.outline_size = 10
		_number.modulate = Color(1, 1, 1, 0.85)
		_number.position = Vector3(0, -0.62, 0.0)
		_face.add_child(_number)
	_refresh_face()


## Change l'apparence (rang / rayon / couleur). Réutilisable (aperçu).
func apply_def(p_rank: int, def: FruitDef) -> void:
	rank = p_rank
	radius = def.radius
	_body.scale = Vector3.ONE * radius
	var model := FruitModels.get_model(def.id)
	if model:
		_mesh.mesh = model.mesh
		_mesh.material_override = FruitModels.fruit_material()
		_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mesh.scale = Vector3.ONE / radius
		_face.position = model.face_position / radius
		_face.scale = Vector3.ONE * model.face_scale
		_mesh.set_instance_shader_parameter(&"outline_radial", FruitModels.outline_radial_for(def.id))
	else:
		_mesh.mesh = FxMeshes.fruit_mesh(p_rank, def.color)
		_mesh.material_override = null
		_mesh.scale = Vector3.ONE
		_face.position = Vector3(0, 0, 1)
		_face.scale = Vector3.ONE
	_apply_halo(p_rank)
	_update_blob_visibility()
	if _number:
		_number.text = str(p_rank + 1)


## Halo additif derrière les fruits précieux (data/visual.tres).
func _apply_halo(p_rank: int) -> void:
	var on := FruitModels.is_halo_rank(p_rank)
	if on and _halo == null:
		var vc := FruitModels.get_config()
		_halo = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2.ONE * vc.halo_size
		q.material = FxMeshes.additive_material(vc.halo_color, 2)
		_halo.mesh = q
		_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(_halo)
	if _halo:
		_halo.visible = on
		# Derrière le fruit mais devant le fond du panier (z monde ≈ -0,95).
		_halo.position = Vector3(0, 0, -minf(0.95 / maxf(radius, 0.01), 1.0))


## M4 : silhouette de l'album (le halo additif n'a pas de sens teinté en noir).
func hide_halo() -> void:
	if _halo:
		_halo.visible = false


## Matériau courant (après changement de qualité).
func refresh_material() -> void:
	if _mesh.material_override:
		_mesh.material_override = FruitModels.fruit_material()
	_update_blob_visibility()


## Visage + ombre rendus en MultiMesh par `batcher` (1 draw call pour tous).
func use_batcher(batcher: FruitBatcher) -> void:
	_batcher = batcher
	_face_mesh.visible = false
	if _blob:
		_blob.queue_free()
		_blob = null
	batcher.register(self)


func batched_face_key() -> Vector2i:
	return Vector2i(face.mood, int(_eyes_closed))


func batched_face_mesh() -> Mesh:
	return FxMeshes.face_mesh(face.mood, _eyes_closed, config)


func batched_face_transform() -> Transform3D:
	return _face_mesh.global_transform


func batched_blob_visible() -> bool:
	return body != null and FruitModels.blob_shadows()


## Ombre sur le fond du panier, décalée selon la lumière, à la taille du fruit.
func batched_blob_transform() -> Transform3D:
	var vc := FruitModels.get_config()
	var r := radius * scale.x
	var p := body.global_position
	return Transform3D(Basis.from_scale(Vector3.ONE * r * vc.blob_shadow_scale),
		Vector3(p.x + vc.blob_shadow_offset.x * r, p.y + vc.blob_shadow_offset.y * r, -0.97))


func _update_blob_visibility() -> void:
	var want := body != null and FruitModels.blob_shadows() and _batcher == null
	if want and _blob == null:
		_blob = MeshInstance3D.new()
		_blob.mesh = FruitModels.blob_mesh()
		_blob.top_level = true
		_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_blob)
	if _blob:
		_blob.visible = want


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


## Arrive d'en haut (`height` m) avec un petit rebond, en `duration` s.
func drop_in(height: float, duration: float) -> void:
	_drop_h = height
	_drop_time = maxf(duration, 0.01)
	_drop_t = 0.0
	_apply_transform()


## Tourne le regard vers un point monde pendant `duration` s.
func look_toward(world_pos: Vector3, duration: float) -> void:
	var d := Vector2(world_pos.x - global_position.x, world_pos.y - global_position.y)
	_look_target = d.normalized() if d.length() > 0.01 else Vector2.ZERO
	_look_left = duration


func look_amount() -> Vector2:
	return _look


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
	if _blob and _blob.visible and body:
		_blob.global_transform = batched_blob_transform()
	if _halo and _halo.visible:
		var vc := FruitModels.get_config()
		_halo.scale = Vector3.ONE * (1.0 + sin(_time * vc.halo_pulse_speed) * vc.halo_pulse_amplitude)
	if _squash_t < 1.0:
		_squash_t = minf(_squash_t + delta / config.impact_recover_time, 1.0)
	if _pop_t < 1.0:
		_pop_t = minf(_pop_t + delta / _pop_time, 1.0)
	if _drop_t < 1.0:
		_drop_t = minf(_drop_t + delta / _drop_time, 1.0)
	if _flash_t < 1.0:
		_flash_t = minf(_flash_t + delta / _flash_time, 1.0)
		_mesh.set_instance_shader_parameter(&"flash", 1.0 - _flash_t)

	var fruit := body as Fruit
	_trembling = false
	if fruit and not fruit.merging and not fruit.freeze:
		_trembling = fruit.age >= danger_grace_time and fruit.top_y() > danger_line_y
		face.set_above_line(_trembling)
	_look_left -= delta
	var look_to := _look_target if _look_left > 0.0 else Vector2.ZERO
	_look = _look.lerp(look_to, 1.0 - exp(-12.0 * delta))
	_face_mesh.position = Vector3(_look.x, _look.y, 0.0) * config.look_offset
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
	if _drop_t < 1.0:
		var off_y := _drop_h * (1.0 - _bounce_out(_drop_t))
		_anim.position += inv * Vector3(0, off_y, 0) / maxf(scale.x, 0.01)


## Chute avec rebonds (0 → 1).
static func _bounce_out(p: float) -> float:
	var n := 7.5625
	var d := 2.75
	if p < 1.0 / d:
		return n * p * p
	if p < 2.0 / d:
		p -= 1.5 / d
		return n * p * p + 0.75
	if p < 2.5 / d:
		p -= 2.25 / d
		return n * p * p + 0.9375
	p -= 2.625 / d
	return n * p * p + 0.984375


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
	if _face_mesh == null:
		return
	_eyes_closed = face.eyes_closed()
	_face_mesh.mesh = FxMeshes.face_mesh(face.mood, _eyes_closed, config)
