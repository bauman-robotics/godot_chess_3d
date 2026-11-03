extends RefCounted
## Таймлайн «Партии века»: 82 полухода, якорные планы, новые типы камеры.
## Время — единственный вход; расписание вычисляется из длительностей тактов.

const TOTAL := 296.0
const INTRO := 24.0
const FPS := 30.0
const HAS_CLOCK := false
const HAS_EVAL := false
const TITLE_TEXT := "ПАРТИЯ ВЕКА"
const TITLE_SUB := "Бобби Фишер, 13 лет. Нью-Йорк, 1956"
const END_MAIN := "0 — 1"
const END_SUB := "41 ход. 13 лет. Партия века."

# Длительность такта (сек) по номеру полухода
static func _beat(ply: int) -> float:
	if ply <= 32:
		return 2.45
	if ply <= 35:
		return 11.0
	if ply <= 45:
		return 4.2
	if ply <= 80:
		return 2.55
	return 9.0


static func schedule() -> Array:
	var out := []
	var t := INTRO
	for ply in range(1, 83):
		out.append(t)
		t += _beat(ply)
	return out


# Отрезки: p0..p1 — полуходы, kind — тип плана
const SEGMENTS := [
	{"p0": 1, "p1": 4, "kind": "orbit", "az0": 47.0},
	{"p0": 5, "p1": 8, "kind": "track", "off": 3.2},
	{"p0": 9, "p1": 12, "kind": "crane"},
	{"p0": 13, "p1": 16, "kind": "orbit", "az0": -2.0},
	{"p0": 17, "p1": 20, "kind": "track", "off": -3.2},
	{"p0": 21, "p1": 24, "kind": "close", "sq": "c5"},
	{"p0": 25, "p1": 28, "kind": "orbit", "az0": 50.0},
	{"p0": 29, "p1": 32, "kind": "crane"},
	{"p0": 33, "p1": 33, "kind": "close", "sq": "f8"},
	{"p0": 34, "p1": 34, "kind": "freeze", "sq": "d8"},
	{"p0": 35, "p1": 35, "kind": "close", "sq": "c5"},
	{"p0": 36, "p1": 45, "kind": "chase", "sq": "e1"},
	{"p0": 46, "p1": 49, "kind": "orbit", "az0": 6.0},
	{"p0": 50, "p1": 53, "kind": "track", "off": 3.0},
	{"p0": 54, "p1": 57, "kind": "crane"},
	{"p0": 58, "p1": 61, "kind": "orbit", "az0": 45.0},
	{"p0": 62, "p1": 65, "kind": "track", "off": -3.0},
	{"p0": 66, "p1": 69, "kind": "orbit", "az0": -4.0},
	{"p0": 70, "p1": 73, "kind": "close", "sq": "g3"},
	{"p0": 74, "p1": 77, "kind": "crane"},
	{"p0": 78, "p1": 80, "kind": "orbit", "az0": 44.0},
	{"p0": 81, "p1": 81, "kind": "close", "sq": "c1"},
	{"p0": 82, "p1": 82, "kind": "top"},
]

const END_T0 := 284.6
# «А если бы взял слона» — призрачный вариант внутри кадра
const WHATIF_T0 := 127.4
const WHATIF_T1 := 135.1
const WHATIF_MOVES := [
	{"t": 0.00, "from": "c4", "to": "e6"},
	{"t": 1.15, "from": "b6", "to": "b5"},
	{"t": 2.30, "from": "e6", "to": "c4"},
	{"t": 3.45, "from": "b5", "to": "c4"},
	{"t": 4.60, "from": "f1", "to": "g1"},
	{"t": 5.75, "from": "c3", "to": "e2"},
]


static func whatif_active(t: float) -> bool:
	return t >= WHATIF_T0 and t <= WHATIF_T1


static func whatif_moves() -> Array:
	return WHATIF_MOVES
const TITLE_T0 := 12.0
const TITLE_T1 := 21.0

static var _sched := []
static var _moves := []
static var _free := []
static var _ply_caps := []


static func set_game(data: Dictionary) -> void:
	_moves = data["moves"]
	var f := FileAccess.open("res://data/captions_v2.json", FileAccess.READ)
	if f:
		var j = JSON.parse_string(f.get_as_text())
		_free = j["free"]
		_ply_caps = j["ply"]


static func moves() -> Array:
	return _moves


static func ply_time(ply: int) -> float:
	if _sched.is_empty():
		_sched = schedule()
	return _sched[ply - 1]


static func shot_at(t: float) -> Dictionary:
	return segment_at(t)


static func segment_at(t: float) -> Dictionary:
	var s := schedule()
	for seg in SEGMENTS:
		var t0: float = s[seg["p0"] - 1] - 0.15
		var t1: float = (s[seg["p1"]] - 0.15) if seg["p1"] < 82 else TOTAL
		if t >= t0 and t < t1:
			var out: Dictionary = seg.duplicate()
			out["t0"] = t0
			out["t1"] = t1
			return out
	var last: Dictionary = SEGMENTS[SEGMENTS.size() - 1].duplicate()
	last["t0"] = s[81] - 0.15
	last["t1"] = TOTAL
	return last


static func caption_fade(t: float) -> float:
	for c in _free:
		if t >= float(c[0]) and t <= float(c[1]):
			return minf(clampf((t - float(c[0])) / 0.28, 0.0, 1.0), clampf((float(c[1]) - t) / 0.28, 0.0, 1.0))
	var s := schedule()
	for c in _ply_caps:
		var p0 := int(c[0])
		var p1 := int(c[1])
		var t0: float = s[p0 - 1]
		var t1: float = (s[p1] + _beat(p1)) if p1 < 82 else (s[81] + _beat(82))
		if t >= t0 and t <= t1:
			return minf(clampf((t - t0) / 0.28, 0.0, 1.0), clampf((t1 - t) / 0.28, 0.0, 1.0))
	return 0.0


static func caption_at(t: float) -> String:
	for c in _free:
		if t >= float(c[0]) and t <= float(c[1]):
			return String(c[2])
	var s := schedule()
	for c in _ply_caps:
		var p0 := int(c[0])
		var p1 := int(c[1])
		var t0: float = s[p0 - 1] - 0.1
		var t1: float = (s[p1] - 0.1) if p1 < 82 else s[81] + 9.0
		if t >= t0 and t <= t1:
			return String(c[2])
	return ""


static func move_tag_at(t: float) -> String:
	if _moves.is_empty():
		return ""
	var s := schedule()
	var idx := -1
	for i in range(82):
		if t >= s[i] - 0.05:
			idx = i
	if idx < 0:
		return ""
	var m: Dictionary = _moves[idx]
	var num := int(m["num"])
	var dots := "." if String(m["side"]) == "w" else "…"
	return "%d%s %s" % [num, dots, String(m["san"])]


static func clock_text(t: float) -> Array:
	if _moves.is_empty():
		return ["", ""]
	var s := schedule()
	var idx := 0
	for i in range(82):
		if t >= s[i] - 0.05:
			idx = i
	var num := int(_moves[idx]["num"])
	return ["ход %d / 41" % num, ""]


static func eval_at(t: float) -> float:
	return 0.0


static func ease_in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


static func noise3(t: float, seed: float) -> Vector3:
	return Vector3(
		sin(t * 0.73 + seed) * 0.55 + sin(t * 1.91 + seed * 2.1) * 0.30 + sin(t * 4.13 + seed * 3.7) * 0.15,
		sin(t * 0.61 + seed * 1.3) * 0.50 + sin(t * 2.27 + seed * 2.9) * 0.32 + sin(t * 5.11 + seed * 1.1) * 0.18,
		sin(t * 0.87 + seed * 0.7) * 0.52 + sin(t * 1.63 + seed * 3.3) * 0.30 + sin(t * 3.71 + seed * 2.3) * 0.18)


# --- камера ------------------------------------------------------------

const ANCHOR_AZ := 15.0
const ANCHOR_EL := 50.0
const ANCHOR_DIST := 13.6
const ANCHOR_TGT := Vector3(0.0, 0.0, 1.0)
const ANCHOR_FOV := 42.0


static func _sq(sq: String) -> Vector3:
	var f := sq.unicode_at(0) - 97
	var r := int(sq[1])
	return Vector3(float(f) - 3.5, 0.0, float(8 - r) - 3.5)


static func _orbit_pos(az_deg: float, el_deg: float, dist: float) -> Vector3:
	var az := deg_to_rad(az_deg)
	var el := deg_to_rad(el_deg)
	return ANCHOR_TGT + Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el)) * dist


static func _anchor() -> Dictionary:
	return {"pos": _orbit_pos(ANCHOR_AZ, ANCHOR_EL, ANCHOR_DIST), "target": ANCHOR_TGT, "fov": ANCHOR_FOV}


## Оценка камеры. follow_pos — позиция фигуры для chase.
static func camera_at(t: float, follow_pos: Vector3, seg: Dictionary) -> Dictionary:
	if whatif_active(t):
		return {"pos": _orbit_pos(ANCHOR_AZ + 9.0, 46.0, 11.6), "target": ANCHOR_TGT, "fov": 40.0}
	var t0 := float(seg.get("t0", 0.0))
	var t1 := float(seg.get("t1", TOTAL))
	var u := clampf((t - t0) / maxf(0.001, t1 - t0), 0.0, 1.0)
	var kind := String(seg["kind"])
	var anchor := _anchor()

	# «заморозка» на ход века: медленный наезд, без отъезда
	if kind == "freeze":
		var c: Vector3 = _sq(String(seg.get("sq", "d8")))
		var a: Vector3 = c + Vector3(2.7, 2.3, -3.7)
		var b: Vector3 = c + Vector3(2.0, 2.0, -2.9)
		return {"pos": a.lerp(b, ease_in_out(u)), "target": c + Vector3(0, 0.6, 0), "fov": lerpf(34.0, 29.0, u)}

	# к якорю приходим к 78% отрезка, дальше держим
	var e := ease_in_out(clampf(u / 0.78, 0.0, 1.0))
	var pos: Vector3 = anchor["pos"]
	var tgt: Vector3 = anchor["target"]
	var fov: float = anchor["fov"]

	match kind:
		"orbit":
			var az: float = float(seg.get("az0", ANCHOR_AZ + 20.0))
			pos = _orbit_pos(lerpf(az, ANCHOR_AZ, e), lerpf(48.0, ANCHOR_EL, e), lerpf(13.8, ANCHOR_DIST, e))
			fov = lerpf(42.0, ANCHOR_FOV, e)
		"track":
			var off: float = float(seg.get("off", 3.0))
			var a: Vector3 = _orbit_pos(ANCHOR_AZ, ANCHOR_EL - 6.0, ANCHOR_DIST + 1.2)
			var b: Vector3 = anchor["pos"]
			var lateral := Vector3(off, -1.1, 0.8) * (1.0 - e)
			pos = a.lerp(b, e) + lateral
			fov = lerpf(43.0, ANCHOR_FOV, e)
		"crane":
			var a: Vector3 = _orbit_pos(ANCHOR_AZ + 12.0, 26.0, 15.0)
			pos = a.lerp(anchor["pos"], ease_in_out(clampf(u / 0.82, 0.0, 1.0)))
			tgt = Vector3(0.0, 1.0, 0.4).lerp(ANCHOR_TGT, ease_in_out(clampf(u / 0.82, 0.0, 1.0)))
			fov = lerpf(46.0, ANCHOR_FOV, e)
		"close":
			var c: Vector3 = _sq(String(seg.get("sq", "e4")))
			var a: Vector3 = c + Vector3(2.9, 2.4, -3.9)
			var tc: Vector3 = c + Vector3(0, 0.55, 0)
			var w := ease_in_out(clampf((u - 0.62) / 0.38, 0.0, 1.0))
			pos = a.lerp(anchor["pos"], w)
			tgt = tc.lerp(ANCHOR_TGT, w)
			fov = lerpf(33.0, ANCHOR_FOV, w)
		"chase":
			var center: Vector3 = follow_pos
			var ang := lerpf(-40.0, 110.0, ease_in_out(u))
			var rad := lerpf(5.6, 5.0, u)
			var a: Vector3 = center + Vector3(sin(deg_to_rad(ang)) * rad, 3.0, -cos(deg_to_rad(ang)) * rad)
			pos = a.lerp(anchor["pos"], ease_in_out(clampf((u - 0.82) / 0.18, 0.0, 1.0)))
			tgt = (center + Vector3(0, 0.5, 0)).lerp(ANCHOR_TGT, ease_in_out(clampf((u - 0.82) / 0.18, 0.0, 1.0)))
			fov = lerpf(38.0, ANCHOR_FOV, ease_in_out(clampf((u - 0.82) / 0.18, 0.0, 1.0)))
		"top":
			var c: Vector3 = _sq("c1")
			var a: Vector3 = c + Vector3(3.6, 3.6, -5.2)
			var w := ease_in_out(u)
			pos = anchor["pos"].lerp(a, w)
			tgt = ANCHOR_TGT.lerp(c + Vector3(0, 0.8, 0), w)
			fov = lerpf(ANCHOR_FOV, 35.0, w)

	pos += noise3(t, 11.0) * 0.035
	return {"pos": pos, "target": tgt, "fov": fov}
