extends SceneTree
## Mesure de scores réels (physique Jolt) pour caler tools/sim_economy.gd.
## Deux bots : « hasard » (lâcher aléatoire) et « malin » (lâche au-dessus du
## fruit identique le plus haut, sinon sur le bord le plus bas).
## Usage : Godot --headless --path . --fixed-fps 60 -s tools/bot_scores.gd -- 20 docs/economy/bot_scores.csv

var games: int = 20
var out_path := "res://docs/economy/bot_scores.csv"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		games = int(args[0])
	if args.size() > 1:
		out_path = args[1]
	root.get_node("SaveManager").use_path("user://bot_scores_save.json")
	var lines := PackedStringArray(["bot,seed,score,max_rank,drops,merges,game_seconds"])
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	for i in games:
		for bot in ["hasard", "malin"]:
			var row: Array = await _play(bot, 1000 + i)
			lines.append("%s,%d,%d,%d,%d,%d,%d" % ([bot, 1000 + i] + row))
			print("%s #%d score=%d rang=%d" % [bot, i, row[0], row[1] + 1])
			# Écrit après chaque partie (un arrêt en cours garde les mesures).
			var f := FileAccess.open(out_path, FileAccess.WRITE)
			f.store_string("\n".join(lines) + "\n")
			f.close()
	print("BOT_SCORES -> %s" % out_path)
	quit()


func _play(bot: String, seed_value: int) -> Array:
	var g = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	g.seed_value = seed_value
	g.juice_enabled = false
	root.add_child(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var half: float = g.config.basket_inner_width * 0.5
	var drops := 0
	var merges := [0]
	g.merged.connect(func(_r: int, _p: Vector3, _pts: int, _c: int) -> void: merges[0] += 1)
	var t := 0
	while not g.is_over and drops < 600:
		await physics_frame
		t += 1
		if t % 30 != 0:
			continue
		var x := rng.randf_range(-half, half)
		if bot == "malin":
			x = _smart_x(g, rng, half)
		if g.drop(x):
			drops += 1
	var row := [g.score, g.max_rank_reached, drops, merges[0], int(t / 60.0)]
	g.queue_free()
	await process_frame
	return row


## Au-dessus du fruit de même rang le plus haut ; sinon là où la pile est la plus basse.
func _smart_x(g, rng: RandomNumberGenerator, half: float) -> float:
	var r: int = g.spawner.current()
	var best_y := -INF
	var best_x := NAN
	for f in g.fruits():
		if f.rank == r and f.global_position.y > best_y:
			best_y = f.global_position.y
			best_x = f.global_position.x
	if not is_nan(best_x):
		return best_x + rng.randf_range(-0.05, 0.05)
	var lowest_x := 0.0
	var lowest := INF
	for k in 9:
		var x := lerpf(-half * 0.9, half * 0.9, k / 8.0)
		var top: float = 0.0
		for f in g.fruits():
			if absf(f.global_position.x - x) < f.radius:
				top = maxf(top, f.top_y())
		if top < lowest:
			lowest = top
			lowest_x = x
	return lowest_x
