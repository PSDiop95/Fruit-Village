extends SceneTree
## Génère data/ambiances/*.tres et data/ambiances.tres (valeurs de départ ;
## ensuite, régler directement dans les .tres / l'inspecteur).
## Usage : Godot --headless --path . -s tools/make_ambiances.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/ambiances"))
	var vc: Resource = load("res://data/visual.tres")
	var set_script: GDScript = load("res://scripts/data/ambiances.gd")
	var def_script: GDScript = load("res://scripts/data/ambiance_def.gd")
	var defs: Array[Resource] = []

	# Jour : le décor tel quel (lumière de visual.tres).
	var jour: Resource = def_script.new()
	jour.id = &"jour"
	jour.display_name = "Jour"
	jour.short_name = "Jour"
	jour.background_color = vc.background_color
	jour.haze_color = vc.decor_haze_color
	jour.sun_color = vc.sun_color
	jour.sun_energy = vc.sun_energy
	jour.sun_rotation_degrees = vc.sun_rotation_degrees
	jour.ambient_color = vc.ambient_color
	jour.ambient_energy = vc.ambient_energy
	jour.rim_color = vc.rim_color
	jour.glow_intensity = vc.glow_intensity
	defs.append(jour)

	# Coucher de soleil : ciel rose-orangé, lumière rasante chaude, guirlandes.
	var soir: Resource = def_script.new()
	soir.id = &"coucher"
	soir.display_name = "Coucher de soleil"
	soir.short_name = "Soir"
	soir.sky_override = true
	soir.sky_top = Color("3e4c8e")
	soir.sky_mid = Color("d0789a")
	soir.sky_horizon = Color("ffb36e")
	soir.background_color = Color("3e4c8e")
	soir.decor_mul = Color(0.98, 0.76, 0.7)
	soir.decor_add = Color(0.06, 0.0, 0.03)
	soir.haze_color = Color("f0a07e")
	soir.sun_color = Color("ffb27a")
	soir.sun_energy = 1.0
	soir.sun_rotation_degrees = Vector3(-14, -40, 0)
	soir.ambient_color = Color("ffbca4")
	soir.ambient_energy = 0.35
	soir.rim_color = Color("ff9a40")
	soir.glow_intensity = 0.6
	soir.frame_tint = Color(1.0, 0.94, 0.88)
	soir.garlands = true
	soir.bulb_colors = PackedColorArray([Color("ffd27a"), Color("ffe6a0"), Color("ffc060")])
	soir.bulb_energy = 2.2
	defs.append(soir)

	# Nuit festive : ciel bleu nuit étoilé, lune, guirlandes multicolores.
	var nuit: Resource = def_script.new()
	nuit.id = &"nuit"
	nuit.display_name = "Nuit festive"
	nuit.short_name = "Nuit"
	nuit.sky_override = true
	nuit.sky_top = Color("0b1236")
	nuit.sky_mid = Color("1e2c62")
	nuit.sky_horizon = Color("4a4888")
	nuit.background_color = Color("0b1236")
	nuit.decor_mul = Color(0.36, 0.4, 0.62)
	nuit.decor_add = Color(0.02, 0.02, 0.06)
	nuit.haze_color = Color("202a58")
	nuit.sun_color = Color("c0c8ff")
	nuit.sun_energy = 0.75
	nuit.sun_rotation_degrees = Vector3(-30, 30, 0)
	nuit.ambient_color = Color("ffd6a0")
	nuit.ambient_energy = 0.5
	nuit.rim_color = Color("ffc860")
	nuit.glow_intensity = 0.8
	nuit.frame_tint = Color(0.96, 0.88, 0.8)
	nuit.garlands = true
	nuit.bulb_colors = PackedColorArray([Color("ffd060"), Color("ff7a3a"), Color("ff4a6a"),
		Color("6ae070"), Color("60b0ff"), Color("ffd060")])
	nuit.bulb_energy = 2.8
	nuit.night_stars = true
	nuit.moon = true
	defs.append(nuit)

	var list: Array[AmbianceDef] = []
	for d in defs:
		var path := "res://data/ambiances/%s.tres" % d.id
		ResourceSaver.save(d, path)
		list.append(load(path))
	var s: Resource = set_script.new()
	s.list = list
	ResourceSaver.save(s, "res://data/ambiances.tres")
	print("AMBIANCES %d" % list.size())
	quit()
