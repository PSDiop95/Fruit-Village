class_name FruitBatcher
extends Node3D
## Regroupe le rendu des visages et des taches d'ombre de tous les fruits de la
## partie en MultiMesh : 1 draw call par expression de visage + 1 pour toutes
## les ombres, au lieu de 2 par fruit. Les FruitVisual gardent leur logique
## (expressions, squash, tremblement) : on recopie juste leurs transformations
## finales à chaque frame, après leur mise à jour.

var _visuals: Array[FruitVisual] = []
var _faces: Dictionary = {}  # clé visage -> MultiMeshInstance3D
var _blobs: MultiMeshInstance3D


func _init() -> void:
	name = "FruitBatcher"
	# Après tous les FruitVisual (priorité 0) : transformations à jour.
	process_priority = 100


func register(v: FruitVisual) -> void:
	if not _visuals.has(v):
		_visuals.append(v)
		v.tree_exiting.connect(unregister.bind(v), CONNECT_ONE_SHOT)


func unregister(v: FruitVisual) -> void:
	_visuals.erase(v)


func registered_count() -> int:
	return _visuals.size()


func _process(_delta: float) -> void:
	var groups := {}
	var blob_xf: Array[Transform3D] = []
	for v in _visuals:
		if not is_instance_valid(v) or not v.is_visible_in_tree():
			continue
		var key := v.batched_face_key()
		if not groups.has(key):
			groups[key] = [] as Array[Transform3D]
			if not _faces.has(key):
				_faces[key] = _new_instance(v.batched_face_mesh())
		groups[key].append(v.batched_face_transform())
		if v.batched_blob_visible():
			blob_xf.append(v.batched_blob_transform())
	for key in groups:
		_fill(_faces[key], groups[key])
	for key in _faces:
		if not groups.has(key):
			_faces[key].multimesh.visible_instance_count = 0
	_fill(_blob_instance(), blob_xf)


func _fill(mmi: MultiMeshInstance3D, xfs: Array[Transform3D]) -> void:
	var mm := mmi.multimesh
	if mm.instance_count < xfs.size():
		mm.instance_count = maxi(xfs.size(), mm.instance_count * 2)
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	mm.visible_instance_count = xfs.size()


func _blob_instance() -> MultiMeshInstance3D:
	if _blobs == null:
		_blobs = _new_instance(FruitModels.blob_mesh())
	return _blobs


func _new_instance(mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = 16
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Pas de culling : les instances couvrent tout le panier.
	mmi.custom_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	add_child(mmi)
	return mmi
