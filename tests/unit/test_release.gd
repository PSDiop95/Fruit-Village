extends GutTest
## M5 : configuration de release (identifiants pub, presets d'export,
## secrets, désactivations debug). Le contrôle de l'AAB produit (manifeste,
## contenu du .pck) est fait par tools/check_build.sh.

const PRESETS := "res://export_presets.cfg"
const RELEASE_PRESET := "Android Release"
const IOS_PRESET := "iOS Release"
const REAL_IOS := {"app_id": "ca-app-pub-1234567890123456~9876543210",
	"rewarded_id": "ca-app-pub-1234567890123456/3333333333",
	"interstitial_id": "ca-app-pub-1234567890123456/4444444444"}
const PACKAGE := "com.smartiaservices.fruitvillage"
const REAL := {"app_id": "ca-app-pub-1234567890123456~1234567890",
	"rewarded_id": "ca-app-pub-1234567890123456/1111111111",
	"interstitial_id": "ca-app-pub-1234567890123456/2222222222"}

var config: AdsConfig = preload("res://data/ads.tres")


func _cfg(values: Dictionary) -> ConfigFile:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value(AdIds.SECTION, k, values[k])
	return cf


func _cfg_ios(values: Dictionary) -> ConfigFile:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value(AdIds.IOS, k, values[k])
	return cf


func _test_cfg() -> ConfigFile:
	return _cfg({"app_id": config.test_app_id, "rewarded_id": config.test_rewarded_id,
		"interstitial_id": config.test_interstitial_id})


func _presets() -> Dictionary:  # nom -> {section, options}
	var cf := ConfigFile.new()
	assert_eq(cf.load(PRESETS), OK, "export_presets.cfg lisible")
	var out := {}
	for s in cf.get_sections():
		if s.ends_with(".options"):
			continue
		var opts := {}
		for k in cf.get_section_keys(s + ".options"):
			opts[k] = cf.get_value(s + ".options", k)
		out[cf.get_value(s, "name")] = {"section": s, "cf": cf, "options": opts}
	return out


func _value(p: Dictionary, key: String) -> Variant:
	return (p["cf"] as ConfigFile).get_value(p["section"], key, "")


# ---------------------------------------------------------------- AdIds

func test_google_test_ids_are_test() -> void:
	for v in [config.test_app_id, config.test_rewarded_id, config.test_interstitial_id]:
		assert_true(AdIds.is_test_id(v), v)
		assert_false(AdIds.is_real_id(v), v)


func test_placeholders_are_not_real() -> void:
	assert_false(AdIds.is_real_id("ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"))
	assert_false(AdIds.is_real_id(""))
	assert_true(AdIds.is_real_id(REAL["app_id"]))


func test_debug_always_uses_test_ids_even_with_real_file() -> void:
	var ids := AdIds.resolve(config, true, _cfg(REAL))
	assert_true(ids["test"])
	for k in AdIds.KEYS:
		assert_true(AdIds.is_test_id(ids[k]), "debug %s = test" % k)
		assert_false(AdIds.is_real_id(ids[k]), "debug %s jamais réel" % k)


func test_release_uses_real_ids() -> void:
	var ids := AdIds.resolve(config, false, _cfg(REAL))
	assert_false(ids["test"])
	for k in AdIds.KEYS:
		assert_eq(ids[k], REAL[k])


func test_release_never_uses_test_ids() -> void:
	for cf in [_test_cfg(), null, _cfg({"app_id": "ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"})]:
		var ids := AdIds.resolve(config, false, cf)
		for k in AdIds.KEYS:
			assert_false(AdIds.is_test_id(ids[k]), "release %s sans test" % k)


func test_release_missing_unit_disables_format() -> void:
	var partial := REAL.duplicate()
	partial.erase("interstitial_id")
	var ids := AdIds.resolve(config, false, _cfg(partial))
	assert_eq(ids["interstitial_id"], "")
	assert_eq(ids["rewarded_id"], REAL["rewarded_id"])


## Le fichier local (embarqué en release) ne doit contenir que de vrais
## identifiants : sinon l'AAB contiendrait un identifiant de test.
func test_local_ads_ids_file_is_release_ready() -> void:
	var cf := AdIds.load_file()
	if cf == null:
		pending("ads_ids.cfg absent : build release impossible (voir ads_ids.example.cfg)")
		return
	for k in AdIds.KEYS:
		var v := str(cf.get_value(AdIds.ANDROID, k, ""))
		assert_true(AdIds.is_real_id(v), "ads_ids.cfg [android] %s : vrai identifiant" % k)
	if not cf.has_section(AdIds.IOS):
		pending("ads_ids.cfg : section [ios] absente (build iOS release impossible)")
		return
	for k in AdIds.KEYS:
		var v := str(cf.get_value(AdIds.IOS, k, ""))
		assert_true(AdIds.is_real_id(v), "ads_ids.cfg [ios] %s : vrai identifiant" % k)


## project.godot (versionné, lu par le plugin AdMob pour le manifeste) :
## App ID de test ; le vrai n'est posé qu'à l'export release (fv_release).
func test_project_app_id_is_test() -> void:
	var cf := ConfigFile.new()
	assert_eq(cf.load("res://project.godot"), OK)
	# Absent = valeur par défaut du plugin (App ID de test Google).
	var v := str(cf.get_value("admob", "general/android/app_id", AdIds.GOOGLE_TEST_APP_ID))
	assert_eq(v, AdIds.GOOGLE_TEST_APP_ID)
	var vi := str(cf.get_value("admob", "general/ios/app_id", AdIds.GOOGLE_TEST_IOS_APP_ID))
	assert_eq(vi, AdIds.GOOGLE_TEST_IOS_APP_ID)


func test_release_runtime_never_mock_ads() -> void:
	var src := FileAccess.get_file_as_string("res://autoload/AdsManager.gd")
	assert_string_contains(src, "elif OS.is_debug_build():\n\t\tp = MockAds.new()")


# ---------------------------------------------------------------- Presets

func test_release_preset() -> void:
	var all := _presets()
	assert_true(all.has(RELEASE_PRESET), "preset « %s »" % RELEASE_PRESET)
	if not all.has(RELEASE_PRESET):
		return
	var p: Dictionary = all[RELEASE_PRESET]
	var o: Dictionary = p["options"]
	assert_true(o["gradle_build/use_gradle_build"])
	assert_eq(o["gradle_build/export_format"], 1, "AAB")
	assert_eq(str(o["gradle_build/target_sdk"]), "36", "targetSdk Google Play")
	# Godot 4.7 + renderer Mobile (Vulkan 1.1) : 29 par défaut. Voir rapport M5.
	assert_eq(str(o["gradle_build/min_sdk"]), "29")
	assert_true(o["architectures/arm64-v8a"])
	assert_true(o["architectures/armeabi-v7a"])
	assert_false(o["architectures/x86"])
	assert_false(o["architectures/x86_64"])
	assert_eq(o["package/unique_name"], PACKAGE)
	assert_true(o["package/signed"])
	assert_true(str(_value(p, "include_filter")).contains("ads_ids.cfg"))
	assert_false(str(_value(p, "exclude_filter")).contains("ads_ids.cfg"))


func test_release_permissions_minimal() -> void:
	var all := _presets()
	if not all.has(RELEASE_PRESET):
		return
	var o: Dictionary = all[RELEASE_PRESET]["options"]
	var on: Array[String] = []
	for k in o:
		if k.begins_with("permissions/") and k != "permissions/custom_permissions" and o[k] == true:
			on.append(k.trim_prefix("permissions/"))
	on.sort()
	assert_eq(on, ["access_network_state", "internet", "vibrate"] as Array[String])
	assert_eq(Array(o["permissions/custom_permissions"]),
		["com.google.android.gms.permission.AD_ID"])


func test_debug_presets_never_embed_real_ids() -> void:
	for name in _presets():
		if name == RELEASE_PRESET or name == IOS_PRESET:
			continue
		var p: Dictionary = _presets()[name]
		assert_false(str(_value(p, "include_filter")).contains("ads_ids.cfg"), name)
		assert_true(str(_value(p, "exclude_filter")).contains("ads_ids.cfg"), name)


func test_no_secret_in_presets() -> void:
	var text := FileAccess.get_file_as_string(PRESETS)
	for key in ["keystore/release_password", "keystore/release_user", "keystore/release=",
			"keystore/debug_password"]:
		for line in text.split("\n"):
			if line.begins_with(key):
				assert_true(line.ends_with("=\"\""), "pas de secret : %s" % line)
	assert_false(text.contains(".keystore"), "aucun chemin de keystore")
	assert_false(text.contains(".jks"), "aucun chemin de keystore")


# ---------------------------------------------------------------- iOS

func test_ios_debug_uses_ios_test_ids() -> void:
	var ids := AdIds.resolve(config, true, _cfg_ios(REAL_IOS), AdIds.IOS)
	assert_eq(ids["app_id"], AdIds.GOOGLE_TEST_IOS_APP_ID)
	for k in AdIds.KEYS:
		assert_true(AdIds.is_test_id(ids[k]), "debug iOS %s = test" % k)
		assert_ne(ids[k], AdIds.test_ids(config)[k], "iOS : identifiants de test iOS, pas Android")


func test_ios_release_reads_ios_section_only() -> void:
	var cf := _cfg(REAL)  # [android] seul
	var ids := AdIds.resolve(config, false, cf, AdIds.IOS)
	for k in AdIds.KEYS:
		assert_eq(ids[k], "", "iOS sans section [ios] : format désactivé")
	cf = _cfg_ios(REAL_IOS)
	ids = AdIds.resolve(config, false, cf, AdIds.IOS)
	for k in AdIds.KEYS:
		assert_eq(ids[k], REAL_IOS[k])
	assert_eq(AdIds.resolve(config, false, cf, AdIds.ANDROID)["app_id"], "", "pas de croisement")


func test_ios_preset() -> void:
	var all := _presets()
	assert_true(all.has(IOS_PRESET), "preset « %s »" % IOS_PRESET)
	if not all.has(IOS_PRESET):
		return
	var p: Dictionary = all[IOS_PRESET]
	var o: Dictionary = p["options"]
	assert_eq(o["application/bundle_identifier"], PACKAGE)
	assert_eq(o["application/targeted_device_family"], 2, "iPhone et iPad")
	assert_true(o["application/export_project_only"], "compilation : xcodebuild (CI)")
	assert_eq(o["application/app_store_team_id"], "", "équipe Apple : secret de CI, jamais versionné")
	var plist := str(o["application/additional_plist_content"])
	assert_string_contains(plist, "NSUserTrackingUsageDescription")
	assert_string_contains(plist, "<key>ITSAppUsesNonExemptEncryption</key><false/>")
	assert_string_contains(plist, "<key>UIRequiresFullScreen</key><true/>")
	# NSPrivacyTracking à true exige des NSPrivacyTrackingDomains, que iOS bloque
	# sans accord ATT (plus de pubs) ; sans domaines, Apple invalide le binaire
	# (ITMS-91064, build 22). Le SDK Google déclare son suivi dans son manifeste.
	assert_false(o["privacy/tracking_enabled"], "NSPrivacyTracking false (ITMS-91064)")
	assert_eq(Array(o["privacy/tracking_domains"]), [], "aucun domaine de suivi")
	# Pas de Firebase sur iOS en 1.0 : les xcframeworks du plugin godotx ne sont
	# pas signés par Google (refus automatique Apple ITMS-91065 / 91061).
	assert_false(o["plugins/GodotxFirebaseCore"], "pas de Firebase iOS (SDK non signés)")
	assert_false(o["plugins/GodotxFirebaseAnalytics"], "pas de Firebase iOS (SDK non signés)")
	# Game Center activé sur l'app dans App Store Connect : Apple refuse le
	# binaire sans ce droit (« INVALID_BINARY »), même sans fonction Game Center.
	assert_true(o["entitlements/game_center"], "droit Game Center")
	# Godot écrit ces clés même vides ; vides, Apple invalide le binaire (ITMS-90683).
	for key in ["camera", "microphone", "photolibrary"]:
		assert_ne(str(o.get("privacy/%s_usage_description" % key, "")), "", "texte %s requis" % key)
	assert_true(str(_value(p, "include_filter")).contains("ads_ids.cfg"))
	assert_true(str(_value(p, "exclude_filter")).contains("GoogleService-Info.plist"))
	var icon := Image.load_from_file(ProjectSettings.globalize_path(o["icons/icon_1024x1024"]))
	assert_eq(icon.get_size(), Vector2i(1024, 1024))
	assert_false(icon.detect_alpha() != Image.ALPHA_NONE, "icône App Store opaque")


## Le plugin AdMob iOS lit l'App ID dans son _export_begin : _fv_release doit
## être chargé avant lui (l'éditeur trie la liste par ordre alphabétique).
func test_release_plugin_loads_before_admob() -> void:
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled")
	var sorted := enabled.duplicate()
	sorted.sort()
	assert_eq(sorted, enabled, "liste triée (comme l'éditeur l'écrit)")
	assert_lt(enabled.find("res://addons/_fv_release/plugin.cfg"),
		enabled.find("res://addons/admob/plugin.cfg"))


func test_screen_fit_letterbox_rules() -> void:
	assert_false(ScreenFit.needs_letterbox(Vector2(1179, 2556)), "iPhone : plein écran, zone sûre")
	assert_true(ScreenFit.needs_letterbox(Vector2(2064, 2752)), "iPad")
	assert_true(ScreenFit.needs_letterbox(Vector2(1600, 2560)), "tablette Android")
	assert_false(ScreenFit.needs_letterbox(Vector2(1080, 2408)), "téléphone Android : inchangé")
	assert_false(ScreenFit.needs_letterbox(Vector2(1080, 1920)))
	assert_false(ScreenFit.needs_letterbox(Vector2.ZERO))


## iPhone : interface et cadrage dans la zone sûre, décor plein écran ; le
## panier y occupe la même place qu'en 9:16 sans encoche.
func test_safe_area_layout() -> void:
	var saved := ScreenFit.safe_insets
	var vp := SubViewport.new()
	vp.size = Vector2i(1080, 2341)  # iPhone 6,1" au canevas de 1080 de large
	add_child_autofree(vp)
	var cfg: GameConfig = load("res://data/game_config.tres")
	ScreenFit.safe_insets = Vector2.ZERO
	assert_eq(ScreenFit.safe_rect(vp), Rect2(0, 0, 1080, 2341), "sans encoche : écran entier")
	var cam_full := Game.camera_y(cfg, vp)
	assert_almost_eq(cam_full, Game.camera_center_y(cfg, 2341.0 / 1080.0), 0.0001)
	ScreenFit.safe_insets = ScreenFit.IPHONE_INSETS
	var safe := ScreenFit.safe_rect(vp)
	assert_almost_eq(safe.position.y, 2341.0 * 59.0 / 852.0, 0.01, "sous la Dynamic Island")
	assert_almost_eq(safe.end.y, 2341.0 * (1.0 - 34.0 / 852.0), 0.01, "au-dessus de la barre d'accueil")
	# Le bas du panier (y = 0 dans le monde) tombe au même endroit de la zone
	# sûre que sur un écran de la taille de cette zone, sans encoche.
	var w := cfg.basket_inner_width + cfg.wall_thickness * 2.0 + cfg.camera_side_margin
	var ppm := 1080.0 / w
	var floor_on_screen := 2341.0 * 0.5 + Game.camera_y(cfg, vp) * ppm
	var floor_in_safe := TitleScreen.basket_screen_rect(safe.size).end.y
	assert_almost_eq(floor_on_screen - safe.position.y, floor_in_safe, 0.5)
	ScreenFit.safe_insets = saved

# ---------------------------------------------------------------- Debug off

func test_release_disables_stdout() -> void:
	assert_true(ProjectSettings.get_setting("application/run/disable_stdout.release", false))


func test_debug_menu_and_fps_debug_only() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/juice/juice.gd")
	assert_string_contains(src, "show_fps = OS.is_debug_build() and")
	assert_string_contains(src, "if OS.is_debug_build():\n\t\t_debug = DebugMenu.new()")
	assert_true(FileAccess.get_file_as_string("res://scripts/debug/perf_probe.gd").contains(
		"return OS.is_debug_build() and"))


func test_secrets_are_git_ignored() -> void:
	var gi := FileAccess.get_file_as_string("res://.gitignore")
	for pat in ["ads_ids.cfg", "export_credentials.cfg", "*.keystore", "*.jks",
			"google-services.json", "GoogleService-Info.plist", "/ios/", "*.p8"]:
		assert_true(gi.split("\n").has(pat), ".gitignore : %s" % pat)
