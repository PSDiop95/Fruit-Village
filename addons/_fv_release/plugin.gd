@tool
extends EditorPlugin
## Branche FvReleaseExport sur l'export (identifiants AdMob debug/release).

var _export: EditorExportPlugin


func _enter_tree() -> void:
	_export = preload("res://addons/_fv_release/release_export.gd").new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null
