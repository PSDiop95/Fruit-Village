extends SceneTree
## Capture visuelle (hors tests) : joue une partie seedée et sauve des PNG.
## Usage : Godot --path . -s tools/capture.gd -- <dossier_sortie>

## Chargé à l'exécution : un preload compilerait game.gd avant les autoloads.
const GAME_SCENE := "res://scenes/Game.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out_dir := "user://captures"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_node("SaveManager").use_path("user://capture_save.json")

	var game: Node3D = (load(GAME_SCENE) as PackedScene).instantiate()
	game.seed_value = 777
	root.add_child(game)
	current_scene = game
	await physics_frame

	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var half: float = game.config.basket_inner_width * 0.5
	var shots := {10: "01_debut", 45: "02_milieu", 90: "03_plein"}
	for i in 200:
		if game.is_over:
			break
		game.drop(rng.randf_range(-half, half))
		for k in 27:
			await physics_frame
		if shots.has(i):
			await _shot(out_dir, shots[i])
	if not game.is_over:
		# Force un débordement pour voir l'écran de fin.
		for j in 30:
			game._spawn_fruit(9, Vector3([-1.5, 1.5][j % 2], game.config.spawn_y, 0))
			for k in 30:
				await physics_frame
			if game.is_over:
				break
	for k in 30:
		await process_frame
	await _shot(out_dir, "04_game_over")
	print("CAPTURE score=%d max_rank=%d over=%s" % [game.score, game.max_rank_reached, game.is_over])
	# Rejouer : clic réel sur le bouton (centre de l'écran de fin).
	var btn: Button = game.find_children("*", "Button", true, false)[0]
	btn.pressed.emit()
	for k in 10:
		await process_frame
	var fresh: Node = current_scene
	print("REPLAY new_scene=%s score=%d over=%s" % [fresh != game, fresh.score, fresh.is_over])
	await _shot(out_dir, "05_rejouer")
	quit()


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(dir.path_join(name + ".png"))
