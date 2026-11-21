extends GutTest
## V2-0.1 : localisation FR/EN. Détection de la langue, repli français,
## choix manuel persistant, complétude des traductions, actualisation à chaud
## des écrans.

const MainScene := preload("res://scenes/Main.tscn")
const CSV_PATH := "res://localization/translations.csv"
const SAVE_PATH := "user://test_locale_save.json"
## Clés littérales dans le code qui ne sont pas des clés de traduction.
const NON_KEYS := ["FV2_", "ADS_IDS", "AD_GLYPH"]
## Textes identiques en FR et EN admis (noms propres, mots communs).
const SAME_TEXT_OK := ["Missions", "Album", "Score", "Combo", "OK", "Ok", "Menu",
	"Pause", "Record", "Fruit Village"]

var _rows: Dictionary = {}  # clé -> [fr, en]


func before_all() -> void:
	_rows = _read_csv()


func before_each() -> void:
	SaveManager.erase_files(SAVE_PATH)
	SaveManager.use_path(SAVE_PATH)
	Locale.system_locale_override = "fr_FR"
	Locale.apply()


func after_each() -> void:
	get_tree().paused = false
	Locale.system_locale_override = "fr_FR"
	SaveManager.erase_files(SAVE_PATH)
	SaveManager.use_path(SaveManager.DEFAULT_SAVE_PATH)
	Locale.apply()


static func _read_csv() -> Dictionary:
	var out := {}
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	var header := f.get_csv_line()
	assert(header[0] == "keys")
	while not f.eof_reached():
		var line := f.get_csv_line()
		if line.size() < 3 or line[0].is_empty():
			continue
		out[line[0]] = [line[1], line[2]]
	return out


# ---------------------------------------------------------------- Choix de la langue

func test_normalize_codes() -> void:
	assert_eq(LocaleCore.normalize("en_US"), "en")
	assert_eq(LocaleCore.normalize("EN-gb"), "en")
	assert_eq(LocaleCore.normalize("fr"), "fr")
	assert_eq(LocaleCore.normalize(" "), "")


func test_french_is_default() -> void:
	assert_eq(LocaleCore.DEFAULT, "fr")
	assert_eq(LocaleCore.resolve(LocaleCore.AUTO, ""), "fr", "aucune info : français")
	assert_eq(ProjectSettings.get_setting("internationalization/locale/fallback"), "fr")
	assert_eq(SaveManager.DEFAULT_SETTINGS[&"language"], LocaleCore.AUTO)


func test_system_language_detected() -> void:
	assert_eq(LocaleCore.resolve(LocaleCore.AUTO, "en_US"), "en")
	assert_eq(LocaleCore.resolve(LocaleCore.AUTO, "fr_SN"), "fr")
	Locale.system_locale_override = "en_GB"
	Locale.apply()
	assert_eq(Locale.language, "en")
	assert_eq(TranslationServer.get_locale(), "en")
	assert_eq(Loc.t("MENU_PLAY"), "Play")


func test_unknown_language_falls_back_to_french() -> void:
	for sys in ["wo_SN", "de_DE", "ja_JP", "zz", ""]:
		assert_eq(LocaleCore.resolve(LocaleCore.AUTO, sys), "fr", sys)
	Locale.system_locale_override = "de_DE"
	Locale.apply()
	assert_eq(Locale.language, "fr")
	assert_eq(Loc.t("MENU_PLAY"), "Jouer")


func test_manual_choice_wins_over_system() -> void:
	Locale.system_locale_override = "en_US"
	Locale.set_language("fr")
	assert_eq(Locale.language, "fr", "choix explicite prioritaire")
	assert_eq(LocaleCore.resolve("en", "fr_FR"), "en")
	assert_eq(LocaleCore.resolve("xx", "en_US"), "en", "préférence invalide ignorée")


func test_unsupported_choice_reverts_to_auto() -> void:
	Locale.set_language("de")
	assert_eq(Locale.preference(), LocaleCore.AUTO)
	assert_eq(Locale.language, "fr")


func test_choice_persists_and_reloads() -> void:
	Locale.set_language("en")
	assert_eq(Locale.language, "en")
	# Relance : relecture du disque, langue système différente.
	TranslationServer.set_locale("fr")
	SaveManager.use_path(SAVE_PATH)
	assert_eq(SaveManager.get_setting(&"language"), "en")
	assert_eq(Locale.language, "en", "rechargée au lancement")
	assert_eq(TranslationServer.get_locale(), "en")
	Locale.set_language("fr")
	SaveManager.use_path(SAVE_PATH)
	assert_eq(Locale.language, "fr")


func test_changed_signal_only_on_real_change() -> void:
	watch_signals(Locale)
	Locale.set_language("fr")
	assert_signal_not_emitted(Locale, "changed")
	Locale.set_language("en")
	assert_signal_emitted_with_parameters(Locale, "changed", ["en"])


func test_plural_forms() -> void:
	assert_eq(LocaleCore.plural_form("fr", 0), "ONE")
	assert_eq(LocaleCore.plural_form("fr", 1), "ONE")
	assert_eq(LocaleCore.plural_form("fr", 2), "OTHER")
	assert_eq(LocaleCore.plural_form("en", 0), "OTHER")
	assert_eq(LocaleCore.plural_form("en", 1), "ONE")
	assert_eq(LocaleCore.plural_form("en", 5), "OTHER")


# ---------------------------------------------------------------- Complétude

func test_csv_has_no_missing_translation() -> void:
	assert_gt(_rows.size(), 150)
	for k in _rows:
		assert_true(k.to_upper() == k and not k.contains(" "), "clé stable : %s" % k)
		assert_false(_rows[k][0].strip_edges().is_empty(), "FR manquant : %s" % k)
		assert_false(_rows[k][1].strip_edges().is_empty(), "EN manquant : %s" % k)


func test_placeholders_match_between_languages() -> void:
	var re := RegEx.create_from_string("%[-0-9.]*[sdif%]")
	for k in _rows:
		var a := re.search_all(_rows[k][0]).map(func(m: RegExMatch) -> String: return m.get_string())
		var b := re.search_all(_rows[k][1]).map(func(m: RegExMatch) -> String: return m.get_string())
		assert_eq(b, a, "formats identiques FR/EN : %s" % k)


func test_translations_are_loaded_for_every_key() -> void:
	for lang in ["fr", "en"]:
		TranslationServer.set_locale(lang)
		var col := 0 if lang == "fr" else 1
		for k in _rows:
			assert_eq(Loc.t(k), _rows[k][col].replace("\\n", "\n"), "%s/%s" % [lang, k])
	TranslationServer.set_locale(Locale.language)


func test_every_key_used_in_code_exists() -> void:
	var re := RegEx.create_from_string("\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	var missing := []
	for path in _scripts(["res://scripts", "res://autoload"]):
		var src := FileAccess.get_file_as_string(path)
		for m in re.search_all(src):
			var key := m.get_string(1)
			if key in _rows or (key + "_ONE" in _rows and key + "_OTHER" in _rows) \
					or NON_KEYS.any(func(p: String) -> bool: return key.begins_with(p)):
				continue
			missing.append("%s (%s)" % [key, path.get_file()])
	assert_eq(missing, [], "clés utilisées absentes du CSV")


func test_data_keys_exist() -> void:
	var keys: Array[String] = []
	var fruits: FruitCatalog = load("res://data/fruits.tres")
	for d in fruits.fruits:
		for field in ["NAME", "FACT", "GOAL", "COUNT_ONE", "COUNT_OTHER"]:
			keys.append(String(Loc.data_key("FRUIT", d.id, field)))
	var lore: FruitsLore = load("res://data/fruits_lore.tres")
	for e in lore.entries:
		keys.append(String(Loc.data_key("LORE", e.id, "TEXT")))
		if not e.benefits.is_empty():
			keys.append(String(Loc.data_key("LORE", e.id, "BENEFITS")))
	var pcfg: PowerupsConfig = load("res://data/powerups.tres")
	for p in pcfg.powerups:
		keys.append(Loc.powerup_key(p.id, "NAME"))
		keys.append(Loc.powerup_key(p.id, "DESC"))
	for a in Ambiances.load_default().list:
		keys.append(String(Loc.data_key("AMBIANCE", a.id, "SHORT")))
	for kind in MissionDef.Kind.values():
		keys.append(Missions.kind_key(kind) + "_ONE")
		keys.append(Missions.kind_key(kind) + "_OTHER")
	for f in [ProgressionCore.MISSIONS, ProgressionCore.POWERUPS, ProgressionCore.DAILY,
			ProgressionCore.ALBUM]:
		keys.append(MetaUi.feature_key(f))
	for q in [VisualQuality.AUTO, 0, 1, 2]:
		keys.append(VisualQuality.label_key(q))
	for lang in LocaleCore.SUPPORTED:
		keys.append("LANGUAGE_NAME_" + lang.to_upper())
	for k in keys:
		assert_has(_rows, k, "clé de donnée : %s" % k)


func test_french_text_matches_data_reference() -> void:
	var fruits: FruitCatalog = load("res://data/fruits.tres")
	for d in fruits.fruits:
		assert_eq(_rows[String(Loc.fruit_name_key(d.id))][0], d.display_name, String(d.id))
	var pcfg: PowerupsConfig = load("res://data/powerups.tres")
	for p in pcfg.powerups:
		assert_eq(_rows[Loc.powerup_key(p.id, "NAME")][0], p.display_name, String(p.id))
	var lore: FruitsLore = load("res://data/fruits_lore.tres")
	for e in lore.entries:
		assert_eq(_rows[String(Loc.fruit_name_key(e.id))][1], e.name_en, "nom anglais %s" % e.id)


func test_notifications_follow_language() -> void:
	var cfg: DailyRewardsConfig = load("res://data/daily_rewards.tres")
	var clock := MetaClock.new()
	Locale.set_language("en")
	var plan := NotificationPlanner.plan(clock, cfg, false, 3)
	assert_gt(plan.size(), 0)
	for n in plan:
		assert_true(n["title"] in [_rows["NOTIF_TITLE"][1]], "titre EN")
		assert_true(n["text"] in [_rows["NOTIF_REMINDER"][1], _rows["NOTIF_STREAK"][1]], "texte EN")


static func _scripts(dirs: Array) -> Array[String]:
	var out: Array[String] = []
	for d in dirs:
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				out.append(d.path_join(f))
		for sub in DirAccess.get_directories_at(d):
			out.append_array(_scripts([d.path_join(sub)]))
	return out


# ---------------------------------------------------------------- Actualisation

func test_bound_label_refreshes_live() -> void:
	var l := Label.new()
	add_child_autofree(l)
	Loc.set_text(l, "MENU_PLAY")
	var c := Label.new()
	add_child_autofree(c)
	Loc.set_plural(c, "DAILY_STREAK", 3)
	assert_eq(l.text, "Jouer")
	var fr_plural := c.text
	Locale.set_language("en")
	assert_eq(l.text, "Play", "re-traduit sans relance")
	assert_ne(c.text, fr_plural, "pluriel re-traduit")
	assert_string_contains(c.text, "3")
	Locale.set_language("fr")
	assert_eq(l.text, "Jouer")


## Textes visibles sous `root` encore en français alors que l'anglais est actif.
func _french_leftovers(root: Node) -> Array:
	var fr_only := {}
	for k in _rows:
		var fr: String = _rows[k][0].replace("\\n", "\n")
		if fr != _rows[k][1].replace("\\n", "\n") and not fr in SAME_TEXT_OK and fr.length() > 2:
			fr_only[fr] = k
	var out := []
	for n in root.find_children("*", "", true, false):
		if not (n is Label or n is Button) or not (n as CanvasItem).is_visible_in_tree():
			continue
		if _in_dev_tool(n):
			continue
		var text: String = n.text
		if text.is_empty():
			continue
		for fr in fr_only:
			# Phrase entière ou fragment de phrase (jamais un mot seul :
			# « Tamarind » contient « Tamarin »).
			if text == fr or (fr.contains(" ") and fr.length() > 8 and not fr.contains("%")
					and text.contains(fr)):
				out.append("%s : « %s »" % [n.name, text])
				break
	return out


func test_title_and_settings_switch_to_english_live() -> void:
	var m: Main = MainScene.instantiate()
	add_child_autofree(m)
	await wait_process_frames(2)
	var s := m.title.open_settings()
	await wait_process_frames(1)
	assert_eq(m.title.play_button.text, "Jouer")
	assert_eq(s.language_buttons.size(), 2, "sélecteur FR / EN dans l'en-tête des réglages")
	s.language_buttons[1].pressed.emit()  # English
	await wait_process_frames(1)
	assert_eq(SaveManager.get_setting(&"language"), "en")
	assert_eq(m.title.play_button.text, "Play")
	assert_eq(_french_leftovers(m), [], "titre + réglages en anglais")
	s.language_buttons[0].pressed.emit()
	await wait_process_frames(1)
	assert_eq(m.title.play_button.text, "Jouer")


func test_english_screens_have_no_french_text() -> void:
	Locale.set_language("en")
	var m: Main = MainScene.instantiate()
	add_child_autofree(m)
	await wait_process_frames(2)
	for f in [ProgressionCore.MISSIONS, ProgressionCore.DAILY, ProgressionCore.ALBUM]:
		var modal := m.title.open_feature(f)
		await wait_process_frames(1)
		assert_eq(_french_leftovers(m), [], "panneau %s en anglais" % f)
		if is_instance_valid(modal):
			modal.queue_free()
		await wait_process_frames(1)
	m.start_game()
	await wait_process_frames(2)
	var hud := m.game.hud()
	assert_eq(_french_leftovers(m), [], "HUD en anglais")
	hud.open_pause()
	assert_eq(_french_leftovers(m), [], "pause en anglais")
	hud.close_pause()
	m.game._end_game()
	await wait_process_frames(2)
	assert_eq(_french_leftovers(m), [], "fin de partie en anglais")


## Outils de développement exclus de la traduction (jamais en release) :
## menu debug (OS.is_debug_build), régies publicitaires/consentement simulées.
static func _in_dev_tool(n: Node) -> bool:
	var p := n
	while p != null:
		if p is DebugMenu or p is MockAdOverlay or p is MockConsentDialog:
			return true
		p = p.get_parent()
	return false


## La carte Réglages (avec la ligne Langue) tient dans l'écran 9:16 de
## référence, en français comme en anglais.
func test_settings_card_fits_portrait_screen() -> void:
	var h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	for lang in ["fr", "en"]:
		Locale.set_language(lang)
		var p := SettingsPanel.new()
		var c := SettingsPanel.centered(p)
		add_child_autofree(c)
		await wait_process_frames(3)
		gut.p("Réglages %s : %.0f px / %.0f" % [lang, p.size.y, h])
		# V1 : 1899 px. La langue (en-tête) n'ajoute aucune hauteur.
		assert_lte(p.size.y, 1899.0, "pas plus haute qu'en V1 (%s)" % lang)
		assert_lt(p.size.y, h, "carte entière visible (%s)" % lang)
		c.queue_free()
