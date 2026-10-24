extends SceneTree
## Découpe la maquette des power-ups (art_src/ui_refs/powerup.png, 916x495,
## fond beige uni) en boutons de jeu assets/ui/hud/pu_<id>.png :
## anneau en liane + icône, fond transparent, sans pastille rouge ni étiquette.
## Les pastilles rouges (boutons 1-3) mordent sur l'anneau : l'anneau propre du
## 4e bouton sert de base commune, et chaque bouton y reçoit son disque
## intérieur (fond sombre + icône). Le bas de l'anneau, caché par l'étiquette
## sur la maquette, l'est aussi en jeu par la pastille (PowerupBar).
## Coordonnées (px) relevées sur l'image d'origine.
## Usage : Godot --headless --path . -s tools/prepare_powerup_art.gd [planche.png]

const SRC := "res://art_src/ui_refs/powerup.png"
const OUT := "res://assets/ui/hud/"
const IDS := ["shake", "pestle", "swap", "grow"]
## Centres des anneaux (dans l'ordre de IDS).
const CENTERS := [Vector2(130, 246), Vector2(350, 246), Vector2(570, 246), Vector2(791, 246)]
## Base : anneau du 4e bouton (aucune pastille dessus).
const BASE := 3
## Rayon extérieur gardé (anneau + lianes), rayon du disque transplanté.
const R_OUT := 104.0
## Rayon du disque transplanté, par bouton (Agrandir : pas de pastille,
## pièces plus bas).
const R_ICONS := [52.0, 52.0, 52.0, 68.0]
const R_ICON := 58.0
## Fond intérieur de l'anneau (repeint en uni sur la base).
const R_INNER := 72.0
const FEATHER := 5.0
## Haut des étiquettes : tout ce qui est dessous est coupé.
const LABEL_TOP := 327
## Écart de couleur (somme RGB, 0..765) toléré pour le fond beige.
const BG_TOLERANCE := 60
const OUT_SIZE := 256


func _initialize() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	src.convert(Image.FORMAT_RGBA8)
	var bg := src.get_pixel(4, 4)
	var size := int(R_OUT * 2.0)
	var base := _square(src, CENTERS[BASE], size)
	var c := Vector2(R_OUT, R_OUT)
	# Fond intérieur de la base repeint en uni (sinon flèche et pièces du
	# 4e bouton dépassent du disque transplanté).
	var inner := base.get_pixelv(Vector2i(c + Vector2(-R_ICON + 4.0, 0.0)))
	for y in size:
		for x in size:
			var d := Vector2(x, y).distance_to(c)
			if d <= R_INNER:
				var k := clampf((R_INNER - d) / FEATHER, 0.0, 1.0)
				base.set_pixel(x, y, base.get_pixel(x, y).lerp(Color(inner, 1.0), k))
	var sheet := Image.create(size * 4, size, false, Image.FORMAT_RGBA8)
	for i in IDS.size():
		var img := base.duplicate() as Image
		var icon := _square(src, CENTERS[i], size)
		var r_icon: float = R_ICONS[i]
		for y in size:
			for x in size:
				var d := Vector2(x, y).distance_to(c)
				if d > r_icon or _is_badge(icon.get_pixel(x, y), Vector2(x, y) - c):
					continue
				var k := clampf((r_icon - d) / FEATHER, 0.0, 1.0)
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(icon.get_pixel(x, y), k))
		_clean(img, bg)
		sheet.blit_rect(img, Rect2i(0, 0, size, size), Vector2i(i * size, 0))
		var out := img.duplicate() as Image
		out.resize(OUT_SIZE, OUT_SIZE, Image.INTERPOLATE_LANCZOS)
		out.save_png(ProjectSettings.globalize_path(OUT + "pu_%s.png" % IDS[i]))
		print("pu_%s.png %dx%d" % [IDS[i], OUT_SIZE, OUT_SIZE])
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		sheet.save_png(args[0])
	quit()


## Reste de pastille rouge (rouge ou blanc) dans le quart haut-droit.
func _is_badge(p: Color, off: Vector2) -> bool:
	if off.x < 8.0 or off.y > -8.0 or off.length() < 34.0:
		return false
	var red := p.r > 0.55 and p.g < 0.35 and p.b < 0.35
	var white := p.r > 0.82 and p.g > 0.82 and p.b > 0.82
	return red or white


## Carré centré sur `c` ; ce qui est sous les étiquettes est vidé.
func _square(src: Image, c: Vector2, size: int) -> Image:
	var o := Vector2i(c - Vector2(size, size) * 0.5)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.blit_rect(src, Rect2i(o, Vector2i(size, size)), Vector2i.ZERO)
	for y in size:
		if o.y + y >= LABEL_TOP:
			for x in size:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


## Fond beige → transparent (avec liseré adouci), et hors du disque R_OUT.
func _clean(img: Image, bg: Color) -> void:
	var c := Vector2(R_OUT, R_OUT)
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a == 0.0:
				continue
			if Vector2(x, y).distance_to(c) > R_OUT:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var diff := (absf(p.r - bg.r) + absf(p.g - bg.g) + absf(p.b - bg.b)) * 255.0
			if diff < BG_TOLERANCE:
				img.set_pixel(x, y, Color(p, 0.0))
			elif diff < BG_TOLERANCE * 2.0:
				img.set_pixel(x, y, Color(p, (diff - BG_TOLERANCE) / BG_TOLERANCE))
