extends Control
## Миниатюра опыта: «до» → «после»

const Law = preload("res://law.gd")
const CS := 26.0

var before: Array = []
var after: Array = []


func setup(b: Array, a: Array) -> void:
	before = b.duplicate()
	after = a.duplicate()
	custom_minimum_size = Vector2(CS * Law.N * 2 + 60, CS * Law.N + 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var bs := CS * Law.N
	_grid(Vector2(0, 4), before, [])
	_grid(Vector2(bs + 60, 4), after, before)
	var y := 4 + bs / 2.0
	var col := Color("8b91a8")
	draw_line(Vector2(bs + 12, y), Vector2(bs + 46, y), col, 3.0)
	draw_line(Vector2(bs + 46, y), Vector2(bs + 36, y - 8), col, 3.0)
	draw_line(Vector2(bs + 46, y), Vector2(bs + 36, y + 8), col, 3.0)


func _grid(o: Vector2, g: Array, ref: Array) -> void:
	draw_rect(Rect2(o, Vector2(CS, CS) * Law.N), Color("1b1f2e"))
	for i in g.size():
		var x: int = i % Law.N
		var y: int = floori(i / float(Law.N))
		var c := o + Vector2(x + 0.5, y + 0.5) * CS
		if g[i] >= 0:
			Law.draw_fig(self, g[i], c, CS * 0.32)
		elif not ref.is_empty() and ref[i] >= 0:
			Law.draw_fig(self, ref[i], c, CS * 0.32, 0.25)
			draw_line(c + Vector2(-8, -8), c + Vector2(8, 8), Color("ff5a5a"), 2.5)
			draw_line(c + Vector2(8, -8), c + Vector2(-8, 8), Color("ff5a5a"), 2.5)
	for k in range(Law.N + 1):
		draw_line(o + Vector2(k * CS, 0), o + Vector2(k * CS, CS * Law.N), Color(1, 1, 1, 0.08), 1.0)
		draw_line(o + Vector2(0, k * CS), o + Vector2(CS * Law.N, k * CS), Color(1, 1, 1, 0.08), 1.0)
