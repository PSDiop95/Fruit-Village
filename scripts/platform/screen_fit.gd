class_name ScreenFit
extends RefCounted
## Cadrage de l'écran. L'interface est conçue en 1080x1920 (9:16) avec des
## positions absolues ; le mode « keep_width » du projet ajoute de la hauteur
## sur les téléphones allongés (le décor 3D la remplit), mais :
## - sur iPhone, le haut et le bas passent sous l'encoche / Dynamic Island et
##   l'indicateur d'accueil : l'interface et le cadrage du panier se placent
##   dans la zone sûre (safe_rect), le décor reste plein écran ;
## - sur un écran plus large que 9:16 (iPad, tablettes), il manque de la
##   hauteur : cadre 9:16 centré (bandes noires ; Godot 4 ne permet pas de les
##   décorer).

const BASE_ASPECT := 1080.0 / 1920.0
const ASPECT_TOLERANCE := 0.01
## Zone sûre d'un iPhone à Dynamic Island (59 pt en haut, 34 pt en bas sur
## 852 pt de haut), en fraction de la hauteur d'écran : captures « ios ».
const IPHONE_INSETS := Vector2(59.0 / 852.0, 34.0 / 852.0)

## Marges de la zone sûre (haut, bas) en fraction de la hauteur d'écran :
## lues au démarrage sur iOS, nulles ailleurs.
static var safe_insets := Vector2.ZERO
## Cadrage fait une fois par exécution : Main ne défait pas celui des captures.
static var _applied := false


## `screen` : taille de l'écran en pixels (largeur, hauteur).
static func needs_letterbox(screen: Vector2) -> bool:
	if screen.x <= 0.0 or screen.y <= 0.0:
		return false
	return screen.x / screen.y > BASE_ASPECT + ASPECT_TOLERANCE


## À appeler au démarrage (Main). `os_name` : forçable pour les captures, qui
## simulent alors la zone sûre d'un iPhone (`insets`).
static func apply(window: Window, os_name: String = OS.get_name(),
		insets: Vector2 = Vector2(-1.0, -1.0)) -> bool:
	if _applied:
		return window.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP
	_applied = true
	if needs_letterbox(Vector2(window.size)):
		safe_insets = Vector2.ZERO
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		return true
	if insets.x >= 0.0:
		safe_insets = insets
	elif os_name == "iOS":
		safe_insets = _read_insets()
	else:
		safe_insets = Vector2.ZERO
	return false


static func _read_insets() -> Vector2:
	var screen := Vector2(DisplayServer.screen_get_size())
	if screen.y <= 0.0:
		return Vector2.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	return Vector2(safe.position.y, screen.y - safe.end.y).max(Vector2.ZERO) / screen.y


## Partie du canevas hors encoche et barre d'accueil (unités du canevas).
static func safe_rect(vp: Viewport) -> Rect2:
	var view := vp.get_visible_rect().size
	var top := safe_insets.x * view.y
	var bottom := safe_insets.y * view.y
	return Rect2(0.0, top, view.x, maxf(view.y - top - bottom, 1.0))


## Fait déborder un Control plein écran, enfant d'un Control ramené à la zone
## sûre, sur l'encoche et la barre d'accueil (voiles, teintes). Dans l'arbre.
static func bleed_to_screen(control: Control) -> void:
	var vp := control.get_viewport()
	var safe := safe_rect(vp)
	control.offset_top = -safe.position.y
	control.offset_bottom = vp.get_visible_rect().size.y - safe.end.y


## Ramène un Control plein écran à la zone sûre (fenêtre principale si le
## Control n'est pas encore dans l'arbre).
static func fit_to_safe(control: Control) -> void:
	var vp: Viewport = control.get_viewport() if control.is_inside_tree() \
		else (Engine.get_main_loop() as SceneTree).root
	var safe := safe_rect(vp)
	control.offset_top = safe.position.y
	control.offset_bottom = safe.end.y - vp.get_visible_rect().size.y
