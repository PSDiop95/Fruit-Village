class_name FxItems
extends RefCounted
## Petits effets poolés (onde, texte flottant). Chacun expose tick(delta) -> bool.


## Anneau d'onde qui s'élargit et s'efface.
class Ring extends MeshInstance3D:
	var duration: float = 0.35
	var max_scale: float = 2.4
	var _t: float = 1.0
	var _base: float = 1.0
	var _mat: StandardMaterial3D
	var _color: Color

	func _init(color: Color) -> void:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.86
		torus.outer_radius = 1.0
		torus.rings = 24
		torus.ring_segments = 4
		mesh = FxMeshes.transformed(torus, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO))
		_color = color
		_mat = FxMeshes.unshaded(Color(color, color.a * 0.999))
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material_override = _mat
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func start(pos: Vector3, radius: float, color: Color) -> void:
		global_position = pos
		_base = radius
		_t = 0.0
		_color = color
		scale = Vector3.ONE * radius

	func tick(delta: float) -> bool:
		_t += delta / duration
		var u := clampf(_t, 0.0, 1.0)
		var e := 1.0 - (1.0 - u) * (1.0 - u)
		scale = Vector3.ONE * _base * lerpf(1.0, max_scale, e)
		_mat.albedo_color = Color(_color, _color.a * (1.0 - u))
		return _t < 1.0


## Éclair de fusion : halo radial additif qui jaillit puis s'éteint, avec une
## croix d'étincelle (2 quads fins) qui tourne. Déclenche le glow.
class Flash extends Node3D:
	var duration: float = 0.22
	var max_scale: float = 3.2
	var _t: float = 1.0
	var _base: float = 1.0
	var _halo: MeshInstance3D
	var _cross: MeshInstance3D
	var _halo_mat: ShaderMaterial
	var _cross_mat: ShaderMaterial

	func _init(color: Color) -> void:
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		_halo = MeshInstance3D.new()
		_halo.mesh = q
		_halo_mat = FxMeshes.additive_material(color, 2)
		_halo.material_override = _halo_mat
		_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_halo)
		# Croix : deux bandes fines, dégradé radial (pointes effilées)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for rot in [0.0, PI * 0.5]:
			var b := Basis(Vector3.BACK, rot)
			var c := [Vector3(-0.5, -0.04, 0), Vector3(0.5, -0.04, 0), Vector3(0.5, 0.04, 0), Vector3(-0.5, 0.04, 0)]
			var uv := [Vector2(0, 0.42), Vector2(1, 0.42), Vector2(1, 0.58), Vector2(0, 0.58)]
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_uv(uv[i])
				st.add_vertex(b * c[i])
		_cross = MeshInstance3D.new()
		_cross.mesh = st.commit()
		_cross_mat = FxMeshes.additive_material(Color(1, 1, 0.9, 1), 2)
		_cross.material_override = _cross_mat
		_cross.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_cross)
		visible = false

	func start(pos: Vector3, radius: float) -> void:
		global_position = pos
		_base = radius
		_t = 0.0
		visible = true
		tick(0.0)

	func tick(delta: float) -> bool:
		_t += delta / duration
		var u := clampf(_t, 0.0, 1.0)
		var grow := 1.0 - pow(1.0 - u, 3.0)
		var a := 1.0 - u
		_halo.scale = Vector3.ONE * _base * lerpf(0.6, max_scale, grow)
		_halo_mat.set_shader_parameter("alpha", a)
		_cross.scale = Vector3.ONE * _base * lerpf(1.0, max_scale * 1.3, grow)
		_cross.rotation.z = u * 0.8
		_cross_mat.set_shader_parameter("alpha", a * a)
		visible = _t < 1.0
		return _t < 1.0


## Texte flottant « +28 » : monte, rebondit, s'efface.
class FloatText extends Label3D:
	var duration: float = 0.9
	var rise: float = 1.3
	var _t: float = 1.0
	var _origin := Vector3.ZERO
	var _size: float = 1.0

	func _init(font_px: int, color: Color, outline: Color) -> void:
		font_size = font_px
		pixel_size = 0.004
		outline_size = 18
		modulate = color
		outline_modulate = outline
		no_depth_test = true
		render_priority = 10
		outline_render_priority = 9
		double_sided = true
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	func start(pos: Vector3, txt: String, color: Color, size_mult: float) -> void:
		_origin = pos
		global_position = pos
		text = txt
		modulate = color
		_size = size_mult
		scale = Vector3.ONE * size_mult
		_t = 0.0

	func tick(delta: float) -> bool:
		_t += delta / duration
		var u := clampf(_t, 0.0, 1.0)
		# Montée rapide puis ralentie, rebond d'échelle à l'apparition.
		var rise_k := 1.0 - pow(1.0 - u, 3.0)
		global_position = _origin + Vector3(0, rise * rise_k, 0)
		var pop := 1.0 + 0.35 * sin(u / 0.25 * PI) if u < 0.25 else 1.0
		scale = Vector3.ONE * _size * pop
		modulate.a = 1.0 if u < 0.6 else 1.0 - (u - 0.6) / 0.4
		outline_modulate.a = modulate.a
		return _t < 1.0
