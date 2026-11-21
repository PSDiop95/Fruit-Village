class_name FruitCard
extends MetaModal
## Fiche d'un fruit de l'album : modèle 3D qui tourne, noms, anecdote,
## partage (image de la carte + lien du store).

var rank: int
var thumb: FruitThumb
var share_button: Button
var last_share_path: String = ""


func _init(p_rank: int) -> void:
	rank = p_rank
	super(String(Loc.fruit_name_key(Collection.catalog.get_def(rank).id)), 900.0)


func _ready() -> void:
	super()
	var entry: FruitLore = Collection.lore.get_entry(rank)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 380)
	body.add_child(holder)
	thumb = FruitThumb.new()
	thumb.spin = true
	thumb.size = Vector2(380, 380)
	holder.add_child(thumb)
	holder.resized.connect(func() -> void: thumb.position = Vector2((holder.size.x - 380) * 0.5, 0))
	thumb.set_fruit(rank)
	var id := Collection.catalog.get_def(rank).id
	if entry:
		# Nom dans l'autre langue (FR ↔ EN), puis wolof s'il existe.
		var other := func() -> String: return entry.name_en if Locale.language == LocaleCore.FR \
			else entry.name_fr
		var wolof := not entry.name_wo.is_empty()
		var n := MetaUi.tlabel("CARD_NAMES_WOLOF" if wolof else "CARD_NAMES",
			[other, entry.name_wo] if wolof else [other], 36, UiTheme.INK_SOFT, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(n)
		var sec := PanelContainer.new()
		sec.theme_type_variation = &"PanelSection"
		body.add_child(sec)
		var lore := MetaUi.tlabel("%s", [Loc.data_key("LORE", id, "TEXT")], 38)
		lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore.custom_minimum_size = Vector2(640, 0)
		sec.add_child(lore)
		if not entry.benefits.is_empty():
			var bsec := PanelContainer.new()
			bsec.theme_type_variation = &"PanelSection"
			body.add_child(bsec)
			var bv := VBoxContainer.new()
			bv.add_theme_constant_override("separation", 4)
			bsec.add_child(bv)
			var cap := Label.new()
			Loc.set_text(cap, "CARD_BENEFITS")
			cap.theme_type_variation = &"LabelCaption"
			cap.add_theme_color_override("font_color", UiTheme.WAX_GREEN)
			bv.add_child(cap)
			var ben := MetaUi.tlabel("%s", [Loc.data_key("LORE", id, "BENEFITS")], 36)
			ben.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ben.custom_minimum_size = Vector2(640, 0)
			bv.add_child(ben)
	share_button = MetaUi.button("CARD_SHARE", &"ButtonGreen", Vector2(460, 116), share, 48)
	body.add_child(share_button)


## Capture de la carte + texte avec lien du store, via le partage natif.
func share() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var r := Rect2i(card.get_global_rect())
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if r.size.x > 0 and r.size.y > 0:
		img = img.get_region(r)
	var def := Collection.catalog.get_def(rank)
	var text := Loc.f("SHARE_FRUIT_TEXT", [Loc.fruit_name_key(def.id), Collection.lore.store_url])
	last_share_path = ShareService.share(img, text, "fruit_%s" % def.id, self)
