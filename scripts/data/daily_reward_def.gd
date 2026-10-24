class_name DailyRewardDef
extends Resource
## Une case du calendrier 7 jours.

@export var coins: int = 0
## Power-up offert (vide = aucun) et quantité.
@export var powerup: StringName = &""
@export var powerup_count: int = 0
## Jour 7 : gros coffre (affiché « Coffre » ; contenu = pièces + power-up ci-dessus).
@export var is_chest: bool = false
