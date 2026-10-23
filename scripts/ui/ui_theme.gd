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
## Texte des boutons peints : crème cerné de brun (comme les références).
const BUTTON_TEXT := Color("fff6dc")
const HUD_DIR := "res://assets/ui/hud/"
const FRAME_TEX := "res://assets/ui/hud/basket_frame.png"
## Géométrie des boutons peints dans la source recomposée (px, hauteur 415) :
## bords gauche / droit, coin haut, bas (socle 3D + ombre).
const BUTTON_SRC := {"h": 415.0, "cap_l": 115.0, "cap_r": 105.0, "top": 80.0, "bottom": 165.0}
const CREAM_SRC := {"h": 296.0, "cap_l": 140.0, "cap_r": 140.0, "top": 140.0, "bottom": 150.0}
## Pastille « Plus gros fruit » (hauteur source 296, texture 200 px) ;
## médaillon : centre (138, 142), rayon 95.
const PILL_SRC := {"h": 296.0, "cap_l": 252.0, "cap_r": 140.0, "inset": Vector2(138, 142), "inset_r": 95.0}
const PILL_K := 200.0 / 296.0
const BUTTON_HEIGHTS := {"s": 112.0, "l": 200.0}

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

	# Boutons peints (assets/ui/hud/btn_*.png, tools/prepare_ui_art.gd) en 9 zones :
	# orange par défaut, vert (action principale), bleu, crème (choix non actif).
	# « Big » = texture haute (écran titre).
	_texture_button(t, "Button", "orange", "s")
	for v in [["ButtonGreen", "green", "s"], ["ButtonBlue", "blue", "s"], ["ButtonCream", "cream", "s"],
			["ButtonGreenBig", "green", "l"], ["ButtonOrangeBig", "orange", "l"]]:
		t.set_type_variation(v[0], "Button")
		_texture_button(t, v[0], v[1], v[2])
	t.set_type_variation("ButtonRound", "Button")
	_button_styles(t, "ButtonRound", CREAM, 999, INK)
	for type in ["Button", "ButtonGreen", "ButtonBlue", "ButtonGreenBig", "ButtonOrangeBig"]:
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			t.set_color(c, type, BUTTON_TEXT)
		t.set_color("font_outline_color", type, INK)
		t.set_constant("outline_size", type, 16)
		t.set_font_size("font_size", type, 52)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "ButtonCream", INK)
	t.set_constant("outline_size", "ButtonCream", 0)
	t.set_font_size("font_size", "ButtonCream", 44)
	t.set_font_size("font_size", "ButtonGreenBig", 96)
	t.set_font_size("font_size", "ButtonOrangeBig", 70)
	t.set_constant("outline_size", "ButtonGreenBig", 22)
	t.set_constant("outline_size", "ButtonOrangeBig", 18)
	t.set_color("font_color", "ButtonRound", INK)
	t.set_color("font_hover_color", "ButtonRound", INK)
	t.set_color("font_pressed_color", "ButtonRound", INK)
	t.set_font_size("font_size", "ButtonRound", 52)

	# Panneaux : cadre bois + frise wax (même peinture que le panier).
	var wood := StyleBoxTexture.new()
	wood.texture = load(FRAME_TEX)
	wood.set_texture_margin_all(110)
	wood.content_margin_left = 110
	wood.content_margin_right = 110
	wood.content_margin_top = 100
	wood.content_margin_bottom = 100
	t.set_stylebox("panel", "PanelContainer", wood)
	# Pastille crème à médaillon (« Plus gros fruit »).
	t.set_type_variation("PillBest", "PanelContainer")
	var best := StyleBoxTexture.new()
	best.texture = load(HUD_DIR + "pill_best.png")
	best.texture_margin_left = PILL_SRC.cap_l * PILL_K
	best.texture_margin_right = PILL_SRC.cap_r * PILL_K
	best.texture_margin_top = 99
	best.texture_margin_bottom = 99
	best.content_margin_left = PILL_SRC.cap_l * PILL_K + 6
	best.content_margin_right = 40
	best.content_margin_top = 20
	best.content_margin_bottom = 34
	t.set_stylebox("panel", "PillBest", best)
	var panel := StyleBoxFlat.new()
	panel.bg_color = CREAM
	panel.set_corner_radius_all(44)
	panel.set_border_width_all(8)
	panel.border_color = INK
	panel.shadow_color = Color(INK, 0.45)
	panel.shadow_size = 0
	panel.shadow_offset = Vector2(0, 14)
	panel.set_content_margin_all(44)
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
	t.set_constant("outline_size", "CheckButton", 0)
	t.set_font("font", "CheckButton", font())
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


## Bouton peint en 9 zones ; enfoncé = plus sombre, texte descendu de 4 px.
static func _texture_button(t: Theme, type: String, color: String, size: String) -> void:
	var tex: Texture2D = load(HUD_DIR + "btn_%s_%s.png" % [color, size])
	var src: Dictionary = CREAM_SRC if color == "cream" else BUTTON_SRC
	var k: float = BUTTON_HEIGHTS[size] / src.h
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		var sb := StyleBoxTexture.new()
		sb.texture = tex
		sb.texture_margin_left = src.cap_l * k
		sb.texture_margin_right = src.cap_r * k
		sb.texture_margin_top = src.top * k
		sb.texture_margin_bottom = src.bottom * k
		sb.content_margin_left = src.cap_l * k * 0.8
		sb.content_margin_right = src.cap_r * k * 0.8
		sb.content_margin_top = 10.0 * k / 0.27
		sb.content_margin_bottom = src.bottom * k * 0.55
		match state:
			"hover", "focus":
				sb.modulate_color = Color(1.06, 1.06, 1.06)
			"pressed":
				sb.modulate_color = Color(0.86, 0.86, 0.86)
				sb.content_margin_top += 4
				sb.content_margin_bottom -= 4
			"disabled":
				sb.modulate_color = Color(0.7, 0.7, 0.7, 0.8)
		t.set_stylebox(state, type, sb)


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
