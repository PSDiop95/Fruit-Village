class_name FruitThumb
extends SubViewportContainer
## Miniature 3D d'un fruit (vrai modèle + visage) pour l'UI : bulle « Suivant »,
## plus gros fruit atteint. SubViewport à monde propre, rendu à la demande.

var catalog: FruitCatalog = preload("res://data/fruits.tres")
var juice: JuiceConfig = preload("res://data/juice.tres")

var _vp: SubViewport
var _visual: FruitVisual
var _cam: Camera3D
var _time: float = 0.0
var _rank: int = -1


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	var vc := FruitModels.get_config()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = vc.sun_rotation_degrees
	sun.light_color = vc.sun_color
	sun.light_energy = vc.sun_energy
	_vp.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = vc.ambient_color
	e.ambient_light_energy = vc.ambient_energy + 0.1
	env.environment = e
	_vp.add_child(env)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.position = Vector3(0, 0, 10)
	_vp.add_child(_cam)
	_visual = FruitVisual.new()
	var cfg := juice.duplicate() as JuiceConfig
	cfg.show_rank_numbers = false
	_visual.setup(cfg, 3)
	_vp.add_child(_visual)
	if _rank >= 0:
		set_fruit(_rank)


func set_fruit(rank: int) -> void:
	_rank = rank
	if _visual == null:
		return
	var def := catalog.get_def(rank)
	_visual.apply_def(rank, def)
	# Cadrage : le fruit remplit la bulle quelle que soit sa taille.
	_cam.size = def.radius * 2.0 * 1.22


## Petit « pop » quand le fruit change (bulle Suivant).
func pop() -> void:
	if _visual:
		_visual.pop(0.6, 1.12, 0.22)


func current_rank() -> int:
	return _rank


func _process(delta: float) -> void:
	_time += delta
	if _visual:
		_visual.rotation.z = sin(_time * 1.6) * 0.12
