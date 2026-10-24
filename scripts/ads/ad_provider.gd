class_name AdProvider
extends Node
## Interface d'un fournisseur de pubs (consentement, rewarded, interstitiel).
## Implémentations : MockAds (dev, tests), AdMobAds (prod, Android).
## AdsManager est le seul à l'utiliser ; le jeu ne parle qu'à AdsManager.

const REWARDED := &"rewarded"
const INTERSTITIAL := &"interstitial"

## Consentement résolu (UMP). `can_request_ads` : pubs autorisées ;
## `analytics_ok` : statistiques autorisées.
signal consent_resolved(can_request_ads: bool, analytics_ok: bool)
signal loaded(kind: StringName)
signal load_failed(kind: StringName, message: String)
signal opened(kind: StringName)
## Callback de récompense du SDK (rewarded uniquement).
signal earned
signal closed(kind: StringName)
signal show_failed(kind: StringName, message: String)


func provider_name() -> String:
	return "none"


## Consentement puis initialisation du SDK. Aucune requête de pub avant
## consent_resolved(true, …).
func start(_config: AdsConfig, _ids: Dictionary) -> void:
	consent_resolved.emit(false, false)


## Le formulaire « gérer mon consentement » doit-il être proposé ?
func privacy_options_required() -> bool:
	return false


func show_privacy_options() -> void:
	pass


func load_ad(_kind: StringName) -> void:
	pass


func is_loaded(_kind: StringName) -> bool:
	return false


func show_ad(_kind: StringName) -> void:
	show_failed.emit(_kind, "unsupported")


## Une pub est à l'écran (ouverte, pas encore fermée).
func is_presenting() -> bool:
	return false
