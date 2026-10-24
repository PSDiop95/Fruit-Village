class_name ShareService
extends RefCounted
## Partage natif (image + texte + lien du store).
## Android : plugin « Share » (godot-mobile-plugins/godot-share, singleton
## ou nœud Share) si présent. Sinon (PC, plugin absent) : l'image est
## enregistrée dans user://share/ et le texte copié dans le presse-papiers.
## Renvoie le chemin de l'image enregistrée.


static func _class_path(cls: String) -> String:
	for c in ProjectSettings.get_global_class_list():
		if c["class"] == cls:
			return c["path"]
	return ""


static func share(image: Image, text: String, file_name: String, host: Node) -> String:
	DirAccess.make_dir_recursive_absolute("user://share")
	var path := "user://share/%s.png" % file_name
	if image:
		image.save_png(path)
	var abs_path := ProjectSettings.globalize_path(path)
	Analytics.log_event(&"share", {"item": file_name})
	var share_cls := _class_path("Share")
	if OS.get_name() == "Android" and share_cls != "":
		var node: Node = load(share_cls).new()
		host.add_child(node)
		var data_cls := _class_path("ShareData")
		if data_cls != "" and node.has_method("share"):
			var data: Object = load(data_cls).new()
			data.call("set_title", "Fruit Village")
			data.call("set_text", text)
			data.call("set_file_path", abs_path)
			data.call("set_mime_type", "image/png")
			node.call("share", data)
		elif node.has_method("share_image"):
			node.call("share_image", abs_path, "Fruit Village", "Fruit Village", text)
		node.queue_free.call_deferred()
		return path
	DisplayServer.clipboard_set(text)
	return path
