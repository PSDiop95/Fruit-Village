extends SceneTree
## Mesures de perf M3 : FPS (vsync coupé), draw calls, triangles à l'écran,
## en qualité Haut et Bas, panier typique (25 fruits) et plein (45 fruits).
## Usage (fenêtré) : Godot --path . --resolution 540x960 -s tools/perf_m3.gd -- docs/perf_m3.md

const GAME_SCENE := "res://scenes/Game.tscn"
const MEASURE_TIME := 3.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://perf_m3.md"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.get_node("SaveManager").use_path("user://perf_save.json")
	var rows: Array = []
	for q in [2, 0]:
		for count in [25, 45]:
			rows.append(await _measure(q, count))
	var lines := PackedStringArray()
	lines.append("# Mesures de performance M3")
	lines.append("")
	lines.append("Machine : %s, %s, fenêtre %s, vsync coupé, %s s de mesure par cas." % [
		OS.get_name(), RenderingServer.get_video_adapter_name(), str(root.get_visible_rect().size),
		MEASURE_TIME])
	lines.append("Renderer : Mobile (Vulkan). Partie réelle seedée, fruits posés au repos.")
	lines.append("")
	lines.append("| Qualité | Fruits | FPS moyen | FPS min (1 s) | Draw calls total | dont 3D | dont UI 2D | Triangles |")
	lines.append("|---|---|---|---|---|---|---|---|")
	for r in rows:
		lines.append("| %s | %d | %.0f | %.0f | %d | %d | %d | %d |" % [r.q, r.n, r.fps, r.fps_min, r.draws,
			r.draws_3d, r.draws - r.draws_3d, r.tris])
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	print("\n".join(lines))
	quit()


func _measure(quality: int, count: int) -> Dictionary:
	var g = (load(GAME_SCENE) as PackedScene).instantiate()
	g.seed_value = 99
	root.add_child(g)
	current_scene = g
	await physics_frame
	g.set_quality(quality)
	g.juice().auto_quality_allowed = false
	# Remplissage déterministe : rangs variés, sans fusion immédiate.
	var ranks := [0, 1, 2, 3, 4, 5, 0, 2, 4, 1, 3, 6, 0, 1, 2, 3, 4, 5, 7, 0, 1, 2, 3, 4, 2]
	var half: float = g.config.basket_inner_width * 0.5 - 0.6
	for i in count:
		g.spawn_fruit(ranks[i % ranks.size()], Vector3(-half + fmod(i * 1.37, half * 2.0),
			g.config.spawn_y + float(i % 4) * 0.4, 0))
		for k in 4:
			await physics_frame
	for k in 120:
		await physics_frame
	var t := 0.0
	var frames := 0
	var draws := 0
	var tris := 0
	var objects := 0
	var fps_min := INF
	var win_t := 0.0
	var win_f := 0
	var last := Time.get_ticks_usec()
	while t < MEASURE_TIME:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000000.0
		last = now
		t += dt
		frames += 1
		win_t += dt
		win_f += 1
		if win_t >= 1.0:
			fps_min = minf(fps_min, win_f / win_t)
			win_t = 0.0
			win_f = 0
		draws = maxi(draws, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		tris = maxi(tris, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		objects = maxi(objects, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	# Part 3D seule : on masque l'UI (HUD + calques Juice) quelques frames.
	g.hud().visible = false
	for c in g.juice().get_children():
		if c is CanvasLayer:
			c.visible = false
	for k in 4:
		await process_frame
	var draws_3d := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var res := {"q": ["Bas", "Moyen", "Haut"][quality], "n": g.fruits().size(), "fps": frames / t,
		"fps_min": fps_min, "draws": draws, "draws_3d": draws_3d, "tris": tris, "objects": objects}
	g.queue_free()
	await process_frame
	return res
