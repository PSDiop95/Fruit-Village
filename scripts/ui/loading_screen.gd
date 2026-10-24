class_name LoadingScreen
extends CanvasLayer
## Écran de chargement : même image et même cadrage (« couvrir ») que le
## splash de démarrage, donc transition invisible ; la jauge peinte du splash
## avance avec le vrai chargement en arrière-plan (ResourceLoader threadé) de
## la scène de jeu, des données, modèles, sons et éléments d'interface, puis
## la préparation des modèles des fruits. Émet `finished` à la fin.

signal finished

const SPLASH := "res://assets/ui/splash.png"
const UNDER := "res://assets/ui/loading_under.png"
const FILL := "res://assets/ui/loading_fill.png"
## Jauge dans splash.png (px), relevée par tools/prepare_splash.gd.
const BAR_RECT := Rect2(237.66, 1822.5, 607.5, 102.66)
## Creux de la jauge dans loading_under.png (px de la texture d'origine).
const FILL_OFFSET := Vector2(22, 28)
## Ressources préchargées (scènes, données) ; plus les dossiers ci-dessous.
const FILES := ["res://scenes/Game.tscn", "res://data/visual.tres", "res://data/juice.tres",
	"res://data/sounds.tres", "res://data/fruits.tres", "res://assets/ui/theme.tres",
	"res://data/ambiances.tres"]
const DIRS := ["res://assets/models", "res://assets/ui/hud", "res://assets/sfx"]
## Part de la jauge pour les chargements ; le reste : préparation des modèles.
const LOAD_SHARE := 0.85
## Avance visuelle maximale de la jauge (part par seconde) : pas de saut sec.
const BAR_SPEED := 1.6

var bar: TextureProgressBar
var progress: float = 0.0
## Ressources gardées en mémoire (cache) jusqu'à la fin du chargement.
var loaded: Array[Resource] = []

var _paths: PackedStringArray = []
var _shown: float = 0.0
var _done_loading: bool = false
var _finished: bool = false


func _ready() -> void:
	layer = 90
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := TextureRect.new()
	bg.texture = load(SPLASH)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	bar = TextureProgressBar.new()
	bar.texture_under = load(UNDER)
	bar.texture_progress = load(FILL)
	bar.texture_progress_offset = FILL_OFFSET
	bar.max_value = 1.0
	bar.step = 0.0
	root.add_child(bar)
	_place_bar()
	get_viewport().size_changed.connect(_place_bar)
	_collect()
	for p in _paths:
		ResourceLoader.load_threaded_request(p)


## Jauge à l'emplacement de la barre peinte, avec le cadrage « couvrir ».
func _place_bar() -> void:
	var view := get_viewport().get_visible_rect().size
	var img := Vector2((load(SPLASH) as Texture2D).get_size())
	var k := maxf(view.x / img.x, view.y / img.y)
	var origin := (view - img * k) * 0.5
	var under_w := float(bar.texture_under.get_width())
	var s := BAR_RECT.size.x * k / under_w
	bar.scale = Vector2(s, s)
	bar.position = origin + BAR_RECT.position * k


func _collect() -> void:
	for f in FILES:
		if ResourceLoader.exists(f):
			_paths.append(f)
	for d in DIRS:
		for f in ResourceLoader.list_directory(d):
			var p: String = d.path_join(f)
			if not f.ends_with("/") and ResourceLoader.exists(p):
				_paths.append(p)


func _process(delta: float) -> void:
	if not _done_loading:
		var sum := 0.0
		var all_done := true
		for p in _paths:
			var prog := []
			var st := ResourceLoader.load_threaded_get_status(p, prog)
			match st:
				ResourceLoader.THREAD_LOAD_LOADED:
					sum += 1.0
				ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					sum += float(prog[0]) if not prog.is_empty() else 0.0
					all_done = false
				_:
					sum += 1.0  # échec : on n'attend pas
		progress = LOAD_SHARE * (sum / maxf(_paths.size(), 1))
		if all_done:
			_done_loading = true
			for p in _paths:
				var r := ResourceLoader.load_threaded_get(p)
				if r:
					loaded.append(r)
			_warm_up.call_deferred()
	_shown = move_toward(_shown, progress, delta * BAR_SPEED)
	bar.value = _shown
	if _finished and _shown >= 0.999:
		set_process(false)
		finished.emit()


## Matériaux et modèles des fruits prêts avant le titre (évite l'à-coup du
## premier lancement de partie).
func _warm_up() -> void:
	FruitModels.warm_up(load("res://data/fruits.tres"))
	progress = 1.0
	_finished = true
