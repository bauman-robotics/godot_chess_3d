extends Node3D
## Фигура: меш + материал + служебные поля для анимации.

const Pieces := preload("res://scripts/pieces.gd")
const Mat := preload("res://scripts/mat.gd")

var ptype := "p"
var side := "w"
var square := ""
var mesh_inst: MeshInstance3D
var mat: StandardMaterial3D
var home := Vector3.ZERO
var fallen := false
var yaw := 0.0


static func create(t: String, s: String, sq: String) -> Node3D:
	var p = load("res://scripts/piece.gd").new()
	p.ptype = t
	p.side = s
	p.square = sq
	return p


func _ready() -> void:
	home = Vector3.ZERO
	mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = Pieces.build(ptype)
	mat = (Mat.ivory() if side == "w" else Mat.ebony()).duplicate()
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_inst)


func set_square(sq: String, world: Vector3) -> void:
	square = sq
	home = world
	position = world


func place(world: Vector3) -> void:
	home = world
	position = world


func restore() -> void:
	position = home
	rotation = Vector3(0, yaw, 0)
	fallen = false
	visible = true
