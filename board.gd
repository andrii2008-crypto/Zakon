extends Control
## Игровое поле 6x6

const Law = preload("res://law.gd")

signal cell_tapped(x: int, y: int)

var grid: Array = []
var marks := {}    # индекс клетки -> цвет рамки
var ghosts := {}   # индекс клетки -> код исчезнувшей фигуры
var ghost_a := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0, 600)
	grid.resize(Law.N * Law.N)
	grid.fill(-1)


func set_grid(g: Array) -> void:
	grid = g.duplicate()
	queue_redraw()


func show_ghosts(d: Dictionary) -> void:
	ghosts = d
	ghost_a = 1.0
	queue_redraw()
	if d.is_empty():
		return
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_method(_set_ghost, 1.0, 0.0, 1.2)


func _set_ghost(v: float) -> void:
	ghost_a = v
	queue_redraw()


func _side() -> float:
	return minf(size.x, size.y)


func _origin() -> Vector2:
	var s := _side()
	return Vector2((size.x - s) / 2.0, (size.y - s) / 2.0)


func _center(i: int, o: Vector2, cs: float) -> Vector2:
	var x: int = i % Law.N
	var y: int = floori(i / float(Law.N))
	return o + Vector2(x + 0.5, y + 0.5) * cs


func _draw() -> void:
	var s := _side()
	var o := _origin()
	var cs := s / Law.N
	draw_rect(Rect2(o, Vector2(s, s)), Color("1b1f2e"))
	for y in Law.N:
		for x in Law.N:
			var r := Rect2(o + Vector2(x, y) * cs, Vector2(cs, cs))
			if (x + y) % 2 == 0:
				draw_rect(r, Color(1, 1, 1, 0.06))
			draw_rect(r, Color(1, 1, 1, 0.10), false, 1.0)
	draw_line(o + Vector2(s / 2.0, 0), o + Vector2(s / 2.0, s), Color(1, 1, 1, 0.22), 2.0)
	draw_line(o + Vector2(0, s / 2.0), o + Vector2(s, s / 2.0), Color(1, 1, 1, 0.22), 2.0)
	for i in grid.size():
		if grid[i] >= 0:
			Law.draw_fig(self, grid[i], _center(i, o, cs), cs * 0.32)
	for i in ghosts:
		var c := _center(i, o, cs)
		Law.draw_fig(self, ghosts[i], c, cs * 0.32, ghost_a * 0.6)
		var col := Color(1, 0.35, 0.35, ghost_a)
		var d := cs * 0.28
		draw_line(c + Vector2(-d, -d), c + Vector2(d, d), col, 5.0)
		draw_line(c + Vector2(d, -d), c + Vector2(-d, d), col, 5.0)
	for i in marks:
		var rr := Rect2(_center(i, o, cs) - Vector2(cs, cs) / 2.0, Vector2(cs, cs)).grow(-4)
		draw_rect(rr, marks[i], false, 5.0)


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var s := _side()
		var p := mb.position - _origin()
		if p.x < 0 or p.y < 0 or p.x >= s or p.y >= s:
			return
		var cs := s / Law.N
		cell_tapped.emit(int(p.x / cs), int(p.y / cs))
