class_name ThemeMaterials
extends RefCounted
## Materials for one theme, built from Constants.THEME_MATERIALS — the same
## numbers the Python validator enforces. Nothing here invents a color.

static var _cache: Dictionary = {}

static func spec(theme: String) -> Dictionary:
	var all: Dictionary = Constants.THEME_MATERIALS
	return all.get(theme, all["void_glitch"])

## The theme a source game reads as, matching the bridge EXACTLY: the
## pinned hint if there is one, else `THEMES[prng_seed(game,
## "fallback_theme") % len(THEMES)]`.
##
## `prng_seed` is sha256-based on purpose ("never use Python's built-in
## hash()", constants.py) — so this cannot use Godot's `hash()` either, or
## the Hub board and reveal card would colour a game differently from the
## theme the bridge actually built its Zone in.
static var _theme_cache: Dictionary = {}

static func theme_for_game(game: String) -> String:
	var hint: Dictionary = Constants.THEME_BY_GAME_HINT
	if hint.has(game):
		return hint[game]
	if _theme_cache.has(game):
		return _theme_cache[game]
	var themes: Array = Constants.THEMES
	var theme: String = themes[_prng_seed_mod(
			"%s|fallback_theme" % game, themes.size())]
	_theme_cache[game] = theme
	return theme

## `int.from_bytes(sha256(key)[:8], "big") % modulus`, computed byte by
## byte so the unsigned 64-bit value never has to fit in a signed int.
static func _prng_seed_mod(key: String, modulus: int) -> int:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(key.to_utf8_buffer())
	var digest := context.finish()
	var accumulator := 0
	for i in 8:
		accumulator = (accumulator * 256 + digest[i]) % modulus
	return accumulator

## A game's signature colour, for anywhere the multiworld is visualised.
static func color_for_game(game: String) -> Color:
	return Color(spec(theme_for_game(game))["accent_color"])

static func _material(theme: String, kind: String,
		noise_override: String = "") -> StandardMaterial3D:
	var key := "%s|%s|%s" % [theme, kind, noise_override]
	if _cache.has(key):
		return _cache[key]
	var s := spec(theme)
	var base := Color(s["base_color"])
	var accent := Color(s["accent_color"])
	var trim := Color(s["trim_color"])
	var noise: String = noise_override if noise_override != "" else s["noise"]
	var color := base
	match kind:
		"floor": color = base.darkened(0.15)
		"wall": color = base
		"accent": color = accent
		"trim": color = trim
	var material := StandardMaterial3D.new()
	material.albedo_texture = ProcTextures.get_texture(noise, color, accent)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = float(s["roughness"])
	material.uv1_scale = Vector3(0.25, 0.25, 0.25)  # ~4m per tile repeat
	material.uv1_triplanar = true
	_cache[key] = material
	return material

static func floor_mat(theme: String) -> StandardMaterial3D:
	return _material(theme, "floor")

static func wall_mat(theme: String) -> StandardMaterial3D:
	return _material(theme, "wall")

static func accent_mat(theme: String) -> StandardMaterial3D:
	return _material(theme, "accent", "panel")

static func trim_mat(theme: String) -> StandardMaterial3D:
	return _material(theme, "trim", "panel")

static func hazard_mat(theme: String) -> StandardMaterial3D:
	return _material(theme, "accent", "hazard")

static func light_color(theme: String) -> Color:
	return Color(spec(theme)["light_color"])

static func light_energy(theme: String) -> float:
	return float(spec(theme)["light_energy"])

static func void_color(theme: String) -> Color:
	return Color(spec(theme)["trim_color"]).darkened(0.6)

static func glow_material(color: Color, energy: float = 1.6) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
