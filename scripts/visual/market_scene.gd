class_name MarketScene
extends Node3D
## Habillage du marché : lumière, panier calebasse, étal, fond peint (ou, à
## défaut, décor 3D en plans estompés avec passants en aller-retour).
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


var backdrop: MeshInstance3D


func setup(cfg: VisualConfig, game_cfg: GameConfig = null) -> void:
	config = cfg
	name = "Market"
	_build_light()
	basket = _model_instance(cfg.basket_model, "BasketVisual")
	stall = _model_instance(cfg.stall_model, "StallVisual")
	if cfg.backdrop:
		_build_backdrop(game_cfg if game_cfg else load("res://data/game_config.tres"))
	else:
		_build_decor()
	apply_quality(FruitModels.quality)


## Fond peint : l'illustration occupe toute la largeur visible, son bord haut
## au bord haut d'un écran 9:16 ; ciel au-dessus (écrans plus allongés), sol
## en dessous (derrière le panier). Non éclairé : couleurs de l'illustration.
func _build_backdrop(gc: GameConfig) -> void:
	var tex := config.backdrop
	var w := (gc.basket_inner_width + gc.wall_thickness * 2.0 + gc.camera_side_margin) * config.backdrop_cover
	var h := w * float(tex.get_height()) / float(tex.get_width())
	var center_y := gc.basket_height * 0.5 + gc.camera_y_offset
	var screen_w := gc.basket_inner_width + gc.wall_thickness * 2.0 + gc.camera_side_margin
	var top := center_y + screen_w * 16.0 / 9.0 * 0.5
	var z := -config.backdrop_depth
	var img := tex.get_image()
	var sky := _row_average(img, 2)
	# Sol : chemin sableux au centre du bas de l'image (pas la végétation des bords).
	var ground := _row_average(img, img.get_height() - 3, 0.35, 0.65)
	backdrop = _flat_quad(Vector2(w, h), Vector3(0, top - h * 0.5, z), tex, Color.WHITE)
	backdrop.name = "Backdrop"
	_flat_quad(Vector2(w * 1.2, 40.0), Vector3(0, top + 20.0 - 0.01, z - 0.1), null, sky).name = "Sky"
	_flat_quad(Vector2(w * 1.2, 40.0), Vector3(0, top - h - 20.0 + 0.01, z - 0.1), null, ground).name = "Ground"
	# Fondu : le bas de l'illustration se fond dans la couleur du sol (pas de coupure).
	var fade := _flat_quad(Vector2(w * 1.2, config.backdrop_fade),
		Vector3(0, top - h + config.backdrop_fade * 0.5, z + 0.05), null, ground)
	fade.name = "GroundFade"
	var fm := fade.mesh.material as StandardMaterial3D
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.vertex_color_use_as_albedo = false
	fm.albedo_texture = _vertical_fade_texture()


## Dégradé vertical blanc opaque (bas) → transparent (haut), teinté par albedo_color.
static func _vertical_fade_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 1))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 4
	t.height = 64
	return t


func _flat_quad(size: Vector2, pos: Vector3, tex: Texture2D, color: Color) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if tex:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	q.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func _row_average(img: Image, y: int, from := 0.0, to := 1.0) -> Color:
	if img == null:
		return Color.SKY_BLUE
	var acc := Color(0, 0, 0)
	var n := 0
	for x in range(int(img.get_width() * from), int(img.get_width() * to), 4):
		acc += img.get_pixel(x, clampi(y, 0, img.get_height() - 1))
		n += 1
	return Color(acc.r / n, acc.g / n, acc.b / n)


func _build_light() -> void:
	var env := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = config.background_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = config.ambient_color
	environment.ambient_light_energy = config.ambient_energy
	environment.glow_enabled = config.glow_enabled
	environment.glow_intensity = config.glow_intensity
	environment.glow_strength = config.glow_strength
	environment.glow_hdr_threshold = config.glow_hdr_threshold
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
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
	mi.material_override = FruitModels.prop_material()
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
	# Passants articulés (femmes / hommes), en aller-retour derrière le panier.
	for i in config.people_models.size():
		var path: String = config.people_models[i]
		if not ResourceLoader.exists(path):
			continue
		var person := (load(path) as PackedScene).instantiate() as Node3D
		for mi in person.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			m.material_override = _decor_mat
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.set_instance_shader_parameter(&"fade", config.passant_fade)
			m.set_instance_shader_parameter(&"desaturate", 0.0)
		var holder := Node3D.new()
		holder.name = "Passant%d" % i
		holder.add_child(person)
		add_child(holder)
		holder.position = Vector3(0, config.passant_ground_y, -config.passant_depth - i * 0.6)
		passants.append(holder)
		# Déphasage déterministe : chaque passant à un endroit et un sens différents.
		_passant_phase.append(float(i) / maxf(config.people_models.size(), 1) * TAU + 0.7 * i)


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
			mi.material_override = FruitModels.prop_material()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func shadows_enabled() -> bool:
	return sun != null and sun.shadow_enabled


func _process(delta: float) -> void:
	_time += delta
	# Passants : aller-retour (sinus), trois-quarts vers le sens de marche,
	# jambes et bras en balancier opposé, léger rebond.
	for i in passants.size():
		var p := passants[i]
		var w := config.passant_speed / maxf(config.passant_range, 0.01)
		var ph := _time * w + _passant_phase[i]
		p.position.x = sin(ph) * config.passant_range
		var vel := cos(ph)  # vitesse relative (-1..1)
		var person := p.get_child(0) as Node3D
		person.rotation.y = lerp_angle(person.rotation.y, signf(vel) * config.walk_turn, 0.08)
		var step := _time * config.walk_cadence * TAU + i
		var amp := config.walk_swing * clampf(absf(vel) * 1.5, 0.0, 1.0)
		var swing := sin(step) * amp
		_rot(person, "leg_l", swing)
		_rot(person, "leg_r", -swing)
		_rot(person, "arm_l", -swing * 0.8)
		_rot(person, "arm_r", swing * 0.8)
		person.position.y = absf(cos(step)) * config.walk_bob * absf(vel)


static func _rot(person: Node3D, part: String, angle: float) -> void:
	var n := person.find_child(part, true, false) as Node3D
	if n:
		n.rotation.x = angle
