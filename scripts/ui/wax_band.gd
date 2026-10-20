class_name WaxBand
extends Control
## Frise wax (triangles alternés) dessinée en code : bordure des panneaux,
## logo. Même motif que la tranche de la calebasse.

const COLORS := [UiTheme.WAX_ORANGE, UiTheme.WAX_YELLOW, UiTheme.WAX_GREEN, UiTheme.WAX_RED,
	UiTheme.WAX_YELLOW, UiTheme.WAX_BLUE]

@export var tooth: float = 46.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(0, 34)


func _draw() -> void:
	var n := maxi(1, int(size.x / tooth))
	var w := size.x / n
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.WAX_BLUE)
	for i in n:
		var x := i * w
		var up := i % 2 == 0
		var pts := PackedVector2Array([Vector2(x + 2, size.y - 4 if up else 4),
			Vector2(x + w * 0.5, 4 if up else size.y - 4), Vector2(x + w - 2, size.y - 4 if up else 4)])
		draw_colored_polygon(pts, COLORS[i % COLORS.size()])


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
