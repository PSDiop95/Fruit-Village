class_name PerfProbe
extends Node
## Sonde de perf sur appareil (builds debug) : active seulement si le fichier
## user://perf_probe existe (adb shell run-as <pkg> touch files/perf_probe).
## Remplit le panier puis mesure le FPS moyen en coupant un poste à la fois ;
## résultats dans le log (logcat, balise « PERF »).

const FLAG := "user://perf_probe"
const MEASURE := 4.0

var game: Game


static func enabled() -> bool:
	return OS.is_debug_build() and FileAccess.file_exists(FLAG)


func run(p_game: Game) -> void:
	game = p_game
	await get_tree().create_timer(1.0).timeout
	var ranks := [0, 1, 2, 3, 4, 5, 0, 2, 4, 1, 3, 6, 0, 1, 2, 3, 4, 5, 7, 0, 1, 2, 3, 4, 2]
	for i in ranks.size():
		game.spawn_fruit(ranks[i], Vector3(-2.6 + fmod(i * 1.37, 5.2), game.config.spawn_y, 0))
		await get_tree().create_timer(0.12).timeout
	await get_tree().create_timer(3.0).timeout
	var vp := get_viewport()
	var env := game.market().environment
	print("PERF device=%s gpu=%s size=%s fruits=%d" % [OS.get_model_name(),
		RenderingServer.get_video_adapter_name(), vp.get_visible_rect().size, game.fruits().size()])
	# Niveaux de qualité (VisualQuality / JuiceConfig.Quality), puis voile flou
	# de fin de partie par-dessus le panier plein.
	for q in [JuiceConfig.Quality.HIGH, JuiceConfig.Quality.MEDIUM, JuiceConfig.Quality.LOW]:
		game.set_quality(q)
		await _measure("qualité %s" % VisualQuality.label(q))
		var blur := BlurBackdrop.new()
		game.hud().add_child(blur)
		blur.capture()
		blur.set_amount(1.0)
		blur.visible = true
		await _measure("qualité %s + flou" % VisualQuality.label(q))
		blur.queue_free()
	game.set_quality(JuiceConfig.Quality.HIGH)
	# Mesures alternées (le téléphone chauffe : la base est remesurée entre deux variantes).
	await _measure("base (FSR 80 %, MSAA 2x)")
	vp.scaling_3d_scale = 1.0
	await _measure("3D 100 %")
	vp.scaling_3d_scale = 0.8
	await _measure("base")
	vp.scaling_3d_scale = 0.7
	await _measure("3D 70 %")
	vp.scaling_3d_scale = 0.8
	await _measure("base")
	env.glow_enabled = false
	await _measure("sans glow")
	env.glow_enabled = true
	await _measure("base")
	vp.msaa_3d = Viewport.MSAA_DISABLED
	await _measure("sans MSAA")
	vp.msaa_3d = Viewport.MSAA_2X
	await _measure("base")
	print("PERF fin")


func _measure(label: String) -> void:
	await get_tree().create_timer(0.5).timeout
	var t := 0.0
	var frames := 0
	var last := Time.get_ticks_usec()
	while t < MEASURE:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		t += (now - last) / 1000000.0
		last = now
		frames += 1
	print("PERF %-32s %5.1f FPS" % [label, frames / t])
