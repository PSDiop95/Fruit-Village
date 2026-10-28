extends GutTest
## M3 : modèles des fruits (pipeline Blender) et branchement visuel.
## La collision ne dépend jamais du modèle.

const VERIFY := preload("res://tools/verify_models.gd")

var catalog: FruitCatalog = preload("res://data/fruits.tres")
var juice: JuiceConfig = preload("res://data/juice.tres")


func test_chaque_fruit_a_un_modele_conforme() -> void:
	var errors: PackedStringArray = VERIFY.check_dir("res://assets/models")
	assert_eq(errors.size(), 0, "\n".join(errors))


func test_modele_et_ancre_de_visage_charges() -> void:
	for def in catalog.fruits:
		var m := FruitModels.get_model(def.id)
		assert_not_null(m, "modèle %s" % def.id)
		if m == null:
			continue
		# Visage sur la face avant (+Z), dans le rayon.
		assert_gt(m.face_position.z, def.radius * 0.3, "visage devant : %s" % def.id)
		assert_lt(m.face_position.length(), def.radius * 1.01, "visage dans le rayon : %s" % def.id)


## Collision calée sur le modèle : jamais plus large que le fruit visible
## (pas de « vide invisible »), capsule pour les fruits allongés.
func test_collision_epouse_le_modele() -> void:
	var config: GameConfig = preload("res://data/game_config.tres")
	for i in catalog.count():
		var def := catalog.get_def(i)
		var m := FruitModels.get_model(def.id)
		var f := Fruit.new()
		f.setup(i, def, config, juice)
		var shapes := f.find_children("*", "CollisionShape3D", false, false)
		assert_eq(shapes.size(), 1)
		var s := f.collision_shape()
		if m == null:
			assert_almost_eq((s as SphereShape3D).radius, def.radius, 0.0001)
			f.free()
			continue
		var box := m.mesh.get_aabb()
		var half_w: float = s.radius
		var half_max := maxf(box.size.x, box.size.y) * 0.5
		assert_lt(half_w, half_max + 0.001, "pas plus large que le modèle : %s" % def.id)
		assert_lt(half_w, def.radius + 0.001, "jamais plus large qu'avant : %s" % def.id)
		assert_gt(half_w, box.size.x * 0.5 * 0.85, "assez large : %s" % def.id)
		var elongated := box.size.y >= box.size.x * config.capsule_min_elongation
		assert_eq(s is CapsuleShape3D, elongated, "capsule si allongé : %s" % def.id)
		assert_almost_eq(f.size_factor(), 1.0, 0.0001)
		f.set_size_factor(0.7)
		assert_almost_eq(s.radius, half_w * 0.7, 0.0001, "grandit avec le fruit")
		f.free()
	var mango := catalog.get_def(6)
	assert_eq(mango.id, &"mangue")
	assert_ne(FruitModels.collider_dims(mango, config).y, 0.0, "mangue en capsule")


func test_top_y_suit_l_inclinaison_de_la_capsule() -> void:
	var config: GameConfig = preload("res://data/game_config.tres")
	var f := Fruit.new()
	f.setup(6, catalog.get_def(6), config, juice)
	add_child_autofree(f)
	var d := FruitModels.collider_dims(catalog.get_def(6), config)
	f.global_position = Vector3.ZERO
	assert_almost_eq(f.top_y(), d.z + d.y * 0.5, 0.001, "debout : demi-hauteur")
	f.rotation.z = PI * 0.5
	assert_almost_eq(f.top_y(), d.x, 0.001, "couchée : rayon")


func test_halo_seulement_sur_pain_de_singe() -> void:
	for i in catalog.count():
		assert_eq(FruitModels.is_halo_rank(i), i == catalog.max_rank())


func test_basket_model_never_enters_play_area() -> void:
	# Le modèle s'adapte à la collision M1 : aucun sommet dans la zone jouable.
	var cfg: GameConfig = preload("res://data/game_config.tres")
	var mesh := MarketScene._load_mesh(FruitModels.get_config().basket_model)
	assert_not_null(mesh, "basket_calebasse.glb importé")
	if mesh == null:
		return
	var half := cfg.basket_inner_width * 0.5 - 0.005
	var bad := 0
	for s in mesh.get_surface_count():
		for v in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if absf(v.x) < half and v.y > 0.005 and v.y < cfg.basket_height - 0.005 and absf(v.z) < 0.995:
				bad += 1
	assert_eq(bad, 0, "sommets du panier dans la zone de jeu")


func test_basket_collision_unchanged() -> void:
	var g: Game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(g)
	var cfg: GameConfig = g.config
	var shapes := g.get_node("Basket").find_children("*", "CollisionShape3D", false, false)
	assert_eq(shapes.size(), 3, "sol + 2 murs (M1)")
	var floor_shape := (shapes[0] as CollisionShape3D).shape as BoxShape3D
	assert_eq(floor_shape.size, Vector3(cfg.basket_inner_width + cfg.wall_thickness * 2.0, cfg.wall_thickness, 2.0))
	var wall := (shapes[1] as CollisionShape3D).shape as BoxShape3D
	assert_eq(wall.size, Vector3(cfg.wall_thickness, cfg.basket_height, 2.0))


func test_batcher_tracks_fruits_and_merges() -> void:
	var g: Game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(g)
	await wait_physics_frames(2)
	var batcher: FruitBatcher = g.find_child("FruitBatcher", true, false)
	assert_not_null(batcher, "visages/ombres regroupés en MultiMesh")
	var a := g.spawn_fruit(0, Vector3(-0.3, 1.0, 0))
	var b := g.spawn_fruit(0, Vector3(0.3, 1.0, 0))
	assert_eq(batcher.registered_count(), 2)
	for k in 60:
		await wait_physics_frames(1)
		if not is_instance_valid(a) and not is_instance_valid(b):
			break
	await wait_process_frames(2)
	assert_eq(batcher.registered_count(), g.all_fruits().size(), "un visage par fruit vivant")
