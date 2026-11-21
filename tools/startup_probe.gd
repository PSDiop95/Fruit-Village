extends SceneTree
## V2-0 : temps de démarrage jusqu'à l'écran titre (rendu réel, fenêtré).
## Usage : Godot --path . --resolution 540x960 -s tools/startup_probe.gd
## Affiche « STARTUP autoloads=<ms> title=<ms> » : millisecondes depuis le
## lancement du moteur (autoloads prêts, écran titre affiché). Mesure
## RELATIVE (comparer deux versions sur la même machine) ; l'écran de
## chargement du 1er lancement (préchauffage des shaders) n'est pas inclus.
## Utilise sa propre sauvegarde (jamais celle du joueur).

const SAVE := "user://startup_probe_save.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var autoloads := Time.get_ticks_msec()
	root.get_node("SaveManager").use_path(SAVE)
	var main: Node = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	while main.get("title") == null:
		await process_frame
	await process_frame  # première image du titre
	print("STARTUP autoloads=%d title=%d" % [autoloads, Time.get_ticks_msec()])
	quit()
