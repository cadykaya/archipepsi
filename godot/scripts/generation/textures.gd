class_name ProcTextures
extends RefCounted
## Procedural 64x64 late-90s textures, generated in code at runtime.
## No image files ship; no asset shopping. NEAREST filtering everywhere.
##
## Each generator takes the theme's base color and returns a grimy,
## panel-lined, deliberately crude ImageTexture. Deterministic per
## (noise, color) so chambers of one theme agree.

const SIZE := 64

static var _cache: Dictionary = {}

static func get_texture(noise_name: String, base: Color,
		accent: Color) -> ImageTexture:
	var key := "%s|%s|%s" % [noise_name, base.to_html(), accent.to_html()]
	if _cache.has(key):
		return _cache[key]
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	match noise_name:
		"speckle": _speckle(image, rng, base, accent)
		"rust": _rust(image, rng, base, accent)
		"tile": _tile(image, rng, base, accent)
		"brick": _brick(image, rng, base, accent)
		"sandstone": _sandstone(image, rng, base, accent)
		"checker": _checker(image, rng, base, accent)
		"panel": _panel(image, rng, base, accent)
		"hazard": _hazard(image, rng, base, accent)
		_: _speckle(image, rng, base, accent)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

static func _vary(rng: RandomNumberGenerator, c: Color, amount: float) -> Color:
	var d := rng.randf_range(-amount, amount)
	return Color(clampf(c.r + d, 0, 1), clampf(c.g + d, 0, 1),
			clampf(c.b + d, 0, 1))

static func _fill_noise(image: Image, rng: RandomNumberGenerator,
		base: Color, amount: float) -> void:
	for y in SIZE:
		for x in SIZE:
			image.set_pixel(x, y, _vary(rng, base, amount))

static func _grime(image: Image, rng: RandomNumberGenerator,
		blotches: int, strength: float) -> void:
	for i in blotches:
		var cx := rng.randi_range(0, SIZE - 1)
		var cy := rng.randi_range(0, SIZE - 1)
		var r := rng.randi_range(3, 10)
		for y in range(maxi(0, cy - r), mini(SIZE, cy + r)):
			for x in range(maxi(0, cx - r), mini(SIZE, cx + r)):
				var dist := Vector2(x - cx, y - cy).length()
				if dist < r:
					var p := image.get_pixel(x, y)
					var f := strength * (1.0 - dist / r) * rng.randf()
					image.set_pixel(x, y, p.darkened(f))

static func _speckle(image: Image, rng: RandomNumberGenerator,
		base: Color, _accent: Color) -> void:
	_fill_noise(image, rng, base, 0.05)
	for i in 220:
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(0, SIZE - 1)
		image.set_pixel(x, y, _vary(rng, base.darkened(0.25), 0.1))
	# concrete seams every 32px
	for y in SIZE:
		image.set_pixel(31, y, base.darkened(0.3))
		image.set_pixel(32, y, base.lightened(0.08))
	_grime(image, rng, 4, 0.25)

static func _rust(image: Image, rng: RandomNumberGenerator,
		base: Color, accent: Color) -> void:
	_fill_noise(image, rng, base, 0.08)
	# corrugation stripes
	for x in SIZE:
		var band := absf(sin(x * TAU / 16.0))
		for y in SIZE:
			var p := image.get_pixel(x, y)
			image.set_pixel(x, y, p.darkened(band * 0.18))
	# rust streaks bleeding downward
	for i in 14:
		var x := rng.randi_range(0, SIZE - 1)
		var start_y := rng.randi_range(0, 20)
		var length := rng.randi_range(8, 40)
		for y in range(start_y, mini(SIZE, start_y + length)):
			var p := image.get_pixel(x, y)
			image.set_pixel(x, y, p.lerp(accent, 0.35 * rng.randf()))
	_grime(image, rng, 6, 0.3)

static func _tile(image: Image, rng: RandomNumberGenerator,
		base: Color, accent: Color) -> void:
	_fill_noise(image, rng, base, 0.03)
	for y in SIZE:
		for x in SIZE:
			if x % 16 == 0 or y % 16 == 0:
				image.set_pixel(x, y, base.darkened(0.45))
			elif x % 16 == 1 or y % 16 == 1:
				image.set_pixel(x, y, base.lightened(0.10))
	# one accent tile
	var tx := rng.randi_range(0, 3) * 16
	var ty := rng.randi_range(0, 3) * 16
	for y in range(ty + 2, ty + 15):
		for x in range(tx + 2, tx + 15):
			if x < SIZE and y < SIZE:
				image.set_pixel(x, y, _vary(rng, accent, 0.05))
	_grime(image, rng, 3, 0.2)

static func _brick(image: Image, rng: RandomNumberGenerator,
		base: Color, _accent: Color) -> void:
	_fill_noise(image, rng, base, 0.06)
	var mortar := base.darkened(0.5)
	for row in 4:
		var y0 := row * 16
		for x in SIZE:
			image.set_pixel(x, y0, mortar)
			image.set_pixel(x, mini(y0 + 1, SIZE - 1), mortar)
		var offset := 16 if row % 2 == 1 else 0
		for col in 3:
			var x0 := (col * 32 + offset) % SIZE
			for y in range(y0, mini(y0 + 16, SIZE)):
				image.set_pixel(x0, y, mortar)
	_grime(image, rng, 6, 0.35)

static func _sandstone(image: Image, rng: RandomNumberGenerator,
		base: Color, accent: Color) -> void:
	_fill_noise(image, rng, base, 0.07)
	# strata bands
	for y in SIZE:
		var band := sin(y * TAU / 24.0 + 1.3) * 0.08
		for x in SIZE:
			var p := image.get_pixel(x, y)
			image.set_pixel(x, y, p.darkened(maxf(0.0, band)))
	# cracks
	for i in 5:
		var x := rng.randi_range(4, SIZE - 5)
		for y in range(rng.randi_range(0, 20), rng.randi_range(30, SIZE)):
			x = clampi(x + rng.randi_range(-1, 1), 0, SIZE - 1)
			image.set_pixel(x, y, base.darkened(0.4))
	# root intrusion, occasionally
	for i in 2:
		var y := rng.randi_range(0, SIZE - 1)
		for x in range(0, rng.randi_range(10, 30)):
			y = clampi(y + rng.randi_range(-1, 1), 0, SIZE - 1)
			image.set_pixel(x, y, accent.darkened(0.2))
	_grime(image, rng, 4, 0.2)

static func _checker(image: Image, _rng: RandomNumberGenerator,
		base: Color, accent: Color) -> void:
	# The classic missing-texture checker, void_glitch's whole personality.
	for y in SIZE:
		for x in SIZE:
			var cell := (x / 8 + y / 8) % 2
			image.set_pixel(x, y, accent if cell == 0 else base)

static func _panel(image: Image, rng: RandomNumberGenerator,
		base: Color, _accent: Color) -> void:
	_fill_noise(image, rng, base, 0.04)
	for y in SIZE:
		for x in SIZE:
			if x % 32 == 0 or y % 32 == 0:
				image.set_pixel(x, y, base.darkened(0.4))
	# rivets
	for py in [4, 28, 36, 60]:
		for px in [4, 28, 36, 60]:
			image.set_pixel(px, py, base.lightened(0.25))
	_grime(image, rng, 3, 0.2)

static func _hazard(image: Image, rng: RandomNumberGenerator,
		base: Color, accent: Color) -> void:
	for y in SIZE:
		for x in SIZE:
			var stripe := int((x + y) / 8.0) % 2
			image.set_pixel(x, y, accent if stripe == 0 else base.darkened(0.6))
	_grime(image, rng, 3, 0.25)
