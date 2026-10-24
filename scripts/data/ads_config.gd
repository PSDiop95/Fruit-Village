class_name AdsConfig
extends Resource
## Publicité : placements rewarded, règles de l'interstitiel, identifiants de
## TEST Google. Les vrais identifiants viennent de res://ads_ids.cfg (ignoré
## par git) et ne sont lus qu'en build release.

const CONTINUE := &"continue"
const SHAKE_FREE := &"shake_free"
const DOUBLE_COINS := &"double_coins"
const DOUBLE_MISSION := &"double_mission"
const STREAK_SHIELD := &"streak_shield"
const INTERSTITIAL := &"interstitial"

## Placements rewarded actifs (retirer un placement = bouton jamais proposé).
@export var rewarded_placements: Array[StringName] = [CONTINUE, SHAKE_FREE, DOUBLE_COINS,
	DOUBLE_MISSION, STREAK_SHIELD]

## Politique de confidentialité (Réglages, consentement, fiche Play Store).
@export var privacy_policy_url: String = "https://fruit-village.netlify.app/"

@export_group("Continuer")
@export var continue_remove_count: int = 3
@export var continue_max_per_game: int = 1
## Délai (s) avant que l'offre « Continuer » se retire d'elle-même.
@export var continue_offer_seconds: float = 6.0

@export_group("Interstitiel")
@export var interstitial_enabled: bool = true
@export var interstitial_min_games_between: int = 3
@export var interstitial_min_seconds_between: float = 180.0
## Jamais avant cette partie de la vie du joueur (5 = au plus tôt après la 5e).
@export var interstitial_min_lifetime_games: int = 5
## Pas d'interstitiel si un rewarded a été vu il y a moins de N s.
@export var interstitial_after_rewarded_seconds: float = 90.0
## Jamais pendant les N premières secondes de la session.
@export var interstitial_session_grace_seconds: float = 120.0

@export_group("Chargement")
## Délais de relance après un échec de chargement (s) ; le dernier se répète.
@export var retry_delays: PackedFloat32Array = PackedFloat32Array([5.0, 15.0, 30.0, 60.0])

@export_group("Identifiants de test Google (Android)")
@export var test_app_id: String = "ca-app-pub-3940256099942544~3347511713"
@export var test_rewarded_id: String = "ca-app-pub-3940256099942544/5224354917"
@export var test_interstitial_id: String = "ca-app-pub-3940256099942544/1033173712"

@export_group("Consentement UMP (debug uniquement)")
## Simule la zone EEE (formulaire RGPD) sur les appareils de test, en debug.
@export var ump_debug_eea: bool = false
## Empreintes d'appareils de test (logcat : « addTestDeviceHashedId(...) »).
@export var ump_test_device_ids: PackedStringArray = PackedStringArray()

@export_group("Pubs simulées (MockAds)")
## Probabilité qu'une pub simulée se charge.
@export var mock_fill_rate: float = 1.0
@export var mock_load_seconds: float = 0.5
@export var mock_ad_seconds: float = 3.0


func is_placement_enabled(placement: StringName) -> bool:
	return placement in rewarded_placements
