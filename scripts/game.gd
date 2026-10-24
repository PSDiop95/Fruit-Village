class_name Game
extends Node3D
## Scène de jeu : panier, visée, lâcher, fusions, score, combos, game over.
## Habillage M3 : MarketScene (panier calebasse, étal, décor, lumière). La
## collision du panier reste les boîtes M1 construites ici.
## Aucun effet ici : Juice (M2) écoute les signaux ci-dessous.

signal score_changed(score: int)
signal merged(rank_created: int, position: Vector3, points: int, combo: int)
signal fruit_discovered(rank: int)
signal top_merge(position: Vector3)
signal game_over(score: int, max_rank: int, is_record: bool)
signal dropped(fruit: Fruit)
signal fruit_spawned(fruit: Fruit, from_merge: bool)
signal fruit_impact(fruit: Fruit, speed: float)
## Le fruit à lâcher réapparaît en haut (fin du cooldown).
signal preview_shown(rank: int)
signal danger_changed(ratio: float, state: DangerMonitor.State)
## Rejouer / retour au titre : gérés par Main s'il écoute, sinon rechargement.
signal restart_requested
signal menu_requested
## M4 : fruit retiré sans fusion (pilon, « Continuer »). `reason` : &"pestle", &"continue".
signal fruit_removed(fruit: Fruit, reason: StringName)
## M4 : la partie reprend après « Continuer ».
signal revived
## M4 : power-up « Secouer » appliqué.
signal basket_shaken

const FRUIT_SCRIPT := preload("res://scripts/fruit.gd")

@export var catalog: FruitCatalog = preload("res://data/fruits.tres")
@export var config: GameConfig = preload("res://data/game_config.tres")
@export var juice_config: JuiceConfig = preload("res://data/juice.tres")
@export var visual_config: VisualConfig = preload("res://data/visual.tres")
## false : aucun effet (bancs de perf comparatifs).
@export var juice_enabled: bool = true
## 0 = graine aléatoire. Valeur fixe = partie reproductible (tests, défi du jour).
@export var seed_value: int = 0

var score: int = 0
var max_rank_reached: int = 0
var is_over: bool = false
## M4 : « Continuer » déjà utilisés dans cette partie.
var continues_used: int = 0

var spawner := Spawner.new()
var merge_system := MergeSystem.new()
var combo := ComboTracker.new()
var danger := DangerMonitor.new()
## M4 : méta (pièces, XP, missions, album, analytics) et power-ups.
var meta: GameMeta
var powerups: PowerupController
## Aléatoire des power-ups (secousse, échange), dérivé de la graine de partie.
var _power_rng := RandomNumberGenerator.new()
var _game_counted: bool = false

var _fruits_root: Node3D
## Fruits vivants (registre : évite de rescanner les enfants à chaque frame).
var _fruits: Array[Fruit] = []
var _camera: Camera3D
var _preview: FruitVisual
var _preview_was_visible: bool = false
var _guide: MeshInstance3D
var _danger_line: MeshInstance3D
var _danger_mat: StandardMaterial3D
var _aim_x: float = 0.0
var _cooldown: float = 0.0
var _time: float = 0.0
var _hud: GameHud
var _juice: Juice
var _market: MarketScene
var _mascot: Mascot
var _batcher: FruitBatcher
var _last_danger_ratio: float = -1.0
var _last_danger_state: DangerMonitor.State = DangerMonitor.State.SAFE


func _ready() -> void:
	var s := seed_value if seed_value != 0 else int(Time.get_unix_time_from_system() * 1000.0)
	spawner.setup(catalog.droppable_ranks(), s, config.preview_count,
		catalog.droppable_weights())
	_power_rng.seed = hash([s, "powerups"])
	combo.configure(config.combo_window, config.combo_max_multiplier)
	danger.configure(config.danger_warn_time, config.danger_game_over_time)
	FruitModels.warm_up(catalog)

	_build_environment()
	_build_basket()
	_fruits_root = Node3D.new()
	_fruits_root.name = "Fruits"
	add_child(_fruits_root)
	_batcher = FruitBatcher.new()
	add_child(_batcher)
	_build_preview()

	meta = GameMeta.new()
	meta.name = "Meta"
	add_child(meta)
	powerups = PowerupController.new()
	powerups.name = "Powerups"
	add_child(powerups)
	powerups.bind(self)
	meta.bind(self)

	_hud = GameHud.new()
	add_child(_hud)
	_hud.bind(self)
	if juice_enabled:
		_juice = Juice.new()
		_juice.name = "Juice"
		add_child(_juice)
		_juice.bind(self)
		_mascot = Mascot.create(visual_config, juice_config)
		if _mascot:
			add_child(_mascot)
			_mascot.bind(self)
	_hud.menu_requested.connect(go_to_menu)
	var q_setting := int(SaveManager.get_setting(&"quality"))
	if _juice:
		_juice.auto_quality_allowed = q_setting == VisualQuality.AUTO
	set_quality(VisualQuality.resolve(q_setting))
	SaveManager.setting_changed.connect(_on_setting_changed)
	_refresh_preview()
	if PerfProbe.enabled():
		var probe := PerfProbe.new()
		add_child(probe)
		probe.run(self)


# ---------------------------------------------------------------- Construction

func _build_environment() -> void:
	# Lumière, panier calebasse, étal et décor : purement visuel (M3).
	_market = MarketScene.new()
	add_child(_market)
	_market.setup(visual_config, config)
	_market.follow_ambiance_setting()

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = config.basket_inner_width + config.wall_thickness * 2.0 		+ config.camera_side_margin
	_camera.position = Vector3(0, camera_center_y(config, _viewport_aspect()), 20)
	_camera.current = true
	add_child(_camera)


func _build_basket() -> void:
	var body := StaticBody3D.new()
	body.name = "Basket"
	var mat := PhysicsMaterial.new()
	mat.friction = config.friction
	mat.bounce = 0.0
	body.physics_material_override = mat
	add_child(body)

	var w := config.basket_inner_width
	var h := config.basket_height
	var t := config.wall_thickness
	var color := Color("a0522d")
	# Collision M1 inchangée. Boîtes visibles seulement sans modèle de panier.
	var placeholder := _market == null or not _market.has_basket()
	# sol
	_add_box(body, Vector3(w + t * 2.0, t, 2.0), Vector3(0, -t * 0.5, 0), color, placeholder)
	# murs
	_add_box(body, Vector3(t, h, 2.0), Vector3(-(w + t) * 0.5, h * 0.5, 0), color, placeholder)
	_add_box(body, Vector3(t, h, 2.0), Vector3((w + t) * 0.5, h * 0.5, 0), color, placeholder)
	if placeholder:
		# fond (visuel seulement)
		var back := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, 0.1)
		var back_mat := StandardMaterial3D.new()
		back_mat.albedo_color = Color("e9c48a")
		bm.material = back_mat
		back.mesh = bm
		back.position = Vector3(0, h * 0.5, -1.0)
		add_child(back)

	# Ligne de danger : cordelette rouge tendue entre les bords + lueur pulsée (Juice).
	_build_danger_cord(w)
	_danger_line = MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = visual_config.danger_cord_radius * 2.2
	lm.bottom_radius = lm.top_radius
	lm.height = w
	lm.radial_segments = 8
	lm.rings = 1
	_danger_mat = StandardMaterial3D.new()
	_danger_mat.albedo_color = Color(0.9, 0.1, 0.1, juice_config.line_alpha_safe)
	_danger_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_danger_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.material = _danger_mat
	_danger_line.mesh = lm
	_danger_line.rotation.z = PI * 0.5
	_danger_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_danger_line.position = Vector3(0, config.danger_line_y, 0.9)
	add_child(_danger_line)


## Cordelette (visuel) : corde rouge + nœuds aux deux bords du panier.
func _build_danger_cord(w: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = visual_config.danger_cord_color
	mat.roughness = 1.0
	var rope := MeshInstance3D.new()
	rope.name = "DangerCord"
	var cm := CylinderMesh.new()
	cm.top_radius = visual_config.danger_cord_radius
	cm.bottom_radius = cm.top_radius
	cm.height = w
	cm.radial_segments = 6
	cm.rings = 1
	cm.material = mat
	rope.mesh = cm
	rope.rotation.z = PI * 0.5
	rope.position = Vector3(0, config.danger_line_y, 0.95)
	add_child(rope)
	for side in [-1.0, 1.0]:
		var knot := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = visual_config.danger_cord_radius * 2.4
		sm.height = sm.radius * 2.0
		sm.radial_segments = 8
		sm.rings = 4
		sm.material = mat
		knot.mesh = sm
		knot.position = Vector3(side * w * 0.5, config.danger_line_y, 0.95)
		add_child(knot)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, visible_mesh := true) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = pos
	parent.add_child(col)
	if not visible_mesh:
		return
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	bm.material = m
	mesh.mesh = bm
	mesh.position = pos
	parent.add_child(mesh)


func _build_preview() -> void:
	_preview = FruitVisual.new()
	_preview.name = "Preview"
	_preview.setup(juice_config, 1)
	add_child(_preview)
	_guide = MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.03, 1.0, 0.03)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.material = mat
	_guide.mesh = gm
	add_child(_guide)


func _refresh_preview() -> void:
	var rank := spawner.current()
	var def := catalog.get_def(rank)
	_preview.apply_def(rank, def)
	_preview.visible = _cooldown <= 0.0 and not is_over
	_aim_x = _clamp_x(_aim_x, def.radius)
	_preview.position = Vector3(_aim_x, config.spawn_y, 0)
	var guide_h := config.spawn_y - def.radius
	_guide.scale = Vector3(1, guide_h, 1)
	_guide.position = Vector3(_aim_x, guide_h * 0.5, 0)
	_guide.visible = _preview.visible
	if _preview.visible and not _preview_was_visible:
		preview_shown.emit(rank)
	_preview_was_visible = _preview.visible
	if _hud:
		var next_rank: int = spawner.upcoming()[0]
		_hud.set_next(next_rank, catalog.get_def(next_rank))


# ---------------------------------------------------------------- Entrées

func _unhandled_input(event: InputEvent) -> void:
	if is_over:
		return
	# Doigt glissé (souris émulée) ou survol desktop : on vise.
	if event is InputEventMouseMotion:
		_aim_at(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_aim_at(event.position)
		if not event.pressed:
			drop()


func _aim_at(screen_pos: Vector2) -> void:
	var world := _camera.project_position(screen_pos, _camera.position.z)
	_aim_x = _clamp_x(world.x, catalog.get_def(spawner.current()).radius)
	_preview.position.x = _aim_x
	_guide.position.x = _aim_x


## Position x visée (m), pour les regards de la mascotte.
func aim_x() -> float:
	return _aim_x


func mascot() -> Mascot:
	return _mascot


func _clamp_x(x: float, r: float) -> float:
	var half := config.basket_inner_width * 0.5 - r - 0.01
	return clampf(x, -half, half)


## Lâche le fruit courant à la position visée (ou `at_x` si fourni).
func drop(at_x: float = NAN) -> Fruit:
	if is_over or _cooldown > 0.0:
		return null
	if not is_nan(at_x):
		_aim_x = _clamp_x(at_x, catalog.get_def(spawner.current()).radius)
	var rank := spawner.take()
	if config.combo_reset_on_drop:
		combo.reset()
	max_rank_reached = maxi(max_rank_reached, rank)
	var fruit := _spawn_fruit(rank, Vector3(_aim_x, config.spawn_y, 0))
	_cooldown = config.drop_cooldown
	_refresh_preview()
	dropped.emit(fruit)
	return fruit


# ---------------------------------------------------------------- Fruits

## Fait apparaître un fruit (debug, tests, captures). N'affecte pas le score.
func spawn_fruit(rank: int, pos: Vector3) -> Fruit:
	return _spawn_fruit(rank, pos)


func _spawn_fruit(rank: int, pos: Vector3, from_merge := false) -> Fruit:
	var f: Fruit = FRUIT_SCRIPT.new()
	f.setup(rank, catalog.get_def(rank), config, juice_config)
	f.visual().use_batcher(_batcher)
	f.position = pos
	f.touched.connect(_on_fruit_touched)
	f.impacted.connect(func(fr: Fruit, speed: float) -> void: fruit_impact.emit(fr, speed))
	f.tree_exiting.connect(_on_fruit_exiting.bind(f))
	_fruits_root.add_child(f)
	_fruits.append(f)
	fruit_spawned.emit(f, from_merge)
	return f


func _on_fruit_exiting(f: Fruit) -> void:
	_fruits.erase(f)


func _on_fruit_touched(a: Fruit, b: Fruit) -> void:
	merge_system.request(a.get_instance_id(), b.get_instance_id())


func fruits() -> Array[Fruit]:
	var out: Array[Fruit] = []
	for f in _fruits:
		if not f.merging:
			out.append(f)
	return out


func _physics_process(delta: float) -> void:
	_time += delta
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_refresh_preview()
	if is_over:
		return
	_rescan_contacts()
	_process_merges()
	_check_danger(delta)


## Filet de sécurité : body_entered ne se déclenche qu'au premier contact.
func _rescan_contacts() -> void:
	for f in _fruits:
		if f.merging or merge_system.is_engaged(f.get_instance_id()):
			continue
		for b in f.get_colliding_bodies():
			if f.can_merge_with(b) 					and merge_system.request(f.get_instance_id(), b.get_instance_id()):
				break


func _process_merges() -> void:
	for pair in merge_system.flush():
		var a := instance_from_id(pair[0]) as Fruit
		var b := instance_from_id(pair[1]) as Fruit
		if a == null or b == null or not a.can_merge_with(b):
			continue
		_merge(a, b)


func _merge(a: Fruit, b: Fruit) -> void:
	a.merging = true
	b.merging = true
	var rank := a.rank
	var pos := (a.global_position + b.global_position) * 0.5
	pos.z = 0.0
	var vel := (a.linear_velocity + b.linear_velocity) * 0.5
	# Plus de collision immédiatement ; l'aspiration visuelle dure merge_suck_time.
	var suck := juice_config.merge_suck_time if juice_enabled else 0.0
	a.vanish_toward(pos, suck)
	b.vanish_toward(pos, suck)

	var mult := combo.register(_time)
	var pts := catalog.merge_points(rank) * mult
	score += pts
	score_changed.emit(score)

	if catalog.is_top(rank):
		top_merge.emit(pos)
		merged.emit(-1, pos, pts, mult)
		return

	var new_rank := rank + 1
	var nf := _spawn_fruit(new_rank, pos, true)
	nf.linear_velocity = vel
	nf.grow_in(config.merge_grow_start_scale, config.merge_grow_time)
	nf.apply_central_impulse(Vector3.UP * config.merge_up_impulse * nf.mass)
	if new_rank > max_rank_reached:
		max_rank_reached = new_rank
		fruit_discovered.emit(new_rank)
	merged.emit(new_rank, pos, pts, mult)


# ---------------------------------------------------------------- Danger

func _check_danger(delta: float) -> void:
	var above: Array[int] = []
	for f in _fruits:
		if f.merging or f.age < config.danger_grace_time:
			continue
		if f.top_y() > config.danger_line_y:
			above.append(f.get_instance_id())
	var state := danger.update(above, delta)
	var ratio := danger.max_ratio()
	if not is_equal_approx(ratio, _last_danger_ratio) or state != _last_danger_state:
		_last_danger_ratio = ratio
		_last_danger_state = state
		danger_changed.emit(ratio, state)
	if _hud:
		_hud.set_danger(ratio)
	if state == DangerMonitor.State.GAME_OVER:
		_end_game()


func _end_game() -> void:
	is_over = true
	_preview.visible = false
	_guide.visible = false
	if powerups:
		powerups.cancel_aim()
	# Avec Juice, les fruits se figent un par un (séquence de fin) ; sinon tout de suite.
	if _juice == null:
		for f in _fruits:
			f.freeze = true
	# Après « Continuer », la même partie n'est pas comptée deux fois.
	var is_record := SaveManager.record_game(score, max_rank_reached, not _game_counted)
	_game_counted = true
	game_over.emit(score, max_rank_reached, is_record)


# ---------------------------------------------------------------- M4 : retraits, Continuer, power-ups

## Retrait propre d'un fruit hors fusion (pilon, Continuer) : le fruit est
## marqué `merging` (plus aucune fusion possible), sort de la physique et
## disparaît par le même chemin qu'une fusion. Juice joue l'éclaboussure.
func remove_fruit(f: Fruit, reason: StringName) -> bool:
	if f == null or not is_instance_valid(f) or f.merging:
		return false
	var suck := juice_config.merge_suck_time if juice_enabled else 0.0
	fruit_removed.emit(f, reason)
	f.vanish_toward(f.global_position, suck)
	return true


## Les `count` fruits dont le haut est le plus élevé.
func top_fruits(count: int) -> Array[Fruit]:
	var list := fruits()
	list.sort_custom(func(a: Fruit, b: Fruit) -> bool: return a.top_y() > b.top_y())
	return list.slice(0, count)


## « Continuer » (rewarded) : retire les fruits les plus hauts et relance la
## partie. Une seule fois par partie (ads.tres).
func continue_game(remove_count: int, max_per_game: int) -> bool:
	if not is_over or continues_used >= max_per_game:
		return false
	continues_used += 1
	for f in top_fruits(remove_count):
		remove_fruit(f, &"continue")
	revive()
	return true


func revive() -> void:
	is_over = false
	danger.reset()
	_last_danger_ratio = -1.0
	for f in _fruits:
		if not f.merging:
			f.freeze = false
			f.age = 0.0
			f.visual().set_gray(0.0)
	_cooldown = 0.0
	_refresh_preview()
	revived.emit()


## Fruit sous un point de l'écran (pilon), ou null.
func fruit_at_screen(screen_pos: Vector2) -> Fruit:
	var world := _camera.project_position(screen_pos, _camera.position.z)
	var p := Vector2(world.x, world.y)
	var best: Fruit = null
	var best_d := INF
	for f in fruits():
		var d := p.distance_to(Vector2(f.global_position.x, f.global_position.y))
		if d <= f.radius * 1.15 and d < best_d:
			best = f
			best_d = d
	return best


## Secouer : impulsion aléatoire contrôlée (graine de partie) à chaque fruit.
## Les fusions qui en résultent passent par le MergeSystem habituel.
func shake_basket(horizontal: float, vertical: float) -> void:
	for f in fruits():
		f.freeze = false
		f.sleeping = false
		var v := Vector3(_power_rng.randf_range(-horizontal, horizontal),
			vertical * _power_rng.randf_range(0.6, 1.0), 0.0)
		f.apply_central_impulse(v * f.mass)
	basket_shaken.emit()


## Échange : remplace le fruit à lâcher par un autre fruit lâchable.
func swap_current() -> void:
	var ranks := catalog.droppable_ranks().filter(func(r: int) -> bool: return r != spawner.current())
	if ranks.is_empty():
		return
	spawner.replace_current(ranks[_power_rng.randi_range(0, ranks.size() - 1)])
	_refresh_preview()


## Agrandir : le fruit à lâcher monte d'un rang, plafonné à `max_rank`.
func grow_current(max_rank: int) -> bool:
	var r := spawner.current()
	if r >= max_rank:
		return false
	spawner.replace_current(mini(r + 1, max_rank))
	_refresh_preview()
	return true


# ---------------------------------------------------------------- Accès (Juice, debug)

func camera() -> Camera3D:
	return _camera


func preview_visual() -> FruitVisual:
	return _preview


func danger_line_material() -> StandardMaterial3D:
	return _danger_mat


## Tous les fruits vivants, y compris ceux en cours de fusion.
func all_fruits() -> Array[Fruit]:
	return _fruits


func juice() -> Juice:
	return _juice


## Centre vertical de la caméra. Cadrage de référence 9:16 ; sur un écran plus
## allongé, le bas reste calé (panier + étal) et la hauteur en plus va au ciel.
## M4 : la hauteur en plus va d'abord à une bande en bas (barre de power-ups,
## bottom_ui_band_px), puis au ciel.
static func camera_center_y(cfg: GameConfig, aspect_hw: float) -> float:
	var w := cfg.basket_inner_width + cfg.wall_thickness * 2.0 + cfg.camera_side_margin
	var ref_center := cfg.basket_height * 0.5 + cfg.camera_y_offset
	var bottom := ref_center - w * 16.0 / 9.0 * 0.5
	return bottom - bottom_band_world(cfg, aspect_hw) + w * maxf(aspect_hw, 16.0 / 9.0) * 0.5


## Hauteur (m) de la bande du bas réservée à l'UI : 0 en 16:9, au plus
## bottom_ui_band_px (canevas 1080 de large) sur les écrans plus allongés.
static func bottom_band_world(cfg: GameConfig, aspect_hw: float) -> float:
	var w := cfg.basket_inner_width + cfg.wall_thickness * 2.0 + cfg.camera_side_margin
	var extra := w * maxf(aspect_hw - 16.0 / 9.0, 0.0)
	return minf(extra, cfg.bottom_ui_band_px * w / 1080.0)


func _viewport_aspect() -> float:
	var s := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(9, 16)
	return s.y / maxf(s.x, 1.0)


func market() -> MarketScene:
	return _market


## Qualité visuelle (Bas/Moyen/Haut) : matériaux, contour, ombres, particules.
func set_quality(level: int) -> void:
	FruitModels.set_quality(level)
	if is_inside_tree():
		VisualQuality.apply_viewport(get_viewport(), level, visual_config)
	if _market:
		_market.apply_quality(level)
	if _mascot:
		_mascot.apply_quality(level)
	for f in _fruits:
		f.visual().refresh_material()
	_preview.refresh_material()
	if _juice:
		_juice.set_quality(level)


func restart() -> void:
	get_tree().paused = false
	if meta:
		meta.finalize(&"restart")
	if restart_requested.get_connections().is_empty():
		get_tree().reload_current_scene()
	else:
		restart_requested.emit()


func go_to_menu() -> void:
	get_tree().paused = false
	if meta:
		meta.finalize(&"quit")
	if menu_requested.get_connections().is_empty():
		get_tree().reload_current_scene()
	else:
		menu_requested.emit()


func hud() -> GameHud:
	return _hud


func _on_setting_changed(key: StringName, value: Variant) -> void:
	if key == &"reduced_effects" and _juice and _juice.reduced != bool(value):
		_juice.set_reduced(bool(value))
	elif key == &"quality" and _juice:
		_juice.auto_quality_allowed = int(value) == VisualQuality.AUTO
