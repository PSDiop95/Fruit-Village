class_name FestiveLights
extends Node3D
## Lumières des ambiances du soir : guirlandes d'ampoules (fil + ampoules qui
## scintillent, au-dessus du seuil du glow), étoiles et lune la nuit.
## Tout en MultiMesh / quelques meshes : 4 draw calls au plus.

const BULB_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform float energy = 2.2;
uniform float twinkle = 0.25;
uniform float speed = 3.0;
varying float phase;
void vertex() { phase = INSTANCE_CUSTOM.x; }
void fragment() {
	float k = 1.0 - twinkle * (0.5 + 0.5 * sin(TIME * speed + phase * 6.2831));
	ALBEDO = COLOR.rgb * energy * k;
}
"""

const STAR_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled;
varying float phase;
void vertex() { phase = INSTANCE_CUSTOM.x; }
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = (1.0 - smoothstep(0.0, 1.0, d)) * (0.55 + 0.45 * sin(TIME * 2.0 + phase * 6.2831));
	ALBEDO = vec3(1.0, 0.97, 0.85) * a * a * 1.4;
}
"""

var bulbs: MultiMeshInstance3D
var stars: MultiMeshInstance3D


## Construit les lumières de l'ambiance `amb` (rien si elle n'en a pas).
func build(cfg: VisualConfig, amb: AmbianceDef) -> void:
	name = "FestiveLights"
	for c in get_children():
		c.queue_free()
	bulbs = null
	stars = null
	if amb.garlands:
		_build_garlands(cfg, amb)
	if amb.night_stars:
		_build_stars(cfg)
	if amb.moon:
		_build_moon(cfg)


## Points d'un fil (parabole de flèche `sag`), pas ~ `step`.
static func catenary(line: Vector4, sag: float, step: float) -> PackedVector2Array:
	var a := Vector2(line.x, line.y)
	var b := Vector2(line.z, line.w)
	var n := maxi(int(a.distance_to(b) / step), 2)
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t)
		p.y -= sag * 4.0 * t * (1.0 - t)
		pts.append(p)
	return pts


func _build_garlands(cfg: VisualConfig, amb: AmbianceDef) -> void:
	var z := cfg.garland_z
	# Fils : rubans fins face caméra
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var positions: Array[Vector3] = []
	for line in cfg.garland_lines:
		var pts := catenary(line, cfg.garland_sag, 0.1)
		for i in pts.size() - 1:
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var n := (p1 - p0).orthogonal().normalized() * cfg.garland_wire_width * 0.5
			var q := [p0 + n, p1 + n, p1 - n, p0 - n]
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(Vector3(q[k].x, q[k].y, z))
		for p in catenary(line, cfg.garland_sag, cfg.garland_bulb_spacing):
			positions.append(Vector3(p.x, p.y - cfg.garland_bulb_radius * 0.9, z + 0.05))
	var wire := MeshInstance3D.new()
	wire.name = "Wires"
	wire.mesh = st.commit()
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.albedo_color = cfg.garland_wire_color
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	wire.material_override = wm
	wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wire)

	var sphere := SphereMesh.new()
	sphere.radius = cfg.garland_bulb_radius
	sphere.height = cfg.garland_bulb_radius * 2.4  # ampoule un peu allongée
	sphere.radial_segments = 8
	sphere.rings = 4
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BULB_SHADER
	mat.shader = sh
	mat.set_shader_parameter("energy", amb.bulb_energy)
	mat.set_shader_parameter("twinkle", cfg.garland_twinkle)
	mat.set_shader_parameter("speed", cfg.garland_twinkle_speed)
	sphere.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = sphere
	mm.instance_count = positions.size()
	var cols := amb.bulb_colors if not amb.bulb_colors.is_empty() else PackedColorArray([Color.WHITE])
	for i in positions.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, positions[i]))
		mm.set_instance_color(i, cols[i % cols.size()])
		mm.set_instance_custom_data(i, Color(_hash01(i, 1), 0, 0, 0))
	bulbs = MultiMeshInstance3D.new()
	bulbs.name = "Bulbs"
	bulbs.multimesh = mm
	bulbs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulbs)


func _build_stars(cfg: VisualConfig) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = STAR_SHADER
	mat.shader = sh
	q.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = cfg.night_star_count
	var r := cfg.night_star_area
	for i in cfg.night_star_count:
		# Positions déterministes (même ciel à chaque partie).
		var x := lerpf(r.x, r.z, _hash01(i, 2))
		var y := lerpf(r.y, r.w, _hash01(i, 3))
		var s := lerpf(cfg.night_star_size.x, cfg.night_star_size.y, _hash01(i, 4)) * 2.5
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, 1)), Vector3(x, y, cfg.night_sky_z)))
		mm.set_instance_custom_data(i, Color(_hash01(i, 5), 0, 0, 0))
	stars = MultiMeshInstance3D.new()
	stars.name = "Stars"
	stars.multimesh = mm
	stars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stars)


func _build_moon(cfg: VisualConfig) -> void:
	var moon := MeshInstance3D.new()
	moon.name = "Moon"
	var q := QuadMesh.new()
	q.size = Vector2(cfg.moon_radius * 5.0, cfg.moon_radius * 5.0)
	moon.mesh = q
	# Disque net + halo doux (additif, dégradé radial du shader de halo).
	var halo := FxMeshes.additive_material(Color(cfg.moon_color, 0.35), 2)
	moon.material_override = halo
	moon.position = Vector3(cfg.moon_position.x, cfg.moon_position.y, cfg.night_sky_z + 0.2)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)
	var disc := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = cfg.moon_radius
	sm.height = cfg.moon_radius * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	disc.mesh = sm
	disc.material_override = FxMeshes.unshaded(cfg.moon_color * 1.3)
	disc.position = Vector3(cfg.moon_position.x, cfg.moon_position.y, cfg.night_sky_z + 0.4)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)


static func _hash01(i: int, k: int) -> float:
	var h := sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453
	return h - floorf(h)
