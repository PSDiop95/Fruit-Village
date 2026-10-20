extends Node
## Audio : bus Master / Music / SFX, pool de lecteurs SFX (zéro instanciation
## en jeu), musique en boucle, passe-bas « danger » sur le bus Music.
## Ne connaît aucune règle de jeu : Juice lui dit quoi jouer.

const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"

var config: JuiceConfig = preload("res://data/juice.tres")

## Nombre de lecteurs créés (tests : doit rester constant après le préchauffage).
var created_players: int = 0

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _music: AudioStreamPlayer
var _lowpass: AudioEffectLowPassFilter
var _rng := RandomNumberGenerator.new()
var _rate: Dictionary = {}  # clé -> PackedFloat64Array (instants des derniers sons, s)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_music = AudioStreamPlayer.new()
	_music.bus = BUS_MUSIC
	_music.finished.connect(_on_music_finished)
	add_child(_music)
	prewarm(config.sfx_pool_size)
	apply_volumes()
	SaveManager.setting_changed.connect(func(_k: StringName, _v: Variant) -> void: apply_volumes())


func _ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, &"Master")
	var mi := AudioServer.get_bus_index(BUS_MUSIC)
	for e in AudioServer.get_bus_effect_count(mi):
		if AudioServer.get_bus_effect(mi, e) is AudioEffectLowPassFilter:
			_lowpass = AudioServer.get_bus_effect(mi, e)
	if _lowpass == null:
		_lowpass = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(mi, _lowpass)
	_lowpass.cutoff_hz = config.lowpass_max_hz


func prewarm(count: int) -> void:
	while _players.size() < count:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		_players.append(p)
		created_players += 1


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, config.master_volume_db)
	var mi := AudioServer.get_bus_index(BUS_MUSIC)
	var si := AudioServer.get_bus_index(BUS_SFX)
	AudioServer.set_bus_volume_db(mi, config.music_volume_db)
	AudioServer.set_bus_volume_db(si, config.sfx_volume_db)
	AudioServer.set_bus_mute(mi, not SaveManager.get_setting(&"music_on"))
	AudioServer.set_bus_mute(si, not SaveManager.get_setting(&"sfx_on"))


## Joue un SFX. `jitter` : variation de hauteur aléatoire ± (sons répétés).
func play(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0,
		jitter: float = 0.0) -> AudioStreamPlayer:
	if stream == null or _players.is_empty():
		return null
	var p := _take_player()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(pitch * (1.0 + _rng.randf_range(-jitter, jitter)), 0.01)
	p.play()
	return p


## Comme play(), mais au plus `max_per_second` sons pour cette `key`.
func play_limited(key: StringName, max_per_second: int, stream: AudioStream,
		volume_db: float = 0.0, pitch: float = 1.0, jitter: float = 0.0) -> AudioStreamPlayer:
	var now := Time.get_ticks_msec() / 1000.0
	var times: PackedFloat64Array = _rate.get(key, PackedFloat64Array())
	var kept := PackedFloat64Array()
	for t in times:
		if now - t < 1.0:
			kept.append(t)
	if kept.size() >= max_per_second:
		_rate[key] = kept
		return null
	kept.append(now)
	_rate[key] = kept
	return play(stream, volume_db, pitch, jitter)


## Lecteur libre, sinon on vole le plus ancien (jamais de nouvelle instance).
func _take_player() -> AudioStreamPlayer:
	for i in _players.size():
		var p := _players[(_next_player + i) % _players.size()]
		if not p.playing:
			_next_player = (_next_player + i + 1) % _players.size()
			return p
	var stolen := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	stolen.stop()
	return stolen


func play_music(stream: AudioStream) -> void:
	if stream == null or (_music.playing and _music.stream == stream):
		return
	_music.stream = stream
	_music.play()


func stop_music() -> void:
	_music.stop()


func _on_music_finished() -> void:
	_music.play()


## 0 = musique claire, 1 = étouffée (danger maximal). Interpolation exponentielle.
func set_danger_filter(ratio: float) -> void:
	var r := clampf(ratio, 0.0, 1.0)
	_lowpass.cutoff_hz = config.lowpass_max_hz * pow(config.lowpass_min_hz / config.lowpass_max_hz, r)


func lowpass_cutoff() -> float:
	return _lowpass.cutoff_hz


func stop_all_sfx() -> void:
	for p in _players:
		p.stop()
