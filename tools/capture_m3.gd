extends SceneTree
## Captures M3 (rendu réel, fenêtré) : parcours complet du joueur.
## Usage : Godot --path . --resolution 720x1280 -s tools/capture_m3.gd -- docs/screens
## Sur Linux CI : xvfb-run -a godot --path . -s tools/capture_m3.gd -- docs/screens
##
## Produit : m3_titre, m3_reglages, m3_partie_debut, m3_partie_moitie,
## m3_baobab, m3_pause, m3_game_over (.png). Partie seedée (reproductible).

var out_dir := "user://screens"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_node("SaveManager").use_path("user://capture_m3_save.json")
	var sm = root.get_node("SaveManager")
	sm.best_score = 4210
	sm.best_rank = 7
	sm.set_setting(&"quality", 2)

	var main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(20)
	await _shot("m3_titre")
	main.title.open_settings()
	await _frames(6)
	await _shot("m3_reglages")
	main.title.open_settings().close()

	main.start_game()
	await _frames(2)
	var game = main.game
	game.seed_value = 777
	await _frames(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var half: float = game.config.basket_inner_width * 0.5
	for i in 70:
		if game.is_over:
			break
		game.drop(rng.randf_range(-half, half))
		await _physics(27)
		if i == 8:
			await _shot("m3_partie_debut")
		if i == 45:
			await _shot("m3_partie_moitie")
	# Moment Baobab (deux pains de singe)
	game.juice()._debug.force_baobab()
	await _physics(70)
	await _shot("m3_baobab")
	await _physics(80)
	game.hud().open_pause()
	await _frames(6)
	await _shot("m3_pause")
	game.hud().close_pause()
	# Fin de partie (même chemin que le débordement réel).
	game._end_game()
	await _frames(150)
	await _shot("m3_game_over")
	print("CAPTURE_M3 score=%d over=%s" % [game.score, game.is_over])
	quit()


func _frames(n: int) -> void:
	for k in n:
		await process_frame


func _physics(n: int) -> void:
	for k in n:
		await physics_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(shot_name + ".png"))
	print("SHOT ", shot_name)
