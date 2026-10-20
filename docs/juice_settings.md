# Réglages Juice (M2) — `data/juice.tres`

Généré depuis `scripts/data/juice_config.gd` + `data/juice.tres`. Unités : s, m (monde), px (UI), dB.


## Animation des fruits

| Réglage | Défaut | Rôle |
|---|---|---|
| `spawn_pop_time` | `0.2` | Pop de l'aperçu : 0 → overshoot → 1. |
| `spawn_pop_overshoot` | `1.1` |  |
| `stretch_max_y` | `1.15` | Étirement en chute (échelles max atteintes à stretch_full_speed m/s). |
| `stretch_min_x` | `0.9` |  |
| `stretch_full_speed` | `14.0` |  |
| `impact_min_speed` | `2.0` | Impact : variation brusque de vitesse (m/s) au-delà de laquelle on écrase. |
| `impact_full_speed` | `9.0` |  |
| `impact_squash_x` | `1.25` |  |
| `impact_squash_y` | `0.8` |  |
| `impact_recover_time` | `0.12` |  |
| `impact_cooldown` | `0.08` | Délai mini entre deux impacts d'un même fruit. |
| `breath_amplitude` | `0.02` | Respiration : amplitude relative et vitesse (rad/s). |
| `breath_speed` | `2.4` |  |
| `merge_suck_time` | `0.08` | Fusion : aspiration des 2 fruits vers le point de contact. |
| `merge_pop_overshoot` | `1.15` | Fusion : pop du nouveau fruit + flash blanc. |
| `merge_pop_time` | `0.22` |  |
| `merge_flash_time` | `0.12` |  |
| `danger_tremble_amplitude` | `0.035` | Tremblement des fruits au-dessus de la ligne (m, Hz). |
| `danger_tremble_speed` | `38.0` |  |

## Visages

| Réglage | Défaut | Rôle |
|---|---|---|
| `face_squashed_min_speed` | `6.0` | Vitesse d'impact (m/s) qui déclenche la grimace. |
| `face_squashed_time` | `0.3` |  |
| `blink_min_interval` | `2.0` |  |
| `blink_max_interval` | `6.0` |  |
| `blink_duration` | `0.12` |  |
| `eye_color` | `Color(0.08, 0.05, 0.04, 1)` |  |
| `eye_highlight_color` | `Color(1, 1, 1, 1)` |  |
| `mouth_color` | `Color(0.25, 0.06, 0.05, 1)` |  |
| `show_rank_numbers` | `true` | Petit numéro de rang sous la bouche (aide M1 / daltonisme). |

## Fusion : jus, onde, texte

| Réglage | Défaut | Rôle |
|---|---|---|
| `splash` | `SubResource("splash")` |  |
| `splash_pool_size` | `10` |  |
| `ring_pool_size` | `6` |  |
| `ring_time` | `0.35` |  |
| `ring_max_scale` | `2.4` |  |
| `ring_color` | `Color(1, 1, 1, 0.8)` |  |
| `float_text_pool_size` | `12` |  |
| `float_text_time` | `0.9` |  |
| `float_text_rise` | `1.3` |  |
| `float_text_font_size` | `110` |  |
| `float_text_color` | `Color(1, 1, 1, 1)` |  |
| `float_text_outline_color` | `Color(0.23, 0.14, 0.08, 1)` |  |

## Combo

| Réglage | Défaut | Rôle |
|---|---|---|
| `combo_min` | `2` |  |
| `combo_text_time` | `0.9` |  |
| `combo_text_font_size` | `130` |  |
| `combo_text_color` | `Color(0.902, 0.318, 0, 1)` |  |
| `hitstop_time` | `0.04` | Hit-stop : temps réel figé et échelle de temps pendant ce gel. |
| `hitstop_time_scale` | `0.05` |  |
| `combo_zoom` | `0.04` | Zoom caméra (fraction de la taille orthographique) et durée aller-retour. |
| `combo_zoom_time` | `0.25` |  |

## Grosse fusion

| Réglage | Défaut | Rôle |
|---|---|---|
| `big_merge_min_rank` | `6` | Rang (0-based) du fruit créé à partir duquel la fusion est « grosse ». 6 = Mangue. |
| `big_merge_trauma` | `0.45` |  |
| `confetti` | `SubResource("confetti")` |  |
| `confetti_pool_size` | `2` |  |

## Screen shake

| Réglage | Défaut | Rôle |
|---|---|---|
| `shake_max_offset` | `0.35` |  |
| `shake_decay` | `1.6` | Trauma perdu par seconde. |
| `shake_frequency` | `22.0` |  |

## Nouveau fruit

| Réglage | Défaut | Rôle |
|---|---|---|
| `discover_slowmo_time` | `0.4` |  |
| `discover_slowmo_scale` | `0.3` |  |
| `discover_banner_time` | `1.6` |  |
| `discover_banner_font_size` | `80` |  |
| `spotlight_time` | `0.8` |  |
| `spotlight_color` | `Color(1, 0.95, 0.6, 0.35)` |  |

## Moment Baobab

| Réglage | Défaut | Rôle |
|---|---|---|
| `baobab_slowmo_time` | `1.0` |  |
| `baobab_slowmo_scale` | `0.35` |  |
| `baobab_sequence_time` | `3.0` | Durée totale de la séquence (plafond 3 s, non bloquante). |
| `baobab_grow_time` | `1.2` |  |
| `baobab_trauma` | `0.7` |  |
| `baobab_text_color` | `Color(0.18, 0.49, 0.196, 1)` |  |
| `baobab_text_font_size` | `170` |  |
| `basket_glow_color` | `Color(1, 0.8, 0.3, 0.55)` |  |
| `leaves` | `SubResource("leaves")` |  |
| `coins` | `SubResource("coins")` |  |

## Danger

| Réglage | Défaut | Rôle |
|---|---|---|
| `line_pulse_speed_min` | `6.0` | Vitesse de pulsation de la ligne (rad/s), de l'alerte au game over. |
| `line_pulse_speed_max` | `24.0` |  |
| `line_alpha_safe` | `0.35` |  |
| `vignette_color` | `Color(0.85, 0.05, 0.05, 1)` |  |
| `vignette_max_alpha` | `0.55` |  |
| `heartbeat_interval_max` | `0.9` | Intervalle entre deux battements de cœur (s), de l'alerte au game over. |
| `heartbeat_interval_min` | `0.4` |  |
| `danger_alert_ratio` | `0.5` | Ratio de danger (0..1) à partir duquel l'alerte audio/visuelle démarre. |
| `lowpass_max_hz` | `20000.0` | Passe-bas sur le bus Music : coupure quand tout va bien → au game over. |
| `lowpass_min_hz` | `700.0` |  |

## Game over

| Réglage | Défaut | Rôle |
|---|---|---|
| `game_over_slowmo_scale` | `0.3` |  |
| `game_over_slowmo_time` | `1.2` |  |
| `game_over_freeze_interval` | `0.05` | Intervalle entre deux fruits qui se figent (du haut vers le bas). |
| `game_over_panel_slide_time` | `0.45` |  |
| `game_over_panel_delay` | `0.5` |  |
| `game_over_score_roll_time` | `1.0` |  |

## HUD

| Réglage | Défaut | Rôle |
|---|---|---|
| `score_roll_time` | `0.35` | Temps (s) pour que le compteur rattrape le score. |
| `score_pulse_scale` | `1.18` |  |
| `score_pulse_time` | `0.15` |  |

## Haptique (ms)

| Réglage | Défaut | Rôle |
|---|---|---|
| `vibrate_drop_ms` | `8` |  |
| `vibrate_merge_ms` | `12` |  |
| `vibrate_big_merge_ms` | `40` |  |
| `vibrate_baobab_ms` | `150` |  |
| `vibrate_game_over_ms` | `80` |  |

## Qualité / effets réduits

| Réglage | Défaut | Rôle |
|---|---|---|
| `quality` | `2` |  |
| `quality_particle_multipliers` | `PackedFloat32Array(0.35, 0.65, 1)` | Multiplicateur de particules par niveau [Bas, Moyen, Haut]. |
| `reduced_particle_divisor` | `3.0` | « Effets réduits » : particules divisées par ce nombre, plus de shake ni de hit-stop. |
| `auto_quality` | `true` | Baisse auto de la qualité si les FPS moyens passent sous ce seuil. |
| `auto_quality_min_fps` | `45.0` |  |
| `auto_quality_window` | `4.0` |  |

## Audio

| Réglage | Défaut | Rôle |
|---|---|---|
| `sounds` | `ExtResource("3")` |  |
| `master_volume_db` | `0.0` |  |
| `music_volume_db` | `-12.0` |  |
| `sfx_volume_db` | `-2.0` |  |
| `sfx_pool_size` | `16` |  |
| `pitch_jitter` | `0.05` | Variation de hauteur aléatoire sur les sons répétés (±). |
| `drop_volume_db` | `-8.0` |  |
| `impact_volume_min_db` | `-26.0` |  |
| `impact_volume_max_db` | `-8.0` |  |
| `impact_max_per_second` | `8` |  |
| `merge_volume_db` | `-3.0` |  |
| `combo_volume_db` | `-6.0` |  |
| `discover_volume_db` | `-2.0` |  |
| `baobab_volume_db` | `0.0` |  |
| `heartbeat_volume_db` | `-4.0` |  |
| `game_over_volume_db` | `-3.0` |  |

## Debug

| Réglage | Défaut | Rôle |
|---|---|---|
| `show_fps_in_debug` | `true` |  |
| `debug_long_press_time` | `1.0` | Appui long à 3 doigts pour ouvrir le menu debug. |

## Gerbes de particules (sous-ressources)

| Gerbe | amount | lifetime | vitesse | forme |
|---|---|---|---|---|
| splash | 24 | 0.6 | 3.0–7.0 | sphère |
| confetti | 70 | 1.6 | 6.0–11.0 | feuille |
| leaves | 50 | 2.6 | 0.5–2.0 | feuille |
| coins | 30 | 2.2 | 1.0–3.0 | pièce |
