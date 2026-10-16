class_name WeaponArt
extends RefCounted
## ARTY'S FIVE WEAPONS ON PROD'S RIG (unified integration 1).
##
## Ported from her reference capture, `tools/crossing_capture/
## five_integration.gd` (`_swap`, `_apply_lean`, `_tex`), on the branch
## `claude/archipepsi-art-weapon-integration-2026-10-14` (a5d322f9), per her
## note `docs/art-requests/2026-10-14-five-weapon-integration-note.md`:
##
## * each model is one geometry GLB swapped in under the rig's `models[w]`
##   node; the rig's own `Muzzle`, `ChargeOrb` and `ChargeLight` are KEPT;
## * one material per weapon from its five lean maps -- NEAREST with
##   mipmaps, the normal map as RG8 (converted at load), roughness and
##   metallic from grey, emission from the lamp mask with the MULTIPLY
##   operator (ADD paints the whole gun green);
## * the rig's moving parts are pointed at the art's nodes by the names the
##   rig already uses; the Foundry's carousel goes through her
##   `CarouselDrive` adapter (the rig's drum turns on Y, the art's on Z);
## * the Driver's core glow is a duplicate of its own lean material with
##   ADD emission at the rig's colour, handed to `material_override`, so the
##   rig's charge look drives it and the painting survives.
##
## THE ONE DEPARTURE, and why: her capture read the PNGs with
## `Image.load_from_file`, which finds nothing in an exported build (only
## the imported copies ship). Here every map is the imported texture, set
## to her import settings (Lossless, mipmaps on, no 3D VRAM detection), and
## the normal is read back with `get_image()` to convert it to RG8.
##
## Timings, recoil, readiness, ADS, muzzles and effects are untouched: the
## art only replaces what the placeholder blocks looked like.

const ROOT := "res://content/weapons/"
const RIG_OWNED := ["Muzzle", "ChargeOrb", "ChargeLight"]
const PARTS := {
	"foundry": {"hammer": "Hammer", "cylinder": "Carousel"},
	"sightline": {"handle": "Handle"},
	"switchback": {"bolt": "Bolt"},
	"bulkhead": {"pump": "Pump", "feed": "Feed"},
	"driver": {"coils": "Coils", "core": "Core"},
}
## The rig's own core glow colour (RangeRig's driver core).
const CORE_GLOW := Color(0.85, 0.85, 1.0)

static var _materials := {}


## Dresses every weapon on `rig`. Returns the ids dressed; a weapon whose
## art is missing keeps its placeholder (and the failure is printed).
static func dress(rig: Node) -> Array[String]:
	var done: Array[String] = []
	for w: String in PARTS:
		if _dress_one(rig, w):
			done.append(w)
	return done


static func _dress_one(rig: Node, w: String) -> bool:
	var models: Dictionary = rig.get("models")
	var model: Node3D = models.get(w)
	var packed := load(ROOT + "%s/%s_geo.glb" % [w, w]) as PackedScene
	if model == null or packed == null:
		push_error("weapon art: %s is missing (model or GLB)" % w)
		return false
	var scene := packed.instantiate() as Node3D
	scene.name = "WeaponArt"
	for child in model.get_children():
		if not String(child.name) in RIG_OWNED:
			model.remove_child(child)
			child.queue_free()
	model.add_child(scene)
	var lean := _material(w)
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			mesh.surface_set_material(s, lean)
	var parts: Dictionary = rig.get("_parts")
	var names: Dictionary = PARTS[w]
	for key: String in names:
		var node := scene.find_child(String(names[key]), true, false) as Node3D
		if node == null:
			push_error("weapon art: %s has no %s" % [w, names[key]])
			continue
		parts[w + "/" + key] = node
	if w == "foundry" and parts.get("foundry/cylinder") is Node3D:
		var carousel := parts["foundry/cylinder"] as Node3D
		var drive := Node3D.new()
		drive.name = "CarouselDrive"
		carousel.get_parent().add_child(drive)
		drive.position = carousel.position
		drive.basis = Basis(Vector3.RIGHT, PI / 2.0)
		carousel.get_parent().remove_child(carousel)
		drive.add_child(carousel)
		carousel.position = Vector3.ZERO
		carousel.basis = Basis(Vector3.RIGHT, -PI / 2.0)
		parts["foundry/cylinder"] = drive
	if w == "driver" and parts.get("driver/core") is MeshInstance3D:
		var core := parts["driver/core"] as MeshInstance3D
		var own := core.mesh.surface_get_material(0) as StandardMaterial3D
		var glow := own.duplicate() as StandardMaterial3D if own != null \
				else StandardMaterial3D.new()
		glow.emission_enabled = true
		glow.emission_texture = null
		glow.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
		glow.emission = CORE_GLOW
		glow.emission_energy_multiplier = 0.0
		core.material_override = glow
	return true


## One material per weapon, built once.
static func _material(w: String) -> StandardMaterial3D:
	if _materials.has(w):
		return _materials[w]
	var dir := ROOT + w + "/lean/"
	var rec: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(dir + "lean.json"))
	var m := StandardMaterial3D.new()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.albedo_texture = load(dir + "albedo.png")
	m.normal_enabled = true
	m.normal_texture = _rg8(load(dir + "normal.png") as Texture2D)
	m.roughness = 1.0
	m.roughness_texture = load(dir + "roughness.png")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.metallic = 1.0
	m.metallic_texture = load(dir + "metallic.png")
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.emission_enabled = true
	m.emission_texture = load(dir + "emission.png")
	m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	if rec is Dictionary and (rec as Dictionary).has("emission_colour_srgb"):
		var c: Array = rec["emission_colour_srgb"]
		m.emission = Color(c[0], c[1], c[2])
	_materials[w] = m
	return m


## Godot reads a normal map's X and Y and rebuilds Z, so RG8 holds all it
## uses at half the memory of the padded RGBA8 (Arty's measurement).
static func _rg8(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return tex
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RG8)
	if not img.has_mipmaps():
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
