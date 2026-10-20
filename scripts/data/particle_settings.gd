class_name ParticleSettings
extends Resource
## Réglages d'une gerbe de particules (jus, confettis, feuilles, pièces).

enum Shape { SPHERE, LEAF, COIN }

## Nombre de particules au niveau de qualité Haut, effets normaux.
@export var amount: int = 24
@export var lifetime: float = 0.6
@export_range(0.0, 1.0) var explosiveness: float = 0.95
@export var direction: Vector3 = Vector3.UP
@export var spread_deg: float = 70.0
@export var speed_min: float = 3.0
@export var speed_max: float = 6.0
@export var gravity: Vector3 = Vector3(0, -16, 0)
@export var size_min: float = 0.6
@export var size_max: float = 1.0
## Taille de base de la particule (m), multipliée par size_min..size_max.
@export var mesh_size: float = 0.12
@export var shape: Shape = Shape.SPHERE
## Demi-étendue de la zone d'émission (zéro = point).
@export var emission_box: Vector3 = Vector3.ZERO
## Vide = couleur fournie à chaque gerbe (ex. couleur du fruit), sinon tirage parmi ces couleurs.
@export var colors: PackedColorArray = PackedColorArray()
