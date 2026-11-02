extends RefCounted
## Материалы: дерево (процедурная текстура), кость, эбен, латунь.

static var _cache := {}


static func _noise_hash(x: int, y: int, seed: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed * 144665) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


static func _wood_image(size: int, base: Color, dark: Color, density: float, seed: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var fx := float(x)
			var fy := float(y)
			# волокна вдоль X с медленным искривлением
			var warp := sin(fx * 0.013 + seed) * 11.0 + sin(fx * 0.041 + seed * 2.0) * 4.0
			var ring := sin((fy + warp) * density) * 0.5 + 0.5
			ring = pow(ring, 2.2)
			var grain := _noise_hash(x >> 1, y, seed) * 0.22
			var t := clampf(ring * 0.85 + grain, 0.0, 1.0)
			img.set_pixel(x, y, base.lerp(dark, t))
	return img


static func _tex(img: Image, repeat := true) -> ImageTexture:
	var t := ImageTexture.create_from_image(img)
	return t


static func wood(light := true) -> StandardMaterial3D:
	var key := "wood_l" if light else "wood_d"
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var base := Color("#b39b73") if light else Color("#40301f")
	var dark := Color("#8c7450") if light else Color("#241710")
	var img := _wood_image(256, base, dark, 0.235 if light else 0.19, 7 if light else 31)
	m.albedo_texture = _tex(img)
	m.albedo_color = Color(1, 1, 1)
	m.roughness = 0.44
	m.metallic = 0.0
	m.metallic_specular = 0.45
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.6, 1.6, 1.6)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cache[key] = m
	return m


static func ivory() -> StandardMaterial3D:
	if _cache.has("ivory"):
		return _cache["ivory"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#bdb098")
	m.roughness = 0.55
	m.metallic = 0.0
	m.metallic_specular = 0.35
	m.rim_enabled = true
	m.rim = 0.10
	m.rim_tint = 0.4
	_cache["ivory"] = m
	return m


static func ebony() -> StandardMaterial3D:
	if _cache.has("ebony"):
		return _cache["ebony"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#1e1d22")
	m.roughness = 0.46
	m.metallic = 0.05
	m.metallic_specular = 0.42
	m.rim_enabled = true
	m.rim = 0.14
	m.rim_tint = 0.2
	_cache["ebony"] = m
	return m


static func brass() -> StandardMaterial3D:
	if _cache.has("brass"):
		return _cache["brass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#7a5a26")
	m.metallic = 0.95
	m.roughness = 0.32
	_cache["brass"] = m
	return m


static func dark_wood() -> StandardMaterial3D:
	if _cache.has("dark_wood"):
		return _cache["dark_wood"]
	var m := StandardMaterial3D.new()
	var img := _wood_image(256, Color("#241a13"), Color("#100b08"), 0.21, 77)
	m.albedo_texture = _tex(img)
	m.roughness = 0.5
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(2.2, 2.2, 2.2)
	_cache["dark_wood"] = m
	return m


static func floor() -> StandardMaterial3D:
	if _cache.has("floor"):
		return _cache["floor"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#0c0b0d")
	m.roughness = 0.62
	m.metallic = 0.0
	_cache["floor"] = m
	return m
