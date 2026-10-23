class_name Mascot
extends Node3D
## Mascotte : petit singe assis sur le coin du cadre du panier. Purement
## visuel : n'écoute que les signaux de Game (aucune logique de jeu ici).
## Réactions : regarde la visée, hoche la tête au lâcher, fait la fête sur les
## gros combos / grosses fusions, danse au Baobab, s'étonne d'un nouveau
## fruit, a peur près de la ligne, boude au game over.
## Réglages : groupe « Mascotte » de data/visual.tres.

enum Mood { IDLE, CHEER, PARTY, SURPRISE, FEAR, SAD }

var config: VisualConfig
var mood: Mood = Mood.IDLE

var _juice_cfg: JuiceConfig
var _game: Game
var _model: Node3D
var _parts: Dictionary = {}  # nom -> Node3D
var _meshes: Array[MeshInstance3D] = []
var _plain_material: ShaderMaterial
var _face: MeshInstance3D
var _face_key: String = ""
var _t: float = 0.0
var _mood_t: float = 0.0
var _mood_len: float = 0.0
var _intensity: float = 1.0
var _nod_t: float = 1.0
var _fear: bool = false
var _over: bool = false
var _blink_left: float = 3.0
var _blink_t: float = 1.0
# Pose courante (lissée vers la pose cible)
var _pose: Dictionary = {}


## Crée la mascotte si le modèle existe (null sinon).
static func create(cfg: VisualConfig, juice_cfg: JuiceConfig) -> Mascot:
	if cfg.mascot_model.is_empty() or not ResourceLoader.exists(cfg.mascot_model):
		return null
	var m := Mascot.new()
	m.name = "Mascot"
	m.config = cfg
	m._juice_cfg = juice_cfg
	m._build()
	return m


func _build() -> void:
	_model = (load(config.mascot_model) as PackedScene).instantiate() as Node3D
	add_child(_model)
	position = config.mascot_position
	scale = Vector3.ONE * config.mascot_scale
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.set_instance_shader_parameter(&"outline_radial", 0.0)
		_meshes.append(m)
	apply_quality(FruitModels.quality)
	for part in ["head", "arm_l", "arm_r", "leg_l", "leg_r", "tail"]:
		var n := _model.find_child(part, true, false) as Node3D
		if n:
			_parts[part] = n
	_face = MeshInstance3D.new()
	_face.name = "Face"
	_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face.position = config.mascot_face_offset
	_face.scale = Vector3.ONE * config.mascot_face_scale
	var head: Node3D = _parts.get("head", _model)
	head.add_child(_face)
	_set_face(FruitFace.Mood.NEUTRAL, false)


## Matériau toon des fruits ; sans contour sous mascot_outline_min_quality.
func apply_quality(level: int) -> void:
	var mat := FruitModels.fruit_material()
	if level < config.mascot_outline_min_quality:
		_plain_material = mat.duplicate() as ShaderMaterial
		_plain_material.next_pass = null
		mat = _plain_material
	for m in _meshes:
		m.material_override = mat


func bind(game: Game) -> void:
	_game = game
	game.dropped.connect(func(_f: Fruit) -> void: _nod_t = 0.0)
	game.merged.connect(_on_merged)
	game.top_merge.connect(func(_p: Vector3) -> void: react(Mood.PARTY))
	game.fruit_discovered.connect(func(rank: int) -> void:
		if rank > SaveManager.best_rank:
			react(Mood.SURPRISE))
	game.danger_changed.connect(func(_r: float, state: DangerMonitor.State) -> void:
		_fear = state != DangerMonitor.State.SAFE)
	game.game_over.connect(func(_s: int, _m: int, _r: bool) -> void:
		_over = true
		mood = Mood.SAD)


func _on_merged(rank_created: int, _pos: Vector3, _points: int, combo: int) -> void:
	if combo >= config.mascot_cheer_combo or rank_created >= config.mascot_cheer_rank:
		react(Mood.CHEER, 1.0 + 0.2 * maxi(combo - config.mascot_cheer_combo, 0))


## Déclenche une réaction minutée (ignorée si une réaction plus forte joue).
func react(m: Mood, intensity: float = 1.0) -> void:
	if _over:
		return
	if mood == Mood.PARTY and m != Mood.PARTY and _mood_t < _mood_len:
		return
	mood = m
	_mood_t = 0.0
	_intensity = minf(intensity, 2.0)
	match m:
		Mood.CHEER: _mood_len = config.mascot_cheer_time
		Mood.PARTY: _mood_len = config.mascot_party_time
		Mood.SURPRISE: _mood_len = config.mascot_surprise_time
		_: _mood_len = 0.0


## Humeur effective (réaction minutée, sinon peur, sinon repos).
func current_mood() -> Mood:
	if _over:
		return Mood.SAD
	if mood in [Mood.CHEER, Mood.PARTY, Mood.SURPRISE] and _mood_t < _mood_len:
		return mood
	return Mood.FEAR if _fear else Mood.IDLE


func _process(delta: float) -> void:
	# Temps réel : la mascotte ne fige pas pendant le hit-stop.
	var dt := clampf(delta / maxf(Engine.time_scale, 0.0001), 0.0, 0.1)
	_t += dt
	_mood_t += dt
	_nod_t += dt / maxf(config.mascot_nod_time, 0.01)
	var m := current_mood()
	var target := _target_pose(m)
	var k := 1.0 - exp(-config.mascot_smoothing * dt)
	for key in target:
		_pose[key] = lerpf(_pose.get(key, 0.0), target[key], k)
	_apply_pose()
	_update_face(m, dt)


## Pose cible : angles (rad) et décalages (m, repère du modèle).
func _target_pose(m: Mood) -> Dictionary:
	var t := _t
	var p := {
		"y": 0.0, "x": 0.0, "spin": 0.0, "lean": 0.0, "breath": sin(t * 2.2) * 0.02,
		"head_x": 0.0, "head_y": 0.0, "head_z": sin(t * 0.9) * 0.08,
		"arm_l": 0.15, "arm_r": 0.15, "arm_fwd": 0.0,
		"leg_l": sin(t * 2.4) * 0.25, "leg_r": -sin(t * 2.4) * 0.25,
		"tail": sin(t * 1.7) * 0.25,
	}
	# Regard vers la visée (repos et peur)
	if _game and is_instance_valid(_game):
		var aim := _game.aim_x() - global_position.x
		p.head_y = clampf(aim * config.mascot_look, -0.6, 0.6)
	if _nod_t < 1.0:
		p.head_x = sin(_nod_t * PI) * 0.25
	var u := clampf(_mood_t / maxf(_mood_len, 0.01), 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.75, 1.0, u)
	match m:
		Mood.CHEER:
			var hop := absf(sin(_mood_t * 9.0)) * config.mascot_jump * _intensity * fade
			p.y = hop
			p.arm_l = config.mascot_arm_raise * fade + sin(_mood_t * 16.0) * 0.3
			p.arm_r = config.mascot_arm_raise * fade - sin(_mood_t * 16.0) * 0.3
			p.leg_l = sin(_mood_t * 18.0) * 0.7
			p.leg_r = -sin(_mood_t * 18.0) * 0.7
			p.head_z = sin(_mood_t * 9.0) * 0.18
			p.tail = sin(_mood_t * 12.0) * 0.6
		Mood.PARTY:
			p.y = absf(sin(_mood_t * 7.0)) * config.mascot_jump * 2.2 * fade
			p.spin = TAU * smoothstep(0.0, 0.28, u)
			p.arm_l = config.mascot_arm_raise + sin(_mood_t * 14.0) * 0.4
			p.arm_r = config.mascot_arm_raise - sin(_mood_t * 14.0) * 0.4
			p.leg_l = sin(_mood_t * 20.0) * 0.8
			p.leg_r = -sin(_mood_t * 20.0) * 0.8
			p.head_z = sin(_mood_t * 7.0) * 0.25
			p.tail = sin(_mood_t * 14.0) * 0.8
		Mood.SURPRISE:
			p.y = sin(clampf(u * 3.0, 0.0, 1.0) * PI) * config.mascot_jump
			p.head_x = -0.3 * fade
			p.arm_l = 1.4 * fade
			p.arm_r = 1.4 * fade
			p.tail = 0.6 * fade
		Mood.FEAR:
			p.x = sin(t * 40.0) * 0.015
			p.arm_l = 2.6
			p.arm_r = 2.6
			p.arm_fwd = -0.5
			p.head_x = 0.15
			p.leg_l = 0.5
			p.leg_r = 0.5
			p.tail = 0.9
		Mood.SAD:
			p.head_x = 0.45
			p.head_y = 0.0
			p.head_z = 0.12
			p.arm_l = -0.05
			p.arm_r = -0.05
			p.leg_l = 0.0
			p.leg_r = 0.0
			p.lean = 0.12
			p.breath = sin(t * 1.2) * 0.015
			p.tail = -0.3
	return p


func _apply_pose() -> void:
	_model.position = Vector3(_pose.x, _pose.y, 0)
	# Assis sur le cadre : suit son écrasement (unités du modèle).
	if _game and is_instance_valid(_game) and _game.market():
		_model.position.y -= _game.market().frame_top_drop() / maxf(scale.y, 0.01)
	_model.rotation = Vector3(_pose.lean, _pose.spin, 0)
	_model.scale = Vector3(1.0 - _pose.breath * 0.5, 1.0 + _pose.breath, 1.0)
	_rot("head", Vector3(_pose.head_x, _pose.head_y, _pose.head_z))
	# Bras : rotation dans le plan de l'écran (gauche vers -Z, droit vers +Z).
	_rot("arm_l", Vector3(_pose.arm_fwd, 0, -_pose.arm_l))
	_rot("arm_r", Vector3(_pose.arm_fwd, 0, _pose.arm_r))
	_rot("leg_l", Vector3(_pose.leg_l, 0, 0))
	_rot("leg_r", Vector3(_pose.leg_r, 0, 0))
	_rot("tail", Vector3(0, 0, _pose.tail))


func _rot(part: String, r: Vector3) -> void:
	var n: Node3D = _parts.get(part)
	if n:
		n.rotation = r


func _update_face(m: Mood, dt: float) -> void:
	_blink_left -= dt
	if _blink_left <= 0.0:
		_blink_left = randf_range(2.0, 5.0)
		_blink_t = 0.0
	_blink_t += dt
	var closed := _blink_t < 0.12
	var face := FruitFace.Mood.NEUTRAL
	match m:
		Mood.CHEER, Mood.PARTY:
			face = FruitFace.Mood.JOY
		Mood.SURPRISE:
			face = FruitFace.Mood.FEAR if _mood_t < _mood_len * 0.4 else FruitFace.Mood.JOY
		Mood.FEAR:
			face = FruitFace.Mood.FEAR
		Mood.SAD:
			face = FruitFace.Mood.SQUASHED
	if face == FruitFace.Mood.JOY:
		closed = true  # yeux plissés de joie
	_set_face(face, closed)


func _set_face(face: int, closed: bool) -> void:
	var key := "%d_%d" % [face, int(closed)]
	if key == _face_key:
		return
	_face_key = key
	_face.mesh = FxMeshes.face_mesh(face, closed, _juice_cfg)
