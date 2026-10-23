extends SceneTree
## Découpe les références d'interface (art_src/ui_refs/, fond beige uni) en
## éléments prêts pour le jeu (assets/ui/hud/) :
##   pause.png       bouton pause bois (fond détouré)
##   next_ring.png   anneau « Suivant » en liane, sans texte ni fruit
##   score_plank.png planche du score, sans étoile ni chiffres (recomposée)
##   star.png        étoile dorée (dessinée, la référence la pose sur le bois)
##   basket_frame.png cadre bois + frise wax, recomposé en 9 zones au format
##                   du panier, fond intérieur peint (une seule texture)
## Les coordonnées (px) se lisent sur les images 2000x2000 d'origine.
## Usage : Godot --headless --path . -s tools/prepare_ui_art.gd

const SRC := "res://art_src/ui_refs/"
const OUT := "res://assets/ui/hud/"
## Écart de couleur (somme RGB, 0..765) toléré pour le fond beige.
const BG_TOLERANCE := 70


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_pause()
	_next_ring()
	_plank()
	_star()
	_frame()
	_menu_buttons()
	print("UI_ART ok -> %s" % OUT)
	quit()


# ---------------------------------------------------------------- Éléments

func _pause() -> void:
	var img := _load("pause.jpg")
	_remove_bg(img, _corners(img))
	img = _crop_alpha(img, 8)
	_save(img, "pause.png", 256)


func _next_ring() -> void:
	var img := _load("suivant.jpg")
	_remove_bg(img, _corners(img))
	# Anneau seul : les mots « Suivant » / « Sidem » sont au-dessus et en dessous.
	img = img.get_region(Rect2i(400, 470, 1180, 1066))
	var c := Vector2(596, 580)
	# Morceaux de texte dans les coins : hors du disque de l'anneau (+ feuilles).
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x, y).distance_to(c) > 615.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	# Le fruit peint au centre est remplacé par le fond sombre de l'anneau.
	var inner := img.get_pixelv(Vector2i(c + Vector2(-310, 0)))
	_paint_disc(img, c, 250.0, inner)
	img = _crop_alpha(img, 8)
	_save(img, "next_ring.png", 320)


## Planche : capuchons gauche/droite d'origine, milieu repeint ligne par ligne
## avec la couleur moyenne d'une fenêtre de bois seul (le grain est horizontal),
## + léger bruit ; fondu de 30 px vers les capuchons.
func _plank() -> void:
	var img := _load("score.jpg")
	_remove_bg(img, _corners(img))
	var strip_w := 24
	var from_x := 272
	var to_x := 1628
	var fade := 18.0
	var src := img.duplicate() as Image
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.01
	var strip_x := 790
	for y in range(560, 1360):
		# Première fenêtre de bois seul (ni étoile, ni chiffres, ni « Record »).
		for cand in range(700, 860, 4):
			if _is_wood(src, cand, y, strip_w):
				strip_x = cand
				break
		if src.get_pixel(strip_x, y).a < 0.5:
			continue
		var acc := Color(0, 0, 0, 0)
		for x in range(strip_x, strip_x + strip_w):
			acc += src.get_pixel(x, y)
		acc /= strip_w
		for x in range(from_x, to_x):
			var g := noise.get_noise_2d(x * 0.6, y * 6.0) * 0.03
			var col := Color(acc.r + g, acc.g + g, acc.b + g, 1.0)
			var k := clampf(minf(x - from_x, to_x - 1 - x) / fade, 0.0, 1.0)
			img.set_pixel(x, y, src.get_pixel(x, y).lerp(col, k) if src.get_pixel(x, y).a > 0.5 else col)
	img = _crop_alpha(img, 8)
	_save(img, "score_plank.png", 720)


static func _is_wood(img: Image, x0: int, y: int, w: int) -> bool:
	for x in range(x0, x0 + w):
		var c := img.get_pixel(x, y)
		if c.a < 0.5 or c.v > 0.78 or c.v < 0.3 or c.s > 0.75:
			return false
	return true


## Étoile dorée bombée : dégradé, contour brun, reflet.
func _star() -> void:
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n * 0.5, n * 0.53)
	var outer := n * 0.47
	var inner := outer * 0.5
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * i / 5.0
		pts.append(c + Vector2.from_angle(a) * (outer if i % 2 == 0 else inner))
	var ink := Color("4a2a12")
	var top := Color("fff3a0")
	var mid := Color("ffc928")
	var bot := Color("e88a10")
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _poly_sdf(p, pts) - 10.0  # arrondi des pointes
			if d > 1.0:
				continue
			var col: Color
			if d > -9.0:
				col = ink
			else:
				var t := clampf((p.y - (c.y - outer)) / (outer * 1.9), 0.0, 1.0)
				col = top.lerp(mid, t / 0.5) if t < 0.5 else mid.lerp(bot, (t - 0.5) / 0.5)
				# Arête centrale : moitié gauche plus claire (étoile bombée)
				if (p - c).angle() > PI * 0.5 or (p - c).angle() < -PI * 0.5:
					col = col.lightened(0.12)
			col.a = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, col)
	# Reflet
	_paint_ellipse(img, c + Vector2(-outer * 0.22, -outer * 0.3), Vector2(outer * 0.14, outer * 0.08),
		Color(1, 1, 1, 0.75))
	_save(img, "star.png", 160)


## Cadre du panier au format du jeu. Monde : intérieur = panier M1
## (basket_inner_width x basket_height), bordure FRAME_BORDER m tout autour.
func _frame() -> void:
	var gc: Resource = load("res://data/game_config.tres")
	var vc: Resource = load("res://data/visual.tres")
	var border_m: float = vc.basket_frame_border
	var ppm := 128.0  # pixels par mètre
	var src := _load("cadre_panier.jpg")
	_remove_bg(src, _corners(src) + [Vector2i(1000, 1000)])
	src = _crop_alpha(src, 0)
	# Épaisseur du bois dans la référence (px) et marge des tranches 9 zones.
	var src_border := 205.0
	var slice := 270
	var k := border_m * ppm / src_border
	var tw := int(round((gc.basket_inner_width + border_m * 2.0) * ppm))
	var th := int(round((gc.basket_height + border_m * 2.0) * ppm))
	var img := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	# Fond intérieur peint sous le cadre (dépasse sous le bois pour ne laisser aucun trou).
	var b := int(border_m * ppm)
	_paint_panel(img, Rect2i(b - 24, b - 24, tw - 2 * b + 48, th - 2 * b + 48), b)
	var m := int(round(slice * k))
	var sw := src.get_width()
	var sh := src.get_height()
	var xs := [[0, slice, 0, m], [slice, sw - slice, m, tw - m], [sw - slice, sw, tw - m, tw]]
	var ys := [[0, slice, 0, m], [slice, sh - slice, m, th - m], [sh - slice, sh, th - m, th]]
	for yy in ys:
		for xx in xs:
			if xx[0] == slice and yy[0] == slice:
				continue  # centre : le fond peint
			var part := src.get_region(Rect2i(xx[0], yy[0], xx[1] - xx[0], yy[1] - yy[0]))
			part.resize(xx[3] - xx[2], yy[3] - yy[2], Image.INTERPOLATE_LANCZOS)
			img.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(xx[2], yy[2]))
	img.save_png(OUT + "basket_frame.png")
	print("frame %dx%d bord=%dpx" % [tw, th, b])


## Fond du panier : bois clair chaud, plus sombre vers les bords (ombre portée
## du cadre), très léger grain horizontal.
func _paint_panel(img: Image, r: Rect2i, shade: int) -> void:
	var light := Color("f3dcae")
	var dark := Color("d9b178")
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.02
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var dx := minf(x - r.position.x, r.end.x - 1 - x)
			var dy := minf(y - r.position.y, r.end.y - 1 - y)
			var edge := clampf(minf(dx, dy) / (shade * 1.4), 0.0, 1.0)
			var col := dark.lerp(light, smoothstep(0.0, 1.0, edge))
			var g := noise.get_noise_2d(x * 0.15, y * 3.0) * 0.035
			img.set_pixel(x, y, Color(col.r + g, col.g + g, col.b + g * 0.6, 1.0))


## Boutons du menu (boutons_menu.jpg, 2000x1493) sans texte, en 9 zones :
## bord gauche + milieu uni (moyenne par ligne d'une bande sans texte) + bord
## droit. Vert d'origine ; orange et bleu par rotation de teinte du vert
## (même géométrie). Deux hauteurs : _l (titre) et _s (panneaux).
## Pastille crème « Plus gros fruit » (médaillon vidé) et bouton crème.
## Géométrie source (px) : UiTheme.BUTTON_SRC / PILL_SRC.
func _menu_buttons() -> void:
	var src := _load("boutons_menu.jpg")
	var bg := src.get_pixel(4, 4)
	_remove_bg(src, _corners(src))
	_soft_shadow(src, bg)
	# Bouton vert : x 100..690, y 550..965 ; texte « Jouer » entre 180 et 620.
	# Lignes du texte (y 650..800) : bande 628..650 ; ailleurs, bande au centre (x 300).
	var green := _compose(src, Rect2i(100, 550, 590, 415), 115, 80, 105, 32, 300, Vector2i(95, 255))
	# Teinte cible (orange, bleu) ; -1 = vert d'origine.
	var variants := {"green": -1.0, "orange": 0.08, "blue": 0.58}
	for key in variants:
		var img := green.duplicate() as Image
		if variants[key] >= 0.0:
			_retint(img, variants[key], 0.3, 1.3 if key == "orange" else 1.0, 1.32 if key == "orange" else 1.05)
		for size in [["l", 200], ["s", 112]]:
			_save_h(img, "btn_%s_%s.png" % [key, size[0]], size[1])
	# Pastille : x 1312..1928, y 604..900 ; médaillon centre (1450, 746) ;
	# texte entre 1568 et 1876 ; bande propre 1552..1564.
	var pill := src.get_region(Rect2i(1312, 604, 616, 296))
	_paint_disc(pill, Vector2(1450 - 1312, 746 - 604), 95.0, Color("ecdfc4"), 10.0)
	var pill_img := _compose(pill, Rect2i(0, 0, 616, 296), 252, 252, 140, 92, 1700 - 1312, Vector2i(74, 204))
	_save_h(pill_img, "pill_best.png", 200)
	# Bouton crème : bout arrondi droit de la pastille recomposée (140 px, sans
	# texte) + son miroir à gauche + son milieu uni.
	var pw := pill_img.get_width()
	var right := pill_img.get_region(Rect2i(pw - 140, 0, 140, 296))
	var left := right.duplicate() as Image
	left.flip_x()
	var cream := Image.create(140 + 40 + 140, 296, false, Image.FORMAT_RGBA8)
	cream.blit_rect(left, Rect2i(0, 0, 140, 296), Vector2i(0, 0))
	cream.blit_rect(pill_img, Rect2i(252, 0, 40, 296), Vector2i(140, 0))
	cream.blit_rect(right, Rect2i(0, 0, 140, 296), Vector2i(180, 0))
	for size in [["l", 200], ["s", 112]]:
		_save_h(cream, "btn_cream_%s.png" % size[0], size[1])


## Recompose une image : bord gauche (`cap_l` px), milieu uni de 40 px (moyenne
## par ligne de la bande `clean` = (x, largeur), coordonnées de `src`), bord droit.
## Recompose une image sans texte : bords d'origine (`cap_l`, `cap_r` px) +
## milieu uni de 40 px. Couleur du milieu par ligne : moyenne de 16 px à
## `center_x` (coordonnées de `src`) ; sur les lignes du texte (`band`, relatives
## à `r`), interpolée entre la ligne au-dessus et celle en dessous. Sur ces
## lignes, les colonnes des bords qui peuvent toucher le texte (au-delà de
## `clean_l` à gauche, en deçà de `clean_r` à droite) prennent aussi cette couleur.
func _compose(src: Image, r: Rect2i, cap_l: int, clean_l: int, cap_r: int, clean_r: int,
		center_x: int, band: Vector2i) -> Image:
	var mid_w := 40
	var h := r.size.y
	var mid: Array[Color] = []
	for y in h:
		var acc := Color(0, 0, 0, 0)
		for x in range(center_x, center_x + 16):
			acc += src.get_pixel(x, r.position.y + y)
		mid.append(acc / 16.0)
	var top := mid[maxi(band.x - 1, 0)]
	var bot := mid[mini(band.y + 1, h - 1)]
	for y in range(band.x, band.y + 1):
		mid[y] = top.lerp(bot, float(y - band.x) / maxf(band.y - band.x, 1))
	var out := Image.create(cap_l + mid_w + cap_r, h, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(r.position.x, r.position.y, cap_l, h), Vector2i.ZERO)
	out.blit_rect(src, Rect2i(r.end.x - cap_r, r.position.y, cap_r, h), Vector2i(cap_l + mid_w, 0))
	for y in h:
		for x in mid_w:
			out.set_pixel(cap_l + x, y, mid[y])
		if y >= band.x and y <= band.y:
			for x in range(clean_l, cap_l):
				out.set_pixel(x, y, mid[y])
			for x in range(0, clean_r):
				out.set_pixel(cap_l + mid_w + x, y, mid[y])
	return out


## Ombre portée douce : pixels « fond assombri » (même teinte que le fond)
## → brun transparent proportionnel à l'assombrissement.
func _soft_shadow(img: Image, bg: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			var kr := c.r / maxf(bg.r, 0.01)
			var kg := c.g / maxf(bg.g, 0.01)
			var kb := c.b / maxf(bg.b, 0.01)
			var k := (kr + kg + kb) / 3.0
			if k > 0.55 and k < 1.02 and absf(kr - k) < 0.07 and absf(kg - k) < 0.07 and absf(kb - k) < 0.09:
				img.set_pixel(x, y, Color(0.24, 0.13, 0.05, clampf((1.0 - k) * 1.6, 0.0, 0.5)))


## Recolore les pixels saturés vers la teinte `hue` en gardant de petits écarts
## de teinte (relief) ; le crème, l'ombre et le contour sombre ne bougent pas.
func _retint(img: Image, hue: float, min_sat: float, sat_mul := 1.0, val_mul := 1.0) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.6 or c.s < min_sat * 0.5:
				continue
			var k := clampf((c.s - min_sat * 0.5) / (min_sat * 0.5), 0.0, 1.0)
			var h := fposmod(hue + (c.h - 0.3) * 0.35, 1.0)
			img.set_pixel(x, y, c.lerp(Color.from_hsv(h, minf(c.s * sat_mul, 1.0), minf(c.v * val_mul, 1.0), c.a), k))


func _save_h(img: Image, file: String, height: int) -> void:
	var out := img.duplicate() as Image
	var w := int(round(float(height) * out.get_width() / out.get_height()))
	out.resize(w, height, Image.INTERPOLATE_LANCZOS)
	out.save_png(OUT + file)
	print("%s %dx%d" % [file, w, height])


# ---------------------------------------------------------------- Outils

func _load(file: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + file))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, file: String, width: int) -> void:
	var out := img.duplicate() as Image
	var h := int(round(float(width) * out.get_height() / out.get_width()))
	out.resize(width, h, Image.INTERPOLATE_LANCZOS)
	out.save_png(OUT + file)
	print("%s %dx%d" % [file, width, h])


func _corners(img: Image) -> Array:
	var w := img.get_width() - 1
	var h := img.get_height() - 1
	return [Vector2i(0, 0), Vector2i(w, 0), Vector2i(0, h), Vector2i(w, h)]


## Rend transparent le fond uni connecté aux graines (remplissage 4-voisins),
## puis adoucit le liseré : alpha selon l'écart au fond sur la bordure.
func _remove_bg(img: Image, seeds: Array) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var bg := img.get_pixelv(seeds[0])
	var br := int(bg.r8)
	var bgg := int(bg.g8)
	var bb := int(bg.b8)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack := PackedInt32Array()
	for s in seeds:
		stack.append(s.y * w + s.x)
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if seen[i] != 0:
			continue
		var o := i * 4
		var dist := absi(data[o] - br) + absi(data[o + 1] - bgg) + absi(data[o + 2] - bb)
		if dist > BG_TOLERANCE:
			continue
		seen[i] = 1
		data[o + 3] = 0
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	# Liseré : pixels opaques voisins du fond → alpha progressif.
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			if seen[i] != 0:
				continue
			if seen[i - 1] == 0 and seen[i + 1] == 0 and seen[i - w] == 0 and seen[i + w] == 0:
				continue
			var o := i * 4
			var dist := absi(data[o] - br) + absi(data[o + 1] - bgg) + absi(data[o + 2] - bb)
			data[o + 3] = clampi(int(255.0 * (dist - BG_TOLERANCE * 0.5) / (BG_TOLERANCE * 2.0)), 40, 255)
	img.set_data(w, h, false, Image.FORMAT_RGBA8, data)


func _crop_alpha(img: Image, pad: int) -> Image:
	var r := img.get_used_rect()
	r = r.grow(pad).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r)


func _paint_disc(img: Image, c: Vector2, r: float, col: Color, feather := 60.0) -> void:
	for y in range(int(c.y - r) - 1, int(c.y + r) + 2):
		for x in range(int(c.x - r) - 1, int(c.x + r) + 2):
			var d := Vector2(x, y).distance_to(c)
			if d > r:
				continue
			# Bord fondu sur 60 px dans le fond d'origine.
			var k := clampf((r - d) / feather, 0.0, 1.0)
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(col, 1.0), k))


func _paint_ellipse(img: Image, c: Vector2, r: Vector2, col: Color) -> void:
	for y in range(int(c.y - r.y), int(c.y + r.y) + 1):
		for x in range(int(c.x - r.x), int(c.x + r.x) + 1):
			var q := (Vector2(x, y) - c) / r
			if q.length() <= 1.0:
				var base := img.get_pixel(x, y)
				if base.a > 0.5:
					img.set_pixel(x, y, base.lerp(Color(col, base.a), col.a * (1.0 - q.length())))


## Distance signée à un polygone (négative à l'intérieur).
static func _poly_sdf(p: Vector2, pts: PackedVector2Array) -> float:
	var d := INF
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		d = minf(d, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
	return -d if Geometry2D.is_point_in_polygon(p, pts) else d
