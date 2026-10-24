class_name MockAds
extends AdProvider
## Pubs simulées (éditeur, PC, tests). Aucune requête réseau.
## - `interactive` : écran « PUB SIMULÉE » avec compte à rebours ; le fermer
##   avant la fin = pas de récompense (comme une vraie rewarded).
## - `manual` (tests) : rien n'est automatique, le test appelle
##   complete_load() / finish().

enum Outcome { COMPLETE, CLOSE_EARLY, FAIL_TO_SHOW }

var config: AdsConfig
var interactive: bool = true
var manual: bool = false
## Chargements réussis ? (sinon load_failed).
var fill: bool = true
var consent_granted: bool = true
var consent_required: bool = true

var _loaded: Dictionary = {}  # kind -> bool
var _presenting: StringName = &""
var _overlay: MockAdOverlay


func provider_name() -> String:
	return "mock"


func start(p_config: AdsConfig, _ids: Dictionary) -> void:
	config = p_config
	if config:
		fill = randf() <= config.mock_fill_rate
	consent_resolved.emit.call_deferred(consent_granted, consent_granted)


func privacy_options_required() -> bool:
	return consent_required


## Mini formulaire de consentement simulé (réglages).
func show_privacy_options() -> void:
	if not interactive:
		return
	var dlg := MockConsentDialog.new()
	add_child(dlg)
	dlg.decided.connect(func(granted: bool) -> void:
		consent_granted = granted
		consent_resolved.emit(granted, granted))


func load_ad(kind: StringName) -> void:
	if _loaded.get(kind, false) or manual:
		return
	var delay := config.mock_load_seconds if config else 0.1
	get_tree().create_timer(delay, true, false, true).timeout.connect(complete_load.bind(kind))


func complete_load(kind: StringName) -> void:
	if fill:
		_loaded[kind] = true
		loaded.emit(kind)
	else:
		load_failed.emit(kind, "no fill (mock)")


func is_loaded(kind: StringName) -> bool:
	return _loaded.get(kind, false)


func is_presenting() -> bool:
	return _presenting != &""


func show_ad(kind: StringName) -> void:
	if not is_loaded(kind):
		show_failed.emit(kind, "not loaded")
		return
	_loaded[kind] = false
	_presenting = kind
	opened.emit(kind)
	if manual or not interactive:
		if not manual:
			finish(Outcome.COMPLETE)
		return
	_overlay = MockAdOverlay.new()
	add_child(_overlay)
	_overlay.run(kind, config.mock_ad_seconds if config else 3.0)
	_overlay.finished.connect(func(completed: bool) -> void:
		finish(Outcome.COMPLETE if completed else Outcome.CLOSE_EARLY))


## Termine la pub en cours (tests : appelé directement).
func finish(outcome: Outcome) -> void:
	var kind := _presenting
	if kind == &"":
		return
	_presenting = &""
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	match outcome:
		Outcome.COMPLETE:
			if kind == REWARDED:
				earned.emit()
			closed.emit(kind)
		Outcome.CLOSE_EARLY:
			closed.emit(kind)
		Outcome.FAIL_TO_SHOW:
			show_failed.emit(kind, "failed (mock)")
