class_name DailyPanel
extends MetaModal
## Cadeau du jour : calendrier 7 cases, série (flamme), réclamation.
## Série cassée : « ▶ Protéger ma série » (rewarded, si dispo) ou repartir du jour 1.

var cells: Array[PanelContainer] = []
var claim_button: Button
var shield_button: Button
var _info: Label


func _init() -> void:
	super("Cadeau du jour", 1000.0)


func _ready() -> void:
	super()
	DailyRewards.changed.connect(_rebuild)
	AdsManager.availability_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for c in body.get_children():
		c.queue_free()
	cells.clear()
	claim_button = null
	shield_button = null
	if not DailyRewards.is_unlocked():
		body.add_child(MetaUi.label("Débloqué au niveau %d" %
			Progression.unlock_level(ProgressionCore.DAILY), 46))
		return
	var st := DailyRewards.status()
	var streak_row := HBoxContainer.new()
	streak_row.alignment = BoxContainer.ALIGNMENT_CENTER
	streak_row.add_theme_constant_override("separation", 12)
	body.add_child(streak_row)
	streak_row.add_child(flame_icon(64))
	var n: int = DailyRewards.core.streak if not st["broken"] else 0
	streak_row.add_child(MetaUi.label("Série : %d jour%s" % [n, "s" if n > 1 else ""], 50,
		UiTheme.WAX_ORANGE, true))

	# Calendrier : 4 cases puis 3, rangées centrées.
	var grid: HBoxContainer
	var today_index: int = st["day_index"]
	var claimed: bool = st["claimed_today"]
	for i in DailyRewards.config.rewards.size():
		var state := "future"
		if claimed:
			if i <= posmod(DailyRewards.core.cycle - 1, DailyRewards.core.days()):
				state = "done"
		elif i < today_index:
			state = "done"
		elif i == today_index:
			state = "today"
		if i % 4 == 0:
			grid = HBoxContainer.new()
			grid.alignment = BoxContainer.ALIGNMENT_CENTER
			grid.add_theme_constant_override("separation", 12)
			body.add_child(grid)
		var cell := _cell(i, DailyRewards.config.rewards[i], state)
		grid.add_child(cell)
		cells.append(cell)

	_info = MetaUi.label("", 38, UiTheme.INK_SOFT)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(760, 0)
	body.add_child(_info)
	if st["clock_suspect"]:
		_info.text = "L'heure du téléphone semble incorrecte : le cadeau reviendra quand elle sera remise à l'heure."
	elif claimed:
		_info.text = "Reviens demain pour le jour %d !" % (DailyRewards.core.cycle + 1)
	elif st["broken"]:
		_info.text = "Tu as manqué un jour : ta série repart de zéro…"
		if st["shield_available"] and AdsManager.is_rewarded_ready(AdsConfig.STREAK_SHIELD):
			_info.text = "Tu as manqué un jour ! Protège ta série de %d jours." % DailyRewards.core.streak
			AdsManager.offer(AdsConfig.STREAK_SHIELD)
			shield_button = MetaUi.ad_button("Protéger ma série", Vector2(640, 116), _shield, 44)
			body.add_child(shield_button)
	if st["can_claim"]:
		claim_button = MetaUi.button("Récupérer" if shield_button == null else "Recommencer au jour 1",
			&"ButtonGreen" if shield_button == null else &"ButtonCream", Vector2(560, 120),
			func() -> void: DailyRewards.claim(false), 48)
		body.add_child(claim_button)
		if shield_button == null:
			UiJuice.breathe(claim_button, 0.04, 1.2)


func _shield() -> void:
	AdsManager.show_rewarded(AdsConfig.STREAK_SHIELD, func() -> void: DailyRewards.claim(true))


func _cell(i: int, r: DailyRewardDef, state: String) -> PanelContainer:
	# Cases : sections M3 ; aujourd'hui = pastille crème cernée, teinte wax.
	var p := PanelContainer.new()
	match state:
		"today":
			p.add_theme_stylebox_override("panel", MetaUi.highlight_style(UiTheme.WAX_YELLOW))
		"done":
			p.theme_type_variation = &"PanelSection"
			p.modulate = Color(1, 1, 1, 0.6)
		_:
			p.theme_type_variation = &"PanelSection"
	p.custom_minimum_size = Vector2(178, 210)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	var head := MetaUi.label("Jour %d" % (i + 1), 34, UiTheme.INK, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	if r.is_chest:
		v.add_child(_center(MetaUi.label("Coffre", 40, UiTheme.WAX_RED, true)))
	if r.coins > 0:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		row.add_child(MetaUi.coin_icon(40))
		row.add_child(MetaUi.label(str(r.coins), 40, UiTheme.INK, true))
		v.add_child(row)
	if r.powerup != &"":
		var def := Wallet.powerups.get_def(r.powerup)
		if def and def.icon:
			var t := TextureRect.new()
			t.texture = def.icon
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.custom_minimum_size = Vector2(84, 84)
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(t)
			v.add_child(_center(MetaUi.label(def.display_name, 30)))
		elif def:
			v.add_child(_center(MetaUi.label(def.glyph, 54, def.color.darkened(0.2), true)))
			v.add_child(_center(MetaUi.label(def.display_name, 30)))
	if state == "done":
		v.add_child(_center(MetaUi.label("✓", 44, UiTheme.WAX_GREEN, true)))
	return p


static func _center(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Flamme de série dessinée (aucun emoji : rendu identique partout).
static func flame_icon(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px * 0.8, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var w := px * 0.8
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for k in 25:
			var t := float(k) / 24.0 * TAU
			# Goutte inversée : pointe en haut.
			var x := sin(t) * 0.5
			var y := -cos(t) * 0.5
			var pinch := 1.0 - 0.55 * maxf(-y * 2.0, 0.0)
			outer.append(Vector2(w * (0.5 + x * pinch), px * (0.55 + y * 0.9)))
			inner.append(Vector2(w * (0.5 + x * pinch * 0.5), px * (0.72 + y * 0.5)))
		c.draw_colored_polygon(outer, UiTheme.WAX_ORANGE)
		c.draw_polyline(outer, UiTheme.INK, 4.0, true)
		c.draw_colored_polygon(inner, UiTheme.WAX_YELLOW))
	return c
