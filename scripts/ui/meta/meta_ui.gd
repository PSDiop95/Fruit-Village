class_name MetaUi
extends RefCounted
## Briques d'UI des écrans méta (pièces, boutons pub, barres, pastilles),
## dans le style du thème (UiTheme).

const COIN := Color("f5b81c")
const AD_GLYPH := "▶"


static func label(text: String, size: int = 44, color: Color = UiTheme.INK,
		display := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if display:
		l.add_theme_font_override("font", UiTheme.display_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Texte « bois » contouré (lisible sur le décor).
static func outlined(text: String, size: int, color: Color = UiTheme.CREAM,
		outline: int = 12) -> Label:
	var l := label(text, size, color, true)
	l.add_theme_color_override("font_outline_color", UiTheme.INK)
	l.add_theme_constant_override("outline_size", outline)
	return l


## Pièce dessinée (disque doré + reflet), sans asset.
static func coin_icon(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var r := px * 0.5
		var ctr := Vector2(r, r)
		c.draw_circle(ctr, r, UiTheme.INK)
		c.draw_circle(ctr, r * 0.86, COIN)
		c.draw_circle(ctr, r * 0.58, COIN.darkened(0.15))
		c.draw_circle(ctr + Vector2(-r * 0.25, -r * 0.3), r * 0.16, Color(1, 1, 1, 0.7)))
	return c


## Pastille crème M3 (variation « Pill » du thème) « [pièce] 1 234 ».
static func coin_pill(amount: int, size: int = 48) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = &"Pill"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	row.add_child(coin_icon(size * 1.1))
	var l := label(format_int(amount), size, UiTheme.INK, true)
	l.name = "Amount"
	row.add_child(l)
	return p


static func set_pill_amount(pill: PanelContainer, amount: int) -> void:
	var l := pill.find_child("Amount", true, false) as Label
	if l:
		l.text = format_int(amount)


static func format_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func button(text: String, variation: StringName, min_size: Vector2, cb: Callable,
		font_size: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = min_size
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if font_size > 0:
		b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(cb)
	return b


## Bouton rewarded (bleu, « ▶ ») : n'existe que si la pub est prête (le
## bouton est masqué sinon, jamais de bouton qui ne fait rien).
static func ad_button(text: String, min_size: Vector2, cb: Callable, font_size: int = 44) -> Button:
	return button("%s  %s" % [AD_GLYPH, text], &"ButtonBlue", min_size, cb, font_size)


## Barre du thème M3 (celle de l'objectif « prochain fruit »), teinte de
## remplissage au choix.
static func progress_bar(height: float, fill: Color = UiTheme.WAX_GREEN) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme = UiTheme.get_theme()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if fill != UiTheme.WAX_GREEN:
		var fg := (UiTheme.get_theme().get_stylebox("fill", "ProgressBar") as StyleBoxFlat).duplicate()
		fg.bg_color = fill
		bar.add_theme_stylebox_override("fill", fg)
	return bar


## Case de calendrier / carte d'état : section M3, ou pastille crème cernée
## (variation « Pill ») teintée pour l'élément mis en avant.
static func highlight_style(color: Color) -> StyleBox:
	var sb := (UiTheme.get_theme().get_stylebox("panel", "Pill") as StyleBoxFlat).duplicate()
	sb.bg_color = color
	sb.set_corner_radius_all(32)
	sb.set_content_margin_all(10)
	return sb


## Pastille rouge de notification (coin haut-droit du parent).
static func badge(text: String = "!") -> Label:
	var l := label(text, 34, Color.WHITE, true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiTheme.WAX_RED
	sb.set_corner_radius_all(999)
	sb.border_color = Color.WHITE
	sb.set_border_width_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	l.add_theme_stylebox_override("normal", sb)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(56, 56)
	return l


## Nom de fonctionnalité (déblocages).
static func feature_name(f: StringName) -> String:
	match f:
		ProgressionCore.MISSIONS: return "Missions du jour"
		ProgressionCore.POWERUPS: return "Power-ups"
		ProgressionCore.DAILY: return "Cadeau du jour"
		ProgressionCore.ALBUM: return "Album des fruits"
	return String(f)
