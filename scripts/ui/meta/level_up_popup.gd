class_name LevelUpPopup
extends MetaModal
## « Niveau supérieur ! » : rayons tournants, gros chiffre élastique,
## récompense en pièces, fonctionnalités débloquées (effet M2 : pop + rebond).

var level: int
var coins: int
var unlocks: Array[StringName]
var _rays: Control
var _big: Label


func _init(p_level: int, p_coins: int, p_unlocks: Array[StringName]) -> void:
	level = p_level
	coins = p_coins
	unlocks = p_unlocks
	super("Niveau supérieur !", 860.0)
	close_button.visible = false


func _ready() -> void:
	super()
	var show := Control.new()
	show.custom_minimum_size = Vector2(0, 300)
	body.add_child(show)
	_rays = Control.new()
	_rays.size = Vector2(520, 520)
	_rays.pivot_offset = _rays.size * 0.5
	_rays.draw.connect(_draw_rays)
	show.add_child(_rays)
	_big = MetaUi.outlined(str(level), 220, UiTheme.WAX_YELLOW, 24)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_big.size = Vector2(400, 300)
	show.add_child(_big)
	show.resized.connect(func() -> void:
		_rays.position = show.size * 0.5 - _rays.size * 0.5
		_big.position = Vector2(show.size.x * 0.5 - 200, 0)
		_big.pivot_offset = _big.size * 0.5)
	if coins > 0:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		body.add_child(row)
		row.add_child(MetaUi.label("Récompense :  ", 44, UiTheme.INK, true))
		row.add_child(MetaUi.coin_pill(coins, 44))
	for f in unlocks:
		var l := MetaUi.label("Débloqué : %s" % MetaUi.feature_name(f), 46, UiTheme.WAX_GREEN, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(l)
		if f == ProgressionCore.POWERUPS:
			var g := MetaUi.label("1 de chaque power-up offert !", 36, UiTheme.INK_SOFT)
			g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.add_child(g)
	body.add_child(MetaUi.button("Super !", &"ButtonGreen", Vector2(440, 120), close, 52))
	_big.scale = Vector2.ONE * 0.2
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_big, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC) \
		.set_ease(Tween.EASE_OUT)
	Audio.play(preload("res://data/juice.tres").sounds.discover, -4.0)


func _process(delta: float) -> void:
	if _rays:
		_rays.rotation += delta * 0.5


func _draw_rays() -> void:
	var c := _rays.size * 0.5
	var col := Color(1.0, 0.78, 0.3, 0.6)
	for i in 14:
		var a := TAU * i / 14
		var half := PI / 14 * 0.5
		_rays.draw_polygon(PackedVector2Array([c, c + Vector2.from_angle(a - half) * c.x,
			c + Vector2.from_angle(a + half) * c.x]), PackedColorArray([col, Color(col, 0), Color(col, 0)]))
