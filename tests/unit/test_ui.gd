extends GutTest
## M3 : écrans (titre, réglages, pause, fin de partie), sauvegarde des réglages,
## qualité automatique.

const MainScene := preload("res://scenes/Main.tscn")
const SAVE_PATH := "user://test_ui_save.json"


func before_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	SaveManager.use_path(SAVE_PATH)


func after_each() -> void:
	get_tree().paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	SaveManager.use_path(SaveManager.DEFAULT_SAVE_PATH)


func _main() -> Main:
	var m: Main = MainScene.instantiate()
	add_child_autofree(m)
	await wait_process_frames(2)
	return m


func test_title_opens_and_closes_settings() -> void:
	var m := await _main()
	assert_not_null(m.title, "écran titre affiché au lancement")
	assert_true(m.title.play_button.visible)
	var s := m.title.open_settings()
	await wait_process_frames(1)
	assert_true(m.title.settings_open())
	s.close()
	await wait_process_frames(1)
	assert_false(m.title.settings_open(), "réglages refermés")


func test_play_then_menu_returns_to_title() -> void:
	var m := await _main()
	m.title.play_button.pressed.emit()
	await wait_process_frames(2)
	assert_null(m.game, "rideau d'abord : la partie se construit écran couvert")
	assert_true(m.curtain.is_covering())
	await wait_seconds(0.3)
	assert_not_null(m.game, "Jouer lance une partie")
	assert_null(m.title, "le titre disparaît")
	m.game.hud().menu_requested.emit()
	await wait_process_frames(3)
	assert_null(m.game, "Menu ferme la partie")
	assert_not_null(m.title, "retour au titre")


func test_pause_and_settings_open_and_close() -> void:
	var m := await _main()
	m.start_game()
	await wait_process_frames(2)
	var hud := m.game.hud()
	hud.open_pause()
	assert_true(get_tree().paused, "pause : arbre en pause")
	assert_true(hud.is_paused())
	var s := hud.open_settings()
	assert_not_null(s, "réglages depuis la pause")
	s.close()
	hud.close_pause()
	assert_false(get_tree().paused, "reprise")
	assert_false(hud.is_paused())


func test_game_over_panel_and_replay() -> void:
	var m := await _main()
	m.start_game()
	await wait_process_frames(2)
	var first := m.game
	first._end_game()
	await wait_process_frames(2)
	assert_true(first.hud()._over_panel.visible, "écran de fin visible")
	first.restart()
	await wait_process_frames(3)
	assert_ne(m.game, first, "Rejouer : nouvelle partie")
	assert_false(m.game.is_over)


func test_settings_are_saved_and_reloaded() -> void:
	var m := await _main()
	var s := m.title.open_settings()
	await wait_process_frames(1)
	(s.toggles[&"music_on"] as CheckButton).button_pressed = false
	(s.toggles[&"reduced_effects"] as CheckButton).button_pressed = true
	s.quality_buttons[1].pressed.emit()  # Bas
	s.close()
	# Rechargement depuis le disque (comme au prochain lancement).
	SaveManager.use_path(SAVE_PATH)
	assert_eq(SaveManager.get_setting(&"music_on"), false)
	assert_eq(SaveManager.get_setting(&"reduced_effects"), true)
	assert_eq(SaveManager.get_setting(&"quality"), JuiceConfig.Quality.LOW)
	assert_typeof(SaveManager.get_setting(&"quality"), TYPE_INT)


func test_quality_setting_applies_to_game() -> void:
	SaveManager.set_setting(&"quality", JuiceConfig.Quality.LOW)
	var m := await _main()
	m.start_game()
	await wait_process_frames(2)
	assert_eq(FruitModels.quality, JuiceConfig.Quality.LOW)
	assert_eq(m.game.juice().quality, JuiceConfig.Quality.LOW)
	assert_false(m.game.juice().auto_quality_allowed, "réglage manuel : pas de baisse auto")
	assert_null(FruitModels.fruit_material().next_pass, "Bas : pas de contour")
	m.game.set_quality(JuiceConfig.Quality.HIGH)
	assert_not_null(FruitModels.fruit_material().next_pass, "Haut : contour")


## Chargement : ressources, scripts, scènes et shaders gardés pour la session
## (« Jouer » ne recharge rien du disque) ; shaders précompilés à l'export
## (sinon premier lancement très long sur Android d'entrée de gamme).
func test_loading_keeps_cache_and_bakes_shaders() -> void:
	var ls := LoadingScreen.new()
	add_child_autofree(ls)
	assert_true(ls._paths.has("res://scenes/Game.tscn"))
	assert_true(ls._paths.has("res://scripts/game.gd"), "scripts compilés au chargement")
	assert_true(ls._paths.has("res://assets/shaders/toon.gdshader"))
	assert_true(ls._paths.has("res://scripts/juice/juice.gd"), "sous-dossiers parcourus")
	var cf := ConfigFile.new()
	assert_eq(cf.load("res://export_presets.cfg"), OK)
	for sec in cf.get_sections():
		if sec.ends_with(".options"):
			assert_true(cf.get_value(sec, "shader_baker/enabled", false), "%s : shader baker" % sec)


func test_auto_quality_rules() -> void:
	assert_eq(VisualQuality.level_for(2.0, "Adreno (TM) 640"), JuiceConfig.Quality.LOW, "2 Go → Bas")
	assert_eq(VisualQuality.level_for(3.0, "Adreno (TM) 640"), JuiceConfig.Quality.MEDIUM)
	assert_eq(VisualQuality.level_for(8.0, "Adreno (TM) 740"), JuiceConfig.Quality.HIGH)
	assert_eq(VisualQuality.level_for(8.0, "Mali-G52 MC2"), JuiceConfig.Quality.LOW, "GPU faible")
	assert_eq(VisualQuality.resolve(JuiceConfig.Quality.MEDIUM), JuiceConfig.Quality.MEDIUM)
	assert_eq(VisualQuality.resolve(VisualQuality.AUTO), JuiceConfig.Quality.HIGH, "Auto = haut de gamme")
