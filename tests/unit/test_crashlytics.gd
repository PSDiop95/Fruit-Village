extends GutTest
## V2-0.4 : Crashlytics (option A, Android). Plugin simulé : initialisation
## après Core, collecte liée au consentement, aucune donnée personnelle,
## plantage de test réservé aux builds debug, configuration d'export.

const PRESETS := "res://export_presets.cfg"


class FakeCore extends RefCounted:
	signal core_initialized(ok: bool)
	var calls: int = 0

	func initialize() -> void:
		calls += 1


class FakeCrashlytics extends RefCounted:
	signal crashlytics_initialized(ok: bool)
	signal crashlytics_error(message: String)
	var log: Array = []

	func initialize() -> void:
		log.append(["initialize"])

	func set_crashlytics_collection_enabled(on: bool) -> void:
		log.append(["collection", on])

	func log_message(m: String) -> void:
		log.append(["log", m])

	func set_custom_value_string(k: String, v: String) -> void:
		log.append(["key", k, v])

	func set_custom_value_int(k: String, v: int) -> void:
		log.append(["key", k, v])

	func set_custom_value_bool(k: String, v: bool) -> void:
		log.append(["key", k, v])

	func set_custom_value_float(k: String, v: float) -> void:
		log.append(["key", k, v])

	func set_user_id(_id: String) -> void:
		log.append(["user_id"])

	func crash() -> void:
		log.append(["crash"])

	func names() -> Array:
		return log.map(func(e: Array) -> String: return e[0])


var _saved_crash: CrashReporter
var _saved_consent: bool
var _saved_setting: bool


func before_each() -> void:
	_saved_crash = Analytics.crash
	_saved_consent = Analytics.consent_granted
	_saved_setting = bool(SaveManager.get_setting(&"analytics_on"))
	FirebaseBoot.reset()
	CrashReporter.singleton_override = null


func after_each() -> void:
	CrashReporter.singleton_override = null
	FirebaseBoot.reset()
	SaveManager.set_setting(&"analytics_on", _saved_setting)
	Analytics.consent_granted = _saved_consent
	Analytics.use_crash_reporter(_saved_crash)


func _ready_reporter() -> Array:
	var core := FakeCore.new()
	var fc := FakeCrashlytics.new()
	FirebaseBoot.core_override = core
	CrashReporter.singleton_override = fc
	var r := CrashReporter.new()
	return [r, fc, core]


func test_without_plugin_everything_is_inert() -> void:
	var r := CrashReporter.new()
	assert_false(CrashReporter.available(), "PC / tests : pas de singleton")
	assert_false(r.is_active())
	r.set_collection_enabled(true)
	r.log_message("x")
	r.set_key("k", 1)
	assert_false(r.test_crash(), "rien à faire planter sans plugin")


func test_initialized_after_core_only_once() -> void:
	var parts := _ready_reporter()
	var fc: FakeCrashlytics = parts[1]
	var core: FakeCore = parts[2]
	assert_eq(fc.log, [], "Core pas prêt : rien")
	FirebaseBoot.when_ready(func(_ok: bool) -> void: pass)  # autre module (Analytics) en attente
	core.core_initialized.emit(true)
	assert_eq(core.calls, 1, "Core initialisé une seule fois")
	assert_eq(fc.names(), ["initialize"])


func test_core_failure_keeps_crashlytics_off() -> void:
	var parts := _ready_reporter()
	var fc: FakeCrashlytics = parts[1]
	(parts[2] as FakeCore).core_initialized.emit(false)
	assert_eq(fc.log, [], "pas d'initialisation si Core échoue")
	assert_false((parts[0] as CrashReporter).test_crash())


func test_collection_follows_consent_and_setting() -> void:
	var parts := _ready_reporter()
	var r: CrashReporter = parts[0]
	var fc: FakeCrashlytics = parts[1]
	(parts[2] as FakeCore).core_initialized.emit(true)
	Analytics.consent_granted = false
	Analytics.use_crash_reporter(r)
	fc.crashlytics_initialized.emit(true)
	assert_eq(fc.log.back(), ["collection", false], "sans consentement : coupée")
	r.log_message("avant consentement")
	assert_false(fc.names().has("log"), "rien journalisé sans consentement")
	Analytics.set_consent(true)
	SaveManager.set_setting(&"analytics_on", true)
	assert_eq(fc.log.back(), ["collection", true], "consentement + réglage : activée")
	SaveManager.set_setting(&"analytics_on", false)
	assert_eq(fc.log.back(), ["collection", false], "réglage « Statistiques » coupé : désactivée")


func test_breadcrumbs_are_event_names_only() -> void:
	var parts := _ready_reporter()
	var r: CrashReporter = parts[0]
	var fc: FakeCrashlytics = parts[1]
	(parts[2] as FakeCore).core_initialized.emit(true)
	fc.crashlytics_initialized.emit(true)
	Analytics.use_crash_reporter(r)
	Analytics.set_consent(true)
	SaveManager.set_setting(&"analytics_on", true)
	Analytics.log_event(&"game_over", {"score": 1234, "max_rank": 7})
	var logs := fc.log.filter(func(e: Array) -> bool: return e[0] == "log")
	assert_eq(logs, [["log", "game_over"]], "nom d'événement seul, aucun paramètre")
	r.log_message("x".repeat(500))
	assert_eq((fc.log.back()[1] as String).length(), CrashReporter.MAX_LOG, "message tronqué")
	r.set_key("quality", 2)
	assert_eq(fc.log.back(), ["key", "quality", 2])
	assert_false(fc.names().has("user_id"), "jamais d'identifiant utilisateur")


func test_test_crash_only_in_debug_builds() -> void:
	var parts := _ready_reporter()
	var r: CrashReporter = parts[0]
	var fc: FakeCrashlytics = parts[1]
	assert_false(r.test_crash(), "SDK pas prêt : refusé")
	(parts[2] as FakeCore).core_initialized.emit(true)
	fc.crashlytics_initialized.emit(true)
	assert_eq(CrashReporter.test_crash_allowed(), OS.is_debug_build())
	assert_true(r.test_crash(), "build debug (tests) : autorisé")
	assert_eq(fc.log.back(), ["crash"])


func test_source_never_sets_user_id_and_guards_test_crash() -> void:
	for path in ["res://scripts/analytics/crash_reporter.gd", "res://autoload/Analytics.gd",
			"res://scripts/juice/debug_menu.gd"]:
		var src := FileAccess.get_file_as_string(path)
		assert_false(src.contains("set_user_id"), "%s : aucun identifiant utilisateur" % path)
	var reporter := FileAccess.get_file_as_string("res://scripts/analytics/crash_reporter.gd")
	assert_string_contains(reporter, "if not test_crash_allowed()")
	var menu := FileAccess.get_file_as_string("res://scripts/juice/debug_menu.gd")
	assert_string_contains(menu, "if CrashReporter.test_crash_allowed():")


func test_export_config_for_crashlytics() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(PRESETS), OK)
	var android_firebase := 0
	for s in cfg.get_sections():
		if not s.ends_with(".options"):
			continue
		var preset := s.trim_suffix(".options")
		var platform := str(cfg.get_value(preset, "platform", ""))
		var core := bool(cfg.get_value(s, "firebase/enable_core", false))
		if platform == "Android" and core:
			android_firebase += 1
			assert_true(cfg.get_value(s, "firebase/enable_crashlytics", false),
				"%s : Crashlytics activé" % preset)
			assert_ne(cfg.get_value(s, "firebase/privacy_safe_defaults", true), false,
				"%s : collecte coupée jusqu'au consentement" % preset)
		if platform == "iOS":
			assert_false(cfg.has_section_key(s, "plugins/GodotxFirebaseCrashlytics")
				and cfg.get_value(s, "plugins/GodotxFirebaseCrashlytics"),
				"iOS : Crashlytics non activé (option C non autorisée)")
	assert_eq(android_firebase, 2, "presets AdMob test et Release")
	for v in ["debug", "release"]:
		assert_true(FileAccess.file_exists(
			"res://android/firebase_crashlytics/firebase_crashlytics.%s.aar" % v), "AAR %s" % v)
	var gradle := FileAccess.get_file_as_string("res://android/build/build.gradle")
	assert_string_contains(gradle, "com.google.firebase:firebase-crashlytics-gradle:")
	assert_string_contains(gradle, "apply plugin: 'com.google.firebase.crashlytics'")
	assert_false(gradle.contains("crashlytics-ndk"), "pas de NDK (option B non retenue)")
	var common := FileAccess.get_file_as_string("res://tools/android_common.sh")
	assert_string_contains(common, "apply plugin: 'com.google.firebase.crashlytics'",
		"gabarit réinstallé : plugin réappliqué")
