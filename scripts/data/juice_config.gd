class_name JuiceConfig
extends Resource
## Tous les réglages du « juice » (M2) : animations, visages, effets, son, qualité.
## Unités : secondes, mètres (monde), pixels (UI), dB (volumes).
## Les valeurs de référence sont dans data/juice.tres. Rien en dur dans le code.

enum Quality { LOW, MEDIUM, HIGH }

@export_group("Animation des fruits")
## Pop de l'aperçu : 0 → overshoot → 1.
@export var spawn_pop_time: float = 0.2
@export var spawn_pop_overshoot: float = 1.1
## Étirement en chute (échelles max atteintes à stretch_full_speed m/s).
@export var stretch_max_y: float = 1.15
@export var stretch_min_x: float = 0.9
@export var stretch_full_speed: float = 14.0
## Impact : variation brusque de vitesse (m/s) au-delà de laquelle on écrase.
@export var impact_min_speed: float = 2.0
@export var impact_full_speed: float = 9.0
@export var impact_squash_x: float = 1.25
@export var impact_squash_y: float = 0.8
@export var impact_recover_time: float = 0.12
## Délai mini entre deux impacts d'un même fruit.
@export var impact_cooldown: float = 0.08
## Respiration : amplitude relative et vitesse (rad/s).
@export var breath_amplitude: float = 0.02
@export var breath_speed: float = 2.4
## Fusion : aspiration des 2 fruits vers le point de contact.
@export var merge_suck_time: float = 0.08
## Fusion : pop du nouveau fruit + flash blanc.
@export var merge_pop_overshoot: float = 1.15
@export var merge_pop_time: float = 0.22
@export var merge_flash_time: float = 0.12
## Tremblement des fruits au-dessus de la ligne (m, Hz).
@export var danger_tremble_amplitude: float = 0.035
@export var danger_tremble_speed: float = 38.0

@export_group("Lâcher")
## Le fruit en visée penche dans le sens du doigt (ressort) : gain (rad par m/s), max (rad).
@export var aim_tilt_gain: float = 0.05
@export var aim_tilt_max: float = 0.4
@export var aim_tilt_stiffness: float = 180.0
@export var aim_tilt_damping: float = 9.0
## Traînée lumineuse derrière le fruit qui tombe : longueur (s × vitesse), max (m), opacité.
@export var trail_length_per_speed: float = 0.13
@export var trail_max_length: float = 2.4
@export var trail_alpha: float = 0.45
@export var trail_pool_size: int = 3
## Petites gouttes à l'impact (vitesse normalisée minimale 0..1).
@export var puff: ParticleSettings
@export var puff_pool_size: int = 4
@export_range(0.0, 1.0) var puff_min_impact: float = 0.45
## Le fruit suivant tombe dans la visée depuis cette hauteur (m) en ce temps (s).
@export var preview_drop_height: float = 0.9
@export var preview_drop_time: float = 0.28

@export_group("Visages")
## Vitesse d'impact (m/s) qui déclenche la grimace.
@export var face_squashed_min_speed: float = 6.0
@export var face_squashed_time: float = 0.3
@export var blink_min_interval: float = 2.0
@export var blink_max_interval: float = 6.0
@export var blink_duration: float = 0.12
@export var eye_color: Color = Color(0.08, 0.05, 0.04)
@export var eye_highlight_color: Color = Color(1, 1, 1)
@export var mouth_color: Color = Color(0.25, 0.06, 0.05)
## Petit numéro de rang sous la bouche (aide M1 / daltonisme).
@export var show_rank_numbers: bool = true
## Regard : les fruits voisins tournent les yeux vers une fusion.
## Rayon (m), durée (s), décalage du visage (fraction du rayon).
@export var look_radius: float = 3.5
@export var look_time: float = 0.9
@export var look_offset: float = 0.12

@export_group("Fusion : jus, onde, texte")
@export var splash: ParticleSettings
@export var splash_pool_size: int = 10
@export var ring_pool_size: int = 6
@export var ring_time: float = 0.35
@export var ring_max_scale: float = 2.4
@export var ring_color: Color = Color(1, 1, 1, 0.8)
@export var float_text_pool_size: int = 12
@export var float_text_time: float = 0.9
@export var float_text_rise: float = 1.3
@export var float_text_font_size: int = 110
@export var float_text_color: Color = Color(1, 1, 1)
@export var float_text_outline_color: Color = Color(0.23, 0.14, 0.08)
## Texte « +28 » teinté par la couleur du fruit (0 = blanc, 1 = couleur pure).
@export_range(0.0, 1.0) var float_text_tint: float = 0.45

@export_group("Fusion : gouttes, étoiles, éclair")
## Grosses gouttes de jus (couleur du fruit), allongées dans le sens de la vitesse.
@export var drops: ParticleSettings
@export var drop_pool_size: int = 8
## Étoiles dorées additives (brillent avec le glow).
@export var stars: ParticleSettings
@export var star_pool_size: int = 8
## Étoiles supplémentaires par niveau de combo au-delà de combo_min (gerbes).
@export var combo_extra_star_bursts: int = 1
## Éclair radial additif au point de fusion : durée, taille (× rayon), couleur.
@export var flash_pool_size: int = 8
@export var flash_time: float = 0.22
@export var flash_scale: float = 3.2
@export var flash_color: Color = Color(1.0, 0.92, 0.6, 0.9)
## Gerbes multipliées par la taille du fruit créé : rang ≥ ce seuil = double gerbe.
@export var big_burst_min_rank: int = 5

@export_group("Combo")
@export var combo_min: int = 2
@export var combo_text_time: float = 0.9
@export var combo_text_font_size: int = 130
@export var combo_text_color: Color = Color("e65100")
## Bannière : dégradé du texte (haut → bas), contours, rayons et halo.
@export var combo_fill_top: Color = Color("fff27a")
@export var combo_fill_bottom: Color = Color("ff8a00")
## Niveau « chaud » (combo ≥ combo_hot_level) : texte plus rouge, rayons plus vifs.
@export var combo_hot_level: int = 5
@export var combo_hot_fill_bottom: Color = Color("ff3d00")
@export var combo_inner_outline: Color = Color("fff6dc")
@export var combo_outer_outline: Color = Color("6b2a06")
@export var combo_ray_color: Color = Color(1.0, 0.7, 0.15, 0.85)
@export var combo_glow_color: Color = Color(1.0, 0.75, 0.2, 0.75)
@export var combo_ray_count: int = 14
## Croissance de la taille du texte par niveau de combo (fraction).
@export var combo_level_growth: float = 0.08
## Tremblement du texte (px) à partir du niveau chaud.
@export var combo_hot_shake: float = 6.0
## Hit-stop : temps réel figé et échelle de temps pendant ce gel.
@export var hitstop_time: float = 0.04
@export var hitstop_time_scale: float = 0.05
## Pas de temps réel max compté par frame pour les ralentis (s) : une frame
## lente (chargement, à-coup) ne consomme pas tout un hit-stop d'un coup.
@export var time_scale_max_step: float = 0.034
## Zoom caméra (fraction de la taille orthographique) et durée aller-retour.
@export var combo_zoom: float = 0.04
@export var combo_zoom_time: float = 0.25

@export_group("Grosse fusion")
## Rang (0-based) du fruit créé à partir duquel la fusion est « grosse ». 6 = Mangue.
@export var big_merge_min_rank: int = 6
@export var big_merge_trauma: float = 0.45
@export var confetti: ParticleSettings
@export var confetti_pool_size: int = 2

@export_group("Panier qui réagit")
## Le cadre s'écrase sur les gros impacts / grosses fusions (ressort amorti).
## Écrasement par impact = vitesse normalisée × rayon × ce gain, plafonné.
@export var basket_bump_gain: float = 0.02
@export var basket_bump_max: float = 0.025
@export var basket_bump_merge: float = 0.02
@export var basket_spring_stiffness: float = 320.0
@export var basket_spring_damping: float = 12.0

@export_group("Screen shake")
@export var shake_max_offset: float = 0.35
## Trauma perdu par seconde.
@export var shake_decay: float = 1.6
@export var shake_frequency: float = 22.0

@export_group("Nouveau fruit")
@export var discover_slowmo_time: float = 0.4
@export var discover_slowmo_scale: float = 0.3
@export var discover_banner_time: float = 1.6
@export var discover_banner_font_size: int = 80
@export var spotlight_time: float = 0.8
@export var spotlight_color: Color = Color(1, 0.95, 0.6, 0.35)

@export_group("Moment Baobab")
@export var baobab_slowmo_time: float = 1.0
@export var baobab_slowmo_scale: float = 0.35
## Durée totale de la séquence (plafond 3 s, non bloquante).
@export var baobab_sequence_time: float = 3.0
@export var baobab_grow_time: float = 1.2
@export var baobab_trauma: float = 0.7
@export var baobab_text_color: Color = Color("2e7d32")
@export var baobab_text_font_size: int = 170
@export var basket_glow_color: Color = Color(1.0, 0.8, 0.3, 0.55)
@export var leaves: ParticleSettings
@export var coins: ParticleSettings

@export_group("Danger")
## Vitesse de pulsation de la ligne (rad/s), de l'alerte au game over.
@export var line_pulse_speed_min: float = 6.0
@export var line_pulse_speed_max: float = 24.0
@export var line_alpha_safe: float = 0.35
@export var vignette_color: Color = Color(0.85, 0.05, 0.05)
@export var vignette_max_alpha: float = 0.55
## Intervalle entre deux battements de cœur (s), de l'alerte au game over.
@export var heartbeat_interval_max: float = 0.9
@export var heartbeat_interval_min: float = 0.4
## Ratio de danger (0..1) à partir duquel l'alerte audio/visuelle démarre.
@export var danger_alert_ratio: float = 0.5
## Passe-bas sur le bus Music : coupure quand tout va bien → au game over.
@export var lowpass_max_hz: float = 20000.0
@export var lowpass_min_hz: float = 700.0

@export_group("Game over")
@export var game_over_slowmo_scale: float = 0.3
@export var game_over_slowmo_time: float = 1.2
## Intervalle entre deux fruits qui se figent (du haut vers le bas).
@export var game_over_freeze_interval: float = 0.05
@export var game_over_panel_slide_time: float = 0.45
@export var game_over_panel_delay: float = 0.5
@export var game_over_score_roll_time: float = 1.0

@export_group("HUD")
## Temps (s) pour que le compteur rattrape le score.
@export var score_roll_time: float = 0.35
@export var score_pulse_scale: float = 1.18
@export var score_pulse_time: float = 0.15
## Étoiles qui volent vers le score : durée du vol, décalage entre étoiles, pool.
@export var fly_time: float = 0.55
@export var fly_stagger: float = 0.06
@export var fly_pool_size: int = 14
## Étoiles par fusion : 1 + rang / ce diviseur (+1 en combo), plafonné.
@export var fly_rank_divisor: int = 3
@export var fly_max: int = 5
## Carte « Le savais-tu ? » : durée d'affichage (s, temps réel).
@export var fact_card_time: float = 4.5

@export_group("Haptique (ms)")
@export var vibrate_drop_ms: int = 8
@export var vibrate_merge_ms: int = 12
@export var vibrate_big_merge_ms: int = 40
@export var vibrate_baobab_ms: int = 150
@export var vibrate_game_over_ms: int = 80

@export_group("Qualité / effets réduits")
@export var quality: Quality = Quality.HIGH
## Multiplicateur de particules par niveau [Bas, Moyen, Haut].
@export var quality_particle_multipliers: PackedFloat32Array = PackedFloat32Array([0.35, 0.65, 1.0])
## « Effets réduits » : particules divisées par ce nombre, plus de shake ni de hit-stop.
@export var reduced_particle_divisor: float = 3.0
## Baisse auto de la qualité si les FPS moyens passent sous ce seuil.
@export var auto_quality: bool = true
@export var auto_quality_min_fps: float = 45.0
@export var auto_quality_window: float = 4.0

@export_group("Audio")
@export var sounds: SoundBank
@export var master_volume_db: float = 0.0
@export var music_volume_db: float = -12.0
@export var sfx_volume_db: float = -2.0
@export var sfx_pool_size: int = 16
## Variation de hauteur aléatoire sur les sons répétés (±).
@export var pitch_jitter: float = 0.05
@export var drop_volume_db: float = -8.0
@export var impact_volume_min_db: float = -26.0
@export var impact_volume_max_db: float = -8.0
@export var impact_max_per_second: int = 8
@export var merge_volume_db: float = -3.0
@export var combo_volume_db: float = -6.0
@export var discover_volume_db: float = -2.0
@export var baobab_volume_db: float = 0.0
@export var heartbeat_volume_db: float = -4.0
@export var game_over_volume_db: float = -3.0
## Son de fusion unique (SoundBank.merge) : demi-tons ajoutés par rang créé.
@export var merge_semitones_per_rank: float = 1.0
@export var ui_click_volume_db: float = -8.0
## Au plus N clics par seconde (le fichier a une longue fin).
@export var ui_click_max_per_second: int = 6
@export var play_volume_db: float = -3.0
@export var powerup_volume_db: float = -3.0
@export var coins_volume_db: float = -4.0
@export var coins_max_per_second: int = 3

@export_group("Debug")
@export var show_fps_in_debug: bool = true
## Appui long à 3 doigts pour ouvrir le menu debug.
@export var debug_long_press_time: float = 1.0


## Multiplicateur de particules pour un niveau de qualité donné.
func particle_multiplier(level: int, reduced: bool) -> float:
	var m := 1.0
	if not quality_particle_multipliers.is_empty():
		m = quality_particle_multipliers[clampi(level, 0, quality_particle_multipliers.size() - 1)]
	return m / reduced_particle_divisor if reduced else m
