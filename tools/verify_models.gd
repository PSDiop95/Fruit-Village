extends SceneTree
## Vérification des modèles exportés de Blender (lancé par tools/build_models.py).
## Usage : Godot --headless --path . -s tools/verify_models.gd -- <dossier res://>
## Code de sortie 0 = tout est conforme, 1 = export refusé.
##
## Règles : fruit_<id>.glb pour chaque fruit de data/fruits.tres, < 2500
## triangles, rayon du mesh = rayon de collision à ±3 %, matériau « palette »,
## ancre « face_anchor » présente.

const MAX_TRIS := 2500
const RADIUS_TOLERANCE := 0.03


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else "res://assets/models"
	var errors := check_dir(dir)
	for e in errors:
		printerr("VERIFY_FAIL ", e)
	print("VERIFY_%s %d erreur(s)" % ["OK" if errors.is_empty() else "FAIL", errors.size()])
	quit(0 if errors.is_empty() else 1)


## Retourne la liste des erreurs (vide = conforme). Réutilisé par les tests.
static func check_dir(dir: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var catalog: FruitCatalog = load("res://data/fruits.tres")
	for def in catalog.fruits:
		var path := dir.path_join("fruit_%s.glb" % def.id)
		var info := inspect(path)
		if info.has("error"):
			errors.append("%s : %s" % [path, info.error])
			continue
		var line := "%-22s tris=%3d rayon=%.4f cible=%.4f écart=%+.2f%%" % [
			"fruit_%s" % def.id, info.tris, info.radius, def.radius,
			(info.radius / def.radius - 1.0) * 100.0]
		print("VERIFY ", line)
		if info.tris >= MAX_TRIS:
			errors.append("%s : %d triangles (max %d)" % [path, info.tris, MAX_TRIS])
		if absf(info.radius / def.radius - 1.0) > RADIUS_TOLERANCE:
			errors.append("%s : rayon %.4f ≠ %.4f (±3 %%)" % [path, info.radius, def.radius])
		if info.material != "palette":
			errors.append("%s : matériau « %s » (attendu « palette »)" % [path, info.material])
		if not info.anchor:
			errors.append("%s : pas de face_anchor" % path)
	return errors


## Mesure un .glb importé : triangles, rayon (max |sommet|), matériau, ancre.
static func inspect(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		return {"error": "absent (non exporté ou non importé)"}
	var scene := load(path) as PackedScene
	if scene == null:
		return {"error": "illisible"}
	var root := scene.instantiate()
	var mi: MeshInstance3D = null
	for n in root.find_children("*", "MeshInstance3D", true, false):
		mi = n
		break
	if mi == null or mi.mesh == null:
		root.free()
		return {"error": "aucun mesh"}
	var tris := 0
	var radius := 0.0
	var mat_name := ""
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		tris += (idx.size() if idx != null and idx.size() > 0 else verts.size()) / 3
		for v in verts:
			radius = maxf(radius, (mi.transform * v).length())
		var mat := mesh.surface_get_material(s)
		if mat and mat_name.is_empty():
			mat_name = mat.resource_name
	var anchor := root.find_child("face_anchor", true, false) != null
	root.free()
	return {"tris": tris, "radius": radius, "material": mat_name, "anchor": anchor}
