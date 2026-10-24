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
## Musique : morceaux enchaînés + piste de tension en fondu (M4).
var _playlist: Array[AudioStream] = []
var _track: int = 0
var _tension: AudioStreamPlayer
var _tension_stream: AudioStream
var _tension_target: float = 0.0
var _tension_level: float = 0.0
var _fade_time: float = 1.5
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
	_tension = AudioStreamPlayer.new()
	_tension.bus = BUS_MUSIC
	_tension.finished.connect(func() -> void: _tension.play())
	add_child(_tension)
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
	_playlist.clear()
	_music.stream = stream
	_music.play()


## Morceaux enchaînés en alternance (sans boucle brute) ; `tension` : piste
## mise en fondu enchaîné par set_tension(). Sans effet si déjà en cours.
func play_music_playlist(tracks: Array[AudioStream], tension: AudioStream = null,
		fade_time: float = 1.5) -> void:
	_tension_stream = tension
	_fade_time = maxf(fade_time, 0.05)
	if tracks.is_empty() or (_music.playing and _playlist == tracks):
		return
	_playlist = tracks.duplicate()
	_track = 0
	_music.stream = _playlist[0]
	_music.play()


## true : la piste de tension prend le dessus (fondu), false : retour au calme.
func set_tension(on: bool) -> void:
	_tension_target = 1.0 if on and _tension_stream else 0.0


func tension_level() -> float:
	return _tension_level


func stop_music() -> void:
	_music.stop()
	_tension.stop()
	_tension_level = 0.0
	_tension_target = 0.0


func _on_music_finished() -> void:
	if not _playlist.is_empty():
		_track = (_track + 1) % _playlist.size()
		_music.stream = _playlist[_track]
	_music.play()


func _process(delta: float) -> void:
	if is_equal_approx(_tension_level, _tension_target):
		return
	_tension_level = move_toward(_tension_level, _tension_target, delta / _fade_time)
	if _tension_level > 0.0 and not _tension.playing and _tension_stream:
		_tension.stream = _tension_stream
		_tension.play()
	# Fondu à puissance constante (pas de creux au milieu du fondu).
	_music.volume_db = linear_to_db(maxf(cos(_tension_level * PI * 0.5), 0.0001))
	_tension.volume_db = linear_to_db(maxf(sin(_tension_level * PI * 0.5), 0.0001))
	if _tension_level <= 0.0:
		_tension.stop()


## 0 = musique claire, 1 = étouffée (danger maximal). Interpolation exponentielle.
func set_danger_filter(ratio: float) -> void:
	var r := clampf(ratio, 0.0, 1.0)
	_lowpass.cutoff_hz = config.lowpass_max_hz * pow(config.lowpass_min_hz / config.lowpass_max_hz, r)


func lowpass_cutoff() -> float:
	return _lowpass.cutoff_hz


func stop_all_sfx() -> void:
	for p in _players:
		p.stop()
