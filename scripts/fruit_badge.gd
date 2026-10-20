class_name FruitBadge
extends Control
## Pastille UI : disque coloré + numéro de rang (aperçu du fruit suivant).

var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()
var number: int = 1:
	set(v):
		number = v
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r, color.darkened(0.35))
	draw_circle(c, r - 5.0, color)
	var font := get_theme_default_font()
	var fs := int(r * 0.9)
	var text := str(number)
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var pos := c + Vector2(-ts.x * 0.5, ts.y * 0.3)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
