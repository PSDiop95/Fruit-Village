class_name PowerupDef
extends Resource
## Un power-up (achetable en pièces, parfois offert via rewarded).

@export var id: StringName
@export var display_name: String
@export var description: String
## Prix en pièces (100 – 300).
@export var price: int = 100
## Pictogramme (caractère affiché dans le bouton, si pas d'icône peinte).
@export var glyph: String = "?"
## Bouton peint complet (anneau + icône), assets/ui/hud/pu_<id>.png.
@export var icon: Texture2D
@export var color: Color = Color.WHITE
## Stock offert au déblocage (onboarding).
@export var unlock_gift: int = 1
## Placement rewarded qui l'offre gratuitement (vide = aucun).
@export var rewarded_placement: StringName = &""
