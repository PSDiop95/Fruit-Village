class_name SoundBank
extends Resource
## Mapping unique événement → son. Remplacer les placeholders ici suffit
## pour brancher les vrais sons (aucun chemin de fichier ailleurs dans le code).

@export var drop: AudioStream
@export var impact: AudioStream
## Une note par rang de fruit CRÉÉ (index = rang). Rang élevé = note plus aiguë.
@export var merge_notes: Array[AudioStream] = []
@export var combo_chord: AudioStream
@export var discover: AudioStream
@export var baobab: AudioStream
@export var danger_heartbeat: AudioStream
@export var game_over: AudioStream
@export var music: AudioStream


func note_for_rank(rank: int) -> AudioStream:
	if merge_notes.is_empty():
		return null
	return merge_notes[clampi(rank, 0, merge_notes.size() - 1)]
