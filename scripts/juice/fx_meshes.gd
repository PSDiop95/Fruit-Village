class_name FxMeshes
extends RefCounted
## Meshes et matériaux placeholders partagés (créés une fois, réutilisés partout).

const FRUIT_SHADER := preload("res://assets/shaders/fruit.gdshader")
const ADDITIVE_SHADER := preload("res://assets/shaders/additive.gdshader")

static var _cache: Dictionary = {}


static func _cached(key: String, builder: Callable) -> Variant:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]


## Sphère du fruit (rayon 1, mise à l'échelle par le nœud) + matériau par rang.
static func fruit_mesh(rank: int, color: Color) -> SphereMesh:
	return _cached("fruit_%d" % rank, func() -> SphereMesh:
		var m := SphereMesh.new()
		m.radius = 1.0
		m.height = 2.0
		m.radial_segments = 24
		m.rings = 12
		var mat := ShaderMaterial.new()
		mat.shader = FRUIT_SHADER
		mat.set_shader_parameter("albedo", color)
		m.material = mat
		return m)


static func unshaded(color: Color, vertex_color := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.vertex_color_use_as_albedo = vertex_color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func eye_mesh(color: Color) -> SphereMesh:
	return _cached("eye", func() -> SphereMesh:
		var m := SphereMesh.new()
		m.radius = 0.12
		m.height = 0.24
		m.radial_segments = 10
		m.rings = 5
		m.material = unshaded(color)
		return m)


static func eye_highlight_mesh(color: Color) -> SphereMesh:
	return _cached("eye_hl", func() -> SphereMesh:
		var m := SphereMesh.new()
		m.radius = 0.04
		m.height = 0.08
		m.radial_segments = 6
		m.rings = 3
		m.material = unshaded(color)
		return m)


## Visage complet d'une expression (yeux + reflets + bouche) fusionné en un
## seul mesh à couleurs de sommets : 1 draw call par fruit au lieu de 5.
## Repère : origine = point avant d'une sphère unité (visage en (0, 0, 1)).
static func face_mesh(mood: int, closed: bool, cfg: JuiceConfig) -> ArrayMesh:
	return _cached("face_%d_%d" % [mood, int(closed)], _build_face.bind(mood, closed, cfg))


static func _build_face(mood: int, closed: bool, cfg: JuiceConfig) -> ArrayMesh:
	var eye_scale := Vector3.ONE
	var highlights := true
	if closed:
		eye_scale = Vector3(1.2, 0.15, 1.0)
		highlights = false
	elif mood == FruitFace.Mood.SQUASHED:
		eye_scale = Vector3(1.15, 0.3, 1.0)
		highlights = false
	elif mood == FruitFace.Mood.FEAR:
		eye_scale = Vector3(1.25, 1.3, 1.0)
	var ex := 0.33
	var ey := 0.15
	var ez := sqrt(1.0 - ex * ex - ey * ey) - 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var eye_xf := Transform3D(Basis.from_scale(eye_scale), Vector3(ex * side, ey, ez))
		_append(st, eye_mesh(cfg.eye_color), eye_xf, cfg.eye_color)
		if highlights:
			_append(st, eye_highlight_mesh(cfg.eye_highlight_color),
				eye_xf * Transform3D(Basis.IDENTITY, Vector3(0.035, 0.045, 0.1)), cfg.eye_highlight_color)
	_append(st, mouth_mesh(mood, cfg.mouth_color), Transform3D(Basis.IDENTITY, Vector3(0, -0.28, 0)),
		cfg.mouth_color)
	var m := st.commit()
	m.surface_set_material(0, _face_material())
	return m


## Ajoute les triangles de `src` (surface 0) transformés, en couleur unie.
static func _append(st: SurfaceTool, src: Mesh, xf: Transform3D, color: Color) -> void:
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx = arrays[Mesh.ARRAY_INDEX]
	st.set_color(color)
	if idx != null and idx.size() > 0:
		for i in idx:
			st.add_vertex(xf * verts[i])
	else:
		for v in verts:
			st.add_vertex(xf * v)


static func _face_material() -> StandardMaterial3D:
	return _cached("face_mat", func() -> StandardMaterial3D:
		var mat := unshaded(Color.WHITE, true)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return mat)


## Bouches (plan XY, visage de rayon 1) : polyline épaisse ou forme pleine.
static func mouth_mesh(mood: int, color: Color) -> ArrayMesh:
	return _cached("mouth_%d" % mood, _build_mouth.bind(mood, color))


static func _build_mouth(mood: int, color: Color) -> ArrayMesh:
	var pts := PackedVector2Array()
	match mood:
		FruitFace.Mood.NEUTRAL:  # sourire
			for i in 9:
				var a := PI + PI * i / 8.0
				pts.append(Vector2(cos(a) * 0.2, sin(a) * 0.11))
			return _polyline(pts, 0.05, color)
		FruitFace.Mood.SQUASHED:  # grimace en zigzag
			for i in 7:
				pts.append(Vector2(-0.21 + 0.07 * i, 0.04 if i % 2 == 0 else -0.04))
			return _polyline(pts, 0.045, color)
		FruitFace.Mood.FEAR:  # petit « o »
			for i in 13:
				var a := TAU * i / 12.0
				pts.append(Vector2(cos(a) * 0.06, sin(a) * 0.08))
			return _polyline(pts, 0.04, color)
		_:  # JOIE : grande bouche ouverte (demi-disque plein)
			return _half_disc(0.17, 0.15, color)


static func _polyline(pts: PackedVector2Array, width: float, color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(color)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := (b - a).orthogonal().normalized() * width * 0.5
		var q := [a + n, b + n, b - n, a - n]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(Vector3(q[idx].x, q[idx].y, 0.0))
		# Rond aux jointures (évite les trous dans les coudes)
		for k in 6:
			var c0 := b + Vector2.from_angle(TAU * k / 6.0) * width * 0.5
			var c1 := b + Vector2.from_angle(TAU * (k + 1) / 6.0) * width * 0.5
			st.add_vertex(Vector3(b.x, b.y, 0.0))
			st.add_vertex(Vector3(c0.x, c0.y, 0.0))
			st.add_vertex(Vector3(c1.x, c1.y, 0.0))
	var m := st.commit()
	m.surface_set_material(0, _mouth_material(color))
	return m


static func _half_disc(rx: float, ry: float, color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 10
	for i in steps:
		var a0 := PI + PI * i / float(steps)
		var a1 := PI + PI * (i + 1) / float(steps)
		st.add_vertex(Vector3(0, 0.03, 0))
		st.add_vertex(Vector3(cos(a0) * rx, sin(a0) * ry + 0.03, 0))
		st.add_vertex(Vector3(cos(a1) * rx, sin(a1) * ry + 0.03, 0))
	var m := st.commit()
	m.surface_set_material(0, _mouth_material(color))
	return m


static func _mouth_material(color: Color) -> StandardMaterial3D:
	return _cached("mouth_mat", func() -> StandardMaterial3D:
		var mat := unshaded(color)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return mat)


## Applique `xform` aux sommets d'un PrimitiveMesh (ex. pièce face caméra).
static func transformed(src: PrimitiveMesh, xform: Transform3D) -> ArrayMesh:
	var arrays := src.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] = xform * verts[i]
		normals[i] = (xform.basis * normals[i]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


## Mesh d'une particule selon sa forme (taille 1 → mis à l'échelle par mesh_size).
static func particle_mesh(shape: int, size: float) -> Mesh:
	var mat := unshaded(Color.WHITE, true)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh: Mesh
	match shape:
		ParticleSettings.Shape.LEAF:
			var s := SphereMesh.new()
			s.radius = size
			s.height = size * 2.0
			s.radial_segments = 6
			s.rings = 3
			mesh = transformed(s, Transform3D(Basis.from_scale(Vector3(1.0, 0.45, 0.15))
				.rotated(Vector3.BACK, 0.6), Vector3.ZERO))
		ParticleSettings.Shape.COIN:
			var c := CylinderMesh.new()
			c.top_radius = size
			c.bottom_radius = size
			c.height = size * 0.25
			c.radial_segments = 10
			c.rings = 1
			mesh = transformed(c, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
		_:
			var sp := SphereMesh.new()
			sp.radius = size
			sp.height = size * 2.0
			sp.radial_segments = 6
			sp.rings = 3
			mesh = sp
	mesh.surface_set_material(0, mat)
	return mesh


static func additive_material(color: Color, falloff: int = 0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ADDITIVE_SHADER
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("falloff", falloff)
	return m
