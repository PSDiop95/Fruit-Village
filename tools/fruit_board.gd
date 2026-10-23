extends SceneTree
## Planche de validation des 11 fruits (M3) : de face, dans l'ordre, rendu jeu.
## Ligne 1 : couleur (qualité Haut). Ligne 2 : noir et blanc (lisibilité des
## silhouettes). Ligne 3 : qualité Bas (sans contour ni rim light).
## Usage (fenêtré, pas --headless) :
##   Godot --path . -s tools/fruit_board.gd -- docs/screens/m3_planche_fruits.png

const SIZE := Vector2i(3600, 1900)
const GAP := 0.35


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://m3_planche_fruits.png"
	var catalog: FruitCatalog = load("res://data/fruits.tres")
	var juice: JuiceConfig = (load("res://data/juice.tres") as JuiceConfig).duplicate()
	juice.show_rank_numbers = false
	var vc := FruitModels.get_config()

	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("f3e3c3")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = vc.ambient_color
	e.ambient_light_energy = vc.ambient_energy
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = vc.sun_rotation_degrees
	sun.light_color = vc.sun_color
	sun.light_energy = vc.sun_energy
	world.add_child(sun)

	var total := 0.0
	for d in catalog.fruits:
		total += d.radius * 2.0 + GAP
	total -= GAP
	var rows := [{"y": 4.6, "gray": 0.0, "q": JuiceConfig.Quality.HIGH, "label": "Haut"},
		{"y": 0.2, "gray": 1.0, "q": JuiceConfig.Quality.HIGH, "label": "N&B"},
		{"y": -4.2, "gray": 0.0, "q": JuiceConfig.Quality.LOW, "label": "Bas"}]
	var visuals: Array = []
	for row in rows:
		var x := -total * 0.5
		for i in catalog.count():
			var d := catalog.get_def(i)
			x += d.radius
			var v := FruitVisual.new()
			v.setup(juice, i + 1)
			v.apply_def(i, d)
			v.position = Vector3(x, row.y + d.radius - 1.1, 0)
			world.add_child(v)
			visuals.append({"v": v, "row": row})
			if row.label == "Haut":
				var lab := Label3D.new()
				lab.text = "%d. %s" % [i + 1, d.display_name]
				lab.font_size = 56
				lab.outline_size = 12
				lab.pixel_size = 0.0042
				lab.modulate = Color("3a2414")
				lab.outline_modulate = Color("f3e3c3")
				lab.position = Vector3(x, row.y - 1.45 - (0.42 if i % 2 == 1 and i < 4 else 0.0), 0.5)
				world.add_child(lab)
			x += d.radius + GAP

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.size = total + 1.2
	cam.position = Vector3(0, 0.9, 20)
	world.add_child(cam)
	cam.current = true

	# Rendu en deux passes : la qualité (contour) est globale aux matériaux.
	var img_hi: Image
	for pass_q in [JuiceConfig.Quality.HIGH, JuiceConfig.Quality.LOW]:
		FruitModels.set_quality(pass_q)
		for item in visuals:
			var v: FruitVisual = item.v
			v.visible = item.row.q == pass_q
			v.refresh_material()
			v.set_gray(item.row.gray)
		for k in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img_hi == null:
			img_hi = img
		else:
			# Ligne Bas : tiers inférieur de la 2e passe collé sur la 1re.
			var y0 := int(SIZE.y * 0.645)
			img_hi.blit_rect(img, Rect2i(0, y0, SIZE.x, SIZE.y - y0), Vector2i(0, y0))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	img_hi.save_png(out)
	print("BOARD ", out)
	quit()
