class_name FruitDef
extends Resource
## Définition d'un fruit (rang = index dans FruitCatalog.fruits).

@export var id: StringName
@export var display_name: String
@export var radius: float = 0.3
@export var color: Color = Color.WHITE
## Points gagnés quand ce fruit est CRÉÉ par une fusion.
@export var points: int = 1
@export var droppable: bool = false
## Poids relatif dans le tirage (ignoré si non lâchable).
@export var spawn_weight: float = 1.0
