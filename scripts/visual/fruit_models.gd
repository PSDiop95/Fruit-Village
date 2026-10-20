class_name FruitModels
extends RefCounted
## Modèles 3D des fruits (assets/models/fruit_<id>.glb, exportés de Blender)
## et matériaux toon partagés. Chargés une fois, réutilisés par tous les fruits :
## un seul matériau pour tous → batching, aucun matériau dupliqué.
##
## Le modèle ne sert QU'AU rendu : la collision reste la sphère de fruits.tres.

const CONFIG_PATH := "res://data/visual.tres"
const TOON_SHADER := preload("res://assets/shaders/toon.gdshader")
const TOON_LOW_SHADER := preload("res://assets/shaders/toon_low.gdshader")
const TOON_PROP_SHADER := preload("res://assets/shaders/toon_prop.gdshader")
const OUTLINE_SHADER := preload("res://assets/shaders/outline.gdshader")

## Données extraites d'un .glb.
class Model:
	var mesh: Mesh
	## Ancre du visage (mètres, repère du fruit) et taille relative du visage.
	var face_position := Vector3(0, 0, 1)
	var face_scale: float = 1.0

static var config: VisualConfig
static var quality: int = JuiceConfig.Quality.HIGH
static var _models: Dictionary = {}
static var _material: ShaderMaterial
static var _material_low: ShaderMaterial
static var _outline: ShaderMaterial
static var _prop_material: ShaderMaterial


static func get_config() -> VisualConfig:
	if config == null:
		config = load(CONFIG_PATH)
	return config


## Précharge tous les modèles + matériaux (évite un à-coup à la première
## apparition de chaque fruit en cours de partie). Idempotent.
static func warm_up(catalog: FruitCatalog) -> void:
	_ensure_materials()
	for def in catalog.fruits:
		get_model(def.id)


## Modèle du fruit `id`, ou null si le .glb n'existe pas (repli sphère M2).
static func get_model(id: StringName) -> Model:
	if _models.has(id):
		return _models[id]
	var m: Model = null
	var path := get_config().fruit_model_pattern % id
	if ResourceLoader.exists(path):
		m = _extract(load(path) as PackedScene)
	_models[id] = m
	return m


static func _extract(scene: PackedScene) -> Model:
	if scene == null:
		return null
	var root := scene.instantiate()
	var mi := _find_mesh(root)
	var m: Model = null
	if mi:
		m = Model.new()
		m.mesh = mi.mesh
		var anchor := mi.find_child("face_anchor", true, false) as Node3D
		if anchor:
			# Repère du mesh : le visuel applique lui-même l'échelle du fruit.
			var xf := _relative(mi, anchor)
			m.face_position = xf.origin
			m.face_scale = xf.basis.get_scale().x
	root.free()
	return m


static func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r:
			return r
	return null


## Transformation de `node` dans le repère de `ancestor` (hors arbre).
static func _relative(ancestor: Node3D, node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n and n != ancestor:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


## Matériau toon partagé selon la qualité courante (contour en next_pass).
static func fruit_material() -> ShaderMaterial:
	_ensure_materials()
	return _material if quality >= get_config().rim_min_quality else _material_low


## Matériau des grands props (panier, étal) : sans grain ni contour.
static func prop_material() -> ShaderMaterial:
	_ensure_materials()
	return _prop_material


static func set_quality(level: int) -> void:
	quality = level
	_ensure_materials()
	var cfg := get_config()
	var outline: Material = _outline if level >= cfg.outline_min_quality else null
	_material.next_pass = outline
	_material_low.next_pass = outline


static func _ensure_materials() -> void:
	if _material:
		return
	var cfg := get_config()
	_outline = ShaderMaterial.new()
	_outline.shader = OUTLINE_SHADER
	_outline.render_priority = -1
	_material = ShaderMaterial.new()
	_material.shader = TOON_SHADER
	_material_low = ShaderMaterial.new()
	_material_low.shader = TOON_LOW_SHADER
	_prop_material = ShaderMaterial.new()
	_prop_material.shader = TOON_PROP_SHADER
	apply_config(cfg)
	set_quality(quality)


## (Ré)applique data/visual.tres aux matériaux (réglage à chaud possible).
static func apply_config(cfg: VisualConfig) -> void:
	config = cfg
	if _material == null:
		return
	_apply_prop_config(cfg)
	for mat in [_material, _material_low]:
		mat.set_shader_parameter("palette", cfg.palette)
		mat.set_shader_parameter("shadow_threshold", cfg.shadow_threshold)
		mat.set_shader_parameter("light_threshold", cfg.light_threshold)
		mat.set_shader_parameter("shadow_tone", cfg.shadow_tone)
		mat.set_shader_parameter("mid_tone", cfg.mid_tone)
		mat.set_shader_parameter("tone_softness", cfg.tone_softness)
		mat.set_shader_parameter("shadow_tint", cfg.shadow_tint)
		mat.set_shader_parameter("specular_shininess", cfg.specular_shininess)
		mat.set_shader_parameter("specular_threshold", cfg.specular_threshold)
		mat.set_shader_parameter("specular_strength", cfg.specular_strength)
		mat.set_shader_parameter("specular_softness", cfg.specular_softness)
		mat.set_shader_parameter("cast_shadow_tone", cfg.cast_shadow_tone)
		mat.set_shader_parameter("grain_strength", cfg.grain_strength)
		mat.set_shader_parameter("saturation", cfg.saturation)
		mat.set_shader_parameter("edge_darken", cfg.edge_darken)
		mat.set_shader_parameter("edge_power", cfg.edge_power)
		mat.set_shader_parameter("top_light", cfg.top_light)
		mat.set_shader_parameter("grain_scale", cfg.grain_scale)
		mat.set_shader_parameter("mottle_strength", cfg.mottle_strength)
		mat.set_shader_parameter("mottle_scale", cfg.mottle_scale)
		mat.set_shader_parameter("rim_color", cfg.rim_color)
		mat.set_shader_parameter("rim_strength", cfg.rim_strength)
		mat.set_shader_parameter("rim_power", cfg.rim_power)
		mat.set_shader_parameter("velvet_strength", cfg.velvet_strength)
		mat.set_shader_parameter("velvet_power", cfg.velvet_power)
	_outline.set_shader_parameter("outline_width", cfg.outline_width)
	_outline.set_shader_parameter("outline_color", cfg.outline_color)


## Mode de contour du fruit (1 radial, 0 normales) : paramètre d'instance.
static func outline_radial_for(id: StringName) -> float:
	var cfg := get_config()
	return 0.0 if cfg.outline_normal_ids.has(String(id)) else cfg.outline_radial


## Taches d'ombre (activées, ou repli si les ombres dynamiques sont coupées).
static func blob_shadows() -> bool:
	var cfg := get_config()
	return cfg.blob_shadows_enabled or quality < cfg.shadows_min_quality


static var _blob_mesh: QuadMesh


static func blob_mesh() -> QuadMesh:
	if _blob_mesh == null:
		_blob_mesh = QuadMesh.new()
		_blob_mesh.size = Vector2.ONE
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/shaders/blob_shadow.gdshader")
		mat.set_shader_parameter("color", get_config().blob_shadow_color)
		_blob_mesh.material = mat
	return _blob_mesh


## Paramètres du shader « éclairage intégré » des props (même lumière que la scène).
static func _apply_prop_config(cfg: VisualConfig) -> void:
	var m := _prop_material
	var dir := Basis.from_euler(cfg.sun_rotation_degrees * PI / 180.0) * Vector3.FORWARD
	m.set_shader_parameter("palette", cfg.palette)
	m.set_shader_parameter("sun_direction", dir)
	m.set_shader_parameter("sun_color", cfg.sun_color)
	m.set_shader_parameter("sun_energy", cfg.sun_energy)
	m.set_shader_parameter("ambient_color", cfg.ambient_color)
	m.set_shader_parameter("ambient_energy", cfg.ambient_energy)
	for p in ["shadow_threshold", "light_threshold", "shadow_tone", "mid_tone", "tone_softness", "saturation"]:
		m.set_shader_parameter(p, cfg.get(p))
	m.set_shader_parameter("shadow_tint", cfg.shadow_tint)


static func is_halo_rank(rank: int) -> bool:
	return get_config().halo_ranks.has(rank)
