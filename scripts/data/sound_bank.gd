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

@export_group("M4 : interface et méta")
## Son de fusion unique, monté d'un demi-ton par rang (gamme montante).
## Vide : notes par rang (merge_notes).
@export var merge: AudioStream
@export var ui_click: AudioStream
## Lancement d'une partie (Jouer, Rejouer).
@export var play: AudioStream
@export var powerup: AudioStream
## Pièces gagnées.
@export var coins: AudioStream

@export_group("Musique")
## Morceaux de fond joués en alternance (enchaînés, pas de boucle brute).
## Vide : `music` en boucle.
@export var music_tracks: Array[AudioStream] = []
## Piste de tension (panier presque plein), en fondu enchaîné.
@export var music_tension: AudioStream

@export_group("Voix de la vendeuse")
@export var voice_waaw: AudioStream
@export var voice_wooy: AudioStream
@export var voice_good: AudioStream
@export var voice_dafa_neex: AudioStream
@export var voice_cest_doux: AudioStream
@export var voice_ca_cest_fort: AudioStream
@export var voice_gaaw: AudioStream


func note_for_rank(rank: int) -> AudioStream:
	if merge_notes.is_empty():
		return null
	return merge_notes[clampi(rank, 0, merge_notes.size() - 1)]
