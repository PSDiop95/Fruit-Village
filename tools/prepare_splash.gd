extends SceneTree
## Splash plein écran + vraie barre de chargement, à partir de
## art_src/splash_1536x2752.jpg (9:16, barre de chargement peinte) :
##   assets/ui/splash.png            1080x2400 (9:20) : barre effacée (sable
##                                   recopié), ciel prolongé en haut, sol en bas.
##                                   Affiché en mode « couvrir » : plein écran
##                                   sans déformation de 16:9 à 20:9.
##   assets/ui/loading_under.png     fond de la jauge (intérieur vide)
##   assets/ui/loading_fill.png      remplissage vert rayé (pleine longueur)
##   assets/ui/icon_adaptive_bg.png  fond d'icône adaptative : ciel uni (sans
##                                   logo : Android 12+ l'étire en plein écran
##                                   au lancement, le logo est au premier plan)
## Coordonnées (px) relevées sur l'image d'origine.
## Usage : Godot --headless --path . -s tools/prepare_splash.gd

const SRC := "res://art_src/splash_1536x2752.jpg"
## Barre peinte (cadre bois compris, sans le halo).
const BAR := Rect2i(338, 2262, 864, 146)
## Intérieur creux de la barre (où avance le remplissage).
const BAR_INNER := Rect2i(360, 2290, 820, 86)
## Zone rayée verte d'origine (sans l'extrémité jaune) et l'extrémité.
const FILL_STRIPES := Rect2i(390, 2295, 368, 76)
## Période des rayures peintes (autocorrélation).
const STRIPE_PERIOD := 92
## Effacement : rectangle de la barre + halo, comblé par le sable situé dessous.
const ERASE := Rect2i(270, 2245, 1000, 182)
const FEATHER := 14
## Fondu horizontal plus large (feuillage sur les côtés du chemin).
const FEATHER_X := 50
## Bande de sable pur au centre du chemin (sous la barre).
const SAND_X0 := 560
const SAND_W := 420
## Format final : 9:20 (téléphones actuels), largeur 1080.
const OUT_W := 1080
const OUT_H := 2400


func _initialize() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	src.convert(Image.FORMAT_RGBA8)
	_bar_textures(src)
	_erase_bar(src)
	var tall := _extend(src)
	var bar_out := _bar_rect_out(src, tall)
	tall.resize(OUT_W, OUT_H, Image.INTERPOLATE_LANCZOS)
	tall.convert(Image.FORMAT_RGB8)
	tall.save_png(ProjectSettings.globalize_path("res://assets/ui/splash.png"))
	_adaptive_bg(src)
	print("SPLASH ok %s ; barre dans splash.png : %s" % [tall.get_size(), bar_out])
	quit()


# ---------------------------------------------------------------- Barre

func _bar_textures(src: Image) -> void:
	# Fond : la barre peinte, intérieur repeint avec le brun du creux.
	# Fond : la barre peinte ; tout l'intérieur (forme pilule) reprend, ligne
	# par ligne, le creux vide de droite (ombrage conservé).
	var under := src.get_region(BAR)
	var inner := Rect2i(BAR_INNER.position - BAR.position, BAR_INNER.size)
	var r := inner.size.y * 0.5
	var cy := inner.position.y + r
	var ref_x := 1100 - BAR.position.x
	for y in range(inner.position.y, inner.end.y):
		var hollow := under.get_pixel(ref_x, y)
		for x in range(inner.position.x, inner.end.x):
			var cx := clampf(x, inner.position.x + r, inner.end.x - r)
			if Vector2(x, y).distance_to(Vector2(cx, cy)) <= r:
				under.set_pixel(x, y, hollow)
	_alpha_rounded(under)
	under.save_png(ProjectSettings.globalize_path("res://assets/ui/loading_under.png"))
	# Remplissage redessiné (sans raccord) avec les couleurs de la peinture :
	# rayures diagonales vert foncé / vert clair, reflet en haut, ombre en bas.
	var stripes := src.get_region(FILL_STRIPES)
	var dark := _extreme(stripes, false)
	var light := _extreme(stripes, true)
	var fill := Image.create(BAR_INNER.size.x, FILL_STRIPES.size.y, false, Image.FORMAT_RGBA8)
	var period := float(STRIPE_PERIOD)
	var fh := float(fill.get_height())
	for y in fill.get_height():
		var v := y / fh
		for x in fill.get_width():
			var t := fposmod(x + y * 0.8, period) / period
			var s := smoothstep(0.42, 0.5, t) - smoothstep(0.9, 0.98, t)
			var c := dark.lerp(light, s * 0.85)
			c = c.lightened(0.35 * clampf(1.0 - v / 0.3, 0.0, 1.0))
			c = c.darkened(0.25 * clampf((v - 0.7) / 0.3, 0.0, 1.0))
			fill.set_pixel(x, y, Color(c, 1.0))
	_alpha_rounded(fill)
	fill.save_png(ProjectSettings.globalize_path("res://assets/ui/loading_fill.png"))


## Couleur la plus claire (ou la plus foncée) d'une zone, moyennée sur les 5 %
## extrêmes (évite un pixel isolé).
func _extreme(img: Image, lightest: bool) -> Color:
	var cols: Array[Color] = []
	for y in range(img.get_height() / 3, img.get_height() * 2 / 3):
		for x in img.get_width():
			cols.append(img.get_pixel(x, y))
	cols.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	var n := maxi(cols.size() / 20, 1)
	var c := Color(0, 0, 0, 0)
	for i in n:
		c += cols[cols.size() - 1 - i] if lightest else cols[i]
	return Color(c / float(n), 1.0)


## Coins arrondis (pilule) : alpha hors de la forme.
func _alpha_rounded(img: Image) -> void:
	var h := float(img.get_height())
	var r := h * 0.5
	for y in img.get_height():
		for x in img.get_width():
			var cx := clampf(x, r, img.get_width() - r)
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(cx, r))
			var a := clampf(r - d + 0.5, 0.0, 1.0)
			if a < 1.0:
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, Color(p, p.a * a))


## Efface la barre : chaque ligne est remplacée par celle située `ERASE.size.y`
## plus bas (sable du chemin), bords fondus.
func _erase_bar(src: Image) -> void:
	var copy := src.duplicate() as Image
	for y in range(ERASE.position.y, ERASE.end.y):
		for x in range(ERASE.position.x, ERASE.end.x):
			# Sable pris au centre du chemin (les bouts voisins ont du feuillage).
			var sx := SAND_X0 + posmod(x - ERASE.position.x, SAND_W)
			var below := copy.get_pixel(sx, mini(y + ERASE.size.y, copy.get_height() - 1))
			var dx := mini(x - ERASE.position.x, ERASE.end.x - 1 - x)
			var dy := mini(y - ERASE.position.y, ERASE.end.y - 1 - y)
			var k := minf(clampf(float(dx) / FEATHER_X, 0.0, 1.0), clampf(float(dy) / FEATHER, 0.0, 1.0))
			src.set_pixel(x, y, copy.get_pixel(x, y).lerp(below, k))


# ---------------------------------------------------------------- Format 9:20

## Prolonge l'image (9:16) en 9:20 par reflet de ses bords.
func _extend(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var th := int(round(w * float(OUT_H) / OUT_W))
	var top := (th - h) / 2
	var out := Image.create(w, th, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(0, 0, w, h), Vector2i(0, top))
	# Reflet de l'image au-delà de ses bords (raccord continu), assombri
	# progressivement : ciel et nuages en haut, feuillage et sable en bas.
	# Haut : ciel uni (couleurs du bord haut lissées), plus profond vers le
	# haut ; un reflet ferait apparaître le logo à l'envers.
	var sky := _edge_colors(src, 0, 30)
	for y in top:
		var t := float(top - y) / top  # 0 au raccord, 1 en haut
		for x in w:
			out.set_pixel(x, y, sky[x].darkened(0.12 * t))
	_blend_seam(out, top, 24)
	for y in range(top + h, th):
		var i := y - top - h
		var t := float(i) / maxf(th - top - h, 1)
		var sy := maxi(h - 1 - i, 0)
		for x in w:
			out.set_pixel(x, y, src.get_pixel(x, sy).darkened(0.30 * t))
	return out



## Couleur moyenne par colonne sur [y0, y1), lissée horizontalement.
func _edge_colors(src: Image, y0: int, y1: int) -> Array[Color]:
	var w := src.get_width()
	var raw: Array[Color] = []
	for x in w:
		var c := Color(0, 0, 0, 0)
		for y in range(y0, y1):
			c += src.get_pixel(x, y)
		raw.append(c / float(y1 - y0))
	var out: Array[Color] = []
	var rad := 60
	for x in w:
		var c := Color(0, 0, 0, 0)
		var n := 0
		for k in range(maxi(x - rad, 0), mini(x + rad + 1, w)):
			c += raw[k]
			n += 1
		out.append(Color(c / float(n), 1.0))
	return out


## Fond le prolongement du haut dans l'image sur `band` px sous le raccord.
func _blend_seam(out: Image, seam_y: int, band: int) -> void:
	for i in band:
		var k := float(i) / band
		var y := seam_y + i
		for x in out.get_width():
			out.set_pixel(x, y, out.get_pixel(x, seam_y - 1).lerp(out.get_pixel(x, y), k))


func _bar_rect_out(src: Image, tall: Image) -> Rect2:
	var top := (tall.get_height() - src.get_height()) / 2
	var k := float(OUT_W) / src.get_width()
	return Rect2(Vector2(BAR.position.x, BAR.position.y + top) * k, Vector2(BAR.size) * k)


# ---------------------------------------------------------------- Icône

## Fond d'icône adaptative : dégradé du ciel du splash (haut → horizon).
func _adaptive_bg(src: Image) -> void:
	var top := src.get_pixel(60, 40)
	var low := src.get_pixel(60, 700)
	var bg := Image.create(432, 432, false, Image.FORMAT_RGB8)
	for y in 432:
		var c := top.lerp(low, float(y) / 431.0)
		for x in 432:
			bg.set_pixel(x, y, Color(c, 1.0))
	bg.save_png(ProjectSettings.globalize_path("res://assets/ui/icon_adaptive_bg.png"))
