class_name MarketScene
extends Node3D
## Habillage du marché (M3) : lumière de fin d'après-midi, panier calebasse,
## étal, décor Sandaga en plans estompés, passants en aller-retour.
## Purement visuel : la collision du panier reste les boîtes M1 de Game.

const DECOR_SHADER := preload("res://assets/shaders/decor.gdshader")

var config: VisualConfig
var sun: DirectionalLight3D
var environment: Environment
var basket: MeshInstance3D
var stall: MeshInstance3D
var layers: Array[MeshInstance3D] = []
var passants: Array[Node3D] = []

var _time: float = 0.0
var _decor_mat: ShaderMaterial
var _passant_phase: PackedFloat32Array = PackedFloat32Array()


func setup(cfg: VisualConfig) -> void:
	config = cfg
	name = "Market"
	_build_light()
	basket = _model_instance(cfg.basket_model, "BasketVisual")
	stall = _model_instance(cfg.stall_model, "StallVisual")
	_build_decor()
	apply_quality(FruitModels.quality)


func _build_light() -> void:
	var env := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = config.background_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = config.ambient_color
	environment.ambient_light_energy = config.ambient_energy
	env.environment = environment
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = config.sun_rotation_degrees
	sun.light_color = config.sun_color
	sun.light_energy = config.sun_energy
	sun.shadow_opacity = config.shadow_opacity
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


## Mesh d'un .glb rendu avec le matériau toon partagé des fruits (même palette).
func _model_instance(path: String, node_name: String) -> MeshInstance3D:
	var mesh := _load_mesh(path)
	if mesh == null:
		return null
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = FruitModels.fruit_material()
	mi.set_instance_shader_parameter(&"outline_radial", 0.0)
	add_child(mi)
	return mi


static var _mesh_cache: Dictionary = {}


## Mesh d'un .glb, chargé une seule fois (une partie relancée ne recharge rien).
static func _load_mesh(path: String) -> Mesh:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	if not ResourceLoader.exists(path):
		_mesh_cache[path] = null
		return null
	var scene := load(path) as PackedScene
	var root := scene.instantiate()
	var mesh: Mesh = null
	for n in root.find_children("*", "MeshInstance3D", true, false):
		mesh = (n as MeshInstance3D).mesh
		break
	root.free()
	_mesh_cache[path] = mesh
	return mesh


func _build_decor() -> void:
	_decor_mat = ShaderMaterial.new()
	_decor_mat.shader = DECOR_SHADER
	_decor_mat.set_shader_parameter("palette", config.palette)
	_decor_mat.set_shader_parameter("haze_color", config.decor_haze_color)
	for layer in config.decor_layers:
		var mesh := _load_mesh(layer.model)
		if mesh == null:
			continue
		var mi := _decor_instance(mesh, layer.fade, layer.desaturate)
		mi.position.z = -float(layer.depth)
		layers.append(mi)
	var pm := _load_mesh(config.passant_model)
	if pm == null:
		return
	for i in config.passant_count:
		var holder := Node3D.new()
		holder.name = "Passant%d" % i
		var mi := _decor_instance(pm, config.passant_fade, 0.3)
		remove_child(mi)
		holder.add_child(mi)
		add_child(holder)
		holder.position = Vector3(0, config.passant_ground_y, -config.passant_depth - i * 0.5)
		passants.append(holder)
		# Déphasage déterministe : chaque passant à un endroit différent.
		_passant_phase.append(float(i) / maxf(config.passant_count, 1) * TAU + 0.7 * i)


func _decor_instance(mesh: Mesh, fade: float, desat: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _decor_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter(&"fade", fade)
	mi.set_instance_shader_parameter(&"desaturate", desat)
	add_child(mi)
	return mi


## Qualité : ombres dynamiques (Moyen/Haut) ou taches d'ombre (Bas).
func apply_quality(level: int) -> void:
	if sun:
		sun.shadow_enabled = level >= config.shadows_min_quality
	for mi in [basket, stall]:
		if mi:
			mi.material_override = FruitModels.fruit_material()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func shadows_enabled() -> bool:
	return sun != null and sun.shadow_enabled


func _process(delta: float) -> void:
	_time += delta
	# Passants : aller-retour lent (sinus), dandinement, demi-tour aux bords.
	for i in passants.size():
		var p := passants[i]
		var w := config.passant_speed / maxf(config.passant_range, 0.01)
		var ph := _time * w + _passant_phase[i]
		p.position.x = sin(ph) * config.passant_range
		var dir := signf(cos(ph))
		p.rotation.z = sin(_time * config.passant_sway_speed + i) * config.passant_sway
		p.scale.x = dir if dir != 0.0 else 1.0
