class_name AlbumPanel
extends MetaModal
## Album des fruits : 11 cartes (silhouette tant que le fruit n'a jamais été
## créé). Une carte débloquée ouvre sa fiche : modèle 3D qui tourne, noms
## FR / EN / wolof, anecdote, partage.

var cards: Array[Button] = []
var detail: FruitCard


func _init() -> void:
	super("Album des fruits", 1000.0)


func _ready() -> void:
	super()
	var cat: FruitCatalog = Collection.catalog
	var progress := MetaUi.label("%d / %d fruits" % [Collection.count(), cat.count()], 44,
		UiTheme.INK_SOFT, true)
	body.add_child(progress)
	if Collection.gold_unlocked():
		body.add_child(MetaUi.label("Album complet : panier doré débloqué !", 38, Color("b8860b"), true))
	else:
		body.add_child(MetaUi.label("Complète l'album pour gagner le panier doré", 34, UiTheme.INK_SOFT))
	# Rangées de 4 centrées (la dernière, incomplète, reste au milieu).
	var row: HBoxContainer
	for r in cat.count():
		if r % 4 == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 10)
			body.add_child(row)
		var b := _card(r)
		row.add_child(b)
		cards.append(b)


func _card(rank: int) -> Button:
	var found := Collection.has(rank)
	var b := Button.new()
	b.theme_type_variation = &"ButtonRound"
	b.custom_minimum_size = Vector2(180, 214)
	b.disabled = not found
	var thumb := FruitThumb.new()
	thumb.position = Vector2(20, 10)
	thumb.size = Vector2(140, 140)
	# Silhouette : le modèle teinté en sombre, sans halo.
	thumb.silhouette = not found
	b.add_child(thumb)
	thumb.set_fruit(rank)
	var name := MetaUi.label(Collection.catalog.get_def(rank).display_name if found else "???",
		28, UiTheme.INK, true)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.position = Vector2(4, 150)
	name.size = Vector2(172, 60)
	b.add_child(name)
	b.pressed.connect(open_card.bind(rank))
	return b


func open_card(rank: int) -> FruitCard:
	if not Collection.has(rank):
		return null
	detail = FruitCard.new(rank)
	add_child(detail)
	return detail
