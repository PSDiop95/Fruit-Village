class_name Fruit
extends RigidBody3D
## Un fruit physique. Mouvement verrouillé sur le plan X/Y (2,5D).
## Le rendu (sphère, visage, squash & stretch) est délégué à FruitVisual.

signal touched(fruit: Fruit, other: Fruit)
## Choc détecté (variation brusque de vitesse, m/s). Aucun effet ici : Juice écoute.
signal impacted(fruit: Fruit, speed: float)

var rank: int = 0
var radius: float = 0.3
var merging: bool = false
## Secondes depuis l'apparition (pour la tolérance de la ligne de danger).
var age: float = 0.0

var _shape: SphereShape3D
var _visual: FruitVisual
var _prev_velocity := Vector3.ZERO
var _impact_min_speed: float = INF
var _impact_cooldown_time: float = 0.08
var _impact_cooldown: float = 0.0


func setup(p_rank: int, def: FruitDef, config: GameConfig, juice: JuiceConfig) -> void:
	rank = p_rank
	radius = def.radius
	name = "Fruit_%s_%d" % [def.id, get_instance_id()]

	# Physique : plan X/Y, seule la rotation Z est libre (roulé).
	axis_lock_linear_z = true
	axis_lock_angular_x = true
	axis_lock_angular_y = true
	gravity_scale = config.gravity_scale
	linear_damp = config.linear_damp
	angular_damp = config.angular_damp
	mass = maxf(config.mass_per_area * radius * radius, 0.01)
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = config.max_contacts
	var mat := PhysicsMaterial.new()
	mat.bounce = config.bounce
	mat.friction = config.friction
	physics_material_override = mat

	# Collision : forme propre à chaque fruit pour pouvoir la faire grandir.
	_shape = SphereShape3D.new()
	_shape.radius = radius
	var col := CollisionShape3D.new()
	col.shape = _shape
	add_child(col)

	# Visuel (placeholder M2 : sphère + visage)
	_impact_min_speed = juice.impact_min_speed
	_impact_cooldown_time = juice.impact_cooldown
	_visual = FruitVisual.new()
	_visual.body = self
	_visual.danger_line_y = config.danger_line_y
	_visual.danger_grace_time = config.danger_grace_time
	_visual.setup(juice, get_instance_id())
	_visual.apply_def(p_rank, def)
	add_child(_visual)
	impacted.connect(func(_f: Fruit, speed: float) -> void: _visual.on_impact(speed))

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	age += delta
	if freeze or merging:
		return
	# Choc = variation de vitesse bien supérieure à celle de la gravité sur un pas.
	_impact_cooldown -= delta
	var dv := (linear_velocity - _prev_velocity).length()
	if age > 0.05 and dv >= _impact_min_speed and _impact_cooldown <= 0.0:
		_impact_cooldown = _impact_cooldown_time
		impacted.emit(self, dv)
	_prev_velocity = linear_velocity


func visual() -> FruitVisual:
	return _visual


## Fusion : le fruit ne collisionne plus, ferme les yeux de joie et
## s'aspire vers `point` en `duration` s, puis disparaît.
func vanish_toward(point: Vector3, duration: float) -> void:
	merging = true
	collision_layer = 0
	collision_mask = 0
	contact_monitor = false
	freeze = true
	_visual.set_joy()
	if duration <= 0.0:
		queue_free()
		return
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position", point, duration)
	tw.tween_property(_visual, "scale", _visual.scale * 0.6, duration)
	tw.chain().tween_callback(queue_free)


## Facteur de taille appliqué au visuel ET à la collision.
func set_size_factor(f: float) -> void:
	_shape.radius = radius * f
	_visual.scale = Vector3.ONE * f


func size_factor() -> float:
	return _shape.radius / radius


## Apparition après fusion : grossit de `start` à 1 en `duration` s.
func grow_in(start: float, duration: float) -> void:
	set_size_factor(start)
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(set_size_factor, start, 1.0, duration)


## Haut du fruit (y monde).
func top_y() -> float:
	return global_position.y + _shape.radius


## Fusion possible avec `other` ?
func can_merge_with(other: Node) -> bool:
	return other is Fruit and other != self and not merging \
		and not other.merging and other.rank == rank


func _on_body_entered(body: Node) -> void:
	if can_merge_with(body):
		touched.emit(self, body)
