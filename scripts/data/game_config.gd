class_name GameConfig
extends Resource
## Tous les réglages de physique et de règles (équilibrage), jamais en dur.
## Unités : mètres / secondes. Les valeurs de référence sont dans data/game_config.tres.

@export_group("Panier")
@export var basket_inner_width: float = 6.4
@export var basket_height: float = 8.6
@export var wall_thickness: float = 0.4
@export var danger_line_y: float = 7.6
@export var spawn_y: float = 9.4

@export_group("Caméra")
## Marge horizontale totale autour du panier (m).
@export var camera_side_margin: float = 1.2
## Décalage vertical du centre caméra au-dessus du milieu du panier (m).
@export var camera_y_offset: float = 1.8
## M4 : bande réservée en bas de l'écran (px du canevas 1080 de large) pour
## la barre de power-ups, prise sur la hauteur en plus des écrans > 16:9.
@export var bottom_ui_band_px: float = 250.0

@export_group("Physique")
@export var gravity_scale: float = 1.6
@export var bounce: float = 0.08
@export var friction: float = 0.45
@export var linear_damp: float = 0.15
@export var angular_damp: float = 0.6
## Masse = mass_per_area * rayon².
@export var mass_per_area: float = 1.0
@export var max_contacts: int = 8
## Collision calée sur la boîte XY du modèle 3D (sinon sphère du rayon, qui
## dépasse des fruits allongés et laisse des vides) : sphère pour les fruits
## ronds, capsule verticale au-delà de cet allongement (hauteur / largeur).
@export var collider_from_model: bool = true
@export var capsule_min_elongation: float = 1.12
## Part de la boîte du modèle couverte par la collision (< 1 : contact visuel).
@export_range(0.8, 1.05) var collider_fit: float = 0.97

@export_group("Lâcher")
@export var drop_cooldown: float = 0.4
@export var preview_count: int = 1

@export_group("Fusion")
@export var merge_grow_start_scale: float = 0.7
@export var merge_grow_time: float = 0.15
@export var merge_up_impulse: float = 1.2

@export_group("Danger / Game over")
## Délai après l'apparition avant qu'un fruit compte pour la ligne de danger.
@export var danger_grace_time: float = 1.0
@export var danger_warn_time: float = 1.0
@export var danger_game_over_time: float = 2.0

@export_group("Combo")
@export var combo_window: float = 1.5
@export var combo_max_multiplier: int = 8
## true : un combo = une cascade issue d'UN lâcher (le spam n'est pas récompensé).
@export var combo_reset_on_drop: bool = true
