extends SceneTree
## Vidéo promo (store/video_promo_script.md) : séquence de jeu réelle,
## enregistrée image par image par le Movie Maker de Godot (cadence fixe,
## son inclus). Textes, zooms et carte finale : tools/video/edit.py.
## Usage : tools/video/make_promo.sh
##
## Imprime « MARK <plan> <image> » au début de chaque plan : edit.py s'en sert
## pour caler zooms et textes. Graine et positions fixes : rendu reproductible.

const SAVE := "user://promo_save.json"

var _game  # non typé : les classes du jeu dépendent des autoloads (script -s)


func _initialize() -> void:
	_run.call_deferred()


func _node(n: String) -> Node:
	return root.get_node(n)


func _mark(shot: String) -> void:
	print("MARK %s %d" % [shot, Engine.get_frames_drawn()])


## Passe image : `-- <dossier>` enregistre chaque image en 1080x1920 (le
## Movie Maker garde la taille de fenêtre du démarrage, bornée par l'écran).
## Passe son : sans argument, sous --write-movie (même pas de temps fixe).
func _capture_frame(dir: String) -> void:
	root.get_texture().get_image().save_png(dir.path_join("f%08d.png" % Engine.get_frames_drawn()))


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		DirAccess.make_dir_recursive_absolute(args[0])
		RenderingServer.frame_post_draw.connect(_capture_frame.bind(args[0]))
	var win := root.get_window()
	win.borderless = true
	win.position = Vector2i.ZERO
	win.size = Vector2i(1080, 1920)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var sm = _node("SaveManager")
	sm.use_path(SAVE)
	sm.best_score = 6850
	sm.best_rank = 9
	sm.set_setting(&"quality", 2)
	sm.set_setting(&"ambiance", 0)  # jour
	await _frames(20)

	var main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(60)
	if main.title.panel:
		main.title.panel.close()
	main.start_game()
	await _frames(15)
	_game = main.game
	var juice = _game.juice()
	juice.set_show_fps(false)
	var sounds = juice.config.sounds
	var mascot = _game.mascot()

	# Panier garni (fond), posé avant le premier plan.
	var xs := [-2.4, -1.2, 0.0, 1.2, 2.4, -1.8, 0.6, 1.8, -0.6, 2.2, -2.2]
	var ranks := [5, 3, 7, 4, 5, 2, 3, 0, 4, 1, 2]
	for i in xs.size():
		_game.spawn_fruit(ranks[i], Vector3(xs[i], 1.0 + 1.6 * (i / 5), 0))
	await _frames(150)
	_game.score = 1840
	_game.score_changed.emit(_game.score)

	# 0,0 s — accroche : deux tamarins qui se touchent en tombant.
	_mark("hook")
	var y: float = _game.config.spawn_y
	var r2: float = _game.catalog.get_def(2).radius
	_game.spawn_fruit(2, Vector3(-0.4 - r2 * 0.6, y - 1.0, 0))
	_game.spawn_fruit(2, Vector3(-0.4 + r2 * 0.6, y - 1.0, 0))
	await _frames(18)

	# 0,6 s — deux mangues → papaye.
	_mark("mango")
	var r6: float = _game.catalog.get_def(6).radius
	_game.spawn_fruit(6, Vector3(1.0 - r6 * 0.95, y - 0.6, 0))
	_game.spawn_fruit(6, Vector3(1.0 + r6 * 0.95, y - 0.6, 0))
	mascot.react(1)  # CHEER
	await _frames(42)

	# 2,0 s — fusions en chaîne (vraies fusions rapprochées → COMBO x2…x4).
	_mark("combo")
	juice._debug.force_combo(4, 1)
	await _frames(120)

	# 6,0 s — tension : ligne rouge, fruits qui ont peur, battement de cœur.
	_mark("tension")
	_game.danger_changed.emit(0.9, 1)  # DangerMonitor.State.WARNING
	mascot.react(4)  # FEAR
	await _frames(60)

	# 8,0 s — lâcher décisif : deux pains de singe → Moment Baobab.
	_mark("decisive")
	_game.danger_changed.emit(0.0, 0)
	juice._debug.force_baobab()
	await _frames(30)
	_mark("baobab")
	await _frames(150)

	# 14,0 s — carte « Le savais-tu ? » du pain de singe.
	_mark("fact")
	_game.hud().show_fact(10)
	_node("Audio").play(sounds.discover, -4.0)
	await _frames(75)

	# 16,5 s — appel à l'action (carte finale composée au montage).
	_mark("cta")
	await _frames(15)
	_node("Audio").play(sounds.voice_dafa_neex, 0.0)
	await _frames(105)
	_mark("end")
	quit()


## Attend n images ; referme la pause automatique (perte de focus de la fenêtre).
func _frames(n: int) -> void:
	for i in n:
		if paused and _game and _game.hud():
			_game.hud().close_pause()
		await process_frame
