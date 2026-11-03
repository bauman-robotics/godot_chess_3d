extends RefCounted
## Данные ролика: расписание ходов, планы камеры, реплики.
## Всё в секундах от начала. 180.0 с = 5400 кадров при 30 fps.

const FPS := 30.0
const HAS_CLOCK := true
const HAS_EVAL := true
const TITLE_TEXT := "11 ХОДОВ"
const TITLE_SUB := "мастер-класс по скоростному поражению"
const END_MAIN := "0 — 1"
const END_SUB := "11 ходов. 15 очков рейтинга. 0 понимания."
const TOTAL := 180.0
const MOVE_DUR := 1.15
const MATE_T := 158.0

# Время начала анимации для каждого полухода (22 полухода)
const SCHEDULE := [
	28.5, 36.5, 44.5, 48.5, 54.5, 58.5, 66.5, 69.5, 77.0, 80.0,
	86.5, 90.5, 96.5, 99.5, 104.5, 108.0, 114.5, 118.0, 128.5, 138.5,
	149.0, 158.0,
]

# Планы. t0/t1 — границы, kind — тип движения камеры.
const SHOTS := [
	{"id": "S1", "t0": 0.0, "t1": 9.0, "kind": "dust"},
	{"id": "S2", "t0": 9.0, "t1": 18.0, "kind": "crane"},
	{"id": "S3", "t0": 18.0, "t1": 26.0, "kind": "wide"},
	{"id": "S4", "t0": 26.0, "t1": 34.0, "kind": "follow", "sq": "e2", "dist": 5.0, "az": 30.0, "el": 24.0, "fov": 30.0},
	{"id": "S5", "t0": 34.0, "t1": 42.0, "kind": "wide"},
	{"id": "S6", "t0": 42.0, "t1": 52.0, "kind": "follow", "sq": "g1", "dist": 5.2, "az": 34.0, "el": 22.0, "fov": 31.0},
	{"id": "S7", "t0": 52.0, "t1": 64.0, "kind": "follow", "sq": "e2", "dist": 5.0, "az": 26.0, "el": 26.0, "fov": 31.0},
	{"id": "S8", "t0": 64.0, "t1": 74.0, "kind": "low", "az": -1.0},
	{"id": "S9", "t0": 74.0, "t1": 84.0, "kind": "follow", "sq": "e1", "dist": 5.8, "az": 30.0, "el": 22.0, "fov": 33.0},
	{"id": "S10", "t0": 84.0, "t1": 94.0, "kind": "low", "az": 1.0},
	{"id": "S11", "t0": 94.0, "t1": 102.0, "kind": "wide"},
	{"id": "S12", "t0": 102.0, "t1": 112.0, "kind": "follow", "sq": "g1", "dist": 4.8, "az": 32.0, "el": 24.0, "fov": 30.0},
	{"id": "S13", "t0": 112.0, "t1": 126.0, "kind": "hfile"},
	{"id": "S14", "t0": 126.0, "t1": 136.0, "kind": "low", "az": -1.0},
	{"id": "S15", "t0": 136.0, "t1": 146.0, "kind": "push", "sq": "d8"},
	{"id": "S16", "t0": 146.0, "t1": 156.0, "kind": "follow", "sq": "b2", "dist": 5.4, "az": 28.0, "el": 26.0, "fov": 32.0},
	{"id": "S17", "t0": 156.0, "t1": 170.0, "kind": "mate", "sq": "d8"},
	{"id": "S18", "t0": 170.0, "t1": 180.0, "kind": "top"},
]

# Реплики: [начало, конец, текст]
const CAPTIONS := [
	[0.8, 8.4, "27 октября 2026. Рапид. Пятнадцать минут на партию."],
	[9.6, 17.4, "И примерно девяносто секунд на то, чтобы понять, что происходит."],
	[18.6, 25.4, "Белые — 1498. Чёрные — 1513. Пятнадцать очков разницы."],
	[27.2, 33.4, "e4. Белые заявляют: «я здесь главный»."],
	[35.2, 41.4, "c6. Чёрные заявляют: «я здесь бухгалтер»."],
	[43.2, 47.4, "Каро-Канн. Назван в честь города, где никто никуда не спешил."],
	[53.0, 57.2, "Единственный размен по обоюдному согласию."],
	[58.2, 63.4, "Дальше — только односторонние решения."],
	[65.2, 73.4, "Слон на e2. Скромно. Как зонтик в пустыне."],
	[75.2, 83.4, "Рокировка. Король уходит на g1. Поближе к h2. Мы ещё вернёмся."],
	[85.2, 93.4, "У белых — пешечный центр. У чёрных — конь на c6. У каждого своё хобби."],
	[95.2, 101.4, "c3 и e6. Обе стороны готовятся. К чему — станет ясно позже."],
	[103.2, 111.4, "Конь идёт на h4 — атаковать слона. Смело. Глупо. Но смело."],
	[113.2, 125.4, "Белые сами открыли линию h. Своим же конём."],
	[127.2, 135.4, "Конь вернулся на d2. Единственный, кто понял, что происходит."],
	[137.2, 145.4, "Ферзь на d6. Диагональ d6–h2 уже работает. Мат стоит в очереди."],
	[147.2, 155.4, "И вот — b3. Форточка. Для короля. Сарказм в том, что форточка — на h2."],
	[157.2, 169.0, "Ферзь на h2. Ладья h8 смотрит на неё с балкона."],
	[170.4, 173.2, "Мат. Одиннадцать ходов."],
	[173.5, 179.7, "Разница в рейтинге — пятнадцать очков. Разница в понимании — одиннадцать ходов."],
]

# Ходы для подписи в углу: [t_start, san]
const MOVE_TAGS := [
	[26.0, ""], [28.2, "1. e4"], [34.0, ""], [36.2, "1… c6"],
	[42.0, ""], [44.2, "2. Nf3"], [48.2, "2… d5"], [52.0, ""], [54.2, "3. exd5"],
	[58.2, "3… cxd5"], [64.0, ""], [66.2, "4. Be2"], [69.2, "4… Nf6"],
	[74.0, ""], [76.6, "5. O-O"], [79.6, "5… Bf5"], [84.0, ""], [86.2, "6. d4"],
	[90.2, "6… Nc6"], [94.0, ""], [96.2, "7. c3"], [99.2, "7… e6"],
	[102.0, ""], [104.2, "8. Nh4"], [107.6, "8… Bg6"], [112.0, ""],
	[114.2, "9. Nxg6"], [117.6, "9… hxg6"], [126.0, ""], [128.2, "10. Nd2"],
	[136.0, ""], [138.2, "10… Qd6"], [146.0, ""], [148.6, "11. b3?!"],
	[156.0, ""], [158.0, "11… Qxh2#"],
]

const TITLE_T0 := 10.6
const TITLE_T1 := 17.6
const END_T0 := 170.4


static func shot_at(t: float) -> Dictionary:
	for s in SHOTS:
		if t >= float(s["t0"]) and t < float(s["t1"]):
			return s
	return SHOTS[SHOTS.size() - 1]


static func schedule() -> Array:
	return SCHEDULE


static func caption_fade(t: float) -> float:
	for c in CAPTIONS:
		if t >= float(c[0]) and t <= float(c[1]):
			return minf(clampf((t - float(c[0])) / 0.28, 0.0, 1.0), clampf((float(c[1]) - t) / 0.28, 0.0, 1.0))
	return 0.0


static func clock_text(t: float) -> Array:
	var wsec := 900.0 - maxf(0.0, (t - 26.0)) * 4.1
	wsec = maxf(wsec, 318.0)
	return ["%d:%02d  белые" % [int(wsec) / 60, int(wsec) % 60],
			"14:%02d  чёрные" % [52 - int(maxf(0.0, t - 26.0) / 30.0)]]


static func caption_at(t: float) -> String:
	for c in CAPTIONS:
		if t >= float(c[0]) and t <= float(c[1]):
			return String(c[2])
	return ""


static func move_tag_at(t: float) -> String:
	var out := ""
	for m in MOVE_TAGS:
		if t >= float(m[0]):
			out = String(m[1])
	return out


static func ease_in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


static func noise3(t: float, seed: float) -> Vector3:
	return Vector3(
		sin(t * 0.73 + seed) * 0.55 + sin(t * 1.91 + seed * 2.1) * 0.30 + sin(t * 4.13 + seed * 3.7) * 0.15,
		sin(t * 0.61 + seed * 1.3) * 0.50 + sin(t * 2.27 + seed * 2.9) * 0.32 + sin(t * 5.11 + seed * 1.1) * 0.18,
		sin(t * 0.87 + seed * 0.7) * 0.52 + sin(t * 1.63 + seed * 3.3) * 0.30 + sin(t * 3.71 + seed * 2.3) * 0.18)


static func _lerp3(a: Vector3, b: Vector3, u: float) -> Vector3:
	return a.lerp(b, u)


## Позиция камеры вокруг точки: az — азимут в градусах, el — возвышение.
static func _orbit(center: Vector3, dist: float, az_deg: float, el_deg: float) -> Vector3:
	var az := deg_to_rad(az_deg)
	var el := deg_to_rad(el_deg)
	return center + Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)) * dist


## Оценка камеры. follow_pos — мировая позиция отслеживаемой фигуры.
static func camera_at(t: float, follow_pos: Vector3, shot: Dictionary) -> Dictionary:
	var t0 := float(shot["t0"])
	var t1 := float(shot["t1"])
	var u := clampf((t - t0) / maxf(0.001, t1 - t0), 0.0, 1.0)
	var e := ease_in_out(u)
	var pos := Vector3.ZERO
	var tgt := Vector3.ZERO
	var fov := 40.0
	match String(shot["kind"]):
		"dust":
			pos = _lerp3(Vector3(3.05, 2.05, -5.55), Vector3(2.25, 2.30, -4.70), e)
			tgt = _lerp3(Vector3(1.30, 0.00, 1.30), Vector3(1.00, 0.00, 1.00), e)
			fov = 30.0
		"crane":
			pos = _lerp3(Vector3(0.90, 1.05, -8.40), Vector3(0.00, 6.40, -12.20), e)
			tgt = _lerp3(Vector3(0.00, 1.00, -1.20), Vector3(0.00, -0.10, 0.20), e)
			fov = lerpf(46.0, 34.0, e)
		"wide":
			pos = Vector3(0.0, 4.15, -11.9) + noise3(t, 1.0) * 0.06
			tgt = Vector3(0.0, -0.05, 0.0) + noise3(t, 1.7) * 0.02
			fov = 34.0
		"low":
			var side := float(shot.get("az", -1.0))
			pos = Vector3(3.6 * side, 1.32, -7.5) + noise3(t, 2.0) * 0.05
			tgt = Vector3(-0.55 * side, 0.52, -0.45) + noise3(t, 2.6) * 0.02
			fov = 34.0
		"follow":
			var dist := float(shot.get("dist", 5.0))
			var az := float(shot.get("az", 30.0))
			var el := float(shot.get("el", 24.0))
			pos = _orbit(follow_pos, dist, az, el) + noise3(t, 3.0) * 0.045
			tgt = follow_pos + Vector3(0.0, 0.50, 0.0)
			fov = float(shot.get("fov", 31.0))
		"hfile":
			pos = _lerp3(Vector3(6.45, 2.45, -6.70), Vector3(5.95, 2.25, -4.30), e) + noise3(t, 4.0) * 0.03
			tgt = _lerp3(Vector3(3.45, 0.45, -2.40), Vector3(3.45, 0.40, 0.20), e)
			fov = lerpf(34.0, 36.0, e)
		"push":
			pos = Vector3(2.30, 2.45, -8.85) + Vector3(-0.25, -0.12, 0.55) * e + noise3(t, 5.0) * 0.04
			tgt = Vector3(0.55, 0.48, -0.15)
			fov = lerpf(35.0, 31.0, e)
		"mate":
			var cam_a := follow_pos + Vector3(3.15, 2.45, -4.70)
			var tgt_a := follow_pos + Vector3(0.0, 0.50, 0.0)
			var w := ease_in_out(clampf((t - 160.6) / 6.4, 0.0, 1.0))
			var cam_b := Vector3(3.30, 4.30, -9.10)
			var tgt_b := Vector3(2.55, 0.05, 2.10)
			pos = _lerp3(cam_a, cam_b, w) + noise3(t, 6.0) * 0.035
			tgt = _lerp3(tgt_a, tgt_b, w)
			fov = lerpf(33.0, 39.0, w)
		"top":
			pos = Vector3(0.0, 11.10, 0.30) + noise3(t, 7.0) * 0.03
			tgt = Vector3(0.0, 0.0, 0.0)
			fov = 47.0
	return {"pos": pos, "target": tgt, "fov": fov}


## Значение eval-бара: -1 (чёрные) … +1 (белые). Сарказм в том, что он стоит.
static func eval_at(t: float) -> float:
	if t < 138.0:
		return 0.02
	if t < MATE_T:
		return -0.08
	if t < 160.6:
		return -0.35
	return -1.0
