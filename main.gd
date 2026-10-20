extends Control
## ЗАКОН — игра про разгадывание скрытых правил

const Law = preload("res://law.gd")
const BoardScript = preload("res://board.gd")
const MiniScript = preload("res://mini_board.gd")
const FigScript = preload("res://fig_button.gd")

const BG := Color("12141d")
const PANEL := Color("1f2333")
const ACCENT := Color("7c5cff")
const GOOD := Color("2fa36b")
const TXT := Color("e8eaf2")
const DIM := Color("8b91a8")
const SAVE_PATH := "user://zakon_save.json"

var prog := {"level": 1, "stars": {}, "daily_date": 0, "daily_score": 0}

var mode := "campaign"   # campaign | daily
var level := 1
var sel_level := 1
var seed_val := 0
var rule: Dictionary = {}
var grid: Array = []
var ticks := 0
var wrong := 0
var log_entries: Array = []
var brush := 0

var host: MarginContainer
var pages := {}
var cur_page := "menu"
var board
var info_label: Label
var nb_button: Button
var brush_buttons: Array = []
var toast: Label
var toast_tween: Tween
var nb_list: VBoxContainer
var notes_edit: TextEdit
var level_btn: Button
var daily_btn: Button
var menu_stats: Label
var res_title: Label
var res_body: Label
var res_next: Callable

var catalog: Array = []
var h_not: Array = []
var h_cat: Array = []
var h_var: Array = []
var h_term: Array = []
var h_conn: Array = []
var h_preview: Label


# ---------------------------------------------------------------- старт

func _ready() -> void:
	randomize()
	_load()
	sel_level = int(prog.level)
	catalog = Law.catalog()

	var bg := ColorRect.new()
	bg.color = BG
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	host = MarginContainer.new()
	add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_theme_constant_override("margin_left", 24)
	host.add_theme_constant_override("margin_right", 24)
	host.add_theme_constant_override("margin_top", 56)
	host.add_theme_constant_override("margin_bottom", 28)

	_build_menu()
	_build_game()
	_build_notebook()
	_build_hyp()
	_build_result()
	_build_help()

	toast = Label.new()
	toast.visible = false
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_font_size_override("font_size", 26)
	toast.add_theme_stylebox_override("normal", _style(Color("000000dd")))
	add_child(toast)
	toast.anchor_left = 0.0
	toast.anchor_right = 1.0
	toast.anchor_top = 1.0
	toast.anchor_bottom = 1.0
	toast.offset_left = 32
	toast.offset_right = -32
	toast.offset_top = -260
	toast.offset_bottom = -170

	_show("menu")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		match cur_page:
			"menu":
				get_tree().quit()
			"game", "result", "help":
				_show("menu")
			_:
				_show("game")


# ---------------------------------------------------------------- UI-помощники

func _style(bg: Color, radius: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


func _btn(text: String, cb: Callable, color: Color = PANEL, h: int = 84, w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", TXT)
	b.add_theme_color_override("font_pressed_color", TXT)
	b.add_theme_color_override("font_hover_color", TXT)
	for st in ["normal", "hover"]:
		b.add_theme_stylebox_override(st, _style(color))
	for st in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, _style(color.lightened(0.25)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


func _label(t: String, fs: int = 28, color: Color = TXT, center: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _option() -> OptionButton:
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.custom_minimum_size = Vector2(0, 70)
	o.fit_to_longest_item = false
	o.clip_text = true
	o.add_theme_font_size_override("font_size", 26)
	var pop := o.get_popup()
	pop.add_theme_font_size_override("font_size", 30)
	pop.add_theme_constant_override("v_separation", 18)
	return o


func _page(id: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	host.add_child(v)
	pages[id] = v
	return v


func _show(id: String) -> void:
	cur_page = id
	for k in pages:
		pages[k].visible = (k == id)
	if id == "notebook":
		_fill_notebook()
	elif id == "menu":
		_refresh_menu()
	elif id == "hyp":
		_update_hyp()


func _toast(t: String, secs: float = 3.0) -> void:
	toast.text = t
	toast.visible = true
	if toast_tween:
		toast_tween.kill()
	toast_tween = create_tween()
	toast_tween.tween_interval(secs)
	toast_tween.tween_callback(func(): toast.visible = false)


# ---------------------------------------------------------------- меню

func _build_menu() -> void:
	var p := _page("menu")
	p.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(_label("ЗАКОН", 110, ACCENT, true))
	p.add_child(_label("Мир подчиняется скрытому закону.\nТвоя задача — вычислить его.", 28, DIM, true))
	p.add_child(_spacer(40))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var prev := _btn("<", _prev_level, PANEL, 110, 110)
	prev.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(prev)
	level_btn = _btn("", _start_campaign, ACCENT, 110)
	row.add_child(level_btn)
	var nxt := _btn(">", _next_level, PANEL, 110, 110)
	nxt.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(nxt)
	daily_btn = _btn("", _start_daily, PANEL, 96)
	p.add_child(daily_btn)
	p.add_child(_btn("Как играть", func(): _show("help"), PANEL, 80))
	p.add_child(_spacer(20))
	menu_stats = _label("", 26, DIM, true)
	p.add_child(menu_stats)


func _refresh_menu() -> void:
	var st := int(prog.stars.get(str(sel_level), 0))
	level_btn.text = "Уровень %d   %s" % [sel_level, "★".repeat(st) + "☆".repeat(3 - st)]
	var d := _today()
	var best := ""
	if prog.daily_date == d:
		best = "  ·  лучший счёт: %d" % int(prog.daily_score)
	daily_btn.text = "Закон дня" + best
	var total := 0
	for k in prog.stars:
		total += int(prog.stars[k])
	menu_stats.text = "Звёзд собрано: %d" % total


func _prev_level() -> void:
	sel_level = maxi(1, sel_level - 1)
	_refresh_menu()


func _next_level() -> void:
	sel_level = mini(sel_level + 1, int(prog.level))
	_refresh_menu()


func _today() -> int:
	var t := Time.get_date_dict_from_system()
	return int(t.year) * 10000 + int(t.month) * 100 + int(t.day)


func _start_campaign() -> void:
	_start("campaign", sel_level, sel_level * 7919 + 13)


func _start_daily() -> void:
	var d := _today()
	_start("daily", 3 + d % 6, d)


func _build_help() -> void:
	var p := _page("help")
	p.add_child(_label("Как играть", 40, ACCENT, true))
	p.add_child(_label(
		"Каждая фигура — цвет и форма. Поле живёт по скрытому закону: после ТИКа одни фигуры выживают, другие исчезают.\n\n" +
		"1. Выбери фигуру внизу и тапай по клеткам. Тап по такой же фигуре убирает её.\n" +
		"2. Жми ТИК и смотри, кто исчез (красные крестики).\n" +
		"3. Блокнот хранит все опыты. Любой можно вернуть на поле.\n" +
		"4. Догадался? Открой «Закон» и собери условие. Если оно неверно, мир покажет контрпример.\n\n" +
		"Закон может зависеть от цвета, формы, соседей (8 клеток вокруг), положения: левая или верхняя половина, край, светлая клетка.\n\n" +
		"Счёт = опыты + 2 за каждую ошибку. Чем меньше, тем лучше.", 28, TXT))
	p.add_child(_spacer(10))
	p.add_child(_btn("Понятно", func(): _show("menu"), ACCENT, 90))


# ---------------------------------------------------------------- игра

func _build_game() -> void:
	var p := _page("game")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	p.add_child(top)
	var mb := _btn("Меню", func(): _show("menu"), PANEL, 72, 150)
	mb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(mb)
	info_label = _label("", 24, DIM)
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(info_label)

	board = BoardScript.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.cell_tapped.connect(_on_cell)
	p.add_child(board)

	var pal := GridContainer.new()
	pal.columns = 6
	pal.add_theme_constant_override("h_separation", 8)
	pal.add_theme_constant_override("v_separation", 8)
	p.add_child(pal)
	for code in 12:
		var fb := FigScript.new(code)
		fb.picked.connect(_set_brush.bind(code))
		pal.add_child(fb)
		brush_buttons.append(fb)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	p.add_child(tools)
	tools.add_child(_btn("Очистить", _clear, PANEL, 68))
	tools.add_child(_btn("Случайно", _random_fill, PANEL, 68))
	tools.add_child(_btn("Отмена тика", _undo, PANEL, 68))

	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 10)
	p.add_child(acts)
	nb_button = _btn("Блокнот", func(): _show("notebook"), PANEL, 96)
	acts.add_child(nb_button)
	var tb := _btn("ТИК", _do_tick, ACCENT, 96)
	tb.add_theme_font_size_override("font_size", 40)
	tb.size_flags_stretch_ratio = 1.4
	acts.add_child(tb)
	acts.add_child(_btn("Закон", func(): _show("hyp"), GOOD, 96))


func _start(m: String, lvl: int, sd: int) -> void:
	mode = m
	level = lvl
	seed_val = sd
	rule = Law.make(lvl, sd)
	grid = []
	grid.resize(Law.N * Law.N)
	grid.fill(-1)
	ticks = 0
	wrong = 0
	log_entries.clear()
	board.marks = {}
	board.ghosts = {}
	board.set_grid(grid)
	notes_edit.text = ""
	_set_brush(0)
	_refresh()
	_show("game")
	_toast("Ставь фигуры и жми ТИК: закон решит, кто выживет.", 3.5)


func _refresh() -> void:
	var head := "Закон дня" if mode == "daily" else "Уровень %d" % level
	info_label.text = "%s\nОпытов %d · пар %d · ошибок %d" % [head, ticks, _par(), wrong]
	nb_button.text = "Блокнот (%d)" % log_entries.size()


func _par() -> int:
	return mini(3 + level, 14)


func _set_brush(code: int) -> void:
	brush = code
	for b in brush_buttons:
		b.selected = (b.code == code)


func _on_cell(x: int, y: int) -> void:
	var i := y * Law.N + x
	board.marks = {}
	if grid[i] == brush:
		grid[i] = -1
	else:
		grid[i] = brush
	board.set_grid(grid)


func _clear() -> void:
	grid.fill(-1)
	board.marks = {}
	board.set_grid(grid)


func _random_fill() -> void:
	for i in grid.size():
		grid[i] = (randi() % 12) if randf() < 0.4 else -1
	board.marks = {}
	board.set_grid(grid)


func _undo() -> void:
	if log_entries.is_empty():
		_toast("Откатывать нечего.")
		return
	var last: Dictionary = log_entries.back()
	grid = last.before.duplicate()
	board.marks = {}
	board.set_grid(grid)


func _do_tick() -> void:
	var has := false
	for c in grid:
		if c >= 0:
			has = true
			break
	if not has:
		_toast("Сначала поставь хотя бы одну фигуру.")
		return
	var before: Array = grid.duplicate()
	var after: Array = Law.tick(rule, grid)
	ticks += 1
	log_entries.append({"before": before, "after": after, "tag": ""})
	var gh := {}
	for i in before.size():
		if before[i] >= 0 and after[i] < 0:
			gh[i] = before[i]
	grid = after
	board.marks = {}
	board.set_grid(grid)
	board.show_ghosts(gh)
	_refresh()


# ---------------------------------------------------------------- блокнот

func _build_notebook() -> void:
	var p := _page("notebook")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	p.add_child(top)
	var back := _btn("← Поле", func(): _show("game"), PANEL, 72, 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(back)
	top.add_child(_label("Блокнот опытов", 32, TXT, true))

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	nb_list = VBoxContainer.new()
	nb_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nb_list.add_theme_constant_override("separation", 10)
	sc.add_child(nb_list)

	notes_edit = TextEdit.new()
	notes_edit.placeholder_text = "Мои гипотезы и заметки…"
	notes_edit.custom_minimum_size = Vector2(0, 220)
	notes_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	notes_edit.add_theme_font_size_override("font_size", 26)
	p.add_child(notes_edit)


func _fill_notebook() -> void:
	for c in nb_list.get_children():
		c.queue_free()
	if log_entries.is_empty():
		nb_list.add_child(_label("Пока пусто. Поставь фигуры на поле и нажми ТИК.", 26, DIM))
		return
	for i in range(log_entries.size() - 1, -1, -1):
		var e: Dictionary = log_entries[i]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _style(PANEL))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(_label("#%d %s" % [i + 1, e.tag], 22, DIM))
		var mb := MiniScript.new()
		mb.setup(e.before, e.after)
		left.add_child(mb)
		h.add_child(left)
		var go := _btn("На поле", _load_entry.bind(i), ACCENT, 70, 150)
		go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(go)
		nb_list.add_child(row)


func _load_entry(i: int) -> void:
	var e: Dictionary = log_entries[i]
	grid = e.before.duplicate()
	board.marks = {}
	board.set_grid(grid)
	_show("game")


# ---------------------------------------------------------------- конструктор закона

func _build_hyp() -> void:
	var p := _page("hyp")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	p.add_child(top)
	var back := _btn("← Поле", func(): _show("game"), PANEL, 72, 200)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top.add_child(back)
	top.add_child(_label("Твой закон", 32, TXT, true))
	p.add_child(_label("Фигура выживает, если… (читается слева направо)", 26, DIM))

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	sc.add_child(box)

	for i in 3:
		var tb := VBoxContainer.new()
		tb.add_theme_constant_override("separation", 8)
		var r1 := HBoxContainer.new()
		var nt := CheckBox.new()
		nt.text = "НЕ"
		nt.add_theme_font_size_override("font_size", 28)
		nt.toggled.connect(_on_hyp_toggle)
		var oc := _option()
		for c in catalog:
			oc.add_item(c.name)
		oc.item_selected.connect(_on_cat.bind(i))
		r1.add_child(nt)
		r1.add_child(oc)
		var ov := _option()
		ov.item_selected.connect(_on_hyp_pick)
		tb.add_child(r1)
		tb.add_child(ov)
		box.add_child(tb)
		h_not.append(nt)
		h_cat.append(oc)
		h_var.append(ov)
		h_term.append(tb)
		if i < 2:
			var oo := _option()
			for t in ["— на этом всё", "И ещё", "ИЛИ", "ровно одно из двух"]:
				oo.add_item(t)
			oo.item_selected.connect(_on_hyp_pick)
			box.add_child(oo)
			h_conn.append(oo)

	h_preview = _label("", 26, ACCENT)
	p.add_child(h_preview)
	p.add_child(_btn("Проверить закон", _submit, GOOD, 96))
	p.add_child(_btn("Сдаться и узнать закон", _giveup, PANEL, 64))
	for i in 3:
		_fill_var(i)
	_update_hyp()


func _fill_var(i: int) -> void:
	var ov: OptionButton = h_var[i]
	ov.clear()
	var lst: Array = catalog[h_cat[i].selected].list
	for it in lst:
		ov.add_item(Law.describe(it))
	ov.visible = lst.size() > 1
	ov.select(0)


func _on_cat(_idx: int, i: int) -> void:
	_fill_var(i)
	_update_hyp()


func _on_hyp_pick(_idx: int) -> void:
	_update_hyp()


func _on_hyp_toggle(_on: bool) -> void:
	_update_hyp()


func _update_hyp() -> void:
	var c0: int = h_conn[0].selected
	var c1: int = h_conn[1].selected
	h_term[1].visible = c0 > 0
	h_conn[1].visible = c0 > 0
	h_term[2].visible = c0 > 0 and c1 > 0
	h_preview.text = Law.statement(_hyp_rule())


func _hyp_rule() -> Dictionary:
	var terms: Array = []
	for i in 3:
		var ci: int = h_cat[i].selected
		var vi: int = h_var[i].selected
		var atom: Dictionary = catalog[ci].list[vi].duplicate()
		if h_not[i].button_pressed:
			atom = {"t": "not", "a": atom}
		terms.append(atom)
	var ops := ["", "and", "or", "xor"]
	var c0: int = h_conn[0].selected
	if c0 == 0:
		return terms[0]
	var r := {"t": ops[c0], "a": terms[0], "b": terms[1]}
	var c1: int = h_conn[1].selected
	if c1 == 0:
		return r
	return {"t": ops[c1], "a": r, "b": terms[2]}


func _submit() -> void:
	var hyp := _hyp_rule()
	var counter := Law.find_counter(rule, hyp)
	if counter.is_empty():
		_win()
		return
	wrong += 1
	var g: Array = counter.board
	var idx: int = counter.cell
	var after: Array = Law.tick(rule, g)
	log_entries.append({"before": g.duplicate(), "after": after, "tag": "· контрпример"})
	grid = g.duplicate()
	board.marks = {idx: Color("ff5a5a")}
	board.ghosts = {}
	board.set_grid(grid)
	_show("game")
	_refresh()
	var pred := Law.ev(hyp, g, idx % Law.N, floori(idx / float(Law.N)))
	_toast("Контрпример! По твоему закону фигура в красной рамке %s. На деле — %s. Жми ТИК, чтобы увидеть." %
		["выживет" if pred else "исчезнет", "исчезнет" if pred else "выживет"], 6.0)


# ---------------------------------------------------------------- результат

func _build_result() -> void:
	var p := _page("result")
	p.alignment = BoxContainer.ALIGNMENT_CENTER
	res_title = _label("", 52, ACCENT, true)
	p.add_child(res_title)
	res_body = _label("", 30, TXT, true)
	p.add_child(res_body)
	p.add_child(_spacer(30))
	p.add_child(_btn("Продолжить", func(): res_next.call(), ACCENT, 100))
	p.add_child(_btn("В меню", func(): _show("menu"), PANEL, 80))


func _win() -> void:
	var score := ticks + wrong * 2
	var par := _par()
	var stars := 1
	if score <= par:
		stars = 3
	elif score <= par * 2:
		stars = 2
	if mode == "campaign":
		var key := str(level)
		prog.stars[key] = maxi(int(prog.stars.get(key, 0)), stars)
		if level >= int(prog.level):
			prog.level = level + 1
	else:
		var d := _today()
		if prog.daily_date != d or score < int(prog.daily_score):
			prog.daily_date = d
			prog.daily_score = score
	_save()
	res_title.text = "Закон разгадан!"
	res_body.text = "%s\n\n%s\n\nОпытов: %d · ошибок: %d\nСчёт: %d (пар %d)" % [
		"★".repeat(stars) + "☆".repeat(3 - stars), Law.statement(rule), ticks, wrong, score, par]
	res_next = _after_win
	_show("result")


func _after_win() -> void:
	if mode == "campaign":
		sel_level = int(prog.level)
		_start("campaign", sel_level, sel_level * 7919 + 13)
	else:
		_show("menu")


func _giveup() -> void:
	res_title.text = "Закон был таким"
	res_body.text = Law.statement(rule)
	res_next = func(): _start(mode, level, seed_val)
	_show("result")


# ---------------------------------------------------------------- сохранение

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	prog.level = maxi(1, int(data.get("level", 1)))
	prog.daily_date = int(data.get("daily_date", 0))
	prog.daily_score = int(data.get("daily_score", 0))
	var st = data.get("stars", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in st:
			prog.stars[str(k)] = int(st[k])


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(prog))
