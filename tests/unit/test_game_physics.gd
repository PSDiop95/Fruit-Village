extends GutTest
## Tests d'intégration : vraie physique Jolt, vraie scène de jeu.

const GameScene := preload("res://scenes/Game.tscn")
const TEST_SAVE := "user://test_save.json"

var game: Game


func before_all() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	SaveManager.use_path(TEST_SAVE)


func after_all() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	SaveManager.use_path(SaveManager.DEFAULT_SAVE_PATH)


func before_each() -> void:
	game = GameScene.instantiate()
	game.seed_value = 12345
	add_child_autofree(game)
	await wait_physics_frames(2)


func _spawn(rank: int, x: float, y: float) -> Fruit:
	return game._spawn_fruit(rank, Vector3(x, y, 0))


func _ranks() -> Array:
	var r := game.fruits().map(func(f: Fruit) -> int: return f.rank)
	r.sort()
	return r


# --- Fusions

func test_two_identical_fruits_merge_into_next_rank() -> void:
	_spawn(2, -0.3, 1.0)
	_spawn(2, 0.3, 2.5)
	await wait_physics_frames(120)
	assert_eq(_ranks(), [3], "deux tamarins → un ditakh")
	assert_eq(game.score, game.catalog.merge_points(2))


func test_different_fruits_do_not_merge() -> void:
	_spawn(1, -0.3, 1.0)
	_spawn(2, 0.3, 2.5)
	await wait_physics_frames(120)
	assert_eq(_ranks(), [1, 2])
	assert_eq(game.score, 0)


func test_triple_contact_does_not_duplicate() -> void:
	# Trois bissaps qui se touchent simultanément dès la 1re frame.
	var r := game.catalog.get_def(1).radius
	_spawn(1, -2.0 * r, r)
	_spawn(1, 0.0, r)
	_spawn(1, 2.0 * r, r)
	watch_signals(game)
	await wait_physics_frames(180)
	assert_eq(_ranks(), [1, 2], "3 bissaps → 1 tamarin + 1 bissap, jamais plus")
	assert_signal_emit_count(game, "merged", 1, "une seule fusion")


func test_triple_stack_contact_does_not_duplicate() -> void:
	# Un bissap tombe pile entre deux bissaps déjà posés.
	var r := game.catalog.get_def(1).radius
	_spawn(1, -r * 1.05, r)
	_spawn(1, r * 1.05, r)
	_spawn(1, 0.0, 3.0)
	await wait_physics_frames(180)
	assert_eq(_ranks(), [1, 2])


func test_chain_reaction_with_combo() -> void:
	# Ditakh posé, puis deux tamarins → ditakh, qui retombe sur le premier → madd.
	_spawn(3, 0.0, 0.6)
	_spawn(2, -0.25, 2.0)
	_spawn(2, 0.25, 3.2)
	await wait_physics_frames(240)
	assert_eq(_ranks(), [4], "réaction en chaîne jusqu'au madd")
	var expected := game.catalog.merge_points(2) * 1 + game.catalog.merge_points(3) * 2
	assert_eq(game.score, expected, "2e fusion enchaînée comptée x2")


func test_drop_resets_combo() -> void:
	game.combo.register(game._time)
	game.combo.register(game._time)
	assert_eq(game.combo.multiplier(), 2)
	game.drop(0.0)
	assert_eq(game.combo.multiplier(), 1, "nouveau lâcher = nouvelle cascade")


func test_merge_grows_from_70_percent() -> void:
	var sizes: Array[float] = []
	game.merged.connect(func(_r: int, _p: Vector3, _pts: int, _c: int) -> void:
		sizes.append(game._fruits.back().size_factor()))
	_spawn(2, -0.3, 1.0)
	_spawn(2, 0.3, 2.5)
	await wait_physics_frames(120)
	assert_eq(sizes.size(), 1)
	assert_almost_eq(sizes[0], game.config.merge_grow_start_scale, 0.001, "pop à 70 %")
	assert_almost_eq(game.fruits()[0].size_factor(), 1.0, 0.001, "taille finale nominale")


func test_top_merge_removes_both() -> void:
	var top := game.catalog.max_rank()
	_spawn(top, -1.0, 2.0)
	_spawn(top, 1.0, 2.0)
	watch_signals(game)
	await wait_physics_frames(200)
	assert_signal_emitted(game, "top_merge")
	assert_eq(game.fruits().size(), 0)
	assert_eq(game.score, game.catalog.top_merge_points)


# --- Lâcher

func test_drop_respects_cooldown_and_walls() -> void:
	var f := game.drop(100.0)
	assert_not_null(f)
	assert_null(game.drop(0.0), "cooldown actif")
	var half := game.config.basket_inner_width * 0.5
	assert_lt(absf(f.position.x) + f.radius, half + 0.001, "visée bornée au panier")
	await wait_seconds(game.config.drop_cooldown + 0.05)
	assert_not_null(game.drop(0.0), "cooldown écoulé → lâcher possible")


func test_drop_uses_announced_next_fruit() -> void:
	var announced: int = game.spawner.upcoming()[0]
	game.drop(0.0)
	await wait_seconds(game.config.drop_cooldown + 0.05)
	assert_eq(game.drop(1.0).rank, announced, "le fruit suivant affiché est bien lâché")


# --- Danger / game over

func test_falling_fruit_crossing_line_is_not_game_over() -> void:
	game.drop(0.0)
	await wait_seconds(4.0)
	assert_false(game.is_over, "traverser la ligne en tombant n'est pas un débordement")


func test_overflow_triggers_game_over_and_saves_record() -> void:
	watch_signals(game)
	var max_ratio := 0.0
	var ranks := [6, 7, 8, 9, 10]
	var xs := [-1.5, 1.5, 0.0]
	for i in 60:
		if game.is_over:
			break
		if i < 30:
			_spawn(ranks[i % ranks.size()], xs[i % 3], game.config.spawn_y)
		await wait_seconds(0.5)
		max_ratio = maxf(max_ratio, game.danger.max_ratio())
	assert_true(game.is_over, "le panier déborde → game over")
	assert_signal_emitted(game, "game_over")
	assert_gt(max_ratio, 0.4, "alerte affichée avant le game over")
	assert_true(game._hud._over_panel.visible, "écran de fin affiché")
	assert_eq(SaveManager.best_score, maxi(game.score, SaveManager.best_score))
	assert_true(FileAccess.file_exists(TEST_SAVE), "record sauvegardé")
	assert_null(game.drop(0.0), "plus de lâcher après game over")


# --- Fumée

func test_random_play_session_stable() -> void:
	# 80 lâchers à positions seedées : rien ne sort du panier, pas de NaN.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var half := game.config.basket_inner_width * 0.5
	var drops := 0
	for i in 80:
		if game.is_over:
			break
		if game.drop(rng.randf_range(-half, half)) != null:
			drops += 1
		await wait_seconds(game.config.drop_cooldown + 0.05)
	assert_gt(drops, 20)
	for f in game.fruits():
		var p := f.global_position
		assert_false(is_nan(p.x) or is_nan(p.y), "position NaN")
		assert_lt(absf(p.x), half + 0.05, "fruit hors panier")
		assert_gt(p.y, -0.5, "fruit passé sous le sol")
		assert_almost_eq(p.z, 0.0, 0.001, "axe Z verrouillé")
	assert_gt(game.score, 0, "des fusions ont eu lieu")
	assert_gt(game.max_rank_reached, 4, "fusions au-delà des fruits lâchables")
