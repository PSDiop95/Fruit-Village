extends SceneTree
## Génère assets/ui/theme.tres depuis UiTheme.build() (thème unique du jeu).
## Usage : Godot --headless --path . -s tools/make_theme.gd


func _initialize() -> void:
	var t := UiTheme.build()
	var err := ResourceSaver.save(t, UiTheme.PATH)
	print("THEME ", UiTheme.PATH, " err=", err)
	quit(0 if err == OK else 1)
