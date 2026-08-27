class_name ThemeMaterials
extends RefCounted
## Materials for one theme, built from Constants.THEME_MATERIALS — the same
## numbers the Python validator enforces. Nothing here invents a color.

static var _cache: Dictionary = {}

static func spec(theme: String) -> Dictionary:
	var all: Dictionary = Constants.THEME_MATERIALS
	return all.get(theme, all["void_glitch"])

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
