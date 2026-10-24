class_name MockConsentDialog
extends CanvasLayer
## Formulaire de consentement simulé (MockAds) : Accepter / Refuser.
## En production, c'est le formulaire UMP de Google qui s'affiche.

signal decided(granted: bool)


func _ready() -> void:
	layer = 121
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelCard"
	card.custom_minimum_size = Vector2(900, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	card.add_child(box)
	var t := Label.new()
	t.text = "Vie privée (simulation)"
	t.theme_type_variation = &"LabelTitle"
	t.add_theme_font_size_override("font_size", 64)
	box.add_child(t)
	var body := Label.new()
	body.text = "Fruit Village utilise des publicités et des statistiques anonymes. " \
		+ "Acceptes-tu des pubs personnalisées et la mesure d'audience ?"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(800, 0)
	box.add_child(body)
	var policy := Button.new()
	policy.text = "Lire la politique de confidentialité"
	policy.theme_type_variation = &"ButtonSegment"
	policy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	policy.pressed.connect(func() -> void: OS.shell_open(AdsManager.config.privacy_policy_url))
	box.add_child(policy)
	for choice in [["Accepter", &"ButtonGreen", true], ["Refuser", &"ButtonCream", false]]:
		var b := Button.new()
		b.text = choice[0]
		b.theme_type_variation = choice[1]
		b.custom_minimum_size = Vector2(520, 116)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var granted: bool = choice[2]
		b.pressed.connect(func() -> void:
			decided.emit(granted)
			queue_free())
		box.add_child(b)
