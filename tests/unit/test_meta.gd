extends GutTest
## M4 : logique pure des systèmes méta (horloge simulée, aucune scène).

const DAY := 86400

var missions_cfg: MissionsConfig = load("res://data/missions.tres")
var daily_cfg: DailyRewardsConfig = load("res://data/daily_rewards.tres")
var ads_cfg: AdsConfig = load("res://data/ads.tres")
var levels_cfg: LevelsConfig = load("res://data/levels.tres")
var powerups_cfg: PowerupsConfig = load("res://data/powerups.tres")


# ---------------------------------------------------------------- Wallet

func test_wallet_never_negative_and_refuses_insufficient_funds() -> void:
	var w := WalletCore.new()
	w.earn(50)
	assert_false(w.spend(80), "achat refusé : fonds insuffisants")
	assert_eq(w.coins, 50, "solde inchangé après refus")
	assert_true(w.spend(50))
	assert_eq(w.coins, 0)
	assert_false(w.spend(1))
	assert_false(w.spend(-10), "montant négatif refusé")
	assert_eq(w.earn(-30), 0, "gain négatif ignoré")
	assert_eq(w.coins, 0, "jamais négatif")


func test_wallet_buy_powerup_and_stock() -> void:
	var w := WalletCore.new()
	w.earn(150)
	assert_false(w.buy(&"grow", 250), "trop cher")
	assert_eq(w.stock_of(&"grow"), 0)
	assert_true(w.buy(&"shake", 100))
	assert_eq(w.coins, 50)
	assert_eq(w.stock_of(&"shake"), 1)
	assert_true(w.use_stock(&"shake"))
	assert_false(w.use_stock(&"shake"), "stock vide")


func test_wallet_load_sanitizes_values() -> void:
	var w := WalletCore.new(1000)
	w.from_dict({"coins": -500, "stock": {"shake": -3, "swap": 2}})
	assert_eq(w.coins, 0)
	assert_eq(w.stock_of(&"shake"), 0)
	assert_eq(w.stock_of(&"swap"), 2)
	w.from_dict({"coins": 99999})
	assert_eq(w.coins, 1000, "plafond")


func test_quality_detection_budget_phones() -> void:
	assert_eq(VisualQuality.level_for(4.0, "Adreno (TM) 610"), JuiceConfig.Quality.LOW,
		"Galaxy A23 : Bas (mesuré 63 FPS, Moyen < 60)")
	assert_eq(VisualQuality.level_for(8.0, "Adreno (TM) 618"), JuiceConfig.Quality.MEDIUM)
	assert_eq(VisualQuality.level_for(8.0, "Adreno (TM) 740"), JuiceConfig.Quality.HIGH)


func test_powerup_prices_in_range() -> void:
	for p in powerups_cfg.powerups:
		assert_between(p.price, 100, 300, "prix %s" % p.id)


# ---------------------------------------------------------------- Progression

func test_progression_levels_and_unlocks() -> void:
	var p := ProgressionCore.new(levels_cfg)
	assert_eq(p.level, 1)
	assert_false(p.is_unlocked(ProgressionCore.MISSIONS))
	var reached := p.add_xp(levels_cfg.xp_for_level(3))
	assert_eq(reached, [2, 3] as Array[int])
	assert_true(p.is_unlocked(ProgressionCore.MISSIONS), "niv. 2 : missions")
	assert_true(p.is_unlocked(ProgressionCore.POWERUPS), "niv. 3 : power-ups")
	assert_false(p.is_unlocked(ProgressionCore.DAILY))
	assert_eq(p.unlock_level(ProgressionCore.DAILY), 4)
	assert_eq(p.unlock_level(ProgressionCore.ALBUM), 5)


func test_xp_curve_is_increasing() -> void:
	for lv in range(2, 30):
		assert_gt(levels_cfg.xp_for_level(lv + 1), levels_cfg.xp_for_level(lv))


# ---------------------------------------------------------------- Missions

func _missions(level := 5) -> MissionsCore:
	var m := MissionsCore.new(missions_cfg, 1234)
	m.refresh(100, level)
	return m


func test_missions_three_active_no_duplicate_kind() -> void:
	for seed_v in 50:
		var m := MissionsCore.new(missions_cfg, seed_v)
		m.refresh(1000 + seed_v, 9)
		assert_eq(m.active.size(), 3)
		var kinds := {}
		for i in m.active.size():
			var k := m.def_of(i).kind
			assert_false(kinds.has(k), "jamais deux missions du même type")
			kinds[k] = true


func test_missions_respect_min_level() -> void:
	for seed_v in 30:
		var m := MissionsCore.new(missions_cfg, seed_v)
		m.refresh(seed_v, 1)
		for i in m.active.size():
			assert_true(m.def_of(i).min_level <= 1)


func test_missions_renew_at_local_midnight() -> void:
	var clock := FakeClock.new(1_760_000_000, 3600)  # UTC+1
	var day := clock.today()
	clock.set_local(day, 23, 50)
	var m := MissionsCore.new(missions_cfg, 7)
	assert_true(m.refresh(clock.today(), 5))
	var before := m.to_dict()
	clock.advance(5 * 60)
	assert_false(m.refresh(clock.today(), 5), "23 h 55 : mêmes missions")
	assert_eq(m.to_dict(), before)
	clock.advance(10 * 60)
	assert_eq(clock.today(), day + 1, "minuit local passé")
	assert_true(m.refresh(clock.today(), 5), "nouvelles missions après minuit")
	for e in m.active:
		assert_eq(int(e["progress"]), 0)


func test_missions_progress_and_claim() -> void:
	var m := _missions()
	var games := -1
	for i in m.active.size():
		if m.def_of(i).kind == MissionDef.Kind.GAMES:
			games = i
	if games < 0:
		# Force une mission « parties » pour le test.
		m.active[0] = {"id": "games", "target": 3, "reward": 30, "progress": 0,
			"claimed": false, "doubled": false}
		games = 0
	var target := int(m.active[games]["target"])
	for k in target - 1:
		m.on_event(MissionDef.Kind.GAMES)
	assert_false(m.can_claim(games))
	assert_eq(m.claim(games), 0, "pas encore terminée")
	m.on_event(MissionDef.Kind.GAMES)
	m.on_event(MissionDef.Kind.GAMES)
	assert_eq(int(m.active[games]["progress"]), target, "progression plafonnée")
	assert_true(m.can_claim(games))
	var reward := int(m.active[games]["reward"])
	assert_eq(m.claim(games, true), reward * missions_cfg.double_multiplier, "doublée")
	assert_eq(m.claim(games), 0, "une seule fois")


func test_mission_score_single_and_create_rank() -> void:
	var m := MissionsCore.new(missions_cfg, 1)
	m.day = 1
	m.active = [
		{"id": "score", "target": 1500, "reward": 40, "progress": 0, "claimed": false, "doubled": false},
		{"id": "mango", "target": 2, "reward": 50, "progress": 0, "claimed": false, "doubled": false},
	] as Array[Dictionary]
	m.on_event(MissionDef.Kind.SCORE_SINGLE, 900)
	m.on_event(MissionDef.Kind.SCORE_SINGLE, 700)
	assert_eq(int(m.active[0]["progress"]), 900, "score d'UNE partie, pas cumulé")
	m.on_event(MissionDef.Kind.SCORE_SINGLE, 2000)
	assert_true(m.is_complete(0))
	m.on_event(MissionDef.Kind.CREATE_RANK, 1, 5)
	assert_eq(int(m.active[1]["progress"]), 0, "une goyave ne compte pas pour la mangue")
	m.on_event(MissionDef.Kind.CREATE_RANK, 1, 6)
	m.on_event(MissionDef.Kind.CREATE_RANK, 1, 6)
	assert_true(m.is_complete(1))


# ---------------------------------------------------------------- Connexion quotidienne

func test_daily_seven_day_sequence() -> void:
	var d := DailyRewardsCore.new(daily_cfg)
	for day in 7:
		var st := d.status(100 + day, true)
		assert_true(st["can_claim"])
		assert_eq(st["day_index"], day)
		var r := d.claim(100 + day, true)
		assert_eq(r, daily_cfg.rewards[day])
		assert_null(d.claim(100 + day, true), "une fois par jour")
	assert_eq(d.streak, 7)
	assert_true(daily_cfg.rewards[6].is_chest, "jour 7 = gros coffre")
	assert_eq(d.status(107, true)["day_index"], 0, "le calendrier recommence")
	d.claim(107, true)
	assert_eq(d.streak, 8, "la série continue")


func test_daily_missed_day_breaks_streak() -> void:
	var d := DailyRewardsCore.new(daily_cfg)
	d.claim(10, true)
	d.claim(11, true)
	d.claim(12, true)
	var st := d.status(14, true)
	assert_true(st["broken"])
	assert_eq(st["streak"], 0)
	assert_eq(st["day_index"], 0)
	var r := d.claim(14, true)
	assert_eq(r, daily_cfg.rewards[0], "repart au jour 1")
	assert_eq(d.streak, 1)


func test_daily_shield_keeps_streak_once_per_week() -> void:
	var d := DailyRewardsCore.new(daily_cfg)
	for day in [10, 11, 12]:
		d.claim(day, true)
	assert_true(d.shield_available(14), "1 jour manqué : bouclier proposé")
	var r := d.claim(14, true, true)
	assert_eq(r, daily_cfg.rewards[3], "jour 4 avec bouclier")
	assert_eq(d.streak, 4)
	d.claim(15, true)
	assert_false(d.shield_available(17), "bouclier déjà utilisé cette semaine")
	d.claim(17, true, true)
	assert_eq(d.streak, 1, "sans bouclier disponible : série cassée")
	assert_false(DailyRewardsCore.new(daily_cfg).shield_available(5), "rien à protéger")


func test_daily_shield_not_for_long_absence() -> void:
	var d := DailyRewardsCore.new(daily_cfg)
	d.claim(10, true)
	assert_false(d.shield_available(14), "3 jours manqués : pas de bouclier")


func test_clock_going_backwards_blocks_reward_without_penalty() -> void:
	var clock := FakeClock.new(1_760_000_000)
	var d := DailyRewardsCore.new(daily_cfg)
	d.guard.begin_session(clock.now(), clock.ticks())
	d.claim(clock.today(), d.guard.is_coherent(clock.now(), clock.ticks()))
	d.guard.mark_seen(clock.now(), clock.ticks())
	clock.advance(DAY)
	d.claim(clock.today(), true)
	d.guard.mark_seen(clock.now(), clock.ticks())
	assert_eq(d.streak, 2)
	# Le joueur recule l'horloge de 3 jours.
	clock.set_wall(clock.now() - 3 * DAY)
	var ok := d.guard.is_coherent(clock.now(), clock.ticks())
	assert_false(ok, "recul détecté")
	assert_null(d.claim(clock.today(), ok), "pas de récompense")
	assert_eq(d.streak, 2, "aucune pénalité")
	assert_true(d.status(clock.today(), ok)["clock_suspect"])


func test_clock_forward_jump_in_session_blocks_reward() -> void:
	var clock := FakeClock.new(1_760_000_000)
	var g := ClockGuard.new()
	g.configure(daily_cfg)
	g.begin_session(clock.now(), clock.ticks())
	clock.advance(3600)
	assert_true(g.is_coherent(clock.now(), clock.ticks()), "temps réel normal")
	clock.set_wall(clock.now() + 3 * DAY)
	assert_false(g.is_coherent(clock.now(), clock.ticks()), "+72 h en 1 h de jeu")
	g.mark_seen(clock.now(), clock.ticks())
	assert_lt(g.last_seen, clock.now(), "heure trichée non mémorisée")
	# Une longue absence entre deux sessions reste normale.
	g.begin_session(clock.now(), clock.ticks())
	assert_true(g.is_coherent(clock.now(), clock.ticks()))


# ---------------------------------------------------------------- Interstitiel

func _policy(clock: FakeClock) -> InterstitialPolicy:
	var p := InterstitialPolicy.new(ads_cfg)
	p.begin_session(clock.now())
	return p


func _finish_games(p: InterstitialPolicy, n: int) -> void:
	for i in n:
		p.on_game_started()
		p.on_game_finished()


func test_interstitial_never_before_5th_game() -> void:
	var clock := FakeClock.new()
	var p := _policy(clock)
	clock.advance(600)
	_finish_games(p, 4)
	assert_eq(p.block_reason(clock.now()), "too_early_lifetime")
	_finish_games(p, 1)
	assert_true(p.can_show(clock.now()), "après la 5e partie")


func test_interstitial_session_grace() -> void:
	var clock := FakeClock.new()
	var p := _policy(clock)
	p.lifetime_games = 20
	p.games_since_last = 5
	clock.advance(60)
	assert_eq(p.block_reason(clock.now()), "session_grace", "pas dans les 2 premières minutes")
	clock.advance(61)
	assert_true(p.can_show(clock.now()))


func test_interstitial_every_3_games_and_3_minutes() -> void:
	var clock := FakeClock.new()
	var p := _policy(clock)
	p.lifetime_games = 10
	clock.advance(300)
	assert_true(p.can_show(clock.now()))
	p.on_interstitial_shown(clock.now())
	_finish_games(p, 2)
	clock.advance(600)
	assert_eq(p.block_reason(clock.now()), "games_between", "2 parties seulement")
	_finish_games(p, 1)
	assert_true(p.can_show(clock.now()))
	p.on_interstitial_shown(clock.now())
	_finish_games(p, 3)
	clock.advance(120)
	assert_eq(p.block_reason(clock.now()), "seconds_between", "3 parties mais 2 min")
	clock.advance(61)
	assert_true(p.can_show(clock.now()))


func test_interstitial_never_right_after_rewarded() -> void:
	var clock := FakeClock.new()
	var p := _policy(clock)
	p.lifetime_games = 10
	clock.advance(600)
	p.on_game_started()
	p.on_rewarded_shown(clock.now())
	p.on_game_finished()
	clock.advance(300)
	assert_eq(p.block_reason(clock.now()), "after_rewarded", "rewarded vu pendant la partie")
	p.on_game_started()
	p.on_game_finished()
	assert_true(p.can_show(clock.now()), "partie suivante sans rewarded")
	p.on_rewarded_shown(clock.now())
	p.rewarded_since_game_end = false
	assert_eq(p.block_reason(clock.now()), "after_rewarded", "rewarded il y a < 90 s")


func test_interstitial_disabled_flag() -> void:
	var cfg := ads_cfg.duplicate() as AdsConfig
	cfg.interstitial_enabled = false
	var p := InterstitialPolicy.new(cfg)
	p.lifetime_games = 99
	assert_eq(p.block_reason(1e9), "disabled")


# ---------------------------------------------------------------- Rewarded

func test_rewarded_reward_only_on_callback() -> void:
	var got := [0]
	var done := []
	var s := RewardedSession.new(&"continue", func() -> void: got[0] += 1,
		func(r: bool) -> void: done.append(r))
	s.handle_closed()
	assert_eq(got[0], 0, "fermée avant la fin : pas de récompense")
	assert_eq(done, [false])
	s.handle_earned()
	assert_eq(got[0], 0, "récompense après la fin ignorée")


func test_rewarded_failure_gives_nothing() -> void:
	var got := [0]
	var done := []
	var s := RewardedSession.new(&"x", func() -> void: got[0] += 1, func(r: bool) -> void: done.append(r))
	s.handle_failed()
	assert_eq(got[0], 0)
	assert_eq(done, [false])


func test_rewarded_earned_once() -> void:
	var got := [0]
	var done := []
	var s := RewardedSession.new(&"x", func() -> void: got[0] += 1, func(r: bool) -> void: done.append(r))
	s.handle_earned()
	s.handle_earned()
	s.handle_closed()
	s.handle_closed()
	assert_eq(got[0], 1)
	assert_eq(done, [true], "fin signalée une fois")


# ---------------------------------------------------------------- Collection

func test_collection_unlock_and_completion() -> void:
	var c := CollectionCore.new(11)
	assert_true(c.discover(3))
	assert_false(c.discover(3), "déjà débloqué")
	assert_false(c.discover(42))
	assert_false(c.claim_completion())
	for r in 11:
		c.discover(r)
	assert_true(c.is_complete())
	assert_true(c.claim_completion())
	assert_false(c.claim_completion(), "une seule fois")


# ---------------------------------------------------------------- Sauvegarde (codec)

func test_save_codec_roundtrip_and_tamper() -> void:
	var text := SaveCodec.encode({"core": {"best_score": 10}, "systems": {"wallet": {"coins": 5}}})
	var res := SaveCodec.decode(text)
	assert_eq(res["status"], SaveCodec.Status.OK)
	assert_eq(int(res["data"]["systems"]["wallet"]["coins"]), 5)
	var hacked := text.replace("\"coins\":5", "\"coins\":99999")
	assert_ne(hacked, text)
	assert_eq(SaveCodec.decode(hacked)["status"], SaveCodec.Status.TAMPERED)


func test_save_codec_migrates_v1() -> void:
	var v1 := JSON.stringify({"version": 1, "best_score": 4210, "best_rank": 7,
		"games_played": 12, "settings": {"music_on": false}})
	var res := SaveCodec.decode(v1)
	assert_eq(res["status"], SaveCodec.Status.MIGRATED)
	var data: Dictionary = res["data"]
	assert_eq(int(data["version"]), 2)
	assert_eq(int(data["core"]["best_score"]), 4210)
	assert_eq(data["systems"]["collection"]["found"], [0, 1, 2, 3, 4, 5, 6, 7],
		"fruits déjà atteints acquis dans l'album")


func test_save_codec_corrupt() -> void:
	for junk in ["", "{oops", "FV2 abc", "FV2 abc\n[1,2", "\u0000\u0001"]:
		assert_eq(SaveCodec.decode(junk)["status"], SaveCodec.Status.CORRUPT, junk)


# ---------------------------------------------------------------- Notifications

func test_notification_plan_max_two_per_day() -> void:
	var clock := FakeClock.new(1_760_000_000, 0)
	clock.set_local(clock.today(), 9)
	var plan := NotificationPlanner.plan(clock, daily_cfg, false, 3)
	assert_eq(plan.size(), 2)
	assert_eq(plan[0]["id"], NotificationPlanner.ID_REMINDER)
	assert_eq(plan[0]["delay"], 3 * 3600, "midi aujourd'hui")
	assert_eq(plan[1]["delay"], 10 * 3600, "19 h aujourd'hui")
	var claimed := NotificationPlanner.plan(clock, daily_cfg, true, 0)
	assert_eq(claimed.size(), 1, "pas de série : un seul rappel")
	assert_eq(claimed[0]["delay"], 27 * 3600, "demain midi")
	var cfg := daily_cfg.duplicate() as DailyRewardsConfig
	cfg.notifications_max_per_day = 0
	assert_true(NotificationPlanner.plan(clock, cfg, false, 3).is_empty())


# ---------------------------------------------------------------- Firebase / push

class FakeCore extends RefCounted:
	signal core_initialized(ok: bool)
	var calls: int = 0

	func initialize() -> void:
		calls += 1


class FakeMessaging extends RefCounted:
	signal messaging_permission_granted
	signal messaging_permission_denied
	signal messaging_token_received(token: String)
	signal messaging_error(message: String)
	var log: Array[String] = []

	func initialize() -> void:
		log.append("initialize")

	func request_permission() -> void:
		log.append("request_permission")

	func get_token() -> void:
		log.append("get_token")


## Core initialisé une seule fois pour Analytics et Messaging (deux
## initialize() = plantage iOS), les modules servis dans l'ordre.
func test_firebase_core_initialized_once() -> void:
	FirebaseBoot.reset()
	var core := FakeCore.new()
	FirebaseBoot.core_override = core
	var got: Array = []
	FirebaseBoot.when_ready(func(ok: bool) -> void: got.append(["analytics", ok]))
	FirebaseBoot.when_ready(func(ok: bool) -> void: got.append(["push", ok]))
	assert_eq(core.calls, 1, "un seul initialize()")
	assert_eq(got, [], "rien avant core_initialized")
	core.core_initialized.emit(true)
	assert_eq(got, [["analytics", true], ["push", true]])
	FirebaseBoot.when_ready(func(ok: bool) -> void: got.append(["tard", ok]))
	assert_eq(got.back(), ["tard", true], "déjà prêt : réponse immédiate")
	assert_eq(core.calls, 1)
	FirebaseBoot.reset()


## Push : permission demandée avant que Core soit prêt = différée ; accord
## puis jeton ; refus = pas de jeton.
func test_push_permission_then_token() -> void:
	FirebaseBoot.reset()
	var core := FakeCore.new()
	FirebaseBoot.core_override = core
	var push := FirebasePush.new()
	var m := FakeMessaging.new()
	push.messaging = m
	add_child_autofree(push)
	push.request_permission()
	assert_eq(m.log, [] as Array[String], "Core pas prêt : rien encore")
	core.core_initialized.emit(true)
	assert_eq(m.log, ["initialize", "request_permission"] as Array[String])
	m.messaging_permission_granted.emit()
	assert_true(push.granted)
	assert_eq(m.log.back(), "get_token")
	watch_signals(push)
	m.messaging_token_received.emit("tok123")
	assert_eq(push.token, "tok123")
	assert_signal_emitted_with_parameters(push, "token_received", ["tok123"])
	m.messaging_permission_denied.emit()
	assert_false(push.granted)
	FirebaseBoot.reset()
