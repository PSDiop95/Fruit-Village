class_name UiTheme
extends RefCounted
## Thème Godot unique de Fruit Village (assets/ui/theme.tres, généré par
## tools/make_theme.gd) : boutons ronds épais à ombre portée, panneaux crème
## cerclés de brun, palette wax. Lisible au soleil : texte brun sur crème,
## blanc cerné de brun sur les boutons. Cibles tactiles ≥ 48 dp.

const PATH := "res://assets/ui/theme.tres"

const WAX_ORANGE := Color("f28c28")
const WAX_YELLOW := Color("f9c22e")
const WAX_GREEN := Color("2e8b57")
const WAX_BLUE := Color("1f2a5a")
const WAX_RED := Color("d6382f")
const CREAM := Color("fff3df")
const INK := Color("3a2414")
const INK_SOFT := Color("6d4c2f")

## Polices (OFL) : Fredoka pour titres et boutons, Baloo 2 pour les textes.
## Polices variables : la graisse est réglée par FontVariation (axe « wght »).
const DISPLAY_FONT := "res://assets/fonts/Fredoka-VariableFont_wdth,wght.ttf"
const TEXT_FONT := "res://assets/fonts/Baloo2-VariableFont_wght.ttf"
const DISPLAY_WEIGHT := 650
const TEXT_WEIGHT := 700
## Repli si les fichiers manquent : police système arrondie et grasse.
const SYSTEM_FONTS := ["Fredoka", "Baloo 2", "Nunito", "Arial Rounded MT Bold", "Segoe UI", "Roboto"]

static var _theme: Theme


## Thème partagé (chargé depuis theme.tres, sinon construit).
static func get_theme() -> Theme:
	if _theme == null:
		_theme = load(PATH) if ResourceLoader.exists(PATH) else build()
		# Textes 3D (combos, points flottants) : même police que l'UI.
		ThemeDB.fallback_font = display_font()
	return _theme


## Police des textes (Baloo 2).
static func font() -> Font:
	return _variable(TEXT_FONT, TEXT_WEIGHT)


## Police des titres et boutons (Fredoka).
static func display_font() -> Font:
	return _variable(DISPLAY_FONT, DISPLAY_WEIGHT)


static func _variable(path: String, weight: int) -> Font:
	if ResourceLoader.exists(path):
		var fv := FontVariation.new()
		fv.base_font = load(path)
		fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		return fv
	var f := SystemFont.new()
	f.font_names = PackedStringArray(SYSTEM_FONTS)
	f.font_weight = weight
	return f


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 44
	var display := display_font()
	for type in ["Button", "LabelTitle", "LabelBig"]:
		t.set_font("font", type, display)

	# Boutons : orange wax par défaut, ombre portée brune, enfoncement au clic.
	_button_styles(t, "Button", WAX_ORANGE)
	t.set_type_variation("ButtonGreen", "Button")
	_button_styles(t, "ButtonGreen", WAX_GREEN)
	t.set_type_variation("ButtonBlue", "Button")
	_button_styles(t, "ButtonBlue", WAX_BLUE)
	t.set_type_variation("ButtonRound", "Button")
	_button_styles(t, "ButtonRound", CREAM, 999, INK)
	for type in ["Button", "ButtonGreen", "ButtonBlue"]:
		t.set_color("font_color", type, Color.WHITE)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color.WHITE)
		t.set_color("font_focus_color", type, Color.WHITE)
		t.set_color("font_outline_color", type, INK)
		t.set_constant("outline_size", type, 12)
		t.set_font_size("font_size", type, 52)
	t.set_color("font_color", "ButtonRound", INK)
	t.set_color("font_hover_color", "ButtonRound", INK)
	t.set_color("font_pressed_color", "ButtonRound", INK)
	t.set_font_size("font_size", "ButtonRound", 52)

	# Panneaux : crème, bord brun épais, coins ronds, ombre.
	var panel := StyleBoxFlat.new()
	panel.bg_color = CREAM
	panel.set_corner_radius_all(44)
	panel.set_border_width_all(8)
	panel.border_color = INK
	panel.shadow_color = Color(INK, 0.45)
	panel.shadow_size = 0
	panel.shadow_offset = Vector2(0, 14)
	panel.set_content_margin_all(44)
	t.set_stylebox("panel", "PanelContainer", panel)
	# Pastille (score, bulle « Suivant ») : même style, marges plus serrées.
	t.set_type_variation("Pill", "PanelContainer")
	var pill := panel.duplicate() as StyleBoxFlat
	pill.set_corner_radius_all(999)
	pill.set_border_width_all(6)
	pill.shadow_offset = Vector2(0, 8)
	pill.content_margin_left = 34
	pill.content_margin_right = 34
	pill.content_margin_top = 10
	pill.content_margin_bottom = 14
	t.set_stylebox("panel", "Pill", pill)

	# Textes
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", Color(CREAM, 0.9))
	t.set_constant("outline_size", "Label", 0)
	t.set_type_variation("LabelTitle", "Label")
	t.set_font_size("font_size", "LabelTitle", 96)
	t.set_color("font_color", "LabelTitle", WAX_ORANGE)
	t.set_color("font_outline_color", "LabelTitle", INK)
	t.set_constant("outline_size", "LabelTitle", 22)
	t.set_type_variation("LabelBig", "Label")
	t.set_font_size("font_size", "LabelBig", 92)
	t.set_type_variation("LabelSmall", "Label")
	t.set_font_size("font_size", "LabelSmall", 34)
	t.set_color("font_color", "LabelSmall", INK_SOFT)

	# Cases à cocher (réglages) : grande pastille verte / grise.
	t.set_font_size("font_size", "CheckButton", 46)
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_hover_color", "CheckButton", INK)
	t.set_color("font_pressed_color", "CheckButton", INK)
	t.set_color("font_hover_pressed_color", "CheckButton", INK)
	t.set_color("font_focus_color", "CheckButton", INK)
	t.set_icon("checked", "CheckButton", _switch_icon(true))
	t.set_icon("unchecked", "CheckButton", _switch_icon(false))
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var e := StyleBoxEmpty.new()
		e.content_margin_top = 18
		e.content_margin_bottom = 18
		t.set_stylebox(s, "CheckButton", e)

	# Barre de progression (objectif « prochain fruit »)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(INK, 0.18)
	bg.set_corner_radius_all(999)
	bg.set_border_width_all(4)
	bg.border_color = INK
	var fill := StyleBoxFlat.new()
	fill.bg_color = WAX_GREEN
	fill.set_corner_radius_all(999)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	return t


static func _button_styles(t: Theme, type: String, color: Color, radius := 60, border := INK) -> void:
	var states := {
		"normal": [color, 12.0], "hover": [color.lightened(0.1), 12.0],
		"focus": [color.lightened(0.1), 12.0], "pressed": [color.darkened(0.12), 3.0],
		"disabled": [color.lerp(Color.GRAY, 0.6), 12.0],
	}
	for state in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[state][0]
		sb.set_corner_radius_all(radius)
		sb.set_border_width_all(7)
		sb.border_color = border
		sb.shadow_color = Color(INK, 0.9)
		sb.shadow_size = 0
		var drop: float = states[state][1]
		sb.shadow_offset = Vector2(0, drop)
		sb.content_margin_left = 48
		sb.content_margin_right = 48
		sb.content_margin_top = 18 + (12.0 - drop)
		sb.content_margin_bottom = 22 - (12.0 - drop)
		t.set_stylebox(state, type, sb)


## Interrupteur dessiné (pas de texture externe) : 120 x 64 px.
static func _switch_icon(on: bool) -> ImageTexture:
	var w := 120
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := WAX_GREEN if on else Color("b8a58c")
	var r := h * 0.5
	for y in h:
		for x in w:
			var cx := clampf(x, r, w - r)
			var d := Vector2(x, y).distance_to(Vector2(cx, r))
			var c := Color(0, 0, 0, 0)
			if d <= r:
				c = INK
			if d <= r - 5:
				c = track
			var kx := w - r if on else r
			var kd := Vector2(x, y).distance_to(Vector2(kx, r))
			if kd <= r - 9:
				c = CREAM
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
