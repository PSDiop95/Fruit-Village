extends GutTest
## Tests M2 « Juice » : visages, notes, pools, effets réduits, hit-stop.

const GameScene := preload("res://scenes/Game.tscn")
const TEST_SAVE := "user://test_save_juice.json"

var cfg: JuiceConfig = load("res://data/juice.tres")
var catalog: FruitCatalog = load("res://data/fruits.tres")


func before_all() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	SaveManager.use_path(TEST_SAVE)


func after_all() -> void:
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(TEST_SAVE)
	SaveManager.use_path(SaveManager.DEFAULT_SAVE_PATH)


func after_each() -> void:
	Engine.time_scale = 1.0


func _new_game() -> Game:
	var g: Game = GameScene.instantiate()
	g.seed_value = 4242
	add_child_autofree(g)
	await wait_physics_frames(2)
	return g


# ---------------------------------------------------------------- FruitFace

func _face() -> FruitFace:
	var f := FruitFace.new()
	f.configure(cfg, 1)
	return f


func test_face_starts_neutral() -> void:
	assert_eq(_face().mood, FruitFace.Mood.NEUTRAL)


func test_face_strong_impact_squashed_then_neutral() -> void:
	var f := _face()
	f.impact(cfg.face_squashed_min_speed + 1.0)
	assert_eq(f.mood, FruitFace.Mood.SQUASHED, "impact fort → grimace")
	f.update(cfg.face_squashed_time * 0.5)
	assert_eq(f.mood, FruitFace.Mood.SQUASHED, "grimace maintenue")
	f.update(cfg.face_squashed_time * 0.6)
	assert_eq(f.mood, FruitFace.Mood.NEUTRAL, "retour au sourire après 0,3 s")


func test_face_weak_impact_stays_neutral() -> void:
	var f := _face()
	f.impact(cfg.face_squashed_min_speed * 0.5)
	assert_eq(f.mood, FruitFace.Mood.NEUTRAL)


func test_face_above_line_fear_and_back() -> void:
	var f := _face()
	f.set_above_line(true)
	assert_eq(f.mood, FruitFace.Mood.FEAR, "au-dessus de la ligne → peur")
	f.set_above_line(false)
	assert_eq(f.mood, FruitFace.Mood.NEUTRAL)


func test_face_squash_over_fear_then_fear() -> void:
	var f := _face()
	f.set_above_line(true)
	f.impact(cfg.face_squashed_min_speed + 1.0)
	assert_eq(f.mood, FruitFace.Mood.SQUASHED, "l'écrasement prime sur la peur")
	f.update(cfg.face_squashed_time + 0.01)
	assert_eq(f.mood, FruitFace.Mood.FEAR, "puis la peur revient")


func test_face_joy_is_final_and_closes_eyes() -> void:
	var f := _face()
	f.set_joy()
	f.impact(100.0)
	f.set_above_line(true)
	assert_eq(f.mood, FruitFace.Mood.JOY)
	assert_true(f.eyes_closed(), "yeux fermés de joie")


func test_face_blinks_between_2_and_6_seconds() -> void:
	var f := _face()
	var t := 0.0
	var first_blink := -1.0
	while t < cfg.blink_max_interval + 0.5:
		f.update(0.01)
		t += 0.01
		if f.is_blinking():
			first_blink = t
			break
	assert_between(first_blink, cfg.blink_min_interval, cfg.blink_max_interval + 0.02,
		"premier clignement dans [2 ; 6] s")
	f.update(cfg.blink_duration + 0.01)
	assert_false(f.is_blinking(), "clignement bref")


func test_face_emits_signal_on_change() -> void:
	var f := _face()
	watch_signals(f)
	f.set_above_line(true)
	f.set_above_line(true)
	assert_signal_emit_count(f, "mood_changed", 1)


# ---------------------------------------------------------------- Notes

## Fréquence fondamentale estimée par autocorrélation (wav PCM 16 bits mono).
func _estimate_hz(path: String) -> float:
	var bytes := FileAccess.get_file_as_bytes(path)
	assert_gt(bytes.size(), 44, "wav lisible : %s" % path)
	var sr := bytes.decode_u32(24)
	var n := mini(4096, (bytes.size() - 44) / 2)
	var x := PackedFloat32Array()
	x.resize(n)
	for i in n:
		x[i] = bytes.decode_s16(44 + i * 2) / 32768.0
	var best_lag := 0
	var best := -INF
	var min_lag := int(sr / 2000.0)
	var max_lag := int(sr / 60.0)
	for lag in range(min_lag, max_lag):
		var acc := 0.0
		for i in range(0, n - lag, 2):
			acc += x[i] * x[i + lag]
		if acc > best:
			best = acc
			best_lag = lag
	return float(sr) / best_lag


func test_one_note_per_rank() -> void:
	assert_eq(cfg.sounds.merge_notes.size(), catalog.count(), "une note par fruit")
	for s in cfg.sounds.merge_notes:
		assert_not_null(s)


func test_rank_to_note_strictly_increasing() -> void:
	var prev := 0.0
	for r in cfg.sounds.merge_notes.size():
		var hz := _estimate_hz(cfg.sounds.merge_notes[r].resource_path)
		assert_gt(hz, prev, "rang %d plus aigu que le rang %d (%.1f Hz)" % [r, r - 1, hz])
		prev = hz


# ---------------------------------------------------------------- Pools

func _pool_snapshot(j: Juice) -> Array[int]:
	var out: Array[int] = []
	for p in j.pools():
		out.append(p.created)
	out.append(Audio.created_players)
	return out


func test_pools_no_instancing_during_60_merges() -> void:
	var g: Game = await _new_game()
	var j := g.juice()
	await wait_process_frames(5)
	var before := _pool_snapshot(j)
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in 60:
		var rank := (i % catalog.count()) - 1  # -1 = Baobab
		var combo := 1 + (i % 6)
		g.merged.emit(rank, Vector3(randf_range(-2, 2), randf_range(1, 7), 0), 10 * i, combo)
		if i % 7 == 0:
			g.fruit_discovered.emit(mini(i % catalog.count() + 1, catalog.max_rank()))
		await wait_process_frames(1)
	await wait_process_frames(10)
	assert_eq(_pool_snapshot(j), before, "aucun nœud d'effet créé après préchauffage")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes_before,
		"nombre total de nœuds inchangé")


func test_pools_recycle_when_exhausted() -> void:
	var g: Game = await _new_game()
	var j := g.juice()
	for i in cfg.splash_pool_size * 3:
		g.merged.emit(0, Vector3.ZERO, 1, 1)
	assert_eq(j.splash_pool.size(), cfg.splash_pool_size, "taille du pool fixe")
	assert_eq(j.splash_pool.created, cfg.splash_pool_size)


func test_real_merges_do_not_grow_pools() -> void:
	var g: Game = await _new_game()
	var j := g.juice()
	var before := _pool_snapshot(j)
	var r := catalog.get_def(0).radius
	for i in 6:
		g.spawn_fruit(0, Vector3(-r * 0.6, 2.0, 0))
		g.spawn_fruit(0, Vector3(r * 0.6, 2.0, 0))
		await wait_physics_frames(20)
	assert_gt(g.score, 0, "des fusions ont eu lieu")
	assert_eq(_pool_snapshot(j), before)


# ---------------------------------------------------------------- Effets réduits

func test_reduced_effects_divide_particles_and_cut_shake_hitstop() -> void:
	var g: Game = await _new_game()
	var j := g.juice()
	j.set_reduced(false)
	var normal := (j.splash_pool.all()[0] as ParticleBurst).amount()
	j.set_reduced(true)
	var reduced := (j.splash_pool.all()[0] as ParticleBurst).amount()
	assert_almost_eq(float(reduced), normal / cfg.reduced_particle_divisor, 1.0,
		"particules divisées par 3")
	assert_true(SaveManager.get_setting(&"reduced_effects"), "réglage sauvegardé")

	j.shake.add(1.0)
	assert_eq(j.shake.trauma, 0.0, "pas de screen shake")
	g.merged.emit(8, Vector3.ZERO, 50, 4)  # grosse fusion + combo
	await wait_process_frames(3)
	assert_eq(g.camera().h_offset, 0.0)
	assert_eq(g.camera().v_offset, 0.0)
	assert_false(j.time_scaler.is_active(), "pas de hit-stop")
	assert_eq(Engine.time_scale, 1.0)

	j.set_reduced(false)
	assert_eq((j.splash_pool.all()[0] as ParticleBurst).amount(), normal, "restauré")
	j.shake.add(0.5)
	assert_gt(j.shake.trauma, 0.0, "shake réactivé")


func test_big_merge_adds_trauma() -> void:
	var g: Game = await _new_game()
	var j := g.juice()
	j.set_reduced(false)
	g.merged.emit(cfg.big_merge_min_rank, Vector3.ZERO, 28, 1)
	assert_gt(j.shake.trauma, 0.0, "fusion rang ≥ 7 → screen shake")
	j.shake.trauma = 0.0
	g.merged.emit(cfg.big_merge_min_rank - 1, Vector3.ZERO, 21, 1)
	assert_eq(j.shake.trauma, 0.0, "petite fusion : pas de shake")


# ---------------------------------------------------------------- Hit-stop / temps

func test_time_scaler_overlap_returns_to_one() -> void:
	var t := TimeScaler.new()
	t.request(0.05, 0.04)
	t.request(0.3, 0.1)
	assert_almost_eq(t.update(0.02), 0.05, 0.0001, "le plus lent l'emporte")
	assert_almost_eq(t.update(0.03), 0.3, 0.0001, "le 1er fini, le 2e continue")
	assert_eq(t.update(0.06), 1.0, "tout fini → 1")
	assert_false(t.is_active())


func test_hitstop_overlapping_restores_time_scale() -> void:
	var g: Game = await _new_game()
	var j := g.juice()
	j.set_reduced(false)
	j.hit_stop()
	await wait_process_frames(1)
	assert_lt(Engine.time_scale, 1.0, "hit-stop actif")
	j.hit_stop()
	g.merged.emit(2, Vector3.ZERO, 6, 3)  # combo → 3e hit-stop superposé
	await wait_seconds(0.3)
	assert_eq(Engine.time_scale, 1.0, "retour à 1 après chevauchement")


func test_hitstop_then_game_over_restores_time_scale() -> void:
	var g: Game = await _new_game()
	var j := g.juice()
	j.set_reduced(false)
	j.hit_stop()
	g._end_game()
	await wait_process_frames(2)
	assert_lt(Engine.time_scale, 1.0, "ralenti de game over")
	# Le ralenti dure en temps réel ; wait_seconds compte en temps ralenti.
	var deadline := Time.get_ticks_msec() + int((cfg.game_over_slowmo_time + 0.5) * 1000)
	while Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(Engine.time_scale, 1.0, "retour à 1 après la fin de partie")


func test_leaving_game_during_slowmo_restores_time_scale() -> void:
	var g: Game = await _new_game()
	g.juice().hit_stop()
	g.top_merge.emit(Vector3(0, 4, 0))  # ralenti Baobab de 1 s
	await wait_process_frames(2)
	assert_lt(Engine.time_scale, 1.0)
	g.queue_free()
	await wait_process_frames(2)
	assert_eq(Engine.time_scale, 1.0, "quitter la partie remet le temps à 1")


func test_baobab_sequence_is_short_and_non_blocking() -> void:
	var g: Game = await _new_game()
	var j := g.juice()
	g.top_merge.emit(Vector3(0, 4, 0))
	await wait_process_frames(2)
	assert_not_null(g.drop(0.0), "on peut toujours jouer pendant le Baobab")
	var deadline := Time.get_ticks_msec() + int((cfg.baobab_sequence_time + 0.3) * 1000)
	while Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_false(j._tree.visible, "séquence terminée en ≤ 3 s")
	assert_eq(Engine.time_scale, 1.0)


# ---------------------------------------------------------------- Animations

func test_impact_squashes_visual_only() -> void:
	var g: Game = await _new_game()
	var f := g.spawn_fruit(4, Vector3(0, 6.0, 0))
	var squashed := false
	var min_y := 1.0
	for i in 600:
		await wait_process_frames(1)
		if f.visual().is_squashing():
			squashed = true
			min_y = minf(min_y, f.visual().anim_scale().y)
	assert_true(squashed, "écrasement à l'impact")
	assert_lt(min_y, 0.95, "aplatissement visible")
	assert_almost_eq(f.size_factor(), 1.0, 0.001, "collision jamais déformée")


func test_falling_stretch_bounded() -> void:
	var g: Game = await _new_game()
	var f := g.spawn_fruit(2, Vector3(0, g.config.spawn_y, 0))
	var max_y := 0.0
	var min_x := 2.0
	for i in 40:
		await wait_physics_frames(1)
		if f.visual().is_squashing():
			break
		var s := f.visual().anim_scale()
		max_y = maxf(max_y, s.y)
		min_x = minf(min_x, s.x)
	assert_gt(max_y, 1.05, "étirement en chute")
	assert_lt(max_y, cfg.stretch_max_y * (1.0 + cfg.breath_amplitude) + 0.001, "≤ 1.15")
	assert_gt(min_x, cfg.stretch_min_x * (1.0 - cfg.breath_amplitude) - 0.001, "≥ 0.9")


func test_merge_sucks_then_removes_with_joy() -> void:
	var g: Game = await _new_game()
	var r := catalog.get_def(1).radius
	var a := g.spawn_fruit(1, Vector3(-r * 0.6, 2.0, 0))
	var b := g.spawn_fruit(1, Vector3(r * 0.6, 2.0, 0))
	# État relevé au moment même de la fusion (signal synchrone) : sous charge,
	# une attente d'une image peut couvrir plusieurs pas physiques et le fruit
	# être déjà supprimé quand on le regarde.
	var seen := {}
	g.merged.connect(func(_r: int, _p: Vector3, _pts: int, _c: int) -> void:
		if seen.is_empty() and is_instance_valid(a):
			seen["joy"] = a.visual().face.mood == FruitFace.Mood.JOY
			seen["layer"] = a.collision_layer)
	for i in 60:
		if not seen.is_empty():
			break
		await wait_physics_frames(1)
	assert_true(seen.get("joy", false), "yeux fermés de joie juste avant la fusion")
	assert_eq(seen.get("layer", -1), 0, "plus de collision pendant l'aspiration")
	await wait_seconds(cfg.merge_suck_time + 0.15)
	assert_false(is_instance_valid(a) or is_instance_valid(b), "supprimés après l'aspiration")


func test_preview_pops_elastically() -> void:
	var g: Game = await _new_game()
	var p := g.preview_visual()
	p.pop(0.0, cfg.spawn_pop_overshoot, cfg.spawn_pop_time)
	var peak := 0.0
	var steps := 30
	for i in steps:
		p._process(cfg.spawn_pop_time / steps)
		peak = maxf(peak, p.anim_scale().z)
	assert_almost_eq(peak, cfg.spawn_pop_overshoot, 0.02, "pic à 1.1")
	assert_almost_eq(p.anim_scale().z, 1.0, 0.001, "revient à 1")


func test_score_counter_rolls() -> void:
	var g: Game = await _new_game()
	g.score = 500
	g.score_changed.emit(500)
	await wait_process_frames(2)
	assert_lt(g._hud.displayed_score(), 500, "le compteur roule")
	var deadline := Time.get_ticks_msec() + int((cfg.score_roll_time + 0.3) * 1000)
	while Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_eq(g._hud.displayed_score(), 500, "puis rattrape le score")


func test_danger_raises_vignette_and_lowpass() -> void:
	var g: Game = await _new_game()
	var j := g.juice()
	g.danger_changed.emit(0.95, DangerMonitor.State.WARNING)
	var deadline := Time.get_ticks_msec() + 800
	while Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
	assert_gt(float(j._vignette_mat.get_shader_parameter("intensity")), 0.1, "vignette rouge")
	assert_lt(Audio.lowpass_cutoff(), cfg.lowpass_max_hz * 0.5, "musique filtrée")
	g.danger_changed.emit(0.0, DangerMonitor.State.SAFE)
