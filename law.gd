extends RefCounted
## Движок законов. Правило — дерево словарей {"t": тип, ...}.

const N := 6
const COLOR_NAMES := ["красный", "синий", "жёлтый", "зелёный"]
const COLOR_VALUES := [Color("e5484d"), Color("3e8bff"), Color("f5c542"), Color("3ecf8e")]
const SHAPE_NAMES := ["круг", "квадрат", "треугольник"]


static func col_of(code: int) -> int:
	return floori(code / 3.0)


static func shape_of(code: int) -> int:
	return code % 3


static func neighbors(g: Array, x: int, y: int) -> Array:
	var out: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx < 0 or ny < 0 or nx >= N or ny >= N:
				continue
			var c: int = g[ny * N + nx]
			if c >= 0:
				out.append(c)
	return out


static func _cmp(a: int, op: String, b: int) -> bool:
	if op == "eq":
		return a == b
	return a >= b


## Выживает ли фигура в клетке (x, y) по правилу node
static func ev(node: Dictionary, g: Array, x: int, y: int) -> bool:
	var me: int = g[y * N + x]
	match node.t:
		"color":
			return col_of(me) == node.v
		"shape":
			return shape_of(me) == node.v
		"nany":
			return _cmp(neighbors(g, x, y).size(), node.op, node.n)
		"nc":
			var k := 0
			for c in neighbors(g, x, y):
				if col_of(c) == node.c:
					k += 1
			return _cmp(k, node.op, node.n)
		"samecol":
			for c in neighbors(g, x, y):
				if col_of(c) == col_of(me):
					return true
			return false
		"sameshape":
			for c in neighbors(g, x, y):
				if shape_of(c) == shape_of(me):
					return true
			return false
		"left":
			return x * 2 < N
		"top":
			return y * 2 < N
		"edge":
			return x == 0 or y == 0 or x == N - 1 or y == N - 1
		"chess":
			return (x + y) % 2 == 0
		"not":
			return not ev(node.a, g, x, y)
		"and":
			return ev(node.a, g, x, y) and ev(node.b, g, x, y)
		"or":
			return ev(node.a, g, x, y) or ev(node.b, g, x, y)
		"xor":
			return ev(node.a, g, x, y) != ev(node.b, g, x, y)
	return false


## Один тик: все решения принимаются одновременно по старому полю
static func tick(rule: Dictionary, g: Array) -> Array:
	var out: Array = g.duplicate()
	for y in N:
		for x in N:
			var i: int = y * N + x
			if g[i] >= 0 and not ev(rule, g, x, y):
				out[i] = -1
	return out


static func random_board(rng: RandomNumberGenerator, density: float) -> Array:
	var g: Array = []
	for i in N * N:
		if rng.randf() < density:
			g.append(rng.randi() % 12)
		else:
			g.append(-1)
	return g


# ---------- описание ----------

static func _op_word(op: String) -> String:
	return "ровно" if op == "eq" else "не меньше"


static func _wrap(n: Dictionary) -> String:
	if n.t in ["and", "or", "xor"]:
		return "(" + describe(n) + ")"
	return describe(n)


static func describe(n: Dictionary) -> String:
	match n.t:
		"color":
			return "цвет — %s" % COLOR_NAMES[n.v]
		"shape":
			return "форма — %s" % SHAPE_NAMES[n.v]
		"nany":
			return "соседей %s %d" % [_op_word(n.op), n.n]
		"nc":
			return "соседей цвета «%s» %s %d" % [COLOR_NAMES[n.c], _op_word(n.op), n.n]
		"samecol":
			return "есть сосед того же цвета"
		"sameshape":
			return "есть сосед той же формы"
		"left":
			return "в левой половине поля"
		"top":
			return "в верхней половине поля"
		"edge":
			return "на краю поля"
		"chess":
			return "на светлой клетке"
		"not":
			return "НЕ " + _wrap(n.a)
		"and":
			return _wrap(n.a) + " И " + _wrap(n.b)
		"or":
			return _wrap(n.a) + " ИЛИ " + _wrap(n.b)
		"xor":
			return "ровно одно из: " + _wrap(n.a) + " / " + _wrap(n.b)
	return "?"


static func statement(n: Dictionary) -> String:
	return "Фигура выживает, если: " + describe(n)


## Каталог атомов для конструктора гипотез
static func catalog() -> Array:
	var cat: Array = []
	var a: Array = []
	for i in 4:
		a.append({"t": "color", "v": i})
	cat.append({"name": "цвет", "list": a})
	a = []
	for i in 3:
		a.append({"t": "shape", "v": i})
	cat.append({"name": "форма", "list": a})
	a = []
	for op in ["eq", "ge"]:
		for n in range(1, 4):
			a.append({"t": "nany", "op": op, "n": n})
	cat.append({"name": "число соседей", "list": a})
	a = []
	for c in 4:
		for op in ["eq", "ge"]:
			for n in range(1, 3):
				a.append({"t": "nc", "c": c, "op": op, "n": n})
	cat.append({"name": "соседи нужного цвета", "list": a})
	cat.append({"name": "сосед того же цвета", "list": [{"t": "samecol"}]})
	cat.append({"name": "сосед той же формы", "list": [{"t": "sameshape"}]})
	cat.append({"name": "левая половина", "list": [{"t": "left"}]})
	cat.append({"name": "верхняя половина", "list": [{"t": "top"}]})
	cat.append({"name": "край поля", "list": [{"t": "edge"}]})
	cat.append({"name": "светлая клетка", "list": [{"t": "chess"}]})
	return cat


# ---------- генератор ----------

static func rand_atom(rng: RandomNumberGenerator, kinds: Array) -> Dictionary:
	var k: String = kinds[rng.randi() % kinds.size()]
	var op: String = ["eq", "ge"][rng.randi() % 2]
	match k:
		"color":
			return {"t": k, "v": rng.randi() % 4}
		"shape":
			return {"t": k, "v": rng.randi() % 3}
		"nany":
			return {"t": k, "op": op, "n": rng.randi_range(1, 3)}
		"nc":
			return {"t": k, "c": rng.randi() % 4, "op": op, "n": rng.randi_range(1, 2)}
	return {"t": k}


static func _maybe_not(rng: RandomNumberGenerator, a: Dictionary) -> Dictionary:
	if rng.randf() < 0.3:
		return {"t": "not", "a": a}
	return a


static func _build(level: int, rng: RandomNumberGenerator) -> Dictionary:
	var simple := ["color", "shape"]
	var nb := ["nany", "nc", "samecol", "sameshape"]
	var pos := ["left", "top", "edge", "chess"]
	var allk: Array = simple + nb + pos
	var logic := ["and", "or"]
	var lg: String = logic[rng.randi() % 2]
	if level <= 1:
		return rand_atom(rng, simple)
	if level == 2:
		if rng.randi() % 2 == 0:
			return {"t": "not", "a": rand_atom(rng, simple)}
		return {"t": lg, "a": rand_atom(rng, ["color"]), "b": rand_atom(rng, ["shape"])}
	if level == 3:
		return rand_atom(rng, nb)
	if level == 4:
		return {"t": lg, "a": rand_atom(rng, simple), "b": rand_atom(rng, nb)}
	if level == 5:
		return {"t": lg, "a": rand_atom(rng, simple), "b": rand_atom(rng, pos)}
	if level == 6:
		return {"t": lg, "a": rand_atom(rng, nb), "b": rand_atom(rng, pos)}
	if level == 7:
		return {"t": "xor", "a": rand_atom(rng, simple), "b": rand_atom(rng, nb + pos)}
	var ops := ["and", "or", "xor"]
	var a := _maybe_not(rng, rand_atom(rng, allk))
	var b := _maybe_not(rng, rand_atom(rng, allk))
	var c := _maybe_not(rng, rand_atom(rng, allk))
	var inner := {"t": ops[rng.randi() % 3], "a": a, "b": b}
	return {"t": ops[rng.randi() % 3], "a": inner, "b": c}


static func nontrivial(rule: Dictionary, rng: RandomNumberGenerator) -> bool:
	var yes := 0
	var total := 0
	for _i in 80:
		var g := random_board(rng, 0.6)
		for y in N:
			for x in N:
				if g[y * N + x] >= 0:
					total += 1
					if ev(rule, g, x, y):
						yes += 1
	if total == 0:
		return false
	var r := float(yes) / float(total)
	return r > 0.2 and r < 0.8


static func make(level: int, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for _attempt in 400:
		var r := _build(level, rng)
		if nontrivial(r, rng):
			return r
	return {"t": "color", "v": 0}


## Контрпример: поле, где закон игрока расходится с настоящим. Пустой словарь — не нашли.
static func find_counter(secret: Dictionary, hyp: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var best: Dictionary = {}
	var best_n := 999
	for _i in 700:
		var g := random_board(rng, rng.randf_range(0.2, 0.8))
		var diff: Array = []
		var count := 0
		for idx in N * N:
			if g[idx] < 0:
				continue
			count += 1
			var x: int = idx % N
			var y: int = floori(idx / float(N))
			if ev(secret, g, x, y) != ev(hyp, g, x, y):
				diff.append(idx)
		if diff.size() > 0 and count < best_n:
			best_n = count
			best = {"board": g, "cell": diff[rng.randi() % diff.size()]}
	return best


# ---------- рисование фигур ----------

static func draw_fig(ci: CanvasItem, code: int, c: Vector2, r: float, a: float = 1.0) -> void:
	var col: Color = COLOR_VALUES[col_of(code)]
	col.a = a
	match shape_of(code):
		0:
			ci.draw_circle(c, r, col)
		1:
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), col)
		_:
			var pts := PackedVector2Array([
				c + Vector2(0, -r * 1.1),
				c + Vector2(r * 1.1, r * 0.9),
				c + Vector2(-r * 1.1, r * 0.9),
			])
			ci.draw_colored_polygon(pts, col)
