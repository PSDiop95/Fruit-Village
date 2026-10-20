extends SceneTree
## Prépare les visuels finaux (art_src/ → assets/ui/) aux tailles du jeu :
## logo 1024, icône 512, icônes adaptatives Android 432 (fond ciel + logo),
## splash 1080 de large. Les originaux restent dans art_src/ (hors APK).
## Usage : Godot --headless --path . -s tools/prepare_art.gd


func _initialize() -> void:
	var logo := _load("res://art_src/logo_2048.png")
	var icon := _load("res://art_src/icon_2048.png")
	var splash := _load("res://art_src/splash_1536x2752.jpg")

	var l := logo.duplicate() as Image
	l.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	l.save_png("res://assets/ui/logo.png")

	var i := icon.duplicate() as Image
	i.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	i.save_png("res://assets/ui/icon.png")

	# Icône adaptative : fond = ciel de l'icône (intérieur du carré arrondi,
	# plein cadre), avant-plan = logo dans la zone sûre (66 % centraux).
	var inner := Rect2i(300, 300, 1448, 1448)
	var bg := icon.get_region(inner)
	bg.resize(432, 432, Image.INTERPOLATE_LANCZOS)
	bg.convert(Image.FORMAT_RGB8)
	bg.save_png("res://assets/ui/icon_adaptive_bg.png")
	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	var lf := logo.duplicate() as Image
	var safe := int(432 * 0.66)
	lf.resize(safe, safe, Image.INTERPOLATE_LANCZOS)
	fg.blend_rect(lf, Rect2i(0, 0, safe, safe), Vector2i((432 - safe) / 2, (432 - safe) / 2))
	fg.save_png("res://assets/ui/icon_adaptive_fg.png")

	var s := splash.duplicate() as Image
	s.resize(1080, int(1080.0 * splash.get_height() / splash.get_width()), Image.INTERPOLATE_LANCZOS)
	s.save_png("res://assets/ui/splash.png")
	# Fond de jeu : illustration du marché (pleine résolution, sans perte).
	var bg_art := _load("res://art_src/background_marche_baie.png")
	bg_art.convert(Image.FORMAT_RGB8)
	bg_art.save_png("res://assets/ui/background_marche.png")
	print("ART logo=%s icon=%s splash=%s fond=%s" % [l.get_size(), i.get_size(), s.get_size(), bg_art.get_size()])
	quit()


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img
