extends RefCounted
## Сборщик процедурных мешей: лате, сферы, торы, боксы, экструзия полигона.
## Все примитивы складываются в один ArrayMesh (одна поверхность, один материал).

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var uvs := PackedVector2Array()
var idx := PackedInt32Array()

# Godot считает лицевыми треугольники с часовой намоткой (при взгляде снаружи).
# Поэтому порядок вершин подбирается автоматически по внешней нормали.
const CW_FRONT := true


func _v(p: Vector3, n: Vector3, uv: Vector2) -> int:
	verts.push_back(p)
	norms.push_back(n.normalized() if n.length_squared() > 0.0 else Vector3.UP)
	uvs.push_back(uv)
	return verts.size() - 1


func tri(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO) -> void:
	var g := (b - a).cross(c - a)
	var ref_n := (na + nb + nc) / 3.0
	if CW_FRONT and g.dot(ref_n) > 0.0:
		var tp := b; b = c; c = tp
		var tn := nb; nb = nc; nc = tn
		var tu := ub; ub = uc; uc = tu
	var i := _v(a, na, ua)
	_v(b, nb, ub)
	_v(c, nc, uc)
	idx.push_back(i)
	idx.push_back(i + 1)
	idx.push_back(i + 2)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, ud := Vector2.ZERO) -> void:
	tri(a, b, c, n, n, n, ua, ub, uc)
	tri(a, c, d, n, n, n, ua, uc, ud)


func quad_n(a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3,
		ua := Vector2.ZERO, ub := Vector2.ZERO, uc := Vector2.ZERO, ud := Vector2.ZERO) -> void:
	tri(a, b, c, na, nb, nc, ua, ub, uc)
	tri(a, c, d, na, nc, nd, ua, uc, ud)


func box(center: Vector3, size: Vector3, xf := Transform3D.IDENTITY, uv_scale := 1.0) -> void:
	var h := size * 0.5
	var p := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z),
		Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	for i in p.size():
		p[i] = xf * (p[i] + center)
	var faces := [
		[0, 3, 2, 1, Vector3.BACK], [4, 5, 6, 7, Vector3.FORWARD],
		[0, 1, 5, 4, Vector3.DOWN], [3, 7, 6, 2, Vector3.UP],
		[0, 4, 7, 3, Vector3.LEFT], [1, 2, 6, 5, Vector3.RIGHT],
	]
	for f in faces:
		var n: Vector3 = xf.basis * (f[4] as Vector3)
		quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], n,
			Vector2(0, 0), Vector2(uv_scale, 0), Vector2(uv_scale, uv_scale), Vector2(0, uv_scale))


## Тело вращения. profile — точки (радиус, высота) снизу вверх.
func lathe(profile: PackedVector2Array, segs: int, xf := Transform3D.IDENTITY, uv_scale := 1.0) -> void:
	var n_pts := profile.size()
	if n_pts < 2:
		return
	# нормали профиля
	var seg_normals := PackedVector2Array()
	for i in n_pts - 1:
		var d := profile[i + 1] - profile[i]
		if d.length_squared() < 1e-12:
			seg_normals.push_back(Vector2(1, 0))
			continue
		var nn := Vector2(d.y, -d.x).normalized()
		seg_normals.push_back(nn)

	var rings: Array = []
	for i in n_pts:
		var ring := PackedVector3Array()
		var nring := PackedVector3Array()
		# средняя нормаль в точке (сглаживание)
		var nprev := seg_normals[max(i - 1, 0)]
		var nnext := seg_normals[min(i, n_pts - 2)]
		var n2 := (nprev + nnext)
		if n2.length_squared() < 1e-9:
			n2 = nprev
		n2 = n2.normalized()
		for s in segs + 1:
			var a := TAU * float(s) / float(segs)
			var ca := cos(a)
			var sa := sin(a)
			ring.push_back(xf * Vector3(profile[i].x * ca, profile[i].y, profile[i].x * sa))
			nring.push_back((xf.basis * Vector3(n2.x * ca, n2.y, n2.x * sa)).normalized())
		rings.push_back([ring, nring])

	for i in n_pts - 1:
		var r0: PackedVector3Array = rings[i][0]
		var n0: PackedVector3Array = rings[i][1]
		var r1: PackedVector3Array = rings[i + 1][0]
		var n1: PackedVector3Array = rings[i + 1][1]
		for s in segs:
			var u0 := float(s) / float(segs)
			var u1 := float(s + 1) / float(segs)
			var v0 := profile[i].y * uv_scale
			var v1 := profile[i + 1].y * uv_scale
			quad_n(r0[s], r0[s + 1], r1[s + 1], r1[s],
				n0[s], n0[s + 1], n1[s + 1], n1[s],
				Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1))

	# заглушки, если профиль не сходится в ось
	if profile[0].x > 1e-5:
		var c0 := xf * Vector3(0, profile[0].y, 0)
		var nb := (xf.basis * Vector3.DOWN).normalized()
		for s in segs:
			var a0 := TAU * float(s) / float(segs)
			var a1 := TAU * float(s + 1) / float(segs)
			tri(c0, xf * Vector3(profile[0].x * cos(a0), profile[0].y, profile[0].x * sin(a0)),
				xf * Vector3(profile[0].x * cos(a1), profile[0].y, profile[0].x * sin(a1)),
				nb, nb, nb)
	if profile[n_pts - 1].x > 1e-5:
		var c1 := xf * Vector3(0, profile[n_pts - 1].y, 0)
		var nt := (xf.basis * Vector3.UP).normalized()
		for s in segs:
			var a0 := TAU * float(s) / float(segs)
			var a1 := TAU * float(s + 1) / float(segs)
			tri(c1, xf * Vector3(profile[n_pts - 1].x * cos(a0), profile[n_pts - 1].y,
				profile[n_pts - 1].x * sin(a0)),
				xf * Vector3(profile[n_pts - 1].x * cos(a1), profile[n_pts - 1].y,
				profile[n_pts - 1].x * sin(a1)),
				nt, nt, nt)


func sphere(center: Vector3, radius: float, xf := Transform3D.IDENTITY, rings := 12, segs := 24,
		scale_y := 1.0) -> void:
	var prof := PackedVector2Array()
	for i in rings + 1:
		var a := PI * float(i) / float(rings) - PI * 0.5
		prof.push_back(Vector2(cos(a) * radius, sin(a) * radius * scale_y))
	lathe(prof, segs, xf * Transform3D(Basis.IDENTITY, center))


func torus(center: Vector3, big_r: float, small_r: float, xf := Transform3D.IDENTITY,
		maj := 32, min_s := 12) -> void:
	var prof := PackedVector2Array()
	for i in min_s + 1:
		var a := TAU * float(i) / float(min_s)
		prof.push_back(Vector2(big_r + small_r * cos(a), small_r * sin(a)))
	var m := xf * Transform3D(Basis.IDENTITY, center)
	var off := Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	# тор строим как лате, сдвинутый по Y: профиль описывает окружность вокруг оси
	var base_y := 0.0
	var prof2 := PackedVector2Array()
	for p in prof:
		prof2.push_back(Vector2(p.x, p.y + base_y))
	lathe(prof2, maj, m)


## Экструзия плоского полигона (в плоскости XY) по Z на толщину t.
func extrude(poly: PackedVector2Array, thickness: float, xf := Transform3D.IDENTITY) -> void:
	if poly.size() < 3:
		return
	var half := thickness * 0.5
	var tri_idx := Geometry2D.triangulate_polygon(poly)
	var nz := (xf.basis * Vector3(0, 0, 1)).normalized()
	var nz_neg := (xf.basis * Vector3(0, 0, -1)).normalized()
	for k in range(0, tri_idx.size(), 3):
		var a := xf * Vector3(poly[tri_idx[k]].x, poly[tri_idx[k]].y, half)
		var b := xf * Vector3(poly[tri_idx[k + 1]].x, poly[tri_idx[k + 1]].y, half)
		var c := xf * Vector3(poly[tri_idx[k + 2]].x, poly[tri_idx[k + 2]].y, half)
		tri(a, b, c, nz, nz, nz)
		var a2 := xf * Vector3(poly[tri_idx[k]].x, poly[tri_idx[k]].y, -half)
		var b2 := xf * Vector3(poly[tri_idx[k + 1]].x, poly[tri_idx[k + 1]].y, -half)
		var c2 := xf * Vector3(poly[tri_idx[k + 2]].x, poly[tri_idx[k + 2]].y, -half)
		tri(a2, b2, c2, nz_neg, nz_neg, nz_neg)
	for i in poly.size():
		var p0 := poly[i]
		var p1 := poly[(i + 1) % poly.size()]
		var d := (p1 - p0).normalized()
		var n2 := Vector2(d.y, -d.x)
		var n := (xf.basis * Vector3(n2.x, n2.y, 0)).normalized()
		var A := xf * Vector3(p0.x, p0.y, half)
		var B := xf * Vector3(p1.x, p1.y, half)
		var C := xf * Vector3(p1.x, p1.y, -half)
		var D := xf * Vector3(p0.x, p0.y, -half)
		quad(A, B, C, D, n)


func commit(material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if material:
		mesh.surface_set_material(0, material)
	return mesh


func tris() -> int:
	return idx.size() / 3


## Лофт: набор замкнутых колец одинаковой длины. Нормали сглаживаются по геометрии.
func loft(rings: Array, close_bottom := true, close_top := true) -> void:
	var n_rings := rings.size()
	if n_rings < 2:
		return
	var n := (rings[0] as PackedVector3Array).size()
	var pos := PackedVector3Array()
	var acc := PackedVector3Array()
	var uvs_local := PackedVector2Array()
	for ri in n_rings:
		var r: PackedVector3Array = rings[ri]
		for i in n:
			pos.push_back(r[i])
			acc.push_back(Vector3.ZERO)
			uvs_local.push_back(Vector2(float(i) / float(n), float(ri) / float(n_rings - 1)))
	var base_idx := verts.size()
	var faces := PackedInt32Array()
	for ri in n_rings - 1:
		for i in n:
			var i2 := (i + 1) % n
			var a := ri * n + i
			var b := ri * n + i2
			var c := (ri + 1) * n + i2
			var d := (ri + 1) * n + i
			faces.append_array([a, d, c, a, c, b])
	for k in range(0, faces.size(), 3):
		var ia := faces[k]
		var ib := faces[k + 1]
		var ic := faces[k + 2]
		var fn := (pos[ib] - pos[ia]).cross(pos[ic] - pos[ia])
		acc[ia] += fn
		acc[ib] += fn
		acc[ic] += fn
	for i in pos.size():
		var nn := acc[i]
		if nn.length_squared() < 1e-12:
			nn = Vector3.UP
		nn = nn.normalized()
		# ориентация наружу: от оси кольца
		verts.push_back(pos[i])
		norms.push_back(nn)
		uvs.push_back(uvs_local[i])
	for k in range(0, faces.size(), 3):
		idx.push_back(base_idx + faces[k])
		idx.push_back(base_idx + faces[k + 1])
		idx.push_back(base_idx + faces[k + 2])
	# крышки
	if close_bottom:
		var c0 := Vector3.ZERO
		for i in n:
			c0 += pos[i]
		c0 /= float(n)
		for i in n:
			var i2 := (i + 1) % n
			tri(pos[i], pos[i2], c0, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN)
	if close_top:
		var c1 := Vector3.ZERO
		var off := (n_rings - 1) * n
		for i in n:
			c1 += pos[off + i]
		c1 /= float(n)
		for i in n:
			var i2 := (i + 1) % n
			tri(pos[off + i], pos[off + i2], c1, Vector3.UP, Vector3.UP, Vector3.UP)


## Труба по 3D-кривой: кольца перпендикулярны касательной.
func tube(path: Array, radii: Array, segs: int, xf := Transform3D.IDENTITY) -> void:
	var m := path.size()
	if m < 2:
		return
	var rings: Array = []
	for i in m:
		var p: Vector3 = path[i]
		var t: Vector3
		if i == 0:
			t = (path[1] as Vector3) - p
		elif i == m - 1:
			t = p - (path[m - 2] as Vector3)
		else:
			t = (path[i + 1] as Vector3) - (path[i - 1] as Vector3)
		if t.length_squared() < 1e-9:
			t = Vector3.UP
		t = t.normalized()
		var right := Vector3(1, 0, 0)
		var up := t.cross(right)
		if up.length_squared() < 1e-6:
			right = Vector3(0, 0, 1)
			up = t.cross(right)
		up = up.normalized()
		var r: float = radii[i]
		var ring := PackedVector3Array()
		var nring := PackedVector3Array()
		for s in segs + 1:
			var a := TAU * float(s) / float(segs)
			var dir := right * cos(a) + up * sin(a)
			ring.push_back(xf * (p + dir * r))
			nring.push_back((xf.basis * dir).normalized())
		rings.push_back([ring, nring])
	for i in m - 1:
		var r0: PackedVector3Array = rings[i][0]
		var n0: PackedVector3Array = rings[i][1]
		var r1: PackedVector3Array = rings[i + 1][0]
		var n1: PackedVector3Array = rings[i + 1][1]
		for s in segs:
			quad_n(r0[s], r0[s + 1], r1[s + 1], r1[s],
				n0[s], n0[s + 1], n1[s + 1], n1[s])
	# заглушки
	if (radii[0] as float) > 1e-4:
		var rr: PackedVector3Array = rings[0][0]
		var nn: PackedVector3Array = rings[0][1]
		var c := Vector3.ZERO
		for p in rr:
			c += p
		c /= float(rr.size())
		var cn := (c - (xf * (path[0] as Vector3))).normalized()
		for s in segs:
			tri(rr[s], rr[s + 1], c, nn[s], nn[s + 1], cn)
	if (radii[m - 1] as float) > 1e-4:
		var rr2: PackedVector3Array = rings[m - 1][0]
		var nn2: PackedVector3Array = rings[m - 1][1]
		var c2 := Vector3.ZERO
		for p in rr2:
			c2 += p
		c2 /= float(rr2.size())
		var cn2 := (c2 - (xf * (path[m - 1] as Vector3))).normalized()
		for s in segs:
			tri(rr2[s], rr2[s + 1], c2, nn2[s], nn2[s + 1], cn2)


## Эллипсоид: единичная сфера, растянутая по трём осям.
func ellipsoid(center: Vector3, radii: Vector3, rings := 14, segs := 28) -> void:
	var prof := PackedVector2Array()
	for i in rings + 1:
		var a := PI * float(i) / float(rings) - PI * 0.5
		prof.push_back(Vector2(cos(a), sin(a)))
	var xf := Transform3D(Basis.from_scale(radii), center)
	lathe(prof, segs, xf)
