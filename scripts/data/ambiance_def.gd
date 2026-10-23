class_name AmbianceDef
extends Resource
## Une ambiance du marché (jour, coucher de soleil, nuit festive) : ciel,
## étalonnage du décor, lumière, guirlandes, étoiles. Purement visuel.
## Fichiers : data/ambiances/*.tres, listés dans data/ambiances.tres.

@export var id: StringName = &"jour"
@export var display_name: String = "Jour"
## Libellé court (bouton des réglages).
@export var short_name: String = "Jour"

@export_group("Ciel")
## false = dégradé d'origine de la palette (rampe ramp_sky).
@export var sky_override: bool = false
@export var sky_top: Color = Color("2a86dc")
@export var sky_mid: Color = Color("6cc0f2")
@export var sky_horizon: Color = Color("c9ecfb")
@export var background_color: Color = Color("2a86dc")

@export_group("Décor")
## Étalonnage du décor et des passants : couleur × mul + add.
@export var decor_mul: Color = Color(1, 1, 1)
@export var decor_add: Color = Color(0, 0, 0)
@export var haze_color: Color = Color("c9ebfa")

@export_group("Lumière")
@export var sun_color: Color = Color("ffe6c4")
@export var sun_energy: float = 1.0
@export var sun_rotation_degrees: Vector3 = Vector3(-28, -32, 0)
@export var ambient_color: Color = Color("ffe8cc")
@export var ambient_energy: float = 0.3
@export var rim_color: Color = Color(1.0, 0.78, 0.45)
@export var glow_intensity: float = 0.45
## Teinte du cadre du panier (multipliée à sa texture).
@export var frame_tint: Color = Color(1, 1, 1)

@export_group("Guirlandes")
@export var garlands: bool = false
## Couleurs des ampoules (tirées dans l'ordre le long des fils).
@export var bulb_colors: PackedColorArray = PackedColorArray([Color("ffd27a")])
## Intensité (> 1 = au-dessus du seuil du glow : les ampoules rayonnent).
@export var bulb_energy: float = 2.2

@export_group("Nuit")
@export var night_stars: bool = false
@export var moon: bool = false
