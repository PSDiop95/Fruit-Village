class_name ParticleBurst
extends Node3D
## Gerbe de particules one-shot poolée. GPUParticles3D, ou CPUParticles3D en
## repli (renderer Compatibility / headless).

var settings: ParticleSettings
var use_gpu: bool = true

var _gpu: GPUParticles3D
var _gpu_mat: ParticleProcessMaterial
var _cpu: CPUParticles3D
var _life: float = 0.0


static func gpu_supported() -> bool:
	return DisplayServer.get_name() != "headless" \
		and RenderingServer.get_current_rendering_method() != "gl_compatibility"


func build(s: ParticleSettings, gpu: bool) -> void:
	settings = s
	use_gpu = gpu
	var mesh := FxMeshes.particle_mesh(s.shape, s.mesh_size)
	if gpu:
		_gpu = GPUParticles3D.new()
		_gpu.one_shot = true
		_gpu.emitting = false
		_gpu.local_coords = false
		_gpu.explosiveness = s.explosiveness
		_gpu.lifetime = s.lifetime
		_gpu.amount = maxi(s.amount, 1)
		_gpu.draw_pass_1 = mesh
		_gpu.visibility_aabb = AABB(Vector3(-8, -12, -2), Vector3(16, 24, 4))
		_gpu_mat = ParticleProcessMaterial.new()
		_gpu_mat.direction = s.direction
		_gpu_mat.spread = s.spread_deg
		_gpu_mat.initial_velocity_min = s.speed_min
		_gpu_mat.initial_velocity_max = s.speed_max
		_gpu_mat.gravity = s.gravity
		_gpu_mat.scale_min = s.size_min
		_gpu_mat.scale_max = s.size_max
		_gpu_mat.angle_min = -180.0
		_gpu_mat.angle_max = 180.0
		_gpu_mat.angular_velocity_min = -360.0
		_gpu_mat.angular_velocity_max = 360.0
		_gpu_mat.particle_flag_rotate_y = false
		_gpu_mat.scale_curve = _shrink_texture()
		if s.emission_box != Vector3.ZERO:
			_gpu_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			_gpu_mat.emission_box_extents = s.emission_box
		if not s.colors.is_empty():
			var tex := GradientTexture1D.new()
			tex.gradient = _palette_gradient(s.colors)
			_gpu_mat.color_initial_ramp = tex
		_gpu.process_material = _gpu_mat
		add_child(_gpu)
	else:
		_cpu = CPUParticles3D.new()
		_cpu.one_shot = true
		_cpu.emitting = false
		_cpu.local_coords = false
		_cpu.explosiveness = s.explosiveness
		_cpu.lifetime = s.lifetime
		_cpu.amount = maxi(s.amount, 1)
		_cpu.mesh = mesh
		_cpu.direction = s.direction
		_cpu.spread = s.spread_deg
		_cpu.initial_velocity_min = s.speed_min
		_cpu.initial_velocity_max = s.speed_max
		_cpu.gravity = s.gravity
		_cpu.scale_amount_min = s.size_min
		_cpu.scale_amount_max = s.size_max
		_cpu.angle_min = -180.0
		_cpu.angle_max = 180.0
		_cpu.scale_amount_curve = _shrink_curve()
		if s.emission_box != Vector3.ZERO:
			_cpu.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			_cpu.emission_box_extents = s.emission_box
		if not s.colors.is_empty():
			_cpu.color_initial_ramp = _palette_gradient(s.colors)
		add_child(_cpu)


## Applique un multiplicateur de quantité (qualité / effets réduits).
## Réalloue les buffers : à n'appeler qu'au changement de réglage, jamais par gerbe.
func set_amount_scale(k: float) -> void:
	var n := maxi(int(ceil(settings.amount * k)), 1)
	if _gpu and _gpu.amount != n:
		_gpu.amount = n
	if _cpu and _cpu.amount != n:
		_cpu.amount = n


func amount() -> int:
	return _gpu.amount if _gpu else _cpu.amount


func burst(pos: Vector3, color: Color = Color.WHITE) -> void:
	global_position = pos
	_life = settings.lifetime + 0.1
	if _gpu:
		if settings.colors.is_empty():
			_gpu_mat.color = color
		_gpu.restart()
	else:
		if settings.colors.is_empty():
			_cpu.color = color
		_cpu.restart()


func tick(delta: float) -> bool:
	_life -= delta
	return _life > 0.0


func _shrink_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(0.7, 0.8))
	c.add_point(Vector2(1.0, 0.0))
	return c


func _shrink_texture() -> CurveTexture:
	var t := CurveTexture.new()
	t.curve = _shrink_curve()
	return t


static func _palette_gradient(colors: PackedColorArray) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offsets := PackedFloat32Array()
	for i in colors.size():
		offsets.append(float(i) / colors.size())
	g.offsets = offsets
	g.colors = colors
	return g
