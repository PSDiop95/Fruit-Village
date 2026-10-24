class_name FruitLore
extends Resource
## Carte de l'album : noms et anecdote culturelle (2 phrases max).

@export var id: StringName
@export var name_fr: String
@export var name_en: String
## Vide tant que le nom wolof n'est pas validé.
@export var name_wo: String = ""
@export_multiline var lore: String
## Bienfaits (nutrition), 1 à 2 phrases, sans allégation médicale.
@export_multiline var benefits: String = ""
## false tant que le texte n'est pas validé par l'équipe.
@export var validated: bool = false
