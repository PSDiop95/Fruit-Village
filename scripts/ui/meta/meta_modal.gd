class_name MetaModal
extends Control
## Fenêtre modale des écrans méta : voile flou, carte bois centrée, titre,
## bouton fermer. Le contenu va dans `body`. Fonctionne jeu en pause.

signal closed

var card: PanelContainer
var body: VBoxContainer
var title_label: Label
var close_button: Button
var _blur: BlurBackdrop


func _init(title: String, width: float = 960.0) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.get_theme()
	_blur = BlurBackdrop.new()
	add_child(_blur)
	_blur.fade_in(0.25)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	card = PanelContainer.new()
	card.theme_type_variation = &"PanelCard"
	card.custom_minimum_size = Vector2(width, 0)
	center.add_child(card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 20)
	card.add_child(outer)
	var head := HBoxContainer.new()
	outer.add_child(head)
	title_label = Label.new()
	title_label.text = title
	title_label.theme_type_variation = &"LabelTitle"
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_label)
	close_button = Button.new()
	close_button.text = "×"
	close_button.theme_type_variation = &"ButtonCream"
	close_button.add_theme_font_size_override("font_size", 64)
	close_button.custom_minimum_size = Vector2(112, 112)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	head.add_child(close_button)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	outer.add_child(body)


func _ready() -> void:
	UiJuice.pop_in(card)
	UiJuice.bounce_all(self)


func close() -> void:
	closed.emit()
	queue_free()
