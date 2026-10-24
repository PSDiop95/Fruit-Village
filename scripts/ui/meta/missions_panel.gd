class_name MissionsPanel
extends MetaModal
## Missions du jour : 3 lignes (texte, barre, récompense), « Récupérer »,
## « ▶ x2 » (rewarded, masqué si aucune pub prête), compte à rebours minuit.

var rows: Array[Dictionary] = []  # {claim: Button, double: Button, bar, status}
var _timer_label: Label
var _clock := MetaClock.new()


func _init() -> void:
	super("Missions du jour", 980.0)


func _ready() -> void:
	super()
	Missions.changed.connect(_rebuild)
	AdsManager.availability_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	for c in body.get_children():
		c.queue_free()
	rows.clear()
	if not Missions.is_unlocked():
		body.add_child(MetaUi.label("Débloqué au niveau %d" %
			Progression.unlock_level(ProgressionCore.MISSIONS), 46))
		return
	Missions.refresh()
	_timer_label = MetaUi.label("", 36, UiTheme.INK_SOFT)
	body.add_child(_timer_label)
	_update_timer()
	for i in Missions.core.active.size():
		body.add_child(_row(i))


func _row(i: int) -> Control:
	var m: Dictionary = Missions.core.active[i]
	var sec := PanelContainer.new()
	sec.theme_type_variation = &"PanelSection"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	sec.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var txt := MetaUi.label(Missions.describe(i), 42, UiTheme.INK, true)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(txt)
	top.add_child(MetaUi.coin_pill(int(m["reward"]), 36))
	var bar := MetaUi.progress_bar(30, UiTheme.WAX_GREEN)
	bar.max_value = int(m["target"])
	bar.value = int(m["progress"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	row.add_child(MetaUi.label("%d/%d" % [int(m["progress"]), int(m["target"])], 36))
	var entry := {"bar": bar}
	if m["claimed"]:
		row.add_child(MetaUi.label("✓ Reçu" + (" x2" if m["doubled"] else ""), 38, UiTheme.WAX_GREEN, true))
	elif Missions.can_claim(i):
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_END
		actions.add_theme_constant_override("separation", 12)
		v.add_child(actions)
		if AdsManager.is_rewarded_ready(AdsConfig.DOUBLE_MISSION):
			AdsManager.offer(AdsConfig.DOUBLE_MISSION)
			entry["double"] = MetaUi.ad_button("x2", Vector2(220, 104), _claim_doubled.bind(i), 40)
			actions.add_child(entry["double"])
		entry["claim"] = MetaUi.button("Récupérer", &"ButtonGreen", Vector2(330, 104),
			func() -> void: Missions.claim(i), 40)
		actions.add_child(entry["claim"])
	rows.append(entry)
	return sec


func _claim_doubled(i: int) -> void:
	AdsManager.show_rewarded(AdsConfig.DOUBLE_MISSION, func() -> void: Missions.claim(i, true))


func _process(_d: float) -> void:
	_update_timer()


func _update_timer() -> void:
	if _timer_label == null or not is_instance_valid(_timer_label):
		return
	var s := _clock.seconds_until_midnight()
	_timer_label.text = "Nouvelles missions dans %d h %02d" % [s / 3600, (s % 3600) / 60]
