extends SceneTree
## Captures M4 (rendu réel, fenêtré) : méta et pub simulée.
## Usage : Godot --path . --resolution 720x1280 -s tools/capture_m4.gd -- docs/screens
##
## Produit : m4_titre, m4_cadeau, m4_missions, m4_album, m4_album_carte,
## m4_partie_powerups, m4_powerup_offre, m4_pilon, m4_continuer, m4_pub_simulee,
## m4_fin_recompenses, m4_niveau, m4_reglages (.png).

var out_dir := "user://screens"


func _initialize() -> void:
	_run.call_deferred()


func _node(n: String) -> Node:
	return root.get_node(n)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capture_m4_save.json"))
	var sm = _node("SaveManager")
	sm.use_path("user://capture_m4_save.json")
	sm.best_score = 4210
	sm.best_rank = 7
	sm.set_setting(&"quality", 2)
	# Joueur niveau 5, 640 pièces, 8 fruits découverts, série de 3 jours.
	_node("Progression").add_xp(_node("Progression").config.xp_for_level(5) + 40)
	var wallet = _node("Wallet")
	wallet.spend(wallet.coins())
	wallet.earn(640)
	for r in 8:
		_node("Collection").discover(r)
	var daily = _node("DailyRewards")
	var today: int = daily.clock.today()
	daily.core.last_claim_day = today - 1
	daily.core.streak = 3
	daily.core.cycle = 3
	var missions = _node("Missions")
	missions.refresh()
	missions.core.active[0]["progress"] = missions.core.active[0]["target"]
	missions.core.active[1]["progress"] = int(missions.core.active[1]["target"]) / 2
	await _frames(40)  # pub simulée chargée

	var main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(80)
	if main.title.panel:
		main.title.panel.close()
	await _frames(10)
	await _shot("m4_titre")
	main.title.open_feature(ProgressionCore.DAILY)
	await _frames(12)
	await _shot("m4_cadeau")
	main.title.panel.close()
	main.title.open_feature(ProgressionCore.MISSIONS)
	await _frames(12)
	await _shot("m4_missions")
	main.title.panel.close()
	var album = main.title.open_feature(ProgressionCore.ALBUM)
	await _frames(20)
	await _shot("m4_album")
	album.open_card(6)
	await _frames(30)
	await _shot("m4_album_carte")
	album.close()
	main.title.open_settings()
	await _frames(10)
	await _shot("m4_reglages")
	main.title.open_settings().close()

	main.start_game()
	await _frames(2)
	var game = main.game
	await _frames(10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var half: float = game.config.basket_inner_width * 0.5
	for i in 30:
		game.drop(rng.randf_range(-half, half))
		await _physics(27)
	await _shot("m4_partie_powerups")
	while wallet.stock_of(PowerupsConfig.GROW) > 0:
		wallet.use_stock(PowerupsConfig.GROW)
	var bar = game.hud().powerup_bar
	var offer = bar.open_offer(PowerupsConfig.GROW)
	await _frames(10)
	await _shot("m4_powerup_offre")
	offer.close()
	wallet.add_stock(PowerupsConfig.PESTLE, 1)
	game.powerups.use(PowerupsConfig.PESTLE)
	await _frames(8)
	await _shot("m4_pilon")
	game.powerups.cancel_aim()
	# Débordement : offre « Continuer ».
	game._end_game()
	await _frames(150)
	await _shot("m4_continuer")
	game.hud()._over.continue_accepted.emit()
	await _frames(20)
	await _shot("m4_pub_simulee")
	var ads = _node("AdsManager")
	ads.provider.finish(0)
	await _frames(40)
	for i in 6:
		game.drop(rng.randf_range(-half, half))
		await _physics(27)
	# Fin définitive : récompenses, puis niveau supérieur.
	game._end_game()
	await _frames(30)
	game.hud()._over.continue_declined.emit()
	await _frames(220)
	if game.hud().level_popup:
		game.hud().level_popup.close()
	await _frames(20)
	await _shot("m4_fin_recompenses")
	game.hud().show_level_up(6, 50, [] as Array[StringName])
	await _frames(40)
	await _shot("m4_niveau")
	print("CAPTURE_M4 ok")
	quit()


func _frames(n: int) -> void:
	for k in n:
		await process_frame


func _physics(n: int) -> void:
	for k in n:
		await physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)
