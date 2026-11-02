extends Node3D
## Доска: 64 клетки, латунная рамка, координаты, плита-основание.

const MeshBuilder := preload("res://scripts/meshbuilder.gd")
const Mat := preload("res://scripts/mat.gd")
const FONT := preload("res://data/fonts/DejaVuSansCondensed-Bold.ttf")

const FRAME_W := 0.46
const FRAME_H := 0.11
const SQ := 1.0


static func square_to_world(sq: String) -> Vector3:
	## a1 -> (-3.5, 0, +3.5); h8 -> (+3.5, 0, -3.5). Чёрные — на z < 0.
	var f := sq.unicode_at(0) - 97
	var r := int(sq[1])
	return Vector3(float(f) - 3.5, 0.0, float(8 - r) - 3.5)


static func world_to_square(p: Vector3) -> String:
	var f := clampi(int(round(p.x + 3.5)), 0, 7)
	var r := clampi(8 - int(round(p.z + 3.5)), 1, 8)
	return String.chr(97 + f) + str(r)


func build() -> void:
	var mb_light := MeshBuilder.new()
	var mb_dark := MeshBuilder.new()
	for f in 8:
		for r in 8:
			var is_dark := (f + r + 1) % 2 == 0
			var mb = mb_dark if is_dark else mb_light
			var x := float(f) - 3.5
			var z := float(r) - 3.5
			mb.box(Vector3(x, -0.030, z), Vector3(SQ, 0.060, SQ), Transform3D.IDENTITY, 1.0)
	# Рамка
	var mb_frame := MeshBuilder.new()
	var half := 4.0
	var outer := half + FRAME_W
	var fy := FRAME_H * 0.5 - 0.055
	mb_frame.box(Vector3(0, fy, -(half + FRAME_W * 0.5)), Vector3(outer * 2.0, FRAME_H, FRAME_W))
	mb_frame.box(Vector3(0, fy, half + FRAME_W * 0.5), Vector3(outer * 2.0, FRAME_H, FRAME_W))
	mb_frame.box(Vector3(-(half + FRAME_W * 0.5), fy, 0), Vector3(FRAME_W, FRAME_H, half * 2.0))
	mb_frame.box(Vector3(half + FRAME_W * 0.5, fy, 0), Vector3(FRAME_W, FRAME_H, half * 2.0))
	# Плита
	var mb_slab := MeshBuilder.new()
	mb_slab.box(Vector3(0, -0.20, 0), Vector3(outer * 2.0 + 0.10, 0.26, outer * 2.0 + 0.10))

	var m_light := Mat.wood(true)
	var m_dark := Mat.wood(false)

	var mi_light := MeshInstance3D.new()
	mi_light.mesh = mb_light.commit(m_light)
	add_child(mi_light)
	var mi_dark := MeshInstance3D.new()
	mi_dark.mesh = mb_dark.commit(m_dark)
	add_child(mi_dark)

	var mi_frame := MeshInstance3D.new()
	mi_frame.mesh = mb_frame.commit(Mat.brass())
	add_child(mi_frame)

	var mi_slab := MeshInstance3D.new()
	mi_slab.mesh = mb_slab.commit(Mat.dark_wood())
	add_child(mi_slab)

	for m in [mi_light, mi_dark, mi_slab]:
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_build_labels()


func _label(text: String, pos: Vector3, size := 0.30) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = FONT
	l.font_size = 64
	l.pixel_size = size / 64.0 * 1.6
	l.modulate = Color(0.93, 0.86, 0.70)
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.position = pos
	# нормаль вверх, верх глифа — от камеры (к +Z), строки идут вдоль -X
	l.basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	add_child(l)


func _build_labels() -> void:
	var z_near := -(4.0 + FRAME_W * 0.5)
	var z_far := 4.0 + FRAME_W * 0.5
	var x_left := -(4.0 + FRAME_W * 0.5)
	var x_right := 4.0 + FRAME_W * 0.5
	for f in 8:
		var file := String.chr(97 + f)
		var x := float(f) - 3.5
		_label(file, Vector3(x, 0.008, z_near), 0.30)
		_label(file, Vector3(x, 0.008, z_far), 0.26)
	for r in 8:
		var rank := str(r)
		var z := float(8 - r) - 3.5
		_label(rank, Vector3(x_left, 0.008, z), 0.30)
		_label(rank, Vector3(x_right, 0.008, z), 0.30)
