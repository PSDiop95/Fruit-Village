extends GutTest
## V2-0.2 (TD-10) et V2-0.3 (TD-14) : récupération des sauvegardes suspectes,
## préservation des sections inconnues, enregistrement des systèmes.
## Fixtures : tests/fixtures/saves (make_fixtures.py).

const SAVE := "user://test_recovery_save.json"
const FIX := "res://tests/fixtures/saves/"
const ALL_SYSTEMS := ["wallet", "progression", "collection", "missions", "daily", "ads"]


class LateSystem:
	extends RefCounted
	var state: Dictionary = {}
	var loads: int = 0

	func save_state() -> Dictionary:
		return state

	func load_state(d: Dictionary) -> void:
		state = d.duplicate(true)
		loads += 1


var _events: Array = []


func before_each() -> void:
	SaveManager.erase_files(SAVE)
	SaveManager.use_path(SAVE)
	# Les signalements sont différés (une image) : on laisse partir ceux des
	# tests précédents avant d'écouter, sinon ils arrivent pendant ce test.
	await wait_process_frames(1)
	_events.clear()
	Analytics.event_logged.connect(_on_event)


func after_each() -> void:
	Analytics.event_logged.disconnect(_on_event)
	SaveManager.unregister_system("zz_late")
	SaveManager.erase_files(SAVE)
	SaveManager.use_path(SaveManager.DEFAULT_SAVE_PATH)


func _on_event(n: StringName, params: Dictionary, _sent: bool) -> void:
	_events.append([n, params])


func _install(fixture: String, dst: String = SAVE) -> PackedByteArray:
	var bytes := FileAccess.get_file_as_bytes(FIX + fixture)
	assert_gt(bytes.size(), 0, "fixture %s" % fixture)
	var f := FileAccess.open(dst, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	return bytes


func _read_saved() -> Dictionary:
	var res := SaveCodec.decode(FileAccess.get_file_as_string(SAVE))
	assert_eq(res["status"], SaveCodec.Status.OK, "fichier réécrit valide")
	return res["data"]


func _assert_valid_profile() -> void:
	assert_eq(SaveManager.best_score, 5230)
	assert_eq(SaveManager.best_rank, 7)
	assert_eq(SaveManager.games_played, 42)
	assert_eq(Wallet.coins(), 310)
	assert_eq(Wallet.stock_of(&"shake"), 2)
	assert_eq(Progression.core.xp, 1450)
	assert_true(Collection.has(7))
	assert_eq(DailyRewards.core.streak, 4)
	assert_eq(SaveManager.get_setting(&"music_on"), false)


# ---------------------------------------------------------------- Formats valides

func test_v1_fixture_migrates_and_keeps_copy() -> void:
	var bytes := _install("v1_valid.json")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.MIGRATED)
	assert_eq(SaveManager.best_score, 3100)
	assert_eq(SaveManager.games_played, 9)
	assert_true(Collection.has(6))
	assert_eq(FileAccess.get_file_as_bytes(SAVE + ".v1"), bytes, "copie v1 intacte")
	assert_true(FileAccess.get_file_as_string(SAVE).begins_with("FV2 "))
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.OK)
	assert_eq(SaveManager.best_score, 3100)


func test_v2_fixture_loads_everything() -> void:
	_install("v2_valid.sav")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.OK)
	assert_eq(SaveManager.recovery, SaveManager.Recovery.NONE)
	_assert_valid_profile()
	assert_eq(SaveManager.get_setting(&"language"), "en")


func test_incomplete_save_loads_known_fields() -> void:
	_install("incomplete.sav")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.OK)
	assert_eq(SaveManager.best_score, 800)
	assert_eq(Wallet.coins(), Wallet.economy.starting_coins)
	assert_eq(Progression.level(), 1)


func test_missing_sections_are_recreated() -> void:
	_install("missing_sections.sav")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.OK)
	assert_eq(SaveManager.best_score, 5230)
	SaveManager.save_data()
	var systems: Dictionary = _read_saved()["systems"]
	for k in ALL_SYSTEMS:
		assert_has(systems, k, "section %s écrite" % k)


func test_large_progression_roundtrip_is_exact() -> void:
	_install("large_progression.sav")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.OK)
	assert_eq(SaveManager.best_score, 98765)
	assert_eq(Wallet.coins(), 54000)
	assert_eq(Wallet.stock_of(&"shake"), 40)
	assert_eq(Progression.core.xp, 250000)
	assert_eq(Collection.count(), 11)
	SaveManager.save_data()
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.OK)
	assert_eq(SaveManager.best_score, 98765)
	assert_eq(Wallet.coins(), 54000)
	assert_eq(Progression.core.xp, 250000)
	assert_eq(Collection.count(), 11)


# ---------------------------------------------------------------- TD-14 : sections préservées

func test_unknown_sections_survive_writes() -> void:
	_install("large_progression.sav")
	SaveManager.use_path(SAVE)
	Wallet.earn(10)
	SaveManager.save_data()
	SaveManager.save_data()
	var data := _read_saved()
	assert_eq(data["systems"]["achievements"],
		{"unlocked": ["first_baobab", "combo_6"], "progress": {"mango": 87.0}},
		"section d'un système absent conservée à l'identique")
	assert_eq(data["core"]["settings"]["future_option"], "keep-me", "réglage inconnu conservé")
	assert_eq(int(data["core"]["lifetime_baobabs"]), 3, "champ inconnu de core conservé")
	assert_eq(int(data["systems"]["wallet"]["coins"]), 54010, "section connue à jour")


func test_every_registered_system_is_saved() -> void:
	SaveManager.save_data()
	var systems: Dictionary = _read_saved()["systems"]
	for k in ALL_SYSTEMS:
		assert_has(systems, k)


func test_late_registration_receives_preserved_section() -> void:
	_install("large_progression.sav")
	SaveManager.use_path(SAVE)
	Wallet.earn(5)
	SaveManager.save_data()  # écriture AVANT l'enregistrement du module
	var late := LateSystem.new()
	SaveManager.register_system("achievements", late)
	assert_eq(late.state["unlocked"], ["first_baobab", "combo_6"], "état remis au module tardif")
	late.state["unlocked"].append("hundred_mangoes")
	SaveManager.save_data()
	SaveManager.unregister_system("achievements")
	SaveManager.save_data()
	assert_eq(_read_saved()["systems"]["achievements"]["unlocked"].size(), 3,
		"retiré : dernier état gardé")


func test_absent_optional_system_gets_empty_state() -> void:
	var late := LateSystem.new()
	SaveManager.register_system("zz_late", late)
	assert_eq(late.loads, 1)
	assert_eq(late.state, {})
	late.state = {"n": 2}
	SaveManager.save_data()
	SaveManager.use_path(SAVE)
	assert_eq(int(late.state["n"]), 2, "rechargé au prochain chargement")


# ---------------------------------------------------------------- TD-10 : récupération

func test_corrupt_without_backup_keeps_copy() -> void:
	var bytes := _install("corrupt.sav")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.CORRUPT)
	assert_eq(SaveManager.recovery, SaveManager.Recovery.RESET)
	assert_eq(FileAccess.get_file_as_bytes(SAVE + ".corrupt"), bytes, "copie identique")
	assert_eq(FileAccess.get_file_as_bytes(SAVE), bytes, "original pas écrasé au chargement")


func test_corrupt_recovers_from_backup() -> void:
	_install("v2_valid.sav", SAVE + ".bak")
	_install("corrupt.sav")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.CORRUPT)
	assert_eq(SaveManager.recovery, SaveManager.Recovery.BACKUP)
	_assert_valid_profile()
	assert_eq(_read_saved()["core"]["best_score"], 5230.0, "fichier principal réparé")


func test_missing_main_recovers_from_backup() -> void:
	_install("v2_valid.sav", SAVE + ".bak")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.MISSING)
	assert_eq(SaveManager.recovery, SaveManager.Recovery.BACKUP)
	_assert_valid_profile()


func test_tampered_recovers_from_backup_and_quarantines() -> void:
	_install("v2_valid.sav", SAVE + ".bak")
	var bytes := _install("tampered.sav")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.TAMPERED)
	assert_eq(SaveManager.recovery, SaveManager.Recovery.BACKUP)
	_assert_valid_profile()
	assert_eq(FileAccess.get_file_as_bytes(SAVE + ".tampered"), bytes, "suspect conservé")
	var bak := SaveCodec.decode(FileAccess.get_file_as_string(SAVE + ".bak"))
	assert_eq(bak["status"], SaveCodec.Status.OK, "la copie de secours reste valide")
	assert_eq(int(bak["data"]["systems"]["wallet"]["coins"]), 310, "jamais remplacée par le suspect")


func test_tampered_without_backup_salvages_progress() -> void:
	_install("tampered.sav")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.TAMPERED)
	assert_eq(SaveManager.recovery, SaveManager.Recovery.SALVAGED)
	assert_eq(SaveManager.best_score, 5230, "progression conservée")
	assert_eq(Progression.core.xp, 1450)
	assert_true(Collection.has(7))
	assert_eq(Wallet.coins(), 310, "solde ramené à départ + gagné − dépensé, pas à zéro")
	assert_true(FileAccess.file_exists(SAVE + ".tampered"))
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.OK, "relu sans alerte")
	assert_eq(Wallet.coins(), 310)


func test_no_reward_duplication_after_backup_recovery() -> void:
	_install("v2_valid.sav")
	SaveManager.use_path(SAVE)
	var day := DailyRewards.core.last_claim_day
	# La copie de secours a une écriture de retard (coupure), le fichier
	# principal, abîmé, montre la récompense du lendemain déjà prise.
	var data := _read_saved()
	SaveCodec.write_atomic(SAVE + ".bak", SaveCodec.encode(data))
	data["systems"]["daily"]["last_claim_day"] = day + 1
	data["systems"]["daily"]["streak"] = 40
	var text := SaveCodec.encode(data)
	text = "FV2 %s%s" % ["0".repeat(24), text.substr(text.find("\n"))]  # checksum faux
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.recovery, SaveManager.Recovery.BACKUP)
	assert_eq(DailyRewards.core.last_claim_day, day + 1, "cadeau du jour déjà pris : pas deux fois")
	assert_eq(DailyRewards.core.streak, 4, "valeur gonflée ignorée")


func test_future_header_is_preserved_not_reset() -> void:
	var bytes := _install("future_header.sav")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.FUTURE)
	assert_eq(SaveManager.recovery, SaveManager.Recovery.SALVAGED)
	assert_eq(FileAccess.get_file_as_bytes(SAVE + ".future"), bytes, "original conservé")
	_assert_valid_profile()
	var data := _read_saved()
	assert_has(data["systems"], "achievements", "section inconnue gardée")
	assert_has(data, "cloud", "champ racine inconnu gardé")


func test_future_version_field_is_detected() -> void:
	_install("future_version.sav")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.FUTURE)
	assert_true(FileAccess.file_exists(SAVE + ".future"))
	_assert_valid_profile()


func test_writes_blocked_when_copy_cannot_be_secured() -> void:
	# Toutes les places de quarantaine prises par d'autres fichiers.
	for i in SaveManager.MAX_QUARANTINE:
		var p := SAVE + ".tampered" + ("" if i == 0 else "-%d" % (i + 1))
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string("autre %d" % i)
		f.close()
	var bytes := _install("tampered.sav")
	SaveManager.use_path(SAVE)
	assert_true(SaveManager.writes_blocked, "écritures suspendues")
	Wallet.earn(10)
	SaveManager.save_data()
	assert_eq(FileAccess.get_file_as_bytes(SAVE), bytes, "unique copie jamais écrasée")
	SaveManager.use_path(SAVE)  # relance : même situation, toujours rien d'effacé
	assert_eq(FileAccess.get_file_as_bytes(SAVE), bytes)


func test_integrity_issue_signalled_without_data() -> void:
	_install("v2_valid.sav", SAVE + ".bak")
	_install("tampered.sav")
	watch_signals(SaveManager)
	SaveManager.use_path(SAVE)
	await wait_process_frames(1)
	assert_signal_emitted_with_parameters(SaveManager, "integrity_issue",
		[SaveCodec.Status.TAMPERED, SaveManager.Recovery.BACKUP])
	var ev := _events.filter(func(e: Array) -> bool: return e[0] == &"save_recovery")
	assert_eq(ev.size(), 1)
	assert_eq(ev[0][1], {"status": "TAMPERED", "recovery": "BACKUP", "blocked": false},
		"état seulement, aucune valeur de la sauvegarde")


func test_normal_load_reports_nothing() -> void:
	_install("v2_valid.sav")
	watch_signals(SaveManager)
	SaveManager.use_path(SAVE)
	await wait_process_frames(1)
	assert_signal_not_emitted(SaveManager, "integrity_issue")


# ---------------------------------------------------------------- Règles pures

func test_codec_detects_future_versions() -> void:
	assert_eq(SaveCodec.header_version("FV3 abc\n{}"), 3)
	assert_eq(SaveCodec.header_version("FV2 abc\n{}"), 2)
	assert_eq(SaveCodec.header_version("{\"version\":1}"), 0)
	assert_eq(SaveCodec.decode("FV12 x\n{\"version\":12}")["status"], SaveCodec.Status.FUTURE)
	assert_eq(SaveCodec.decode("FV3 x\n{tronqué")["status"], SaveCodec.Status.CORRUPT)


func test_fence_only_keeps_restrictive_fields() -> void:
	var trusted := {"systems": {
		"daily": {"last_claim_day": 100, "last_shield_day": 50, "streak": 3},
		"wallet": {"coins": 10},
		"missions": {"day": 100, "active": [{"id": "a", "claimed": false, "doubled": false}]},
	}}
	var suspect := {"systems": {
		"daily": {"last_claim_day": 101, "last_shield_day": 9999, "streak": 99},
		"wallet": {"coins": 99999},
		"missions": {"day": 100, "active": [{"id": "a", "claimed": true, "doubled": true}]},
	}}
	var out := SaveRecovery.fence(trusted, suspect)
	assert_eq(out["systems"]["daily"]["last_claim_day"], 101)
	assert_eq(out["systems"]["daily"]["last_shield_day"], 50, "hors fenêtre : ignoré")
	assert_eq(out["systems"]["daily"]["streak"], 3)
	assert_eq(out["systems"]["wallet"]["coins"], 10)
	assert_true(out["systems"]["missions"]["active"][0]["claimed"])
	assert_eq(trusted["systems"]["daily"]["last_claim_day"], 100, "entrée non modifiée")


func test_salvage_bounds_wallet_and_reports_fields() -> void:
	var res := SaveRecovery.salvage({"core": "x", "systems": {"wallet": {"coins": 500,
		"earned": 100, "spent": 30}, "bad": 3}}, 20)
	var d: Dictionary = res["data"]
	assert_eq(d["systems"]["wallet"]["coins"], 90)
	assert_eq(d["core"], {})
	assert_false(d["systems"].has("bad"))
	assert_eq(res["issues"], ["core", "systems.bad", "wallet.coins"])
	assert_true(SaveRecovery.wallet_consistent({"coins": 90, "earned": 100, "spent": 30}, 20))
