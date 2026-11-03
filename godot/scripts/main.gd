extends Node3D
## Режиссёр: строит мир, разбирает партию в таймлайн, каждый кадр вычисляет
## состояние фигур, камеры и титров. Никакой физики — всё детерминировано.

const Board := preload("res://scripts/board.gd")
const Pieces := preload("res://scripts/pieces.gd")
const Mat := preload("res://scripts/mat.gd")
const Piece := preload("res://scripts/piece.gd")
const TL_V1 := preload("res://scripts/timeline.gd")
const TL_V2 := preload("res://scripts/timeline_v2.gd")
const HUD := preload("res://scripts/hud.gd")

var TL = TL_V1
var film := "v1"
var dump_cues := ""
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
var ghosts := {}     # призрачные фигуры варианта
var ghost_on := false
var by_square := {}  # текущая клетка -> запись


func _ready() -> void:
	_parse_args()
	var gdata := _load_game()
	if TL == TL_V2:
		TL.set_game(gdata)
	_build_environment()
	_build_board()
	_build_pieces_from_fen(_start_fen())
	_build_ghosts(gdata)
	_build_timeline(gdata)
	_build_floor()
	_build_dust()
	_build_camera()
	_build_hud()
	if dump_cues != "":
		_dump_cues(dump_cues)
		get_tree().quit()
	print("pieces=", pieces.size(), " tris=", Pieces.triangles(), " total=", TL.TOTAL)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--start="):
			start_t = float(a.substr(8))
		elif a.begins_with("--frames="):
			max_frames = int(a.substr(9))
		elif a.begins_with("--film="):
			film = a.substr(7)
		elif a.begins_with("--dump-cues="):
			dump_cues = a.substr(12)
		elif a.begins_with("--fps="):
			fps = float(a.substr(6))
	if film == "v2":
		TL = TL_V2


func _load_game() -> Dictionary:
	var path := "res://data/game2.json" if film == "v2" else "res://data/game.json"
	var f := FileAccess.open(path, FileAccess.READ)
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
	hud.TL = TL
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


func _ghost_material(white: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.60, 0.92, 1.0, 0.0) if white else Color(1.0, 0.42, 0.52, 0.0)
	m.emission_enabled = true
	m.emission = Color(0.35, 0.80, 1.0) if white else Color(1.0, 0.30, 0.42)
	m.emission_energy_multiplier = 1.4
	m.no_depth_test = false
	return m


func _build_ghosts(data: Dictionary) -> void:
	if film != "v2":
		return
	var fen := String(data["moves"][33]["fen"])
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
			var mi := MeshInstance3D.new()
			mi.mesh = Pieces.build(ch.to_lower())
			mi.material_override = _ghost_material(side == "w")
			mi.position = Board.square_to_world(sq)
			mi.visible = false
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			ghosts[sq] = mi
			file += 1


func _dim_real(a: float) -> void:
	for k in pieces:
		var node = pieces[k]["node"]
		var m: StandardMaterial3D = node.mat
		if m.albedo_color.a > 0.02:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = a


func _update_whatif(t: float) -> void:
	var t0: float = TL.WHATIF_T0
	var t1: float = TL.WHATIF_T1
	var fade := minf(clampf((t - t0) / 0.45, 0.0, 1.0), clampf((t1 - t) / 0.45, 0.0, 1.0))
	ghost_on = true
	var local := t - t0
	for sq in ghosts:
		var mi: MeshInstance3D = ghosts[sq]
		mi.visible = fade > 0.02
		mi.position = Board.square_to_world(sq)
		var m: StandardMaterial3D = mi.material_override
		m.albedo_color.a = 0.55 * fade
	for mv in TL.whatif_moves():
		var mt: float = mv["t"]
		if local < mt:
			continue
		var node: MeshInstance3D = ghosts.get(String(mv["from"]))
		if node == null:
			continue
		var a := Board.square_to_world(String(mv["from"]))
		var b := Board.square_to_world(String(mv["to"]))
		var u := clampf((local - mt) / 0.85, 0.0, 1.0)
		var e := u * u * (3.0 - 2.0 * u)
		node.position = a.lerp(b, e) + Vector3(0, 0.12 * sin(PI * u), 0)
	_dim_real(0.18)


func _end_whatif() -> void:
	if not ghost_on:
		return
	ghost_on = false
	for sq in ghosts:
		(ghosts[sq] as MeshInstance3D).visible = false
	for k in pieces:
		var node = pieces[k]["node"]
		var m: StandardMaterial3D = node.mat
		if m.albedo_color.a > 0.02:
			m.albedo_color.a = 1.0


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
		var t0: float = TL.schedule()[i]
		var dur: float = 1.15
		var arc := 0.20
		if String(mv["piece"]) == "n":
			arc = 0.40
		if bool(mv["mate"]):
			dur = 2.60 if film == "v1" else 1.90
			arc = 0.34
		if film == "v2":
			dur = clampf(TL._beat(i + 1) * 0.42, 1.0, 3.2)
			arc = 0.26
		rec["events"].append({"type": "move", "t0": t0, "dur": dur,
			"from": from, "to": to, "arc": arc})

		# взятие
		var victim = by_square.get(String(mv["to"]))
		if victim != null and victim != rec:
			var dir: Vector3 = (to - from)
			dir.y = 0
			dir = dir.normalized()
			var impact: float = t0 + (dur - 0.14 if bool(mv["mate"]) else 0.42)
			if film == "v2":
				var ctype := String(mv["capture"])
				var vmode := "fly"
				var vdur := 0.95
				if ctype == "p":
					vmode = "dust"
					vdur = 0.80
				elif ctype == "q":
					vmode = "spark"
					vdur = 1.05
				elif ctype == "k":
					vmode = "king"
					vdur = 1.60
				victim["events"].append({"type": "vanish", "t0": impact, "dur": vdur,
					"mode": vmode, "dir": dir})
			else:
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
	var vanish = null
	for e in rec["events"]:
		var et := String(e["type"])
		if et == "move":
			var t0: float = e["t0"]
			var d: float = e["dur"]
			if t >= t0:
				if t < t0 + d:
					var mu: float = (t - t0) / d
					var u := _ease(mu)
					pos = (e["from"] as Vector3).lerp(e["to"], u) + Vector3(0, float(e["arc"]) * sin(PI * mu), 0)
				else:
					pos = e["to"]
		elif et == "fall":
			if t >= float(e["t0"]):
				fall = e
		elif et == "vanish":
			if t >= float(e["t0"]):
				vanish = e

	# исчезновение съеденной фигуры
	if vanish != null:
		var v: Dictionary = vanish
		var uu := clampf((t - float(v["t0"])) / float(v["dur"]), 0.0, 1.0)
		var mode := String(v["mode"])
		var sc := 1.0
		var alpha := 1.0
		match mode:
			"fly":
				pos.y += 7.5 * uu * uu
				yaw += uu * 7.0
				sc = lerpf(1.0, 0.10, uu)
				alpha = 1.0 - smoothstep(0.45, 1.0, uu)
			"dust":
				pos.y -= 0.12 * uu
				sc = lerpf(1.0, 0.05, uu)
				alpha = 1.0 - uu * uu
			"spark":
				sc = lerpf(1.0, 0.02, uu)
				alpha = 1.0 - uu
			"king":
				pos.y += 2.8 * uu * uu
				sc = lerpf(1.0, 0.25, uu)
				alpha = 1.0 - smoothstep(0.5, 1.0, uu)
		rec["cur"] = pos
		node.position = pos
		node.basis = Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc, sc))
		var m: StandardMaterial3D = node.mat
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = alpha
		if mode == "spark":
			m.emission_enabled = true
			m.emission = Color(1.0, 0.65, 0.25)
			m.emission_energy_multiplier = 2.5 * (1.0 - uu)
		return

	rec["cur"] = pos
	if fall == null:
		node.position = pos
		node.basis = Basis(Vector3.UP, yaw)
		return
	var uu2 := clampf((t - float(fall["t0"])) / float(fall["dur"]), 0.0, 1.0)
	var ang := deg_to_rad(86.0) * (1.0 - pow(1.0 - uu2, 3.0))
	if uu2 > 0.86:
		ang -= deg_to_rad(4.0) * sin((uu2 - 0.86) / 0.14 * PI)
	var fdir: Vector3 = fall["dir"]
	var axis := Vector3.UP.cross(fdir).normalized()
	var rot := Basis(axis, ang) * Basis(Vector3.UP, yaw)
	var pivot: Vector3 = fall["pivot"]
	node.basis = rot
	node.position = rot * (pos - pivot) + pivot


func _dump_cues(path: String) -> void:
	var sched: Array = TL.schedule()
	var caps := []
	for c in TL._free:
		caps.append({"start": float(c[0]), "end": float(c[1]), "text": String(c[2])})
	for c in TL._ply_caps:
		var p0 := int(c[0])
		var p1 := int(c[1])
		var t0: float = sched[p0 - 1]
		var t1: float = (sched[p1] + 1.2) if p1 < 82 else (sched[81] + 9.0)
		caps.append({"start": t0, "end": t1, "text": String(c[2])})
	caps.sort_custom(func(a, b): return a["start"] < b["start"])
	for i in range(caps.size()):
		caps[i]["i"] = i + 1
	var moves := []
	var data := _load_game()
	for k in range(data["moves"].size()):
		moves.append({"t": float(sched[k]), "san": String(data["moves"][k]["san"])})
	var out := {"fps": 30, "duration": TL.TOTAL, "captions": caps, "moves": moves}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	print("cues: ", path, " реплик=", caps.size())


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
	if film == "v2":
		if TL.whatif_active(t):
			_update_whatif(t)
		else:
			_end_whatif()
	var shot := TL.shot_at(t)
	var fp := _follow_pos(String(shot.get("sq", "")))
	var cam := TL.camera_at(t, fp, shot)
	camera.look_at_from_position(cam["pos"], cam["target"], Vector3.UP)
	camera.fov = cam["fov"]
	hud.update(t)
