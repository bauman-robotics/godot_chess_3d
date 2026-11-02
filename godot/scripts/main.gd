extends Node3D
## Режиссёр: строит мир, разбирает партию в таймлайн, каждый кадр вычисляет
## состояние фигур, камеры и титров. Никакой физики — всё детерминировано.

const Board := preload("res://scripts/board.gd")
const Pieces := preload("res://scripts/pieces.gd")
const Mat := preload("res://scripts/mat.gd")
const Piece := preload("res://scripts/piece.gd")
const TL := preload("res://scripts/timeline.gd")
const HUD := preload("res://scripts/hud.gd")

var fps := 30.0
var frame := 0
var start_t := 0.0
var max_frames := -1
var quit_at_end := true

var board: Node3D
var camera: Camera3D
var hud: Node
var env: Environment
var pieces := {}     # стартовая клетка -> запись
var by_square := {}  # текущая клетка -> запись


func _ready() -> void:
	_parse_args()
	_build_environment()
	_build_board()
	_build_pieces_from_fen(_start_fen())
	_build_timeline(_load_game())
	_build_floor()
	_build_dust()
	_build_camera()
	_build_hud()
	print("pieces=", pieces.size(), " tris=", Pieces.triangles(), " total=", TL.TOTAL)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--start="):
			start_t = float(a.substr(8))
		elif a.begins_with("--frames="):
			max_frames = int(a.substr(9))


func _load_game() -> Dictionary:
	var f := FileAccess.open("res://data/game.json", FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


func _start_fen() -> String:
	return String(_load_game()["start_fen"])


# ---------------------------------------------------------------- окружение

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.013, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.34, 0.44)
	env.ambient_light_energy = 1.25
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.tonemap_exposure = 0.86
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.2
	env.ssao_power = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.09)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.92
	we.environment = env
	self.env = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.90, 0.78)
	key.light_energy = 1.0
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	key.directional_shadow_max_distance = 30.0
	key.directional_shadow_split_1 = 0.05
	key.directional_shadow_split_2 = 0.15
	key.directional_shadow_split_3 = 0.4
	key.shadow_blur = 2.0
	key.shadow_bias = 0.02
	key.shadow_normal_bias = 1.5
	key.look_at_from_position(Vector3(-5, 9, -6), Vector3(0, 0, 0), Vector3.UP)
	add_child(key)

	var spot := SpotLight3D.new()
	spot.position = Vector3(0.6, 8.6, -0.8)
	spot.light_color = Color(1.0, 0.92, 0.82)
	spot.light_energy = 2.6
	spot.spot_range = 22.0
	spot.spot_angle = 40.0
	spot.spot_angle_attenuation = 0.9
	spot.shadow_enabled = true
	spot.shadow_bias = 0.03
	spot.look_at_from_position(spot.position, Vector3(0, 0, 0.4), Vector3.UP)
	add_child(spot)

	var rim_r := OmniLight3D.new()
	rim_r.position = Vector3(5.0, 2.6, -5.6)
	rim_r.light_color = Color(0.45, 0.62, 1.0)
	rim_r.light_energy = 4.5
	rim_r.omni_range = 16.0
	add_child(rim_r)

	var rim_l := OmniLight3D.new()
	rim_l.position = Vector3(-5.4, 3.0, 4.2)
	rim_l.light_color = Color(0.55, 0.70, 1.0)
	rim_l.light_energy = 4.0
	rim_l.omni_range = 16.0
	add_child(rim_l)

	var camfill := DirectionalLight3D.new()
	camfill.light_color = Color(0.72, 0.80, 1.0)
	camfill.light_energy = 0.78
	camfill.shadow_enabled = false
	camfill.look_at_from_position(Vector3(-2.5, 3.6, -9.0), Vector3(0, 0.4, 0), Vector3.UP)
	add_child(camfill)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 1.1, -6.4)
	fill.light_color = Color(1.0, 0.72, 0.45)
	fill.light_energy = 1.6
	fill.omni_range = 9.0
	add_child(fill)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = Mat.floor()
	mi.position = Vector3(0, -0.33, 0)
	add_child(mi)


func _build_board() -> void:
	board = Board.new()
	add_child(board)
	board.build()


func _build_dust() -> void:
	# Пыль в луче света: медленно плывёт, ловит свет, создаёт глубину
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.93, 0.80, 0.85)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 64
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	mat.albedo_texture = gt
	mat.disable_receive_shadows = true
	mat.no_depth_test = false
	mesh.material = mat

	var d := CPUParticles3D.new()
	d.mesh = mesh
	d.amount = 220
	d.lifetime = 16.0
	d.preprocess = 16.0
	d.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	d.emission_box_extents = Vector3(5.2, 1.6, 5.2)
	d.position = Vector3(0, 1.9, 0)
	d.direction = Vector3(0, 1, 0)
	d.spread = 40.0
	d.gravity = Vector3(0, 0.012, 0)
	d.initial_velocity_min = 0.01
	d.initial_velocity_max = 0.05
	d.scale_amount_min = 0.5
	d.scale_amount_max = 1.6
	d.color = Color(1.0, 0.94, 0.82, 1.0)
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(d)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.05
	camera.far = 120.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 3.55, -10.6), Vector3(0.0, 0.10, 0.05), Vector3.UP)
	camera.current = true


func _build_hud() -> void:
	hud = HUD.new()
	add_child(hud)
	hud.setup()


# ---------------------------------------------------------------- фигуры

func _build_pieces_from_fen(fen: String) -> void:
	var rows := fen.split(" ")[0].split("/")
	for i in 8:
		var rank := 8 - i
		var file := 0
		for ch in rows[i]:
			if ch.to_int() > 0:
				file += ch.to_int()
				continue
			var side := "w" if ch == ch.to_upper() else "b"
			var sq := String.chr(97 + file) + str(rank)
			var p := Piece.create(ch.to_lower(), side, sq)
			add_child(p)
			p.set_square(sq, Board.square_to_world(sq))
			var yaw := (PI if (ch.to_lower() == "n" and side == "w") else 0.0)
			p.yaw = yaw
			p.rotation.y = yaw
			var rec := {
				"node": p, "start": sq, "events": [], "yaw": yaw,
				"cur": Board.square_to_world(sq), "side": side,
			}
			pieces[sq] = rec
			by_square[sq] = rec
			file += 1


func _build_timeline(data: Dictionary) -> void:
	var moves: Array = data["moves"]
	for i in moves.size():
		var mv: Dictionary = moves[i]
		var rec: Dictionary = by_square.get(String(mv["from"]))
		if rec == null:
			push_error("нет фигуры на " + String(mv["from"]))
			continue
		var from := Board.square_to_world(String(mv["from"]))
		var to := Board.square_to_world(String(mv["to"]))
		var t0: float = TL.SCHEDULE[i]
		var dur: float = TL.MOVE_DUR
		var arc := 0.20
		if String(mv["piece"]) == "n":
			arc = 0.40
		if bool(mv["mate"]):
			dur = 2.60
			arc = 0.34
		rec["events"].append({"type": "move", "t0": t0, "dur": dur,
			"from": from, "to": to, "arc": arc})

		# взятие
		var victim = by_square.get(String(mv["to"]))
		if victim != null and victim != rec:
			var dir: Vector3 = (to - from)
			dir.y = 0
			dir = dir.normalized()
			var impact: float = t0 + (dur - 0.14 if bool(mv["mate"]) else 0.42)
			victim["events"].append({"type": "fall", "t0": impact, "dur": 0.62,
				"dir": dir, "pivot": to + dir * 0.24, "side": 1.0})
			by_square.erase(String(mv["to"]))

		# рокировка
		if bool(mv["castle"]):
			var rf := String(mv["rook_from"])
			var rt := String(mv["rook_to"])
			var rook = by_square.get(rf)
			if rook != null:
				rook["events"].append({"type": "move", "t0": t0 + 0.05, "dur": dur,
					"from": Board.square_to_world(rf), "to": Board.square_to_world(rt), "arc": 0.30})
				by_square.erase(rf)
				by_square[rt] = rook

		by_square.erase(String(mv["from"]))
		by_square[String(mv["to"])] = rec

	# падение белого короля после мата
	var king = by_square.get("g1")
	if king != null:
		var topple_dir := Vector3(-0.72, 0.0, 0.70)
		king["events"].append({"type": "fall", "t0": 160.9, "dur": 1.5,
			"dir": topple_dir, "pivot": Vector3(2.5, 0, 3.5) + topple_dir * 0.24, "side": -1.0})


# ---------------------------------------------------------------- анимация

func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _eval_piece(rec: Dictionary, t: float) -> void:
	var node: Node3D = rec["node"]
	var pos: Vector3 = Board.square_to_world(String(rec["start"]))
	var yaw: float = rec["yaw"]
	var fall = null
	for e in rec["events"]:
		if String(e["type"]) == "move":
			var t0: float = e["t0"]
			var d: float = e["dur"]
			if t >= t0:
				if t < t0 + d:
					var mu: float = (t - t0) / d
					var u := _ease(mu)
					pos = (e["from"] as Vector3).lerp(e["to"], u) + Vector3(0, float(e["arc"]) * sin(PI * mu), 0)
				else:
					pos = e["to"]
		elif String(e["type"]) == "fall":
			if t >= float(e["t0"]):
				fall = e
	rec["cur"] = pos
	if fall == null:
		node.position = pos
		node.basis = Basis(Vector3.UP, yaw)
		return
	var uu := clampf((t - float(fall["t0"])) / float(fall["dur"]), 0.0, 1.0)
	var ang := deg_to_rad(86.0) * (1.0 - pow(1.0 - uu, 3.0))
	if uu > 0.86:
		ang -= deg_to_rad(4.0) * sin((uu - 0.86) / 0.14 * PI)
	var fdir: Vector3 = fall["dir"]
	var axis := Vector3.UP.cross(fdir).normalized()
	var rot := Basis(axis, ang) * Basis(Vector3.UP, yaw)
	var pivot: Vector3 = fall["pivot"]
	node.basis = rot
	node.position = rot * (pos - pivot) + pivot


func _follow_pos(sq: String) -> Vector3:
	var rec = pieces.get(sq)
	if rec == null:
		return Vector3.ZERO
	return rec["cur"]


# ---------------------------------------------------------------- кадр

func _process(_delta: float) -> void:
	var t := start_t + float(frame) / fps
	_update(t)
	frame += 1
	if max_frames > 0 and frame >= max_frames:
		get_tree().quit()
	elif quit_at_end and t >= TL.TOTAL:
		get_tree().quit()


func _update(t: float) -> void:
	# холодный старт: свет проявляется из темноты
	var fade := clampf((t - 0.4) / 5.0, 0.0, 1.0)
	env.tonemap_exposure = 0.86 * (fade * fade * (3.0 - 2.0 * fade))
	for k in pieces:
		_eval_piece(pieces[k], t)
	var shot := TL.shot_at(t)
	var fp := _follow_pos(String(shot.get("sq", "")))
	var cam := TL.camera_at(t, fp, shot)
	camera.look_at_from_position(cam["pos"], cam["target"], Vector3.UP)
	camera.fov = cam["fov"]
	hud.update(t)
