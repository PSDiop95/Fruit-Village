class_name Juice
extends Node
## Tous les retours visuels / sonores / haptiques (M2).
## N'écoute QUE les signaux de Game : aucune logique de jeu ici, et aucune
## logique d'effet dans Game, MergeSystem ou la physique.
## Tous les réglages : data/juice.tres. Effets poolés : zéro instanciation en jeu.

const FX_Z := 2.6  # plan des effets, devant les fruits et le panier

var config: JuiceConfig
var game: Game
var reduced: bool = false
## Baisse auto de qualité sur FPS faibles : seulement si le joueur est en « Auto ».
var auto_quality_allowed: bool = true
var show_fps: bool = false
var quality: int = JuiceConfig.Quality.HIGH

var time_scaler := TimeScaler.new()
var shake := TraumaShake.new()

var splash_pool: NodePool
var confetti_pool: NodePool
var leaves_pool: NodePool
var coins_pool: NodePool
var ring_pool: NodePool
var drop_pool: NodePool
var star_pool: NodePool
var flash_pool: NodePool
var text_pool: NodePool

var _fx_root: Node3D
var _camera: Camera3D
var _camera_base_size: float = 1.0
var _zoom_t: float = 1.0
var _last_merge_fruit: Fruit

# Projecteur (nouveau fruit)
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _beam_target: Fruit
var _beam_t: float = 1.0

# Moment Baobab
var _glow: MeshInstance3D
var _glow_mat: ShaderMaterial
var _tree: Node3D
var _trunk: MeshInstance3D
var _crown: Array[MeshInstance3D] = []
var _baobab_t: float = -1.0

# Danger
var _danger_ratio: float = 0.0
var _danger_state: DangerMonitor.State = DangerMonitor.State.SAFE
var _danger_smooth: float = 0.0
var _line_phase: float = 0.0
var _heartbeat_left: float = 0.0

# Game over
var _freeze_queue: Array[Fruit] = []
var _freeze_left: float = 0.0
var _over: bool = false

# Overlay 2D
var _overlay: CanvasLayer
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _big_text: ComboBanner
var _banner: PanelContainer
var _banner_label: Label
var _banner_tween: Tween
var _fps_label: Label
var _fps_refresh: float = 0.0
var _debug: DebugMenu

# Qualité auto
var _q_time: float = 0.0
var _q_frames: int = 0
var _q_warmup: float = 2.0


func bind(p_game: Game) -> void:
	game = p_game
	config = game.juice_config
	quality = config.quality
	reduced = bool(SaveManager.get_setting(&"reduced_effects"))
	show_fps = OS.is_debug_build() and config.show_fps_in_debug
	shake.configure(config)
	shake.enabled = not reduced
	process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = game.camera()
	_camera_base_size = _camera.size

	_fx_root = Node3D.new()
	_fx_root.name = "Fx"
	game.add_child(_fx_root)
	_build_pools()
	_build_beam()
	_build_baobab()
	_build_overlay()
	_debug = DebugMenu.new()
	add_child(_debug)
	_debug.bind(game, self)
	apply_particle_amounts()

	game.dropped.connect(_on_dropped)
	game.preview_shown.connect(_on_preview_shown)
	game.fruit_spawned.connect(_on_fruit_spawned)
	game.fruit_impact.connect(_on_fruit_impact)
	game.merged.connect(_on_merged)
	game.fruit_discovered.connect(_on_discovered)
	game.top_merge.connect(_on_top_merge)
	game.danger_changed.connect(_on_danger_changed)
	game.game_over.connect(_on_game_over)

	Audio.set_danger_filter(0.0)
	Audio.play_music(config.sounds.music if config.sounds else null)


func _exit_tree() -> void:
	# Garantie : quitter la partie (rejouer, menu) ne laisse jamais le temps ralenti.
	time_scaler.clear()
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- Construction

func _build_pools() -> void:
	var gpu := ParticleBurst.gpu_supported()
	var burst_factory := func(s: ParticleSettings) -> Callable:
		return func() -> ParticleBurst:
			var b := ParticleBurst.new()
			b.build(s, gpu)
			return b
	splash_pool = NodePool.new(_fx_root, burst_factory.call(config.splash), config.splash_pool_size)
	confetti_pool = NodePool.new(_fx_root, burst_factory.call(config.confetti), config.confetti_pool_size)
	leaves_pool = NodePool.new(_fx_root, burst_factory.call(config.leaves), 1)
	coins_pool = NodePool.new(_fx_root, burst_factory.call(config.coins), 1)
	drop_pool = NodePool.new(_fx_root, burst_factory.call(config.drops), config.drop_pool_size)
	star_pool = NodePool.new(_fx_root, burst_factory.call(config.stars), config.star_pool_size)
	flash_pool = NodePool.new(_fx_root, func() -> Node:
		var f := FxItems.Flash.new(config.flash_color)
		f.duration = config.flash_time
		f.max_scale = config.flash_scale
		return f, config.flash_pool_size)
	ring_pool = NodePool.new(_fx_root, func() -> Node:
		var r := FxItems.Ring.new(config.ring_color)
		r.duration = config.ring_time
		r.max_scale = config.ring_max_scale
		return r, config.ring_pool_size)
	text_pool = NodePool.new(_fx_root, func() -> Node:
		var t := FxItems.FloatText.new(config.float_text_font_size, config.float_text_color,
			config.float_text_outline_color)
		t.duration = config.float_text_time
		t.rise = config.float_text_rise
		return t, config.float_text_pool_size)


func _build_beam() -> void:
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 16
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beam.mesh = cyl
	_beam_mat = FxMeshes.additive_material(config.spotlight_color, 1)
	_beam.material_override = _beam_mat
	_beam.visible = false
	_fx_root.add_child(_beam)


func _build_baobab() -> void:
	var gc := game.config
	# Halo derrière les fruits : le panier « s'illumine ».
	_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(gc.basket_inner_width * 1.6, gc.basket_height * 1.4)
	_glow.mesh = q
	_glow_mat = FxMeshes.additive_material(config.basket_glow_color, 2)
	_glow.material_override = _glow_mat
	_glow.position = Vector3(0, gc.basket_height * 0.5, -0.9)
	_glow.visible = false
	_fx_root.add_child(_glow)

	# Baobab placeholder : tronc cylindre + couronne de sphères, en fond.
	_tree = Node3D.new()
	_tree.position = Vector3(0, gc.basket_height * 0.45, -3.0)
	_tree.visible = false
	_fx_root.add_child(_tree)
	_trunk = MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.7
	trunk_mesh.bottom_radius = 1.3
	trunk_mesh.height = 7.0
	trunk_mesh.radial_segments = 10
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color("8d6e63")
	trunk_mesh.material = trunk_mat
	_trunk.mesh = trunk_mesh
	_trunk.position = Vector3(0, 3.5, 0)
	var trunk_pivot := Node3D.new()
	trunk_pivot.name = "TrunkPivot"
	trunk_pivot.add_child(_trunk)
	_tree.add_child(trunk_pivot)
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = Color("558b2f")
	var spots := [Vector3(0, 7.6, 0), Vector3(-2.3, 6.9, 0.3), Vector3(2.3, 6.9, 0.3),
		Vector3(-1.3, 8.4, -0.3), Vector3(1.3, 8.4, -0.3), Vector3(-3.6, 6.3, -0.4),
		Vector3(3.6, 6.3, -0.4)]
	var sizes := [2.0, 1.5, 1.5, 1.4, 1.4, 1.0, 1.0]
	for i in spots.size():
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = sizes[i]
		sm.height = sizes[i] * 2.0
		sm.radial_segments = 12
		sm.rings = 6
		sm.material = crown_mat
		s.mesh = sm
		s.position = spots[i]
		_tree.add_child(s)
		_crown.append(s)


func _make_label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = 22
	ls.outline_color = Color.WHITE
	ls.shadow_size = 8
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(0, 6)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 5
	add_child(_overlay)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = preload("res://assets/shaders/vignette.gdshader")
	_vignette_mat.set_shader_parameter("tint", config.vignette_color)
	_vignette_mat.set_shader_parameter("intensity", 0.0)
	_vignette.material = _vignette_mat
	root.add_child(_vignette)

	_big_text = ComboBanner.new()
	_big_text.setup(config)
	# Centré horizontalement, au-dessus du milieu de l'écran de référence 1080x1920.
	_big_text.home = Vector2(0, 960 - 420 - ComboBanner.H * 0.5)
	root.add_child(_big_text)

	_banner = PanelContainer.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fff3df")
	sb.border_color = Color("e65100")
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(40)
	sb.set_content_margin_all(26)
	_banner.add_theme_stylebox_override("panel", sb)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -440
	_banner.offset_right = 440
	_banner.offset_top = -300
	_banner.offset_bottom = -140
	_banner.visible = false
	root.add_child(_banner)
	_banner_label = _make_label(config.discover_banner_font_size, Color("3b2314"))
	_banner.add_child(_banner_label)

	_fps_label = Label.new()
	_fps_label.position = Vector2(24, 1860)
	_fps_label.add_theme_font_size_override("font_size", 30)
	_fps_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 0.8))
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.visible = show_fps
	root.add_child(_fps_label)


# ---------------------------------------------------------------- Réglages

func set_reduced(v: bool) -> void:
	reduced = v
	shake.enabled = not v
	if v:
		shake.trauma = 0.0
	apply_particle_amounts()
	SaveManager.set_setting(&"reduced_effects", v)


func set_show_fps(v: bool) -> void:
	show_fps = v
	_fps_label.visible = v


func set_quality(level: int) -> void:
	quality = clampi(level, JuiceConfig.Quality.LOW, JuiceConfig.Quality.HIGH)
	apply_particle_amounts()


func particle_multiplier() -> float:
	return config.particle_multiplier(quality, reduced)


## Réalloue les gerbes à la bonne quantité (uniquement au changement de réglage).
func apply_particle_amounts() -> void:
	var k := particle_multiplier()
	for pool in [splash_pool, confetti_pool, leaves_pool, coins_pool, drop_pool, star_pool]:
		for b in pool.all():
			(b as ParticleBurst).set_amount_scale(k)


func pools() -> Array[NodePool]:
	return [splash_pool, confetti_pool, leaves_pool, coins_pool, ring_pool, text_pool,
		drop_pool, star_pool, flash_pool]


func active_fx_count() -> int:
	var n := 0
	for p in pools():
		n += p.active_count()
	return n


func vibrate(ms: int) -> void:
	if ms <= 0 or not SaveManager.get_setting(&"vibration_on"):
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func hit_stop() -> void:
	if not reduced:
		time_scaler.request(config.hitstop_time_scale, config.hitstop_time)


# ---------------------------------------------------------------- Signaux de Game

func _on_dropped(fruit: Fruit) -> void:
	Audio.play(config.sounds.drop, config.drop_volume_db, 1.0, config.pitch_jitter)
	vibrate(config.vibrate_drop_ms)
	if fruit:
		fruit.visual().pop(0.9, 1.0, 0.1)


func _on_preview_shown(_rank: int) -> void:
	game.preview_visual().pop(0.0, config.spawn_pop_overshoot, config.spawn_pop_time)


func _on_fruit_spawned(fruit: Fruit, from_merge: bool) -> void:
	if not from_merge:
		return
	_last_merge_fruit = fruit
	fruit.visual().pop(1.0, config.merge_pop_overshoot, config.merge_pop_time)
	fruit.visual().flash(config.merge_flash_time)


func _on_fruit_impact(_fruit: Fruit, speed: float) -> void:
	var k := clampf(inverse_lerp(config.impact_min_speed, config.impact_full_speed, speed), 0.0, 1.0)
	Audio.play_limited(&"impact", config.impact_max_per_second, config.sounds.impact,
		lerpf(config.impact_volume_min_db, config.impact_volume_max_db, k), 1.0, config.pitch_jitter)


func _on_merged(rank_created: int, pos: Vector3, points: int, combo: int) -> void:
	var top := rank_created < 0
	var shown_rank := game.catalog.max_rank() if top else rank_created
	var def := game.catalog.get_def(shown_rank)
	var fx_pos := Vector3(pos.x, pos.y, FX_Z)

	(flash_pool.acquire() as FxItems.Flash).start(fx_pos + Vector3(0, 0, -0.2), def.radius)
	(splash_pool.acquire() as ParticleBurst).burst(fx_pos, def.color)
	# Gouttes de jus et étoiles : doublées pour les gros fruits.
	var bursts := 2 if shown_rank >= config.big_burst_min_rank else 1
	for i in bursts:
		var off := Vector3(def.radius * 0.35 * (i * 2 - 1), 0, 0) if bursts > 1 else Vector3.ZERO
		(drop_pool.acquire() as ParticleBurst).burst(fx_pos + off, def.color.lightened(0.1))
		(star_pool.acquire() as ParticleBurst).burst(fx_pos + off)
	(ring_pool.acquire() as FxItems.Ring).start(fx_pos, def.radius, config.ring_color)
	var size_mult := 1.0 + 0.12 * minf(combo - 1, 4)
	var txt_color := config.float_text_color.lerp(def.color.lightened(0.25), config.float_text_tint)
	(text_pool.acquire() as FxItems.FloatText).start(fx_pos + Vector3(0, def.radius * 0.6, 0.1),
		"+%d" % points, txt_color, size_mult)
	if not top:
		Audio.play(config.sounds.note_for_rank(rank_created), config.merge_volume_db)
	vibrate(config.vibrate_merge_ms)

	if combo >= config.combo_min:
		_show_big_text("COMBO x%d !" % combo, config.combo_fill_bottom, config.combo_text_font_size, 0.6,
			combo - config.combo_min, config.combo_fill_top)
		for i in mini(combo - config.combo_min, 3) * config.combo_extra_star_bursts:
			(star_pool.acquire() as ParticleBurst).burst(fx_pos + Vector3(0, def.radius * 0.5 * i, 0))
		hit_stop()
		_zoom_t = 0.0
		Audio.play(config.sounds.combo_chord, config.combo_volume_db,
			pow(2.0, minf(combo - 2, 6) / 12.0))

	if not top and rank_created >= config.big_merge_min_rank:
		shake.add(config.big_merge_trauma)
		(confetti_pool.acquire() as ParticleBurst).burst(fx_pos + Vector3(0, 0.5, 0))
		vibrate(config.vibrate_big_merge_ms)


## Nouveau fruit JAMAIS atteint (toutes parties confondues).
func _on_discovered(rank: int) -> void:
	if rank <= SaveManager.best_rank:
		return
	var def := game.catalog.get_def(rank)
	time_scaler.request(config.discover_slowmo_scale, config.discover_slowmo_time)
	_show_banner("Nouveau : %s !" % def.display_name, def.color)
	Audio.play(config.sounds.discover, config.discover_volume_db)
	if _last_merge_fruit and is_instance_valid(_last_merge_fruit) and _last_merge_fruit.rank == rank:
		_beam_target = _last_merge_fruit
		_beam_t = 0.0
		_beam.visible = true
		_last_merge_fruit.visual().flash(config.spotlight_time * 0.6)


func _on_top_merge(pos: Vector3) -> void:
	time_scaler.request(config.baobab_slowmo_scale, config.baobab_slowmo_time)
	shake.add(config.baobab_trauma)
	vibrate(config.vibrate_baobab_ms)
	Audio.play(config.sounds.baobab, config.baobab_volume_db)
	_show_big_text("BAOBAB !", config.baobab_text_color, config.baobab_text_font_size, 1.6)
	var top_y := game.config.basket_height + 3.5
	(leaves_pool.acquire() as ParticleBurst).burst(Vector3(0, top_y, FX_Z))
	(coins_pool.acquire() as ParticleBurst).burst(Vector3(0, top_y, FX_Z))
	(confetti_pool.acquire() as ParticleBurst).burst(Vector3(pos.x, pos.y, FX_Z))
	_baobab_t = 0.0
	_tree.visible = true
	_glow.visible = true
	_update_baobab(0.0)


func _on_danger_changed(ratio: float, state: DangerMonitor.State) -> void:
	_danger_ratio = ratio
	_danger_state = state


func _on_game_over(_score: int, _max_rank: int, _is_record: bool) -> void:
	_over = true
	_danger_ratio = 0.0
	_danger_state = DangerMonitor.State.SAFE
	time_scaler.request(config.game_over_slowmo_scale, config.game_over_slowmo_time)
	Audio.play(config.sounds.game_over, config.game_over_volume_db)
	vibrate(config.vibrate_game_over_ms)
	# Les fruits se figent un par un, du haut vers le bas.
	_freeze_queue = game.all_fruits().filter(func(f: Fruit) -> bool:
		return is_instance_valid(f) and not f.merging)
	_freeze_queue.sort_custom(func(a: Fruit, b: Fruit) -> bool:
		return a.global_position.y > b.global_position.y)
	_freeze_left = 0.0


# ---------------------------------------------------------------- Boucle

func _process(delta: float) -> void:
	# Temps réel = delta non ralenti (compatible Movie Maker, à pas fixe).
	var real_dt := clampf(delta / maxf(Engine.time_scale, 0.0001), 0.0, 0.1)

	Engine.time_scale = time_scaler.update(minf(real_dt, config.time_scale_max_step))

	var off := shake.update(real_dt)
	_camera.h_offset = off.x
	_camera.v_offset = off.y
	if _zoom_t < 1.0:
		_zoom_t = minf(_zoom_t + real_dt / config.combo_zoom_time, 1.0)
		var z := config.combo_zoom if not reduced else config.combo_zoom * 0.5
		_camera.size = _camera_base_size * (1.0 - z * sin(PI * _zoom_t))

	for p in pools():
		p.tick(delta)

	_update_beam(real_dt)
	if _baobab_t >= 0.0:
		_update_baobab(real_dt)
	_update_danger(real_dt)
	_update_freeze(real_dt)
	_update_fps(real_dt)


func _update_beam(dt: float) -> void:
	if not _beam.visible:
		return
	_beam_t += dt / config.spotlight_time
	if _beam_t >= 1.0 or not is_instance_valid(_beam_target):
		_beam.visible = false
		return
	var p := _beam_target.global_position
	var top := game.config.spawn_y + 2.0
	var h := maxf(top - p.y, 0.5)
	_beam.position = Vector3(p.x, p.y + h * 0.5, FX_Z - 0.4)
	_beam.scale = Vector3(_beam_target.radius * 1.3, h, 0.01)
	var a := sin(PI * clampf(_beam_t, 0.0, 1.0))
	_beam_mat.set_shader_parameter("alpha", a)


func _update_baobab(dt: float) -> void:
	_baobab_t += dt
	var total := config.baobab_sequence_time
	var t := _baobab_t
	if t >= total:
		_baobab_t = -1.0
		_tree.visible = false
		_glow.visible = false
		return
	var grow := clampf(t / config.baobab_grow_time, 0.0, 1.0)
	var out := clampf((total - t) / 0.4, 0.0, 1.0)  # disparition sur les 0,4 dernières s
	var trunk_k := _ease_out_back(clampf(grow / 0.6, 0.0, 1.0)) * out
	(_tree.get_node("TrunkPivot") as Node3D).scale = Vector3(1.0, maxf(trunk_k, 0.001), 1.0)
	for i in _crown.size():
		var start := 0.45 + 0.07 * i
		var k := _ease_out_back(clampf((grow - start) / 0.3, 0.0, 1.0)) * out
		_crown[i].scale = Vector3.ONE * maxf(k, 0.001)
	var glow_a := clampf(t / 0.2, 0.0, 1.0) * out * (0.75 + 0.25 * sin(t * 12.0))
	_glow_mat.set_shader_parameter("alpha", glow_a)


func _update_danger(dt: float) -> void:
	var alert := _danger_state != DangerMonitor.State.SAFE and not _over
	var k := clampf(inverse_lerp(config.danger_alert_ratio, 1.0, _danger_ratio), 0.0, 1.0)
	var target := _danger_ratio if not _over else 0.0
	_danger_smooth = move_toward(_danger_smooth, target, dt * 2.0)
	Audio.set_danger_filter(_danger_smooth)

	var mat := game.danger_line_material()
	var vig := 0.0
	if alert:
		_line_phase += dt * lerpf(config.line_pulse_speed_min, config.line_pulse_speed_max, k)
		var pulse := absf(sin(_line_phase))
		mat.albedo_color.a = config.line_alpha_safe + (1.0 - config.line_alpha_safe) * pulse
		vig = config.vignette_max_alpha * (0.45 + 0.55 * k) * (0.7 + 0.3 * pulse)
		_heartbeat_left -= dt
		if _heartbeat_left <= 0.0:
			_heartbeat_left = lerpf(config.heartbeat_interval_max, config.heartbeat_interval_min, k)
			Audio.play(config.sounds.danger_heartbeat, config.heartbeat_volume_db)
	else:
		mat.albedo_color.a = config.line_alpha_safe
		_heartbeat_left = 0.0
	var cur: float = _vignette_mat.get_shader_parameter("intensity")
	_vignette_mat.set_shader_parameter("intensity", move_toward(cur, vig, dt * 3.0))


func _update_freeze(dt: float) -> void:
	if _freeze_queue.is_empty():
		return
	_freeze_left -= dt
	while _freeze_left <= 0.0 and not _freeze_queue.is_empty():
		var f: Fruit = _freeze_queue.pop_front()
		if is_instance_valid(f):
			f.freeze = true
			f.visual().set_gray(0.55)
			f.visual().pop(1.0, 1.08, 0.15)
		_freeze_left += config.game_over_freeze_interval


func _update_fps(real_dt: float) -> void:
	if config.auto_quality and auto_quality_allowed and quality > JuiceConfig.Quality.LOW:
		_q_warmup -= real_dt
		if _q_warmup <= 0.0:
			_q_time += real_dt
			_q_frames += 1
			if _q_time >= config.auto_quality_window:
				if _q_frames / _q_time < config.auto_quality_min_fps:
					game.set_quality(quality - 1)
				_q_time = 0.0
				_q_frames = 0
	if not show_fps:
		return
	_fps_refresh -= real_dt
	if _fps_refresh > 0.0:
		return
	_fps_refresh = 0.25
	_fps_label.text = "FPS %d | fruits %d | fx %d | qualité %s%s | x%.2f" % [
		Engine.get_frames_per_second(), game.fruits().size(), active_fx_count(),
		["Bas", "Moyen", "Haut"][quality], " (réduits)" if reduced else "", Engine.time_scale]


# ---------------------------------------------------------------- UI animée

## Bannière animée. `level` : niveau de combo au-delà du minimum (0 = premier).
## `color` = bas du dégradé (le haut est sa version claire).
func _show_big_text(txt: String, color: Color, font_size: int, hold: float = 0.6, level: int = 0,
		top: Color = Color(0, 0, 0, 0)) -> void:
	var t := top if top.a > 0.0 else color.lightened(0.55)
	_big_text.play(txt, font_size, level, maxf(config.combo_text_time - 0.55, 0.0) + hold * 0.5, t, color)


func _show_banner(txt: String, color: Color) -> void:
	_banner_label.text = txt
	(_banner.get_theme_stylebox("panel") as StyleBoxFlat).border_color = color.darkened(0.2)
	if _banner_tween:
		_banner_tween.kill()
	_banner.visible = true
	_banner.offset_top = -300
	_banner.offset_bottom = -140
	_banner_tween = create_tween().set_ignore_time_scale(true)
	_banner_tween.set_parallel()
	_banner_tween.tween_property(_banner, "offset_top", 340.0, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner, "offset_bottom", 500.0, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.chain().tween_interval(config.discover_banner_time)
	_banner_tween.chain().tween_property(_banner, "offset_top", -300.0, 0.25)
	_banner_tween.parallel().tween_property(_banner, "offset_bottom", -140.0, 0.25)
	_banner_tween.chain().tween_callback(func() -> void: _banner.visible = false)


static func _ease_out_back(p: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(p - 1.0, 3.0) + c1 * pow(p - 1.0, 2.0)
