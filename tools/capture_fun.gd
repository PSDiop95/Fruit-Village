extends SceneTree
## Captures de contrôle du « fun » visuel : fusion (gouttes, étoiles, éclair),
## bannière COMBO (normale et chaude), mascotte (fête, Baobab, peur).
## Les effets sont déclenchés directement (indépendant du hasard physique).
## Usage : Godot --path . --resolution 540x1200 -s tools/capture_fun.gd -- <dossier> [ambiance]

const GAME_SCENE := "res://scenes/Game.tscn"

var _game: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://captures_fun"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_node("SaveManager").use_path("user://capture_fun_save.json")
	if args.size() > 1:
		root.get_node("SaveManager").set_setting(&"ambiance", int(args[1]))
	_game = (load(GAME_SCENE) as PackedScene).instantiate()
	_game.seed_value = 777
	root.add_child(_game)
	current_scene = _game
	await _frames(5)
	# Un panier à moitié plein, posé.
	var xs := [-2.4, -1.2, 0.0, 1.2, 2.4, -1.8, 0.6, 1.8, -0.6, 2.2, -2.2, 0.2]
	var ranks := [6, 4, 7, 3, 5, 2, 4, 1, 5, 0, 3, 2]
	for i in xs.size():
		_game.spawn_fruit(ranks[i], Vector3(xs[i], 1.0 + 1.6 * (i / 5), 0))
	await _frames(150)
	await _shot(out_dir, "fun_00_repos")

	var juice = _game.juice()
	var p := Vector3(0.4, 3.2, 0)
	juice._on_merged(5, p, 21, 1)
	await _frames(5)
	await _shot(out_dir, "fun_01_fusion")

	juice._on_merged(4, p, 30, 3)
	_game.mascot()._on_merged(4, p, 30, 3)
	await _frames(14)
	await _shot(out_dir, "fun_02_combo3")

	juice._on_merged(6, p + Vector3(-1, 0.5, 0), 120, 6)
	_game.mascot()._on_merged(6, p, 120, 6)
	await _frames(16)
	await _shot(out_dir, "fun_03_combo6_chaud")

	await _frames(80)
	juice._on_top_merge(p)
	_game.mascot().react(2)  # Mascot.Mood.PARTY
	await _frames(40)
	await _shot(out_dir, "fun_04_baobab")

	await _frames(200)
	_game.danger_changed.emit(0.9, 1)  # DangerMonitor.State.WARNING
	await _frames(30)
	await _shot(out_dir, "fun_05_peur")
	print("CAPTURE_FUN ok -> %s" % out_dir)
	quit()


## Attend n frames ; referme la pause automatique (perte de focus de la fenêtre).
func _frames(n: int) -> void:
	for i in n:
		if paused and _game and _game.hud():
			_game.hud().close_pause()
		await process_frame


func _shot(dir: String, file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(dir.path_join(file + ".png"))
	var vp := root.get_viewport_rid()
	print("SHOT %s draw_calls=%d objets=%d triangles=%d fps=%d" % [file,
		RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),
		RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
			RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),
		Engine.get_frames_per_second()])
