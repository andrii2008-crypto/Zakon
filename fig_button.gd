extends Control
## Кнопка палитры: одна фигура

const Law = preload("res://law.gd")

signal picked

var code := 0
var selected := false:
	set(v):
		selected = v
		queue_redraw()


func _init(c: int = 0) -> void:
	code = c
	custom_minimum_size = Vector2(90, 76)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("2a3050") if selected else Color("1f2333")
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(4 if selected else 0)
	sb.border_color = Color("ffffff")
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	Law.draw_fig(self, code, size / 2.0, minf(size.x, size.y) * 0.28)


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		picked.emit()
