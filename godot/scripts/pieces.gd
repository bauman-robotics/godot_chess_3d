extends RefCounted
## Процедурные фигуры. Стилизованный Стаунтон: тяжёлое основание, тонкая шейка,
## читаемая голова. Всё строится из лате-профилей, сфер и экструзий.

const MeshBuilder := preload("res://scripts/meshbuilder.gd")

# Основание: широкий диск с мягким переходом в шейку
const BASE := [
	Vector2(0.000, 0.000), Vector2(0.290, 0.000), Vector2(0.312, 0.012),
	Vector2(0.315, 0.046), Vector2(0.300, 0.074), Vector2(0.256, 0.096),
	Vector2(0.216, 0.115), Vector2(0.192, 0.140),
]

const HEIGHTS := {
	"p": 0.94, "r": 1.10, "n": 1.32, "b": 1.45, "q": 1.62, "k": 1.82,
}

static var _cache := {}


static func build(piece_type: String) -> ArrayMesh:
	if _cache.has(piece_type):
		return _cache[piece_type]
	var mb := MeshBuilder.new()
	match piece_type:
		"p": _pawn(mb)
		"r": _rook(mb)
		"n": _knight(mb)
		"b": _bishop(mb)
		"q": _queen(mb)
		"k": _king(mb)
		_: _pawn(mb)
	var mesh := mb.commit(null)
	_cache[piece_type] = mesh
	return mesh


static func height(piece_type: String) -> float:
	return HEIGHTS.get(piece_type, 1.0)


static func P(a: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in a:
		p.push_back(v)
	return p


static func _pawn(mb) -> void:
	mb.lathe(P(BASE), 40)
	mb.lathe(P([
		Vector2(0.192, 0.140), Vector2(0.168, 0.176), Vector2(0.152, 0.222),
		Vector2(0.142, 0.286), Vector2(0.136, 0.356), Vector2(0.135, 0.414),
		Vector2(0.142, 0.446), Vector2(0.162, 0.468), Vector2(0.181, 0.484),
		Vector2(0.178, 0.500), Vector2(0.160, 0.514), Vector2(0.132, 0.528),
		Vector2(0.116, 0.548), Vector2(0.110, 0.574), Vector2(0.115, 0.598),
		Vector2(0.126, 0.620), Vector2(0.120, 0.646), Vector2(0.103, 0.672),
		Vector2(0.086, 0.700), Vector2(0.076, 0.724),
	]), 32)
	mb.sphere(Vector3(0, 0.795, 0), 0.134, Transform3D.IDENTITY, 14, 28)


static func _rook(mb) -> void:
	mb.lathe(P(BASE), 40)
	mb.lathe(P([
		Vector2(0.192, 0.140), Vector2(0.204, 0.176), Vector2(0.212, 0.232),
		Vector2(0.218, 0.310), Vector2(0.222, 0.400), Vector2(0.226, 0.500),
		Vector2(0.232, 0.590), Vector2(0.244, 0.650), Vector2(0.268, 0.692),
		Vector2(0.300, 0.720), Vector2(0.318, 0.750), Vector2(0.322, 0.800),
		Vector2(0.320, 0.880), Vector2(0.314, 0.930), Vector2(0.300, 0.952),
	]), 40)
	# парапет: невысокая стенка + 6 зубцов
	mb.lathe(P([
		Vector2(0.296, 0.952), Vector2(0.296, 1.010), Vector2(0.282, 1.020),
	]), 40)
	for i in 6:
		var a := TAU * float(i) / 6.0
		var pos := Vector3(cos(a) * 0.274, 1.062, sin(a) * 0.274)
		mb.box(pos, Vector3(0.118, 0.092, 0.086),
			Transform3D(Basis(Vector3.UP, -a), Vector3.ZERO))


static func _knight(mb) -> void:
	mb.lathe(P([
		Vector2(0.192, 0.140), Vector2(0.196, 0.180), Vector2(0.196, 0.240),
		Vector2(0.190, 0.310), Vector2(0.182, 0.380), Vector2(0.172, 0.440),
	]), 32)
	# Шея
	mb.tube([Vector3(0, 0.390, -0.020), Vector3(0, 0.500, 0.000), Vector3(0, 0.610, 0.020),
		Vector3(0, 0.720, 0.045), Vector3(0, 0.820, 0.075), Vector3(0, 0.900, 0.100)],
		[0.172, 0.168, 0.162, 0.156, 0.150, 0.140], 26)
	# Череп
	mb.ellipsoid(Vector3(0, 0.985, 0.110), Vector3(0.138, 0.118, 0.170), 14, 26)
	# Морда
	mb.tube([Vector3(0, 0.962, 0.190), Vector3(0, 0.952, 0.260), Vector3(0, 0.938, 0.320),
		Vector3(0, 0.926, 0.362)],
		[0.082, 0.074, 0.062, 0.042], 20)
	# уши
	for sx in [-1.0, 1.0]:
		mb.lathe(P([Vector2(0.040, 0.0), Vector2(0.030, 0.060), Vector2(0.016, 0.110),
			Vector2(0.000, 0.150)]), 10,
			Transform3D(Basis(Vector3.BACK, -sx * 0.24), Vector3(sx * 0.060, 1.045, 0.052)))
	# грива
	mb.tube([Vector3(0, 0.450, -0.185), Vector3(0, 0.580, -0.192), Vector3(0, 0.710, -0.176),
		Vector3(0, 0.840, -0.140), Vector3(0, 0.940, -0.086), Vector3(0, 0.995, -0.030)],
		[0.050, 0.052, 0.050, 0.044, 0.036, 0.024], 16)
	# чёлка
	mb.ellipsoid(Vector3(0, 1.030, 0.155), Vector3(0.055, 0.045, 0.070), 8, 14)

## Экструзия с округлым профилем: слои масштабируются как эллипс.
static func _extrude_round(mb, poly: PackedVector2Array, thickness: float, layers: int,
		xf: Transform3D) -> void:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= float(poly.size())
	var rings := []
	for j in layers + 1:
		var t := -1.0 + 2.0 * float(j) / float(layers)
		var z := t * thickness * 0.5
		var sc := sqrt(maxf(0.03, 1.0 - t * t))
		var ring := PackedVector3Array()
		for p in poly:
			var q: Vector2 = c + (p - c) * sc
			ring.push_back(xf * Vector3(q.x, q.y, z))
		rings.push_back(ring)
	mb.loft(rings, true, true)


static func _ellipse_ring(y: float, cz: float, rx: float, rz: float, n: int) -> PackedVector3Array:
	var r := PackedVector3Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		r.push_back(Vector3(rx * cos(a), y, cz + rz * sin(a)))
	return r


static func _bishop(mb) -> void:
	mb.lathe(P(BASE), 40)
	mb.lathe(P([
		Vector2(0.192, 0.140), Vector2(0.172, 0.178), Vector2(0.156, 0.226),
		Vector2(0.146, 0.300), Vector2(0.140, 0.380), Vector2(0.138, 0.460),
		Vector2(0.142, 0.520), Vector2(0.156, 0.560), Vector2(0.180, 0.590),
		Vector2(0.194, 0.612), Vector2(0.190, 0.632), Vector2(0.172, 0.650),
		Vector2(0.146, 0.668), Vector2(0.132, 0.700), Vector2(0.126, 0.744),
		Vector2(0.130, 0.782), Vector2(0.142, 0.812), Vector2(0.150, 0.840),
	]), 32)
	# митра — выше и острее
	mb.lathe(P([
		Vector2(0.108, 0.840), Vector2(0.128, 0.886), Vector2(0.150, 0.948),
		Vector2(0.166, 1.016), Vector2(0.174, 1.086), Vector2(0.170, 1.156),
		Vector2(0.156, 1.220), Vector2(0.132, 1.276), Vector2(0.098, 1.322),
		Vector2(0.058, 1.352), Vector2(0.000, 1.364),
	]), 32)
	mb.sphere(Vector3(0, 1.404, 0), 0.044, Transform3D.IDENTITY, 10, 20)
	mb.box(Vector3(0.070, 1.196, 0), Vector3(0.176, 0.024, 0.058),
		Transform3D(Basis(Vector3.BACK, -0.52), Vector3.ZERO))


static func _queen(mb) -> void:
	mb.lathe(P(BASE), 40)
	mb.lathe(P([
		Vector2(0.192, 0.140), Vector2(0.178, 0.180), Vector2(0.164, 0.240),
		Vector2(0.154, 0.320), Vector2(0.148, 0.410), Vector2(0.144, 0.510),
		Vector2(0.142, 0.610), Vector2(0.144, 0.700), Vector2(0.152, 0.770),
		Vector2(0.170, 0.820), Vector2(0.196, 0.852), Vector2(0.208, 0.872),
		Vector2(0.204, 0.888), Vector2(0.184, 0.902), Vector2(0.156, 0.916),
		Vector2(0.136, 0.940), Vector2(0.130, 0.972), Vector2(0.136, 1.000),
		Vector2(0.146, 1.022), Vector2(0.142, 1.044), Vector2(0.126, 1.062),
	]), 36)
	# корона
	mb.lathe(P([
		Vector2(0.126, 1.062), Vector2(0.154, 1.086), Vector2(0.184, 1.120),
		Vector2(0.198, 1.160), Vector2(0.198, 1.202), Vector2(0.186, 1.230),
		Vector2(0.166, 1.246),
	]), 36)
	for i in 9:
		var a := TAU * float(i) / 9.0
		mb.sphere(Vector3(cos(a) * 0.176, 1.272, sin(a) * 0.176), 0.034,
			Transform3D.IDENTITY, 6, 12)
	mb.sphere(Vector3(0, 1.336, 0), 0.086, Transform3D.IDENTITY, 12, 24)


static func _king(mb) -> void:
	mb.lathe(P(BASE), 40)
	mb.lathe(P([
		Vector2(0.192, 0.140), Vector2(0.180, 0.182), Vector2(0.168, 0.246),
		Vector2(0.158, 0.330), Vector2(0.150, 0.430), Vector2(0.146, 0.540),
		Vector2(0.144, 0.650), Vector2(0.146, 0.750), Vector2(0.154, 0.826),
		Vector2(0.174, 0.880), Vector2(0.200, 0.914), Vector2(0.212, 0.934),
		Vector2(0.208, 0.950), Vector2(0.188, 0.964), Vector2(0.160, 0.978),
		Vector2(0.140, 1.002), Vector2(0.134, 1.034), Vector2(0.140, 1.062),
		Vector2(0.150, 1.084), Vector2(0.146, 1.106), Vector2(0.130, 1.124),
	]), 36)
	mb.lathe(P([
		Vector2(0.130, 1.124), Vector2(0.158, 1.148), Vector2(0.188, 1.182),
		Vector2(0.202, 1.222), Vector2(0.202, 1.262), Vector2(0.190, 1.290),
		Vector2(0.170, 1.306),
	]), 36)
	mb.lathe(P([
		Vector2(0.170, 1.306), Vector2(0.120, 1.322), Vector2(0.082, 1.338),
		Vector2(0.062, 1.352),
	]), 36)
	# крест
	mb.box(Vector3(0, 1.452, 0), Vector3(0.058, 0.212, 0.058))
	mb.box(Vector3(0, 1.500, 0), Vector3(0.172, 0.056, 0.058))


## Экструзия с фаской: три слоя, края скруглены.
static func _extrude_beveled(mb, poly: PackedVector2Array, thickness: float,
		bevel: float, xf: Transform3D) -> void:
	var t := thickness
	# центральный слой
	mb.extrude(poly, t * 0.62, xf)
	# два внешних слоя с уменьшенным контуром (смещение к центру масс)
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= float(poly.size())
	var inner := PackedVector2Array()
	for p in poly:
		inner.push_back(c + (p - c) * (1.0 - bevel / maxf(0.001, (p - c).length())))
	inner = _clean_poly(inner)
	var shift := t * 0.19
	mb.extrude(inner, t * 0.24, xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, shift)))
	mb.extrude(inner, t * 0.24, xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -shift)))


static func _clean_poly(poly: PackedVector2Array) -> PackedVector2Array:
	# убираем слишком близкие точки, иначе триангулятор ругается
	var out := PackedVector2Array()
	for p in poly:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.004:
			out.push_back(p)
	return out


static func triangles() -> int:
	var total := 0
	for k in ["p", "r", "n", "b", "q", "k"]:
		total += build(k).get_faces().size() / 3
	return total
