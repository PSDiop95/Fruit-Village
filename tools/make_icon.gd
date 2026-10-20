extends SceneTree
## Icône (512²) et écran de démarrage (1080x1920) placeholders : sidem +
## mangue + pain de singe (vrais modèles) sur fond orange wax.
## À remplacer par l'illustration finale. Usage (fenêtré) :
##   Godot --path . -s tools/make_icon.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _render(Vector2i(512, 512), "res://assets/ui/icon.png", false)
	await _render(Vector2i(1080, 1920), "res://assets/ui/splash.png", true)
	quit()


func _render(size: Vector2i, path: String, splash: bool) -> void:
	var catalog: FruitCatalog = load("res://data/fruits.tres")
	var juice: JuiceConfig = (load("res://data/juice.tres") as JuiceConfig).duplicate()
	juice.show_rank_numbers = false
	var vc := FruitModels.get_config()
	var vp := SubViewport.new()
	vp.size = size
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = UiTheme.WAX_ORANGE
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = vc.ambient_color
	e.ambient_light_energy = vc.ambient_energy + 0.1
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = vc.sun_rotation_degrees
	sun.light_color = vc.sun_color
	sun.light_energy = vc.sun_energy
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = 4.2
	cam.position = Vector3(0, 1.3 if splash else 0.0, 10)
	vp.add_child(cam)
	cam.current = true
	# Pain de singe derrière, mangue devant à droite, sidem devant à gauche.
	var placements := [[10, Vector3(0.15, 0.25, -2.0), 0.95], [6, Vector3(0.75, -0.55, 0.0), 0.95],
		[0, Vector3(-0.95, -0.85, 1.0), 1.9]]
	for p in placements:
		var v := FruitVisual.new()
		v.setup(juice, p[0] + 5)
		v.apply_def(p[0], catalog.get_def(p[0]))
		v.position = p[1]
		v.scale = Vector3.ONE * p[2]
		vp.add_child(v)
	if splash:
		var title := Label3D.new()
		title.text = "Merge\nMarché"
		title.font = UiTheme.font()
		title.font_size = 200
		title.outline_size = 40
		title.pixel_size = 0.0034
		title.modulate = UiTheme.CREAM
		title.outline_modulate = UiTheme.INK
		title.position = Vector3(0, 3.6, 2)
		vp.add_child(title)
	for k in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("ICON ", path)
	vp.queue_free()
