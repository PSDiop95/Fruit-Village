class_name VisualConfig
extends Resource
## Réglages du rendu M3 (toon shading, contour, halo, modèles). Valeurs de
## référence dans data/visual.tres. Aucun impact sur la physique.

@export_group("Modèles")
## Modèle d'un fruit : chemin formaté avec FruitDef.id.
@export var fruit_model_pattern: String = "res://assets/models/fruit_%s.glb"
@export var palette: Texture2D

@export_group("Lumière (fin d'après-midi)")
@export var sun_color: Color = Color("ffe6c4")
@export var sun_energy: float = 1.0
@export var sun_rotation_degrees: Vector3 = Vector3(-28, -32, 0)
@export var ambient_color: Color = Color("ffe8cc")
@export var ambient_energy: float = 0.3

@export_group("Toon")
## Seuils N·L (ombre | moyen | lumière) et intensité de chaque ton.
@export_range(-1.0, 1.0) var shadow_threshold: float = 0.05
@export_range(-1.0, 1.0) var light_threshold: float = 0.5
@export_range(0.0, 1.0) var shadow_tone: float = 0.45
@export_range(0.0, 1.0) var mid_tone: float = 0.78
## Largeur de la transition entre tons (anti-crénelage).
@export_range(0.0, 0.2) var tone_softness: float = 0.03
## Teinte des ombres (multipliée à la couleur palette).
@export var shadow_tint: Color = Color(0.82, 0.72, 0.9)
@export_group("Reflet")
@export_range(1.0, 256.0) var specular_shininess: float = 48.0
@export_range(0.0, 1.0) var specular_threshold: float = 0.5
@export_range(0.0, 2.0) var specular_strength: float = 0.55
## Flou du bord du reflet (0 = net, 0.3 = tache douce).
@export_range(0.0, 0.5) var specular_softness: float = 0.02
@export_group("Fruit peint")
## Saturation des couleurs (1 = palette telle quelle).
@export_range(0.5, 2.0) var saturation: float = 1.0
## Assombrissement du bord intérieur (volume) et sa finesse.
@export_range(0.0, 1.0) var edge_darken: float = 0.0
@export_range(0.5, 8.0) var edge_power: float = 2.5
## Éclaircissement du haut / assombrissement du bas (± fraction).
@export_range(0.0, 0.5) var top_light: float = 0.0
@export_group("Grain de peau")
## Mouchetures sombres (fraction d'assombrissement) et fréquence (1/m).
@export_range(0.0, 0.5) var grain_strength: float = 0.0
@export var grain_scale: float = 14.0
## Marbrures larges (± fraction de luminosité) et fréquence (1/m).
@export_range(0.0, 0.5) var mottle_strength: float = 0.0
@export var mottle_scale: float = 2.5
@export_group("Rim light")
@export var rim_color: Color = Color(1.0, 0.78, 0.45)
@export_range(0.0, 2.0) var rim_strength: float = 0.3
@export_range(0.5, 8.0) var rim_power: float = 3.0
## Matière velours (gloss 0 dans la palette) : rim large et doux.
@export_range(0.0, 2.0) var velvet_strength: float = 0.3
@export_range(0.5, 8.0) var velvet_power: float = 1.6

@export_group("Contour (coque inversée)")
## Épaisseur monde (m) : caméra orthographique → épaisseur écran constante.
@export_range(0.0, 0.2) var outline_width: float = 0.035
@export var outline_color: Color = Color("3a2414")
## 1 = extrusion radiale depuis le centre (fruits quasi sphériques, sans fissure
## sur les arêtes vives), 0 = le long des normales.
@export_range(0.0, 1.0) var outline_radial: float = 1.0
## Fruits non convexes (renflements qui se chevauchent) : contour le long des normales.
@export var outline_normal_ids: PackedStringArray = PackedStringArray(["tamarin"])

@export_group("Halo (fruits précieux)")
## Rangs (0-based) entourés d'un halo. 10 = Pain de singe.
@export var halo_ranks: PackedInt32Array = PackedInt32Array([10])
@export var halo_color: Color = Color(1.0, 0.92, 0.55, 0.45)
## Taille du halo (× rayon) et pulsation (amplitude relative, rad/s).
@export var halo_size: float = 2.7
@export var halo_pulse_amplitude: float = 0.08
@export var halo_pulse_speed: float = 2.0

@export_group("Cadre du panier")
## Cadre bois + frise wax peint (tools/prepare_ui_art.gd), au format du panier :
## remplace le modèle de calebasse quand il est défini. Purement visuel.
@export var basket_frame: Texture2D
## Épaisseur du bois autour de l'intérieur du panier (m).
@export var basket_frame_border: float = 0.75
## Profondeur du cadre (derrière les plus gros fruits, rayon 1,68).
@export var basket_frame_z: float = -1.8
## M4 : teinte du cadre « panier doré » (récompense album complet).
@export var basket_gold_tint: Color = Color(1.0, 0.86, 0.42)

@export_group("Mascotte")
## Singe articulé (tools/blender/mascot_singe.py) assis sur le coin du cadre.
## Vide = pas de mascotte.
@export var mascot_model: String = "res://assets/models/mascot_singe.glb"
## Position de l'assise (m, plan du jeu) et échelle.
@export var mascot_position: Vector3 = Vector3(-3.25, 9.35, -1.2)
@export var mascot_scale: float = 1.45
## Visage (yeux + bouche du jeu) : centre relatif au cou et rayon de la tête.
@export var mascot_face_offset: Vector3 = Vector3(0, 0.25, 0.33)
@export var mascot_face_scale: float = 0.36
## Combo (ou rang créé) à partir duquel la mascotte fait la fête.
@export var mascot_cheer_combo: int = 3
@export var mascot_cheer_rank: int = 6
## Durées des réactions (s, temps réel).
@export var mascot_cheer_time: float = 1.3
@export var mascot_party_time: float = 3.0
@export var mascot_surprise_time: float = 1.0
@export var mascot_nod_time: float = 0.25
## Amplitudes : saut (m), bras levés (rad), regard vers la visée (rad/m).
@export var mascot_jump: float = 0.28
@export var mascot_arm_raise: float = 2.4
@export var mascot_look: float = 0.1
## Vitesse de lissage des poses (1/s).
@export var mascot_smoothing: float = 14.0
## Contour de la mascotte à partir de ce niveau de qualité (7 draw calls de plus).
@export var mascot_outline_min_quality: int = 2

@export_group("Guirlandes et ciel de nuit")
## Fils de guirlande (ambiances du soir) : (x0, y0, x1, y1) en m, plan du décor proche.
@export var garland_lines: Array[Vector4] = [Vector4(-4.7, 11.3, 0.5, 11.0), Vector4(-0.3, 11.2, 4.7, 11.45)]
## Flèche du fil au milieu (m), espacement et rayon des ampoules (m).
@export var garland_sag: float = 0.7
@export var garland_bulb_spacing: float = 0.46
@export var garland_bulb_radius: float = 0.1
@export var garland_wire_width: float = 0.03
@export var garland_wire_color: Color = Color("2a1a10")
@export var garland_z: float = -2.2
## Scintillement des ampoules : amplitude relative et vitesse (rad/s).
@export var garland_twinkle: float = 0.25
@export var garland_twinkle_speed: float = 3.0
## Étoiles du ciel de nuit : nombre, zone (x0, y0, x1, y1), taille (m), profondeur.
@export var night_star_count: int = 70
@export var night_star_area: Vector4 = Vector4(-4.5, 10.2, 4.5, 18.0)
@export var night_star_size: Vector2 = Vector2(0.02, 0.05)
@export var night_sky_z: float = -29.0
## Lune : position (plan du ciel), rayon, couleur.
@export var moon_position: Vector2 = Vector2(0.32, 12.35)
@export var moon_radius: float = 0.45
@export var moon_color: Color = Color("fff4cf")

@export_group("Fond peint")
## Illustration du décor (pleine largeur de l'écran, collée en haut), avec le
## ciel prolongé au-dessus et le sol en dessous (couleurs prélevées dans l'image).
## Remplace le décor 3D en plans quand elle est définie.
@export var backdrop: Texture2D
@export var backdrop_depth: float = 40.0
## Agrandissement de l'illustration (1 = pleine largeur exacte). > 1 : l'image
## descend derrière le haut du panier (bords latéraux légèrement rognés).
@export var backdrop_cover: float = 1.18
## Hauteur (m) du fondu entre le bas de l'illustration et la couleur du sol.
@export var backdrop_fade: float = 1.2

@export_group("Marché (panier, étal, décor)")
@export var background_color: Color = Color("f6dcae")
@export var basket_model: String = "res://assets/models/basket_calebasse.glb"
@export var stall_model: String = "res://assets/models/stall_sandaga.glb"
## Plans du décor : modèle, profondeur (m derrière le plan de jeu), estompe, désaturation.
@export var decor_layers: Array[Dictionary] = [
	{"model": "res://assets/models/decor_far.glb", "depth": 30.0, "fade": 0.12, "desaturate": 0.0},
	{"model": "res://assets/models/decor_mid.glb", "depth": 16.0, "fade": 0.05, "desaturate": 0.0},
	{"model": "res://assets/models/decor_near.glb", "depth": 2.5, "fade": 0.0, "desaturate": 0.0},
]
@export var decor_haze_color: Color = Color("f6dcae")
## Passants (personnages articulés : body, arm_l, arm_r, leg_l, leg_r).
@export var people_models: PackedStringArray = PackedStringArray([
	"res://assets/models/decor_femme_bassine.glb", "res://assets/models/decor_homme_blanc.glb",
	"res://assets/models/decor_femme.glb", "res://assets/models/decor_homme_indigo.glb"])
## Marche : amplitude du balancier (rad), cadence (pas/s), rebond (m), angle
## de trois-quarts vers la direction de marche (rad).
@export var walk_swing: float = 0.45
@export var walk_cadence: float = 1.8
@export var walk_bob: float = 0.04
@export var walk_turn: float = 1.0
@export var passant_depth: float = 14.0
@export var passant_fade: float = 0.38
@export var passant_ground_y: float = 8.2
## Aller-retour : demi-amplitude (m), vitesse (m/s), dandinement (rad, Hz).
@export var passant_range: float = 5.5
@export var passant_speed: float = 0.7
@export var passant_sway: float = 0.06
@export var passant_sway_speed: float = 6.0
## Cordelette de la ligne de danger.
@export var danger_cord_radius: float = 0.045
@export var danger_cord_color: Color = Color("c8282a")

@export_group("Glow (effets)")
## Halo lumineux sur les zones très claires (flash de fusion, halo, confettis).
@export var glow_enabled: bool = true
@export var glow_intensity: float = 0.45
@export var glow_strength: float = 1.0
@export var glow_hdr_threshold: float = 0.92

@export_group("Ombres")
## Ombres dynamiques (directionnelle) à partir de ce niveau de qualité.
## 99 = jamais : en vue de face, les fruits touchent presque le fond du panier,
## leur ombre portée reste cachée derrière eux. Les taches d'ombre la remplacent.
@export var shadows_min_quality: int = 99
## Taches d'ombre sous les fruits (tous niveaux de qualité).
@export var blob_shadows_enabled: bool = true
@export var shadow_opacity: float = 1.0
## Ton dans l'ombre portée (1 = invisible, 0,5 = moitié plus sombre).
@export_range(0.0, 1.0) var cast_shadow_tone: float = 0.55
## Tache d'ombre sous chaque fruit, sur le fond du panier.
@export var blob_shadow_color: Color = Color(0.2, 0.08, 0.02, 0.5)
@export var blob_shadow_offset: Vector2 = Vector2(0.24, -0.16)
@export var blob_shadow_scale: float = 2.2

@export_group("Qualité")
## Contour et rim light activés à partir de ce niveau (JuiceConfig.Quality).
@export var outline_min_quality: int = 1
## Contour des fruits (passe d'inversion de normales). Coupé : il n'apparaissait
## qu'en qualité Moyen/Haut, d'où des fruits tantôt cernés de noir, tantôt non.
@export var fruit_outline: bool = false
@export var rim_min_quality: int = 1
## Résolution 3D (part de l'écran, upscale FSR) par niveau Bas / Moyen / Haut.
## Mesures Galaxy A23 (Adreno 610) : 80 % → 38 FPS, 70 % → 45 FPS.
@export var render_scale_by_quality: PackedFloat32Array = PackedFloat32Array([0.62, 0.7, 0.8])
## MSAA 3D par niveau (Viewport.MSAA : 0 = aucun, 1 = 2x).
@export var msaa_by_quality: PackedInt32Array = PackedInt32Array([0, 0, 1])
## Glow (halo lumineux) à partir de ce niveau.
@export var glow_min_quality: int = 2
