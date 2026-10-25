extends Node
## Autoload AdsManager : seule porte d'entrée du jeu vers la pub.
## - fournisseur derrière AdProvider : MockAds (dev, tests), AdMobAds (Android) ;
## - consentement UMP avant toute requête ;
## - une rewarded toujours préchargée ; is_rewarded_ready() faux = bouton masqué ;
## - récompense UNIQUEMENT sur le callback de récompense (RewardedSession) ;
## - jeu en pause et son coupé pendant la pub, reprise propre (fermeture,
##   échec, retour d'arrière-plan) ;
## - interstitiel soumis à InterstitialPolicy.
## Identifiants : TOUJOURS ceux de test Google en debug. En release, UNIQUEMENT
## les vrais de res://ads_ids.cfg (non versionné) ; sinon pas de pub (AdIds).
## Release sans SDK AdMob : aucune pub (jamais MockAds, qui donne des récompenses).

signal availability_changed
signal consent_changed(can_request_ads: bool)
signal ad_started(kind: StringName)
signal ad_finished(kind: StringName)

## Délai de grâce après la fermeture : certains SDK livrent la récompense
## juste APRÈS la fermeture. Au-delà, la fermeture ne récompense jamais.
const CLOSE_GRACE := 0.3
## Pub annoncée mais jamais ouverte après le retour au premier plan (s).
const WATCHDOG := 8.0

var config: AdsConfig = preload("res://data/ads.tres")
var provider: AdProvider
var policy: InterstitialPolicy
var clock := MetaClock.new()
var can_request: bool = false
var consent_known: bool = false

var _session: RewardedSession
var _showing: StringName = &""
var _placement: StringName = &""
var _interstitial_done: Callable
var _was_paused: bool = false
var _was_muted: bool = false
var _retry: Dictionary = {}  # kind -> nombre d'échecs consécutifs
var _show_started: float = 0.0
var _ids: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	policy = InterstitialPolicy.new(config)
	SaveManager.register_system("ads", self)
	policy.begin_session(clock.now())
	var p: AdProvider
	if AdMobAds.available():
		p = AdMobAds.new()
	elif OS.is_debug_build():
		p = MockAds.new()
	else:
		p = AdProvider.new()
	use_provider(p)


func save_state() -> Dictionary:
	return policy.to_dict()


func load_state(d: Dictionary) -> void:
	policy.from_dict(d)


## Change de fournisseur (tests : MockAds en mode manuel) et relance le consentement.
func use_provider(p: AdProvider) -> void:
	if provider:
		provider.queue_free()
	provider = p
	can_request = false
	consent_known = false
	_showing = &""
	_session = null
	_retry.clear()
	add_child(provider)
	provider.consent_resolved.connect(_on_consent)
	provider.loaded.connect(_on_loaded)
	provider.load_failed.connect(_on_load_failed)
	provider.earned.connect(_on_earned)
	provider.closed.connect(_on_closed)
	provider.show_failed.connect(_on_show_failed)
	_ids = ad_ids()
	provider.start(config, _ids)


func use_clock(c: MetaClock) -> void:
	clock = c
	policy.begin_session(clock.now())


## Identifiants à utiliser (règles : AdIds).
func ad_ids() -> Dictionary:
	var debug := OS.is_debug_build()
	return AdIds.resolve(config, debug, null if debug else AdIds.load_file())


## Le format a-t-il un identifiant de bloc ? (sinon jamais chargé ni proposé)
func has_unit(kind: StringName) -> bool:
	return not str(_ids.get("%s_id" % kind, "")).is_empty()


func is_showing() -> bool:
	return _showing != &""


# ---------------------------------------------------------------- Consentement

func _on_consent(can: bool, analytics_ok: bool) -> void:
	can_request = can
	consent_known = true
	Analytics.set_consent(analytics_ok)
	consent_changed.emit(can)
	if can:
		_load(AdProvider.REWARDED)
		_load(AdProvider.INTERSTITIAL)
	availability_changed.emit()


func privacy_options_required() -> bool:
	return provider != null and provider.privacy_options_required()


## Réglages → « Gérer mon consentement ».
func show_privacy_options() -> void:
	if provider:
		provider.show_privacy_options()


# ---------------------------------------------------------------- Chargement

func _load(kind: StringName) -> void:
	if can_request and has_unit(kind) and not provider.is_loaded(kind):
		provider.load_ad(kind)


func _on_loaded(kind: StringName) -> void:
	_retry[kind] = 0
	if kind == AdProvider.REWARDED:
		availability_changed.emit()


func _on_load_failed(kind: StringName, message: String) -> void:
	var n: int = _retry.get(kind, 0)
	_retry[kind] = n + 1
	var delays := config.retry_delays
	var delay := delays[mini(n, delays.size() - 1)] if not delays.is_empty() else 30.0
	Analytics.log_event(&"ad_failed", {"placement": "load_%s" % kind, "reason": message.left(80)})
	get_tree().create_timer(delay, true, false, true).timeout.connect(_load.bind(kind))
	if kind == AdProvider.REWARDED:
		availability_changed.emit()


# ---------------------------------------------------------------- Rewarded

## Bouton affichable ? (faux = bouton masqué, jamais de bouton qui ne fait rien)
func is_rewarded_ready(placement: StringName) -> bool:
	return config.is_placement_enabled(placement) and can_request and not is_showing() \
		and provider != null and provider.is_loaded(AdProvider.REWARDED)


## À appeler quand un bouton rewarded est montré au joueur.
func offer(placement: StringName) -> void:
	Analytics.log_event(&"ad_offered", {"placement": String(placement)})


## Lance une rewarded. `on_reward` : appelé UNIQUEMENT sur le callback de
## récompense. `on_done(rewarded: bool)` : fin (fermeture ou échec), jeu repris.
func show_rewarded(placement: StringName, on_reward: Callable,
		on_done: Callable = Callable()) -> bool:
	if not is_rewarded_ready(placement):
		return false
	_placement = placement
	_session = RewardedSession.new(placement, func() -> void:
		Analytics.log_event(&"ad_rewarded", {"placement": String(placement)})
		on_reward.call(), on_done)
	policy.on_rewarded_shown(clock.now())
	_begin(AdProvider.REWARDED)
	Analytics.log_event(&"ad_shown", {"placement": String(placement)})
	provider.show_ad(AdProvider.REWARDED)
	return true


func _on_earned() -> void:
	if _session:
		_session.handle_earned()


# ---------------------------------------------------------------- Interstitiel

func notify_game_started() -> void:
	policy.on_game_started()


func notify_game_finished() -> void:
	policy.on_game_finished()
	SaveManager.request_save()


## Montre un interstitiel si TOUTES les règles l'autorisent. `on_done` est
## appelé à la fermeture. Renvoie false (sans appeler on_done) sinon.
func try_interstitial(on_done: Callable) -> bool:
	var now := clock.now()
	if not policy.can_show(now) or not can_request or is_showing() \
			or not provider.is_loaded(AdProvider.INTERSTITIAL):
		return false
	_interstitial_done = on_done
	_placement = AdsConfig.INTERSTITIAL
	policy.on_interstitial_shown(now)
	SaveManager.request_save()
	_begin(AdProvider.INTERSTITIAL)
	Analytics.log_event(&"ad_shown", {"placement": "interstitial"})
	provider.show_ad(AdProvider.INTERSTITIAL)
	return true


# ---------------------------------------------------------------- Présentation

func _begin(kind: StringName) -> void:
	_showing = kind
	_show_started = clock.ticks()
	_was_paused = get_tree().paused
	_was_muted = AudioServer.is_bus_mute(0)
	get_tree().paused = true
	AudioServer.set_bus_mute(0, true)
	ad_started.emit(kind)


func _on_closed(kind: StringName) -> void:
	if kind != _showing:
		return
	if kind == AdProvider.REWARDED:
		# Récompense tardive encore acceptée pendant CLOSE_GRACE, puis fin.
		get_tree().create_timer(CLOSE_GRACE, true, false, true).timeout.connect(
			_finish.bind(kind, false))
	else:
		_finish(kind, false)


func _on_show_failed(kind: StringName, message: String) -> void:
	if kind != _showing:
		return
	Analytics.log_event(&"ad_failed", {"placement": String(_placement), "reason": message.left(80)})
	_finish(kind, true)


func _finish(kind: StringName, failed: bool) -> void:
	if _showing != kind:
		return
	_showing = &""
	get_tree().paused = _was_paused
	AudioServer.set_bus_mute(0, _was_muted)
	if kind == AdProvider.REWARDED and _session:
		var s := _session
		_session = null
		if failed:
			s.handle_failed()
		else:
			s.handle_closed()
	elif kind == AdProvider.INTERSTITIAL and _interstitial_done.is_valid():
		var cb := _interstitial_done
		_interstitial_done = Callable()
		cb.call()
	ad_finished.emit(kind)
	_load(kind)
	availability_changed.emit()


## Retour au premier plan : si la pub n'est jamais apparue (SDK muet), on
## reprend le jeu sans récompense plutôt que de rester bloqué en pause.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_IN or not is_showing():
		return
	var kind := _showing
	get_tree().create_timer(WATCHDOG, true, false, true).timeout.connect(func() -> void:
		if _showing == kind and not provider.is_presenting():
			_finish(kind, true))
