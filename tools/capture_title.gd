extends SceneTree
## Captures de l'écran titre et des réglages.
## Usage : Godot --path . --resolution 540x1200 -s tools/capture_title.gd -- <dossier> [ambiance]

const MAIN_SCENE := "res://scenes/Main.tscn"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0] if args.size() > 0 else "user://captures_title"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_node("SaveManager").use_path("user://capture_title_save.json")
	if args.size() > 1:
		root.get_node("SaveManager").set_setting(&"ambiance", int(args[1]))
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await _frames(90)
	await _shot(out_dir, "titre")
	main.title.open_settings()
	await _frames(30)
	await _shot(out_dir, "titre_reglages")
	print("CAPTURE_TITLE ok -> %s" % out_dir)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(dir: String, file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir.path_join(file + ".png"))
