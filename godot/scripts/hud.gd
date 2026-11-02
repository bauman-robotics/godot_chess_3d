extends CanvasLayer
## Графика поверх кадра: реплики, нотация, часы, eval-бар, титул, финальная плашка.
## Свёрстано в координатах 1920×1080 и масштабируется под фактическое разрешение.

const TL := preload("res://scripts/timeline.gd")
const FONT_R := preload("res://data/fonts/DejaVuSansCondensed.ttf")
const FONT_B := preload("res://data/fonts/DejaVuSansCondensed-Bold.ttf")

const GOLD := Color(0.86, 0.72, 0.44)
const PAPER := Color(0.93, 0.90, 0.84)
const DIM := Color(0.62, 0.58, 0.52)

var root: Control
var caption: Label
var move_tag: Label
var clock_w: Label
var clock_b: Label
var title_big: Label
var title_sub: Label
var title_rule: ColorRect
var end_lbl: Label
var end_scrim: ColorRect
var end_sub: Label
var eval_bg: ColorRect
var eval_white: ColorRect
var eval_black: ColorRect
var eval_line: ColorRect
var eval_lbl: Label
var vig: TextureRect
var top_band: TextureRect
var bot_band: TextureRect
var ui_scale := 1.0


func setup() -> void:
	var vs := get_viewport().get_visible_rect().size
	ui_scale = vs.y / 1080.0
	root = Control.new()
	root.size = Vector2(1920, 1080)
	root.scale = Vector2(ui_scale, ui_scale)
	add_child(root)

	# затемнение по краям
	var vg := Gradient.new()
	vg.set_color(0, Color(0, 0, 0, 0.0))
	vg.set_color(1, Color(0, 0, 0, 0.62))
	vg.add_point(0.55, Color(0, 0, 0, 0.0))
	var vt := GradientTexture2D.new()
	vt.gradient = vg
	vt.width = 512
	vt.height = 512
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.05, 0.5)
	vig = TextureRect.new()
	vig.texture = vt
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.size = Vector2(1920, 1080)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vig)

	top_band = _gradient_band(Vector2(0, 0), 240, false)
	bot_band = _gradient_band(Vector2(0, 800), 280, true)

	caption = _mk_label(PAPER, 40, 1720, HORIZONTAL_ALIGNMENT_CENTER)
	caption.position = Vector2(100, 906)
	caption.size = Vector2(1720, 152)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	move_tag = _mk_label(GOLD, 46, 700)
	move_tag.position = Vector2(96, 78)
	move_tag.size = Vector2(700, 64)

	clock_w = _mk_label(DIM, 30, 400, HORIZONTAL_ALIGNMENT_RIGHT)
	clock_w.position = Vector2(1500, 78)
	clock_w.size = Vector2(330, 40)
	clock_b = _mk_label(DIM, 30, 400, HORIZONTAL_ALIGNMENT_RIGHT)
	clock_b.position = Vector2(1500, 122)
	clock_b.size = Vector2(330, 40)

	title_big = _mk_label(PAPER, 150, 1600, HORIZONTAL_ALIGNMENT_CENTER)
	title_big.position = Vector2(160, 430)
	title_big.size = Vector2(1600, 190)
	title_big.text = "11 ХОДОВ"
	title_sub = _mk_label(GOLD, 40, 1600, HORIZONTAL_ALIGNMENT_CENTER)
	title_sub.position = Vector2(160, 620)
	title_sub.size = Vector2(1600, 60)
	title_sub.text = "мастер-класс по скоростному поражению"

	title_rule = ColorRect.new()
	title_rule.color = GOLD
	title_rule.position = Vector2(760, 600)
	title_rule.size = Vector2(400, 2)

	end_scrim = ColorRect.new()
	end_scrim.color = Color(0.0, 0.0, 0.0, 0.58)
	end_scrim.position = Vector2(330, 320)
	end_scrim.size = Vector2(1260, 400)
	end_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(end_scrim)

	end_lbl = _mk_label(PAPER, 120, 1200, HORIZONTAL_ALIGNMENT_CENTER)
	end_lbl.position = Vector2(360, 400)
	end_lbl.size = Vector2(1200, 160)
	end_lbl.text = "0 — 1"
	end_sub = _mk_label(GOLD, 38, 1400, HORIZONTAL_ALIGNMENT_CENTER)
	end_sub.position = Vector2(260, 580)
	end_sub.size = Vector2(1400, 100)
	end_sub.text = "11 ходов. 15 очков рейтинга. 0 понимания."

	# eval-бар справа
	var bx := 1770.0
	eval_bg = ColorRect.new()
	eval_bg.color = Color(0.05, 0.05, 0.06, 0.85)
	eval_bg.position = Vector2(bx, 250)
	eval_bg.size = Vector2(18, 520)
	root.add_child(eval_bg)
	eval_white = ColorRect.new()
	eval_white.color = Color(0.90, 0.87, 0.80, 0.95)
	eval_white.position = Vector2(bx, 250 + 260)
	eval_white.size = Vector2(18, 260)
	root.add_child(eval_white)
	eval_black = ColorRect.new()
	eval_black.color = Color(0.06, 0.06, 0.07, 0.95)
	eval_black.position = Vector2(bx, 250)
	eval_black.size = Vector2(18, 260)
	root.add_child(eval_black)
	eval_line = ColorRect.new()
	eval_line.color = GOLD
	eval_line.position = Vector2(bx - 4, 510)
	eval_line.size = Vector2(26, 3)
	root.add_child(eval_line)
	eval_lbl = _mk_label(GOLD, 26, 160, HORIZONTAL_ALIGNMENT_CENTER)
	eval_lbl.position = Vector2(bx - 70, 782)
	eval_lbl.size = Vector2(160, 40)

	_hide_all()


func _gradient_band(pos: Vector2, h: int, from_bottom: bool) -> TextureRect:
	var g := Gradient.new()
	if from_bottom:
		g.set_color(0, Color(0, 0, 0, 0.0))
		g.set_color(1, Color(0, 0, 0, 0.88))
	else:
		g.set_color(0, Color(0, 0, 0, 0.80))
		g.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 8
	gt.height = 256
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = pos
	tr.size = Vector2(1920, h)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	return tr


func _mk_label(col: Color, size: int, width: float, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", FONT_B)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 9)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func _hide_all() -> void:
	for n in [caption, move_tag, clock_w, clock_b, title_big, title_sub, end_lbl, end_sub, end_scrim]:
		(n as CanvasItem).visible = false
	title_rule.visible = false
	eval_bg.visible = false
	eval_white.visible = false
	eval_black.visible = false
	eval_line.visible = false
	eval_lbl.visible = false


func _fade(l: CanvasItem, a: float) -> void:
	l.visible = a > 0.002
	l.modulate.a = clampf(a, 0.0, 1.0)


func update(t: float) -> void:
	# реплика
	var text := TL.caption_at(t)
	if text == "":
		_fade(caption, 0.0)
	else:
		var a := 1.0
		for c in TL.CAPTIONS:
			if String(c[2]) == text:
				var t0 := float(c[0])
				var t1 := float(c[1])
				a = minf(clampf((t - t0) / 0.28, 0.0, 1.0), clampf((t1 - t) / 0.28, 0.0, 1.0))
				break
		caption.text = text
		_fade(caption, a)

	# нотация
	var tag := TL.move_tag_at(t)
	if tag == "":
		_fade(move_tag, 0.0)
	else:
		move_tag.text = tag
		_fade(move_tag, 1.0)

	# часы
	var show_clock := t >= 18.0 and t < 170.0
	_fade(clock_w, 0.85 if show_clock else 0.0)
	_fade(clock_b, 0.85 if show_clock else 0.0)
	var wsec := 900.0 - maxf(0.0, (t - 26.0)) * 4.1
	wsec = maxf(wsec, 318.0)
	clock_w.text = "%d:%02d  белые" % [int(wsec) / 60, int(wsec) % 60]
	clock_b.text = "%d:%02d  чёрные" % [14, 52 - int(maxf(0.0, t - 26.0) / 30.0)]

	# eval
	var show_eval := t >= 18.0 and t < 170.0
	var ev := TL.eval_at(t)
	var frac := (ev + 1.0) * 0.5  # 0 = чёрные, 1 = белые
	var boundary := 250.0 + 520.0 * (1.0 - frac)
	eval_white.position.y = boundary
	eval_white.size.y = maxf(0.0, 770.0 - boundary)
	eval_black.position.y = 250.0
	eval_black.size.y = maxf(0.0, boundary - 250.0)
	eval_line.position.y = boundary - 1.0
	if ev <= -0.999:
		eval_lbl.text = "−M1"
	elif ev < 0.0:
		eval_lbl.text = "−0.1"
	else:
		eval_lbl.text = "0.0"
	for n in [eval_bg, eval_white, eval_black, eval_line, eval_lbl]:
		_fade(n, 0.9 if show_eval else 0.0)
	_fade(top_band, 1.0 if show_clock else 0.0)
	_fade(bot_band, 1.0 if text != "" else 0.0)

	# титул
	var ta := minf(clampf((t - TL.TITLE_T0) / 0.6, 0.0, 1.0), clampf((TL.TITLE_T1 - t) / 0.6, 0.0, 1.0))
	if ta > 0.0:
		var dx := (1.0 - ta) * 26.0
		title_big.position.x = 160 + dx
		title_sub.position.x = 160 + dx
		title_rule.size.x = 400.0 * ta
		title_rule.position.x = 960.0 - title_rule.size.x * 0.5
	title_big.text = "11 ХОДОВ"
	_fade(title_big, ta)
	_fade(title_sub, ta * 0.95)
	_fade(title_rule, ta)

	# финальная плашка
	var ea := minf(clampf((t - TL.END_T0 - 0.8) / 1.2, 0.0, 1.0), clampf((179.6 - t) / 0.8, 0.0, 1.0))
	_fade(end_lbl, ea)
	_fade(end_sub, ea * 0.9)
	_fade(end_scrim, ea * 0.9)

	# лёгкая виньетка уже нарисована градиентом
