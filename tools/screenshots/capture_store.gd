extends SceneTree
## Captures brutes pour la fiche Google Play (rendu réel, sans bandeau ; le
## bandeau texte est ajouté par tools/screenshots/compose.py).
## Usage : tools/screenshots/make_screenshots.sh (xvfb-run sous Linux,
## fenêtre hors écran sous Windows). Direct :
##   Godot --path . --resolution 1080x1920 -s tools/screenshots/capture_store.gd -- <dossier>
##
## Produit : 01_fusion, 02_combo, 03_album, 04_baobab, 05_missions, 06_rares (.png).
## Graine et positions fixes : captures identiques d'une exécution à l'autre.

const SAVE := "user://capture_store_save.json"

var out_dir := "user://store_raw"
var _game  # non typé : les classes du jeu dépendent des autoloads (script -s)


func _initialize() -> void:
	_run.call_deferred()


func _node(n: String) -> Node:
	return root.get_node(n)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Rendu 1080x1920 même sur un écran plus petit : fenêtre sans bordure,
	# agrandie au-delà de l'écran (Windows l'autorise sans bordure).
	var win := root.get_window()
	win.borderless = true
	win.position = Vector2i.ZERO
	win.size = Vector2i(1080, 1920)
	await _frames(10)
	print("WINDOW %s" % win.size)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var sm = _node("SaveManager")
	sm.use_path(SAVE)
	sm.best_score = 6850
	sm.best_rank = 9
	sm.set_setting(&"quality", 2)
	sm.set_setting(&"ambiance", 0)  # jour
	# Joueur niveau 6, 9 fruits découverts, missions en cours.
	_node("Progression").add_xp(_node("Progression").config.xp_for_level(6) + 40)
	var wallet = _node("Wallet")
	wallet.spend(wallet.coins())
	wallet.earn(860)
	for r in 9:
		_node("Collection").discover(r)
	var missions = _node("Missions")
	missions.refresh()
	missions.core.active[0]["progress"] = missions.core.active[0]["target"]
	missions.core.active[1]["progress"] = int(missions.core.active[1]["target"]) / 2
	await _frames(40)

	var main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(80)
	if main.title.panel:
		main.title.panel.close()
	await _frames(10)

	# 3) Album des fruits, 5) Missions du jour.
	main.title.open_feature(ProgressionCore.ALBUM)
	await _frames(30)
	await _shot("03_album")
	main.title.panel.close()
	main.title.open_feature(ProgressionCore.MISSIONS)
	await _frames(20)
	await _shot("05_missions")
	main.title.panel.close()
	await _frames(10)

	# Partie : panier garni de fruits variés, posés.
	main.start_game()
	await _frames(12)
	_game = main.game
	_game.juice().set_show_fps(false)  # compteur debug : jamais sur une capture store
	_game.score = 2480
	_game.score_changed.emit(_game.score)
	var xs := [-2.4, -1.2, 0.0, 1.2, 2.4, -1.8, 0.6, 1.8, -0.6, 2.2, -2.2, 0.2, 1.0, -1.0]
	var ranks := [6, 4, 7, 3, 5, 2, 4, 1, 5, 0, 3, 2, 1, 0]
	for i in xs.size():
		_game.spawn_fruit(ranks[i], Vector3(xs[i], 1.0 + 1.6 * (i / 5), 0))
	await _frames(160)

	# 1) Fusion : éclaboussure au point de contact.
	var juice = _game.juice()
	var p := Vector3(0.4, 3.2, 0)
	juice._on_merged(5, p, 21, 1)
	await _frames(5)
	await _shot("01_fusion")

	# 2) Combo x4.
	juice._on_merged(4, p, 30, 3)
	_game.mascot()._on_merged(4, p, 30, 3)
	await _frames(6)
	juice._on_merged(6, p + Vector3(-1, 0.5, 0), 84, 4)
	_game.mascot()._on_merged(6, p, 84, 4)
	await _frames(14)
	await _shot("02_combo")

	# 4) Moment Baobab.
	await _frames(90)
	juice._on_top_merge(p)
	_game.mascot().react(2)  # Mascot.Mood.PARTY
	await _frames(110)
	await _shot("04_baobab")

	# 6) Fruits rares : gros fruits au panier + carte du Pain de singe.
	await _frames(240)
	# Deux gros fruits, sous la ligne (pas d'alerte danger sur la capture).
	_game.spawn_fruit(8, Vector3(-1.4, 3.6, 0))
	_game.spawn_fruit(9, Vector3(1.4, 3.6, 0))
	await _frames(120)
	_game.danger_changed.emit(0.0, 0)
	_game.hud().show_fact(10)
	await _frames(40)
	await _shot("06_rares")
	print("CAPTURE_STORE ok -> %s" % out_dir)
	quit()


## Attend n frames ; referme la pause automatique (perte de focus de la fenêtre).
func _frames(n: int) -> void:
	for i in n:
		if paused and _game and _game.hud():
			_game.hud().close_pause()
		await process_frame


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(file + ".png"))
	print("SHOT %s %s" % [file, img.get_size()])
