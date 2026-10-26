class_name ScreenFit
extends RefCounted
## Cadrage de l'écran. L'interface est conçue en 1080x1920 (9:16) avec des
## positions absolues ; le mode « keep_width » du projet ajoute de la hauteur
## sur les téléphones allongés, mais :
## - sur iPhone, ce surplus passe sous l'encoche / Dynamic Island et
##   l'indicateur d'accueil (zone non sûre) ;
## - sur un écran plus large que 9:16 (iPad, tablettes), il manque de la
##   hauteur : le haut et le bas de l'interface sortiraient de l'écran.
## Dans ces deux cas : cadre 9:16 centré (bandes noires ; Godot 4 ne permet
## pas de les décorer). Sur iPhone, la bande du haut couvre l'encoche.

const BASE_ASPECT := 1080.0 / 1920.0
const ASPECT_TOLERANCE := 0.01


## `screen` : taille de l'écran en pixels (largeur, hauteur).
static func needs_letterbox(os_name: String, screen: Vector2) -> bool:
	if screen.x <= 0.0 or screen.y <= 0.0:
		return false
	return os_name == "iOS" or screen.x / screen.y > BASE_ASPECT + ASPECT_TOLERANCE


## À appeler au démarrage (Main). `os_name` : forçable pour les captures.
static func apply(window: Window, os_name: String = OS.get_name()) -> bool:
	if not needs_letterbox(os_name, Vector2(window.size)):
		return false
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	return true
