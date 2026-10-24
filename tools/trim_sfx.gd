extends SceneTree
## Convertit les sons MP3 fournis en WAV sans silence de tête (déclenchement
## immédiat) : chaque son est rejoué dans un bus muni d'AudioEffectRecord,
## enregistré, puis rogné au premier échantillon audible.
## Lecture en temps réel : lancer avec un pilote audio (pas --headless).
## Usage : Godot --path . -s tools/trim_sfx.gd

const NAMES := ["ui_click", "play", "merge", "powerup", "coins", "drop"]
const DIR := "res://assets/sfx/"
## Seuil d'audibilité (amplitude, 0..1) et marge gardée avant l'attaque (s).
const THRESHOLD := 0.02
const PRE_ROLL := 0.005
## Fin : silence final coupé aussi (gain de place, pas de queue muette).
const TAIL_PAD := 0.05
## Seuil plus bas pour la fin (garde la résonance naturelle).
const TAIL_THRESHOLD := 0.002


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var bus := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, "TrimRecord")
	var rec := AudioEffectRecord.new()
	rec.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(bus, rec)
	var player := AudioStreamPlayer.new()
	player.bus = "TrimRecord"
	root.add_child(player)
	for n in NAMES:
		var src: AudioStream = load(DIR + n + ".mp3")
		if src == null:
			continue
		rec.set_recording_active(true)
		player.stream = src
		player.play()
		await create_timer(src.get_length() + 0.3).timeout
		player.stop()
		rec.set_recording_active(false)
		var wav := rec.get_recording()
		var lead := _trim(wav)
		wav.save_to_wav(ProjectSettings.globalize_path(DIR + n + ".wav"))
		print("SFX %s : silence de tête %.0f ms, durée %.2f s" % [n, lead * 1000.0, wav.get_length()])
	quit()


## Rogne le silence de tête et de fin ; renvoie le silence de tête retiré (s).
func _trim(wav: AudioStreamWAV) -> float:
	var data := wav.data
	var ch := 2 if wav.stereo else 1
	var frame_bytes := 2 * ch
	var frames := data.size() / frame_bytes
	var first := 0
	var last := frames - 1
	while first < frames and _peak(data, first, ch) < THRESHOLD:
		first += 1
	while last > first and _peak(data, last, ch) < TAIL_THRESHOLD:
		last -= 1
	var rate := float(wav.mix_rate)
	var start := maxi(first - int(PRE_ROLL * rate), 0)
	var end := mini(last + int(TAIL_PAD * rate), frames - 1)
	wav.data = data.slice(start * frame_bytes, (end + 1) * frame_bytes)
	return start / rate


func _peak(data: PackedByteArray, frame: int, ch: int) -> float:
	var m := 0.0
	for c in ch:
		m = maxf(m, absf(data.decode_s16((frame * ch + c) * 2) / 32768.0))
	return m
