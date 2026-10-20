extends SceneTree
## Démo M2 scriptée : captures PNG de chaque effet + mesure FPS.
## Usage :
##   Godot --path . -s tools/demo_m2.gd -- <dossier_sortie>             (captures)
##   Godot --path . --write-movie out.avi -s tools/demo_m2.gd -- <dir>   (vidéo + son)
##   Godot --path . -s tools/demo_m2.gd -- <dir> perf                   (FPS partie pleine)

const GAME_SCENE := "res://scenes/Game.tscn"

var game: Node3D
var out_dir := "user://captures_m2"
var _shots: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var save_path := "user://demo_m2_save.json"
	DirAccess.remove_absolute(save_path)
	root.get_node("SaveManager").use_path(save_path)

	game = (load(GAME_SCENE) as PackedScene).instantiate()
	game.seed_value = 2026
	root.add_child(game)
	current_scene = game
	await _frames(20)

	if args.has("perf"):
		await _perf()
	else:
		await _showcase()
	print("DEMO shots=", _shots)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## `zoom_at` : point monde à agrandir (INF = écran entier), `half_px` en pixels 1080p.
func _shot(name: String, zoom_at := Vector3.INF, half_px := 200) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if zoom_at != Vector3.INF:
		# Projection en coordonnées 1080x1920 → pixels réels de l'image capturée.
		var k := Vector2(img.get_size()) / root.get_visible_rect().size
		var p: Vector2 = game.camera().unproject_position(zoom_at) * k
		var h := int(half_px * k.x)
		var x := clampi(int(p.x) - h, 0, img.get_width() - h * 2)
		var y := clampi(int(p.y) - h, 0, img.get_height() - h * 2)
		img = img.get_region(Rect2i(x, y, h * 2, h * 2))
		img.resize(600, 600, Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join(name + ".png"))
	_shots.append(name)


func _showcase() -> void:
	var dbg: Node = game.juice()._debug
	# 1) Lâchers : squash à l'impact
	var squash_done := false
	for x in [-2.0, 1.8, -0.4, 2.4, 0.6]:
		game.drop(x)
		for k in 40:
			await process_frame
			if not squash_done:
				for f in game.fruits():
					if f.visual().anim_scale().y < 0.86:
						await _shot("01_squash_impact")
						await _shot("01b_squash_zoom", f.global_position, 220)
						squash_done = true
						break
	await _frames(40)
	# 2) Visages (zoom sur le fond du panier)
	await _shot("02_visages", Vector3(0, 1.3, 0), 330)

	# 3) Fusion : éclaboussure, onde, +points
	var on_merge := func(_r: int, _p: Vector3, _pts: int, _c: int) -> void: pass
	var merged := [false]
	on_merge = func(_r: int, _p: Vector3, _pts: int, _c: int) -> void: merged[0] = true
	game.merged.connect(on_merge)
	var r3: float = game.catalog.get_def(3).radius
	game.spawn_fruit(3, Vector3(-r3 * 0.7, 6.5, 0))
	game.spawn_fruit(3, Vector3(r3 * 0.7, 6.5, 0))
	while not merged[0]:
		await process_frame
	await _frames(4)
	await _shot("03_fusion_eclaboussure")
	await _frames(60)

	# 4) Combo
	var top_combo := [0]
	game.merged.connect(func(_r: int, _p: Vector3, _pts: int, c: int) -> void:
		top_combo[0] = maxi(top_combo[0], c))
	dbg.force_combo(4, 0)
	while top_combo[0] < 3:
		await process_frame
	await _frames(8)
	await _shot("04_combo")
	await _frames(90)

	# 5) Nouveau fruit (jamais atteint) → ralenti, projecteur, bandeau
	game.max_rank_reached = 5
	var discovered := [false]
	game.fruit_discovered.connect(func(_r: int) -> void: discovered[0] = true)
	dbg.force_discovery()
	while not discovered[0]:
		await process_frame
	await _frames(14)
	await _shot("05_nouveau_fruit")
	await _frames(100)

	# 6) Moment Baobab
	var baobab := [false]
	game.top_merge.connect(func(_p: Vector3) -> void: baobab[0] = true)
	dbg.force_baobab()
	while not baobab[0]:
		await process_frame
	await _frames(12)
	await _shot("06a_baobab_debut")
	await _frames(40)
	await _shot("06b_baobab_croissance")
	await _frames(50)
	await _shot("06c_baobab_pluie")
	await _frames(120)

	# 7) Danger puis game over
	# Rangs voisins tous différents : on veut un débordement, pas un Baobab.
	var ranks := [10, 8, 9, 7, 6, 5]
	var i := 0
	var danger_shot := false
	while not game.is_over and i < 40:
		game.spawn_fruit(ranks[i % ranks.size()], Vector3([-1.5, 1.5, 0.0][i % 3], game.config.spawn_y, 0))
		i += 1
		for k in 30:
			await process_frame
			if not danger_shot and game.danger.max_ratio() > 0.8 and not game.is_over:
				await _shot("07_danger")
				danger_shot = true
	if not game.is_over:
		game._end_game()
	await _frames(20)
	await _shot("08a_game_over_ralenti")
	await _frames(90)
	await _shot("08b_game_over_panneau")
	# Menu debug
	dbg.toggle()
	await _frames(5)
	await _shot("09_menu_debug")


## Partie pleine (~40 fruits) + effets en continu : FPS moyen / min.
func _perf() -> void:
	game.juice().set_show_fps(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Remplissage contrôlé : fruits variés, sans fusion immédiate.
	var placed := 0
	while game.fruits().size() < 40 and placed < 120:
		var rank := rng.randi_range(0, 6)
		game.spawn_fruit(rank, Vector3(rng.randf_range(-2.6, 2.6), rng.randf_range(1.0, 6.5), 0))
		placed += 1
		await _frames(3)
	await _frames(120)
	var frames := 0
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var last := t0
	var dbg: Node = game.juice()._debug
	while Time.get_ticks_usec() - t0 < 8_000_000:
		await process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
		if frames % 45 == 0:
			game.merged.emit(rng.randi_range(1, 9), Vector3(rng.randf_range(-2, 2), 4, 0),
				30, rng.randi_range(1, 4))
		if frames % 200 == 0:
			dbg.force_combo(3, 0)
	var secs := (Time.get_ticks_usec() - t0) / 1_000_000.0
	await _shot("perf_partie_pleine")
	print("PERF fruits=%d frames=%d avg_fps=%.1f worst_frame_ms=%.1f renderer=%s gpu=%s" % [
		game.fruits().size(), frames, frames / secs, worst,
		RenderingServer.get_current_rendering_method(), RenderingServer.get_video_adapter_name()])
