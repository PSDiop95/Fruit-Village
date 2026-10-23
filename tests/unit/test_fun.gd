extends GutTest
## Tests « fun visuel » : ambiances, guirlandes, mascotte, nouveaux effets de
## fusion poolés, bannière COMBO, cadre du panier, HUD bois.

const GameScene := preload("res://scenes/Game.tscn")
const TEST_SAVE := "user://test_save_fun.json"

var cfg: JuiceConfig = load("res://data/juice.tres")
var vcfg: VisualConfig = load("res://data/visual.tres")
var gcfg: GameConfig = load("res://data/game_config.tres")


func before_all() -> void:
	DirAccess.remove_absolute(TEST_SAVE)
	SaveManager.use_path(TEST_SAVE)


func after_all() -> void:
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(TEST_SAVE)
	SaveManager.use_path(SaveManager.DEFAULT_SAVE_PATH)


func after_each() -> void:
	Engine.time_scale = 1.0
	SaveManager.set_setting(&"ambiance", Ambiances.AUTO)


func _new_game() -> Game:
	var g: Game = GameScene.instantiate()
	g.seed_value = 4242
	add_child_autofree(g)
	await wait_physics_frames(2)
	return g


# ---------------------------------------------------------------- Ambiances

func test_ambiances_load_with_unique_ids() -> void:
	var a := Ambiances.load_default()
	assert_eq(a.list.size(), 3)
	var ids := {}
	for d in a.list:
		ids[d.id] = true
		assert_false(d.short_name.is_empty())
	assert_eq(ids.size(), a.list.size())
	assert_true(a.list[a.night_index].night_stars, "la nuit a des étoiles")
	assert_true(a.list[a.dusk_index].garlands, "le soir a des guirlandes")
	assert_false(a.list[a.day_index].garlands, "pas de guirlandes en plein jour")


func test_ambiance_explicit_setting_wins() -> void:
	var a := Ambiances.load_default()
	for i in a.list.size():
		assert_eq(a.resolve(i, 3), i)
		assert_eq(a.resolve(i, 12), i)


func test_ambiance_auto_follows_local_hour() -> void:
	var a := Ambiances.load_default()
	assert_eq(a.resolve(Ambiances.AUTO, 10), a.day_index)
	assert_eq(a.resolve(Ambiances.AUTO, 18), a.dusk_index)
	assert_eq(a.resolve(Ambiances.AUTO, 22), a.night_index)
	assert_eq(a.resolve(Ambiances.AUTO, 3), a.night_index)
	assert_eq(a.resolve(99, 10), a.day_index, "index invalide = Auto")


func test_garland_curve_hangs_between_anchors() -> void:
	var line := Vector4(-4.0, 11.0, 4.0, 11.0)
	var pts := FestiveLights.catenary(line, 0.8, 0.5)
	assert_almost_eq(pts[0], Vector2(-4, 11), Vector2(0.001, 0.001))
	assert_almost_eq(pts[pts.size() - 1], Vector2(4, 11), Vector2(0.001, 0.001))
	var lowest := INF
	for p in pts:
		lowest = minf(lowest, p.y)
	assert_almost_eq(lowest, 11.0 - 0.8, 0.01, "flèche au milieu")


func test_ambiance_switches_live_and_builds_lights() -> void:
	var g := await _new_game()
	var market := g.market()
	SaveManager.set_setting(&"ambiance", Ambiances.load_default().night_index)
	await wait_process_frames(2)
	assert_eq(market.ambiance.id, &"nuit")
	assert_not_null(market.lights.bulbs, "guirlandes la nuit")
	assert_not_null(market.lights.stars, "étoiles la nuit")
	SaveManager.set_setting(&"ambiance", Ambiances.load_default().day_index)
	await wait_process_frames(2)
	assert_eq(market.ambiance.id, &"jour")
	assert_null(market.lights.bulbs, "pas de guirlandes le jour")


# ---------------------------------------------------------------- Cadre / HUD

func test_basket_frame_replaces_calebasse_without_touching_collision() -> void:
	var g := await _new_game()
	var market := g.market()
	assert_true(market.has_basket())
	assert_not_null(market.frame, "cadre bois peint")
	assert_null(market.basket, "pas de calebasse quand le cadre est défini")
	var q := market.frame.mesh as QuadMesh
	var b := vcfg.basket_frame_border
	assert_almost_eq(q.size.x, gcfg.basket_inner_width + b * 2.0, 0.001)
	assert_almost_eq(q.size.y, gcfg.basket_height + b * 2.0, 0.001)
	# Derrière le plus gros fruit (rayon max) : jamais coupé par un fruit.
	var biggest: FruitDef = load("res://data/fruits.tres").get_def(10)
	assert_lt(market.frame.position.z, -biggest.radius)
	# Pas de boîtes placeholder visibles.
	var basket := g.get_node("Basket")
	assert_eq(basket.find_children("*", "MeshInstance3D", false, false).size(), 0)


func test_hud_art_exists() -> void:
	for f in ["pause.png", "next_ring.png", "score_plank.png", "star.png", "basket_frame.png"]:
		assert_true(ResourceLoader.exists(GameHud.HUD_DIR + f), f)


# ---------------------------------------------------------------- Mascotte

func test_mascot_is_built_with_parts_and_face() -> void:
	var g := await _new_game()
	var m := g.mascot()
	assert_not_null(m)
	for part in ["head", "arm_l", "arm_r", "leg_l", "leg_r", "tail"]:
		assert_not_null(m._parts.get(part), part)
	assert_not_null(m._face.mesh, "visage du jeu posé sur la tête")
	assert_eq(m.current_mood(), Mascot.Mood.IDLE)


func test_mascot_cheers_on_big_combo_only() -> void:
	var g := await _new_game()
	var m := g.mascot()
	g.merged.emit(1, Vector3.ZERO, 3, 1)
	assert_eq(m.current_mood(), Mascot.Mood.IDLE, "petite fusion : rien")
	g.merged.emit(1, Vector3.ZERO, 3, vcfg.mascot_cheer_combo)
	assert_eq(m.current_mood(), Mascot.Mood.CHEER)


func test_mascot_party_is_not_cut_by_a_cheer() -> void:
	var g := await _new_game()
	var m := g.mascot()
	g.top_merge.emit(Vector3.ZERO)
	assert_eq(m.current_mood(), Mascot.Mood.PARTY)
	g.merged.emit(7, Vector3.ZERO, 30, 5)
	assert_eq(m.current_mood(), Mascot.Mood.PARTY)


func test_mascot_fear_then_sad() -> void:
	var g := await _new_game()
	var m := g.mascot()
	g.danger_changed.emit(0.8, DangerMonitor.State.WARNING)
	assert_eq(m.current_mood(), Mascot.Mood.FEAR)
	g.danger_changed.emit(0.0, DangerMonitor.State.SAFE)
	assert_eq(m.current_mood(), Mascot.Mood.IDLE)
	g.game_over.emit(10, 2, false)
	assert_eq(m.current_mood(), Mascot.Mood.SAD)
	m.react(Mascot.Mood.CHEER)
	assert_eq(m.current_mood(), Mascot.Mood.SAD, "plus de fête après le game over")


func test_mascot_reaction_ends() -> void:
	var g := await _new_game()
	var m := g.mascot()
	m.react(Mascot.Mood.CHEER)
	await wait_seconds(vcfg.mascot_cheer_time + 0.2)
	assert_eq(m.current_mood(), Mascot.Mood.IDLE)


# ---------------------------------------------------------------- Effets de fusion

func test_merge_fx_pools_never_grow() -> void:
	var g := await _new_game()
	var j := g.juice()
	for i in 30:
		j._on_merged(i % 10, Vector3(0, 3, 0), 10, 1 + i % 6)
	await wait_process_frames(2)
	for pool in [j.drop_pool, j.star_pool, j.flash_pool]:
		assert_eq(pool.created, pool.size(), "aucune instanciation en jeu")
	assert_eq(j.flash_pool.size(), cfg.flash_pool_size)


func test_flash_ends() -> void:
	var f := FxItems.Flash.new(Color.WHITE)
	add_child_autofree(f)
	f.duration = 0.1
	f.start(Vector3.ZERO, 1.0)
	assert_true(f.tick(0.05))
	assert_false(f.tick(0.1))


# ---------------------------------------------------------------- Bannière COMBO

func _banner() -> ComboBanner:
	var b := ComboBanner.new()
	b.setup(cfg)
	add_child_autofree(b)
	return b


func test_combo_banner_grows_with_level() -> void:
	var b := _banner()
	b.play("COMBO x2 !", 100, 0, 0.3, Color.YELLOW, Color.ORANGE)
	var small := b._settings.font_size
	b.play("COMBO x6 !", 100, 4, 0.3, Color.YELLOW, Color.ORANGE)
	assert_gt(b._settings.font_size, small)
	assert_true(b.visible)


func test_combo_banner_hot_level_turns_red() -> void:
	var b := _banner()
	b.play("x", 100, cfg.combo_hot_level - cfg.combo_min, 0.3, Color.YELLOW, Color.ORANGE)
	assert_eq(b._mat.get_shader_parameter("bottom_color"), cfg.combo_hot_fill_bottom)


func test_combo_banner_hides_after_play() -> void:
	var b := _banner()
	b.play("COMBO x2 !", 100, 0, 0.1, Color.YELLOW, Color.ORANGE)
	await wait_seconds(0.9)
	assert_false(b.is_playing())
	assert_false(b.visible)


# ---------------------------------------------------------------- Motion (passe 2)

func test_neighbours_look_at_merge() -> void:
	var g := await _new_game()
	var f := g.spawn_fruit(2, Vector3(-1.5, 2.0, 0))
	await wait_physics_frames(2)
	f.visual().look_toward(Vector3(1.5, 2.0, 0), 1.0)
	await wait_process_frames(20)
	assert_gt(f.visual().look_amount().x, 0.5, "les yeux vont vers la droite")


func test_basket_bump_squashes_then_settles() -> void:
	var g := await _new_game()
	var j := g.juice()
	j.bump_basket(1.0)
	assert_almost_eq(j.basket_squash(), cfg.basket_bump_max, 0.0001, "plafonné")
	await wait_process_frames(2)
	assert_ne(g.market().frame.scale, Vector3.ONE, "le cadre s'écrase")
	await wait_seconds(1.5)
	assert_almost_eq(j.basket_squash(), 0.0, 0.002, "revient au repos")


func test_trail_follows_drop_then_ends() -> void:
	var g := await _new_game()
	var f := g.drop(0.0)
	await wait_physics_frames(2)
	assert_gt(g.juice().trail_pool.active_count(), 0)
	f.queue_free()
	await wait_process_frames(3)
	assert_eq(g.juice().trail_pool.active_count(), 0, "s'arrête si le fruit disparaît")


func test_stars_fly_to_score_from_pool() -> void:
	var g := await _new_game()
	var hud := g.hud()
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	hud.fly_points(Vector2(540, 1400), 4)
	await wait_seconds(0.3)
	assert_gt(hud.flyers_visible(), 0)
	await wait_seconds(cfg.fly_time + 0.6)
	assert_eq(hud.flyers_visible(), 0, "toutes arrivées")
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "poolées")


func test_every_fruit_has_a_fun_fact() -> void:
	var cat: FruitCatalog = load("res://data/fruits.tres")
	for r in cat.count():
		assert_false(cat.get_def(r).fun_fact.is_empty(), cat.get_def(r).display_name)


func test_fact_card_shows_then_leaves() -> void:
	var g := await _new_game()
	var hud := g.hud()
	hud.show_fact(6)
	assert_true(hud.fact_visible())
	assert_string_contains(hud._fact_text.text, "mangue")
	await wait_seconds(cfg.fact_card_time + 1.0)
	assert_false(hud.fact_visible())


func test_ui_bounce_is_attached_once() -> void:
	var b := Button.new()
	add_child_autofree(b)
	UiJuice.bounce(b)
	UiJuice.bounce(b)
	assert_eq(b.button_down.get_connections().size(), 1)


func test_curtain_reveals() -> void:
	var c := UiJuice.Curtain.new()
	add_child_autofree(c)
	c.reveal(0.1)
	assert_true(c.is_covering())
	await wait_seconds(0.3)
	assert_false(c.is_covering())


# ---------------------------------------------------------------- Menu peint

func test_theme_buttons_are_painted() -> void:
	var t := UiTheme.build()
	for type in ["Button", "ButtonGreen", "ButtonBlue", "ButtonCream", "ButtonGreenBig", "ButtonOrangeBig"]:
		assert_true(t.get_stylebox("normal", type) is StyleBoxTexture, type)
	assert_true(t.get_stylebox("panel", "PanelContainer") is StyleBoxTexture, "panneaux en cadre bois")
	assert_true(t.get_stylebox("panel", "PillBest") is StyleBoxTexture)


func test_title_menu_is_centered_in_basket() -> void:
	var title := TitleScreen.new()
	add_child_autofree(title)
	await wait_process_frames(3)
	var canvas := title.get_viewport().get_visible_rect().size
	var basket := TitleScreen.basket_screen_rect(canvas)
	assert_almost_eq(basket.get_center().x, canvas.x * 0.5, 0.5, "panier centré")
	var play := title.play_button.get_global_rect()
	assert_almost_eq(play.get_center().x, canvas.x * 0.5, 1.0, "Jouer centré")
	assert_true(basket.encloses(play), "Jouer dans le cadre")
	assert_true(basket.encloses(title.settings_button.get_global_rect()), "Réglages dans le cadre")
	assert_lt(title.logo.get_global_rect().end.y, basket.position.y, "logo au-dessus du cadre")


func test_title_settings_dim_is_freed_on_close() -> void:
	var title := TitleScreen.new()
	add_child_autofree(title)
	await wait_process_frames(2)
	var s := title.open_settings()
	var wrapper := s.get_parent().get_parent()
	assert_true(wrapper.has_meta(&"settings_wrapper"))
	s.close()
	await wait_process_frames(2)
	assert_false(is_instance_valid(wrapper), "voile libéré avec le panneau")


# ---------------------------------------------------------------- Réglages / pause / fin

func test_settings_card_has_sections_and_close() -> void:
	var s := SettingsPanel.new()
	add_child_autofree(s)
	await wait_process_frames(1)
	assert_eq(s.theme_type_variation, &"PanelCard", "carte simple")
	assert_eq(s.toggles.size(), 4)
	assert_eq(s.quality_buttons.size(), 4)
	var picked := 0
	for b in s.ambiance_buttons:
		picked += int(b.theme_type_variation == &"Button")
	assert_eq(picked, 1, "un seul choix actif (orange)")
	assert_not_null(s.x_button)


func test_pause_blurs_the_game() -> void:
	var g := await _new_game()
	var hud := g.hud()
	hud.open_pause()
	# Arbre en pause : on vérifie le voile sans attendre (les attentes GUT sont figées).
	assert_true(hud._pause_dim is BlurBackdrop)
	assert_true(hud._pause_dim.visible)
	hud.close_pause()
	assert_false(get_tree().paused)


func test_blur_fades_in() -> void:
	var b := BlurBackdrop.new()
	add_child_autofree(b)
	b.fade_in(0.1)
	await wait_seconds(0.3)
	assert_almost_eq(b.amount(), 1.0, 0.01, "flou complet")
	b.fade_out(0.1)
	await wait_seconds(0.3)
	assert_false(b.visible)


func test_game_over_screen_shows_results_and_record_stamp() -> void:
	var g := await _new_game()
	var hud := g.hud()
	hud.merges = 12
	hud.best_combo = 4
	hud.play_time = 75.0
	g.score = 999999
	g._end_game()
	await wait_seconds(cfg.game_over_panel_delay + cfg.game_over_panel_slide_time
		+ cfg.game_over_score_roll_time + 1.2)
	var o: GameOverScreen = hud._over
	assert_true(o.visible)
	assert_eq(o.displayed_score(), 999999, "score défilé jusqu'au bout")
	assert_true(o.stamp.visible, "tampon nouveau record")
	assert_eq(o._chip_values[0].text, "12")
	assert_eq(o._chip_values[1].text, "x4")
	assert_eq(o._chip_values[2].text, "1:15")
	var r := o.card.get_global_rect()
	var w := o.get_viewport().get_visible_rect().size.x
	assert_almost_eq(r.get_center().x, w * 0.5, 1.0, "carte centrée")
