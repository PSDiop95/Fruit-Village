extends GutTest
## M4 : intégration (vraie scène de jeu, autoloads, pubs simulées pilotées).

const GameScene := preload("res://scenes/Game.tscn")
const SAVE := "user://test_meta_save.json"

var mock: MockAds
var analytics: MemoryAnalytics


func _wipe() -> void:
	for suffix in ["", ".tmp", ".corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE + suffix))


func before_each() -> void:
	_wipe()
	SaveManager.use_path(SAVE)
	analytics = MemoryAnalytics.new()
	Analytics.use_backend(analytics)
	mock = MockAds.new()
	mock.manual = true
	mock.interactive = false
	AdsManager.use_provider(mock)
	await wait_process_frames(2)  # consentement (différé)


func after_each() -> void:
	get_tree().paused = false
	AudioServer.set_bus_mute(0, false)
	_wipe()


func after_all() -> void:
	SaveManager.use_path(SaveManager.DEFAULT_SAVE_PATH)
	var m := MockAds.new()
	m.interactive = false
	AdsManager.use_provider(m)


func _ready_rewarded() -> void:
	mock.complete_load(AdProvider.REWARDED)


# ---------------------------------------------------------------- Rewarded

func test_rewarded_button_hidden_until_loaded() -> void:
	assert_true(AdsManager.can_request, "consentement accordé (mock)")
	assert_false(AdsManager.is_rewarded_ready(AdsConfig.CONTINUE), "aucune pub : bouton masqué")
	_ready_rewarded()
	assert_true(AdsManager.is_rewarded_ready(AdsConfig.CONTINUE))
	mock.consent_granted = false
	AdsManager.use_provider(mock_copy(false))
	await wait_process_frames(2)
	assert_false(AdsManager.can_request, "consentement refusé : aucune requête")


func mock_copy(granted: bool) -> MockAds:
	var m := MockAds.new()
	m.manual = true
	m.interactive = false
	m.consent_granted = granted
	mock = m
	return m


func test_reward_only_on_callback_not_on_close() -> void:
	var got := [0]
	var done := []
	_ready_rewarded()
	assert_true(AdsManager.show_rewarded(AdsConfig.DOUBLE_COINS,
		func() -> void: got[0] += 1, func(r: bool) -> void: done.append(r)))
	assert_true(get_tree().paused, "jeu en pause pendant la pub")
	assert_true(AudioServer.is_bus_mute(0), "son coupé pendant la pub")
	mock.finish(MockAds.Outcome.CLOSE_EARLY)
	await wait_seconds(AdsManager.CLOSE_GRACE + 0.15)
	assert_eq(got[0], 0, "fermée avant la fin : aucune récompense")
	assert_eq(done, [false])
	assert_false(get_tree().paused, "jeu repris")
	assert_false(AudioServer.is_bus_mute(0), "son rétabli")
	assert_eq(analytics.count(&"ad_rewarded"), 0)


func test_reward_on_callback_then_close() -> void:
	var got := [0]
	var done := []
	_ready_rewarded()
	AdsManager.show_rewarded(AdsConfig.DOUBLE_COINS, func() -> void: got[0] += 1,
		func(r: bool) -> void: done.append(r))
	mock.finish(MockAds.Outcome.COMPLETE)
	assert_eq(got[0], 1, "récompense sur le callback")
	await wait_seconds(AdsManager.CLOSE_GRACE + 0.15)
	assert_eq(done, [true])
	assert_eq(analytics.count(&"ad_rewarded"), 1)
	assert_eq(analytics.count(&"ad_shown"), 1)


func test_failed_ad_gives_nothing_and_resumes() -> void:
	var got := [0]
	var done := []
	_ready_rewarded()
	AdsManager.show_rewarded(AdsConfig.SHAKE_FREE, func() -> void: got[0] += 1,
		func(r: bool) -> void: done.append(r))
	mock.finish(MockAds.Outcome.FAIL_TO_SHOW)
	assert_eq(got[0], 0)
	assert_eq(done, [false])
	assert_false(get_tree().paused)
	assert_eq(analytics.count(&"ad_failed"), 1)


func test_paused_game_stays_paused_after_ad() -> void:
	_ready_rewarded()
	get_tree().paused = true
	AdsManager.show_rewarded(AdsConfig.DOUBLE_COINS, func() -> void: pass)
	mock.finish(MockAds.Outcome.FAIL_TO_SHOW)
	assert_true(get_tree().paused, "état de pause d'avant la pub restauré")


func test_disabled_placement_never_offered() -> void:
	_ready_rewarded()
	assert_false(AdsManager.is_rewarded_ready(&"unknown_placement"))


# ---------------------------------------------------------------- Interstitiel (AdsManager)

func test_interstitial_respects_policy_with_simulated_clock() -> void:
	var clock := FakeClock.new()
	AdsManager.use_clock(clock)
	AdsManager.policy.lifetime_games = 0
	AdsManager.policy.games_since_last = 3
	AdsManager.policy.last_shown = -1e12
	AdsManager.policy.last_rewarded = -1e12
	mock.complete_load(AdProvider.INTERSTITIAL)
	clock.advance(600)
	var shown := [0]
	for i in 4:
		AdsManager.notify_game_started()
		AdsManager.notify_game_finished()
	assert_false(AdsManager.try_interstitial(func() -> void: shown[0] += 1), "4 parties seulement")
	AdsManager.notify_game_started()
	AdsManager.notify_game_finished()
	assert_true(AdsManager.try_interstitial(func() -> void: shown[0] += 1), "après la 5e")
	mock.finish(MockAds.Outcome.CLOSE_EARLY)
	assert_eq(shown[0], 1, "partie suivante lancée à la fermeture")
	assert_false(get_tree().paused)
	AdsManager.use_clock(MetaClock.new())


# ---------------------------------------------------------------- Partie : Continuer, power-ups

func _game() -> Game:
	var g: Game = GameScene.instantiate()
	g.seed_value = 4242
	add_child_autofree(g)
	await wait_physics_frames(2)
	return g


func test_continue_removes_three_highest_once_per_game() -> void:
	var g := await _game()
	var xs := [-2.2, -1.1, 0.0, 1.1, 2.2]
	for i in 10:
		g.spawn_fruit(i % 5, Vector3(xs[i % 5], 0.6 + (i / 5) * 1.6, 0))
	await wait_physics_frames(60)
	g._end_game()
	await wait_physics_frames(2)
	var expected := g.top_fruits(3)
	assert_eq(expected.size(), 3)
	var others := g.fruits().filter(func(f: Fruit) -> bool: return not f in expected)
	var removed: Array[Fruit] = []
	g.fruit_removed.connect(func(f: Fruit, reason: StringName) -> void:
		assert_eq(reason, &"continue")
		removed.append(f))
	assert_true(g.continue_game(3, 1))
	assert_eq(removed.size(), 3)
	for f in expected:
		assert_true(f in removed, "fruit le plus haut retiré")
		assert_true(f.merging, "retrait propre (plus de fusion possible)")
	for f in others:
		assert_false(f.merging, "les autres restent")
	assert_false(g.is_over, "la partie reprend")
	g._end_game()
	assert_false(g.continue_game(3, 1), "une seule fois par partie")
	assert_eq(SaveManager.games_played, 1, "la partie n'est comptée qu'une fois")


func test_grow_capped_at_rank_6() -> void:
	var g := await _game()
	Progression.add_xp(5000)
	var pc := g.powerups
	var cap: int = pc.config.grow_max_rank
	assert_eq(cap, 5, "rang 6 = Goyave (index 5)")
	g.spawner.replace_current(3)
	Wallet.add_stock(PowerupsConfig.GROW, 5)
	var stock := Wallet.stock_of(PowerupsConfig.GROW)
	assert_true(pc.use(PowerupsConfig.GROW))
	assert_eq(g.spawner.current(), 4)
	assert_true(pc.use(PowerupsConfig.GROW))
	assert_eq(g.spawner.current(), 5)
	assert_false(pc.can_apply(PowerupsConfig.GROW), "plafond atteint : bouton grisé")
	assert_false(pc.use(PowerupsConfig.GROW))
	assert_eq(g.spawner.current(), 5, "jamais au-delà du rang 6")
	assert_eq(Wallet.stock_of(PowerupsConfig.GROW), stock - 2, "stock non consommé au plafond")
	var f := g.drop()
	assert_eq(f.rank, 5)


func test_pestle_uses_clean_removal() -> void:
	var g := await _game()
	Progression.add_xp(5000)
	var target := g.spawn_fruit(3, Vector3(0, 1.0, 0))
	var other := g.spawn_fruit(3, Vector3(2.0, 1.0, 0))
	await wait_physics_frames(30)
	Wallet.add_stock(PowerupsConfig.PESTLE, 1)
	var stock := Wallet.stock_of(PowerupsConfig.PESTLE)
	var reasons: Array[StringName] = []
	g.fruit_removed.connect(func(_f: Fruit, r: StringName) -> void: reasons.append(r))
	assert_true(g.powerups.use(PowerupsConfig.PESTLE))
	assert_true(g.powerups.aiming, "mode visée")
	assert_true(get_tree().paused, "jeu en pause pendant la visée")
	assert_eq(Wallet.stock_of(PowerupsConfig.PESTLE), stock, "pas consommé avant le choix")
	assert_false(g.powerups.pick(Vector2(5, 5)), "rien sous le doigt")
	var screen := g.camera().unproject_position(target.global_position)
	assert_true(g.powerups.pick(screen))
	assert_eq(reasons, [&"pestle"] as Array[StringName], "passe par Game.remove_fruit")
	assert_true(target.merging, "retiré proprement")
	assert_false(other.merging)
	assert_false(get_tree().paused)
	assert_eq(Wallet.stock_of(PowerupsConfig.PESTLE), stock - 1)
	assert_eq(analytics.last(&"powerup_used").get("type"), "pestle")


func test_pestle_cancel_keeps_stock() -> void:
	var g := await _game()
	Progression.add_xp(5000)
	g.spawn_fruit(2, Vector3(0, 1.0, 0))
	await wait_physics_frames(10)
	Wallet.add_stock(PowerupsConfig.PESTLE, 1)
	var stock := Wallet.stock_of(PowerupsConfig.PESTLE)
	g.powerups.use(PowerupsConfig.PESTLE)
	g.powerups.cancel_aim()
	assert_false(get_tree().paused)
	assert_false(g.powerups.aiming)
	assert_eq(Wallet.stock_of(PowerupsConfig.PESTLE), stock, "annulé : rien consommé")


func test_shake_cooldown_and_buy_with_coins() -> void:
	var g := await _game()
	Progression.add_xp(5000)
	for i in 4:
		g.spawn_fruit(1, Vector3(-1.5 + i, 0.6, 0))
	await wait_physics_frames(20)
	var price: int = g.powerups.config.get_def(PowerupsConfig.SHAKE).price
	while Wallet.stock_of(PowerupsConfig.SHAKE) > 0:
		Wallet.use_stock(PowerupsConfig.SHAKE)
	Wallet.spend(Wallet.coins())
	assert_false(g.powerups.buy_and_use(PowerupsConfig.SHAKE), "pas assez de pièces")
	Wallet.earn(price)
	assert_true(g.powerups.buy_and_use(PowerupsConfig.SHAKE))
	assert_eq(Wallet.coins(), 0)
	assert_gt(g.powerups.cooldown_left(PowerupsConfig.SHAKE), 19.0, "1 fois toutes les 20 s")
	assert_false(g.powerups.can_apply(PowerupsConfig.SHAKE))


func test_powerups_locked_before_level_3() -> void:
	var g := await _game()
	assert_eq(Progression.level(), 1)
	Wallet.add_stock(PowerupsConfig.SWAP, 1)
	assert_false(g.powerups.use(PowerupsConfig.SWAP), "verrouillé avant le niv. 3")


func test_swap_changes_current_to_other_droppable() -> void:
	var g := await _game()
	Progression.add_xp(5000)
	for i in 20:
		var before := g.spawner.current()
		g.swap_current()
		assert_ne(g.spawner.current(), before)
		assert_true(g.spawner.current() in g.catalog.droppable_ranks())


# ---------------------------------------------------------------- Sons M4

func test_m4_sounds_wired_and_merge_rises_with_rank() -> void:
	var cfg: JuiceConfig = load("res://data/juice.tres")
	for s in [cfg.sounds.merge, cfg.sounds.ui_click, cfg.sounds.play, cfg.sounds.powerup,
			cfg.sounds.coins]:
		assert_not_null(s, "son M4 branché")
	var g := await _game()
	var low := g.juice().play_merge_sound(2)
	var high := g.juice().play_merge_sound(8)
	assert_eq(low.stream, cfg.sounds.merge)
	assert_gt(high.pitch_scale, low.pitch_scale, "rang plus haut = son plus aigu")


func test_voices_rate_limited_priority_passes() -> void:
	var g := await _game()
	var s: SoundBank = g.juice_config.sounds
	for v in [s.voice_waaw, s.voice_wooy, s.voice_good, s.voice_dafa_neex, s.voice_cest_doux,
			s.voice_ca_cest_fort, s.voice_gaaw]:
		assert_not_null(v, "voix branchée")
	var j := g.juice()
	assert_not_null(j.play_voice(s.voice_waaw))
	assert_null(j.play_voice(s.voice_good), "une voix toutes les quelques secondes au plus")
	await wait_seconds(g.juice_config.voice_priority_gap + 0.1)
	assert_not_null(j.play_voice(s.voice_ca_cest_fort, true), "voix prioritaire (Baobab)")


func test_music_playlist_and_tension_crossfade() -> void:
	var cfg: JuiceConfig = load("res://data/juice.tres")
	var s: SoundBank = cfg.sounds
	Audio.play_music_playlist(s.music_tracks, s.music_tension, cfg.tension_fade_time)
	assert_eq(s.music_tracks.size(), 2)
	assert_not_null(s.music_tension)
	Audio.set_tension(true)
	await wait_seconds(cfg.tension_fade_time + 0.3)
	assert_almost_eq(Audio.tension_level(), 1.0, 0.01, "tension en fondu")
	Audio.set_tension(false)
	await wait_seconds(cfg.tension_fade_time + 0.3)
	assert_almost_eq(Audio.tension_level(), 0.0, 0.01, "retour au calme")


## Morceau silencieux de `seconds` s (test du fondu croisé).
func _silent_track(seconds: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 8000
	var data := PackedByteArray()
	data.resize(int(seconds * 8000) * 2)
	w.data = data
	return w


func test_music_crossfades_without_gap() -> void:
	var a := _silent_track(1.5)
	var b := _silent_track(1.5)
	Audio.stop_music()
	Audio.play_music_playlist([a, b] as Array[AudioStream], null, 1.0, 0.5)
	var saw_overlap := false
	var gap := false
	for i in 150:
		await wait_process_frames(1)
		var playing := 0
		for p in [Audio._music, Audio._next_music]:
			playing += int(p.playing)
		saw_overlap = saw_overlap or playing == 2
		gap = gap or playing == 0
	assert_true(saw_overlap, "le morceau suivant démarre avant la fin du précédent")
	assert_false(gap, "jamais de silence entre deux morceaux")
	Audio.stop_music()


# ---------------------------------------------------------------- Clôture de partie

func test_finalize_gives_coins_xp_and_events_once() -> void:
	var g := await _game()
	g.drop(0.0)
	g.score = 1234
	var coins_before := Wallet.coins()
	var s := g.meta.finalize(&"overflow")
	var expected := int(round(1234 / Wallet.economy.coin_score_divisor))
	assert_eq(int(s["coins"]), expected, "score / diviseur (economy.tres), arrondi")
	assert_eq(Wallet.coins(), coins_before + expected + int(s["level_coins"]))
	assert_gt(int(s["xp"]), 0)
	g.meta.finalize(&"overflow")
	assert_eq(analytics.count(&"game_over"), 1, "clôture idempotente")
	assert_eq(analytics.last(&"game_over")["cause"], "overflow")


# ---------------------------------------------------------------- Sauvegarde

func _write(text: String) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_save_migration_v1_to_v2() -> void:
	_write(JSON.stringify({"version": 1, "best_score": 3100, "best_rank": 6, "games_played": 9,
		"settings": {"music_on": false, "quality": 1}}))
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.MIGRATED)
	assert_eq(SaveManager.best_score, 3100)
	assert_eq(SaveManager.games_played, 9)
	assert_eq(SaveManager.get_setting(&"music_on"), false)
	assert_eq(SaveManager.get_setting(&"notifications_on"), true, "nouveau réglage par défaut")
	for r in 7:
		assert_true(Collection.has(r), "fruit %d acquis" % r)
	assert_false(Collection.has(7))
	assert_true(FileAccess.get_file_as_string(SAVE).begins_with("FV2 "), "réécrit en v2")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.OK)
	assert_eq(SaveManager.best_score, 3100)


func test_corrupt_save_gives_defaults_without_crash() -> void:
	_write("FV2 deadbeef\n{\"core\": [tronqué")
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.CORRUPT)
	assert_eq(SaveManager.best_score, 0)
	assert_eq(Wallet.coins(), Wallet.economy.starting_coins)
	assert_eq(Progression.level(), 1)
	assert_true(FileAccess.file_exists(SAVE + ".corrupt"), "copie gardée pour analyse")


func test_tampered_save_resets_progress_keeps_settings() -> void:
	Wallet.earn(40)
	SaveManager.set_setting(&"music_on", false)
	SaveManager.save_data()
	var text := FileAccess.get_file_as_string(SAVE)
	_write(text.replace("\"coins\":%d" % Wallet.coins(), "\"coins\":999999"))
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.TAMPERED)
	assert_eq(Wallet.coins(), Wallet.economy.starting_coins)
	assert_eq(SaveManager.get_setting(&"music_on"), false, "réglages conservés")


func test_systems_roundtrip_through_save() -> void:
	Wallet.earn(77)
	Wallet.add_stock(PowerupsConfig.SWAP, 2)
	Progression.add_xp(120)
	Collection.discover(4)
	var lv := Progression.level()
	SaveManager.save_data()
	SaveManager.use_path(SAVE)
	assert_eq(SaveManager.last_status, SaveCodec.Status.OK)
	assert_eq(Wallet.stock_of(PowerupsConfig.SWAP), 2 + (1 if lv >= 3 else 0))
	assert_eq(Progression.level(), lv)
	assert_true(Collection.has(4))
	assert_false(FileAccess.file_exists(SAVE + ".tmp"), "écriture atomique : pas de reste")


# ---------------------------------------------------------------- Consentement / analytics

func test_no_analytics_when_consent_refused() -> void:
	Analytics.set_consent(false)
	Analytics.log_event(&"game_start", {})
	assert_eq(analytics.count(&"game_start"), 0, "rien envoyé sans consentement")
	Analytics.set_consent(true)
	SaveManager.set_setting(&"analytics_on", false)
	Analytics.log_event(&"game_start", {})
	assert_eq(analytics.count(&"game_start"), 0, "statistiques coupées par le joueur")
	SaveManager.set_setting(&"analytics_on", true)
	Analytics.log_event(&"game_start", {})
	assert_eq(analytics.count(&"game_start"), 1)


# ---------------------------------------------------------------- Connexion quotidienne (autoload)

func test_daily_claim_credits_wallet() -> void:
	var clock := FakeClock.new()
	DailyRewards.use_clock(clock)
	Progression.add_xp(5000)
	var before := Wallet.coins()
	var r := DailyRewards.claim()
	assert_not_null(r)
	assert_eq(Wallet.coins(), before + r.coins)
	assert_null(DailyRewards.claim(), "une fois par jour")
	assert_eq(analytics.last(&"daily_claimed")["day"], 1)
	DailyRewards.use_clock(MetaClock.new())
